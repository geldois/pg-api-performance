# Próximos testes

Ideias com status "Pesquisada, teste futuro": apareceram na pesquisa ou nas medições, mas não foram testadas aqui. Cada ficha diz de onde a ideia veio, o que eu acredito que ganharia (como hipótese, sem resultado), como testaria, o que precisaria para testar e por que não testei. Nenhum número de ganho aparece abaixo, porque nada disso foi medido. Os números que cito como motivo vêm dos arquivos de `diagnostico/` e `resultados/`.

## 1. View materializada por dia para `/relatorios/vendas-por-dia`

**De onde veio:** a medição de CPU do banco por rota depois da 14 (`diagnostico/32-cpu-do-banco-por-rota-depois-da-14.txt`): `vendas-por-dia` gasta 82,22 ms de CPU do banco por requisição e, pela conta de composição desse arquivo, responde por 66,6% do CPU do banco sob carga. Fontes: [PostgreSQL 16, 41.3 Materialized Views](https://www.postgresql.org/docs/16/rules-materializedviews.html), que diz que "the data is not always current; yet sometimes current data is not needed", e [PostgreSQL 16, REFRESH MATERIALIZED VIEW](https://www.postgresql.org/docs/16/sql-refreshmaterializedview.html), que diz que o comando "completely replaces the contents of a materialized view" e que a opção `CONCURRENTLY` exige "at least one `UNIQUE` index on the materialized view". Acesso em 2026-11-20.

**O que eu acredito que ganharia (hipótese):** uma view com uma linha por dia (pedidos distintos, itens e receita, sem pedidos cancelados, como a rota faz hoje em `api/src/rotas.js`) tiraria do banco a soma das linhas de itens do período a cada requisição. Como o banco está no teto de 1 CPU, eu acredito que o req/s geral subiria e o p95 de `vendas-por-dia` cairia. É só hipótese.

**Como testaria:** um `.sql` novo em `banco/` com a view e um índice único em `dia`, a rota lendo a view no intervalo pedido, a equivalência contra a rota atual nas mesmas 545 janelas de `diagnostico/30`, o contrato e três medições com o mesmo rótulo.

**O que precisaria:** recriar o banco (`docker compose down -v`), porque o `.sql` novo só roda na criação. Também precisaria decidir como a view se atualiza em produção (`REFRESH MATERIALIZED VIEW CONCURRENTLY` periódico, ou uma tabela de resumo atualizada a cada pedido novo), porque a API desta aplicação só tem rotas `GET` e os dados não mudam durante o uso.

**Por que não testei aqui:** o tempo disponível nesta entrega foi para as mudanças 12 a 14 e para o artigo. O custo que ficaria sem resposta é o de manter a view atualizada num sistema que recebe pedidos novos.

## 2. Índice trigrama para `/produtos/busca?q=`

**De onde veio:** a mesma medição de CPU do banco: `busca-produtos` gasta 16,70 ms de CPU do banco por requisição e responde por 25,3% do CPU do banco sob carga (`diagnostico/32-cpu-do-banco-por-rota-depois-da-14.txt`). A consulta usa `nome ILIKE '%' || $1 || '%'`, que um índice comum não atende por causa do `%` no início. Fonte: [PostgreSQL 16, F.35 pg_trgm](https://www.postgresql.org/docs/16/pgtrgm.html), que diz que os índices `GIN` e `GiST` com trigramas aceitam buscas `LIKE` e `ILIKE` e que "the search string need not be left-anchored", e avisa que "a pattern with no extractable trigrams will degenerate to a full-index scan". Acesso em 2026-11-20.

**O que eu acredito que ganharia (hipótese):** um índice `GIN` com `gin_trgm_ops` em `produtos(nome)` trocaria a leitura de todos os produtos por uma busca no índice, e o CPU do banco por requisição de `busca-produtos` cairia. Isso vale para termos de 3 ou mais letras, e a rota já recusa menos que isso. É só hipótese.

**Como testaria:** `EXPLAIN (ANALYZE, BUFFERS)` da consulta antes e depois, a equivalência da resposta com termos com `%` e `_` (que hoje são curingas e precisam continuar sendo) e com a ordem `nome, id` do `LIMIT 20`, o contrato e três medições.

**O que precisaria:** conferir que a extensão `pg_trgm` existe na imagem do PostgreSQL usada e criá-la num `.sql` novo em `banco/`, com o banco recriado. Precisaria medir o tamanho do índice e o tempo de construção, porque índice maior consome memória, e o banco já chegou ao limite de 512 MiB na 07 (`diagnostico/13-memoria-do-banco-na-07.txt`).

**Por que não testei aqui:** a busca não foi diagnosticada com `EXPLAIN` (consta como não diagnosticada em `diagnostico/indice.md`), e o tempo disponível nesta entrega não deixou espaço para diagnosticar e medir.

## 3. Perfil de CPU da API

**De onde veio:** na 13, tirar o corpo da resposta do log não mudou o CPU da API, e eu escrevi que não sei o que consome a CPU dela porque não fiz um perfil (`experimentos.md`, seção 13). Depois da 14 a API deixou de ser o limite, mas o perfil mostraria o que sobrou. Fonte: [Node.js, Command-line API, `--cpu-prof`](https://nodejs.org/api/cli.html), que diz que a opção "Starts the V8 CPU profiler on start up, and writes the CPU profile to disk". Acesso em 2026-11-20.

**O que eu acredito que ganharia (hipótese):** eu esperaria ver o trabalho de ler e somar as linhas de `vendas-por-dia` dominando o perfil da versão anterior à 14. Para a versão atual não tenho palpite, e é isso que o teste mostraria.

**Como testaria:** subir a API com `node --cpu-prof src/server.js` numa cópia do `Dockerfile`, rodar a carga e abrir o `.cpuprofile` num visualizador de perfis.

**O que precisaria:** mudar o `command` da API só para o diagnóstico (e desfazer depois), e um visualizador de `.cpuprofile`.

**Por que não testei aqui:** mudar o comando da API muda o que se mede, e eu preferi medir o CPU por rota pelo cgroup, que não muda a aplicação (`diagnostico/28` e `31`).

## 4. Parâmetros do PostgreSQL sob 512 MiB

**De onde veio:** o banco chegou ao limite de memória de 512 MiB e usou swap em várias execuções da 07 (`diagnostico/13-memoria-do-banco-na-07.txt`), e roda com a configuração padrão. Fontes: [PostgreSQL 16, 20.4 Resource Consumption](https://www.postgresql.org/docs/16/runtime-config-resource.html), que diz que "a reasonable starting value for `shared_buffers` is 25% of the memory in your system" num servidor dedicado de 1 GB ou mais, e que cada operação de ordenação ou de hash pode usar até o valor de `work_mem`, e [PostgreSQL 16, 32.2 When to JIT?](https://www.postgresql.org/docs/16/jit-decision.html), que diz que "For short queries the added overhead of performing JIT compilation will often be higher than the time it can save". Acesso em 2026-11-20.

**O que eu acredito que ganharia (hipótese):** desligar o JIT poderia poupar CPU de compilação em consultas curtas, e ajustar `shared_buffers` e `work_mem` poderia reduzir o uso de memória e de disco. Eu não sei se os valores padrão já são adequados para estes dados. É só hipótese.

**Como testaria:** um parâmetro por mudança, no `command` do serviço `banco` do `docker-compose.yml`, com uma hipótese em uma frase, o contrato e três medições cada.

**O que precisaria:** um critério para escolher os valores (as fontes dão pontos de partida, não valores para este caso), e atenção ao limite de 512 MiB, porque o banco foi encerrado por falta de memória na tentativa de desligar o swap (`experimentos.md`, seção 07).

**Por que não testei aqui:** cada parâmetro é uma mudança com três medições, e o tempo disponível nesta entrega não comportou.

## 5. Limites menores de memória e CPU

**De onde veio:** a pergunta do desafio, que também aparece no `AGENTS.md`, é deixar a aplicação "mais rápida e mais barata de rodar". A memória média da API caiu de 54,3 para 27,9 MiB e a do banco de 296,5 para 201,9 MiB entre a linha de base e a 14 (`recursos.txt` das pastas), contra limites de 256 MiB e 512 MiB. A origem desta ideia é a própria medição, e não uma fonte externa.

**O que eu acredito que ganharia (hipótese):** a API provavelmente funcionaria com bem menos que 256 MiB e com menos CPU, o que reduziria o custo de rodar. O banco tem menos folga, porque chegou ao limite de memória na 07 (`diagnostico/13-memoria-do-banco-na-07.txt`), embora a memória média dele na 14 seja de 201,9 MiB.

**Como testaria:** baixar o limite da API em passos no `docker-compose.yml`, medir três vezes em cada passo e desenhar a curva do p95 e do req/s contra o limite, parando no primeiro passo que piora a medição ou gera erro.

**O que precisaria:** declarar no artigo que o antes e o depois da comparação principal usam os limites originais, e esta curva fica como medida à parte. Também precisaria de uma leitura de CPU confiável, que neste ambiente só o cgroup dá.

**Por que não testei aqui:** a comparação principal deste trabalho usa os limites originais (`contexto.txt` de cada pasta), então esta medida entraria como mudança própria no fim, e não coube no tempo disponível.
