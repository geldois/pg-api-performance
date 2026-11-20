# Experimentos

Uma linha por ideia aplicada na tabela, e os detalhes de cada uma na seção logo abaixo. O "antes" de cada mudança é a linha de base ou a mudança anterior, e a seção diz qual. Todo número de antes e depois vem dos arquivos de `resultados/` (medianas e faixas das três execuções), e os de diagnóstico vêm de arquivos em `diagnostico/`. Os parâmetros de carga são os mesmos em todas as medições: 20 usuários virtuais, 60 s, semente 42.

| # | Ideia | Fonte | Status | Antes | Depois | Pastas | Conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | Índice em `itens_pedido(pedido_id)` | [PostgreSQL 16, 11.1](https://www.postgresql.org/docs/16/indexes-intro.html) | Aplicada e medida | 4,21 req/s, p95 14.698,7 ms | 7,59 req/s, p95 7.672,0 ms | Antes: `resultados/20261114-*-00-linha-de-base` (3). Depois: `resultados/20261118-*-01-indice-itens-pedido` (3) | `pedidos-do-cliente` caiu de 15.928,5 para 6.402,3 ms, mas o N+1 continua |
| 02 | Pool de conexões (`pg.Pool`, `max` 10) | [node-postgres, Pooling](https://node-postgres.com/features/pooling) e [node-postgres, Pool](https://node-postgres.com/apis/pool) | Aplicada e medida | 7,59 req/s, p95 7.672,0 ms | 9,12 req/s, p95 6.918,9 ms | Antes: `resultados/20261118-17*-01-indice-itens-pedido` (3). Depois: `resultados/20261118-18*-02-pool-de-conexoes` (3) | Melhorou o geral, mas `pedidos-do-cliente`, `cliente` e `busca-produtos` ficaram mais lentas |
| 03 | Consulta única com `LEFT JOIN` em `/clientes/:id/pedidos` | [Rails Guides, N+1](https://guides.rubyonrails.org/active_record_querying.html) e [PostgreSQL 16, 7.2](https://www.postgresql.org/docs/16/queries-table-expressions.html) | Aplicada e medida | 9,12 req/s, p95 6.918,9 ms | 9,75 req/s, p95 5.123,3 ms | Antes: `resultados/20261118-18*-02-pool-de-conexoes` (3). Depois: `resultados/20261118-20*-03-join-pedidos-do-cliente` (3) | `pedidos-do-cliente` caiu de 8.513,6 para 2.773,3 ms, e as rotas leves pioraram |
| 04 | Pool com `max` 20, igual ao número de usuários da carga | [node-postgres, Pooling](https://node-postgres.com/features/pooling) e [node-postgres, Pool sizing](https://node-postgres.com/guides/pool-sizing) | Aplicada, sem ganho | 9,75 req/s, p95 5.123,3 ms | 9,66 req/s, p95 7.399,6 ms | Antes: `resultados/20261118-20*-03-join-pedidos-do-cliente` (3). Depois: `resultados/20261118-20*-04-pool-max-20` (3) | As rotas leves voltaram a ser rápidas, as pesadas ficaram mais lentas e o p95 geral piorou |
| 05 | Índice `(status, criado_em DESC, id DESC)` em `pedidos` | [PostgreSQL 16, 11.4](https://www.postgresql.org/docs/16/indexes-ordering.html) e [PostgreSQL 16, 11.3](https://www.postgresql.org/docs/16/indexes-multicolumn.html) | Aplicada e medida | 9,66 req/s, p95 7.399,6 ms | 13,64 req/s, p95 4.738,1 ms | Antes: `resultados/20261118-20*-04-pool-max-20` (3). Depois: `resultados/20261118-21*-05-indice-pedidos-status` (3) | `pedidos-por-status` caiu de 9.358,0 para 3.259,3 ms e o req/s geral subiu |
| 06 | Índice `(cliente_id, criado_em DESC, id DESC)` em `pedidos` | [PostgreSQL 16, 11.3](https://www.postgresql.org/docs/16/indexes-multicolumn.html) e [PostgreSQL 16, 11.4](https://www.postgresql.org/docs/16/indexes-ordering.html) | Aplicada e medida | 13,64 req/s, p95 4.738,1 ms | 19,6 req/s, p95 5.303,5 ms | Antes: `resultados/20261118-21*-05-indice-pedidos-status` (3). Depois: `resultados/20261119-*-06-indice-pedidos-cliente` (3) | `pedidos-do-cliente` caiu de 3.673,6 para 170,9 ms e o req/s subiu, com o p95 geral na mesma faixa |
| 07 | Filtro por intervalo em `criado_em` e índice em `pedidos(criado_em)` | [PostgreSQL 16, 11.1](https://www.postgresql.org/docs/16/indexes-intro.html) e [PostgreSQL 16, 11.7](https://www.postgresql.org/docs/16/indexes-expressional.html) | Aplicada e medida | 19,6 req/s, p95 5.303,5 ms | 20,52 req/s, p95 2.718,4 ms | Antes: `resultados/20261119-125*-06-indice-pedidos-cliente` (3). Depois: as 5 pastas `resultados/20261119-*-07-indice-pedidos-criado-em` listadas na seção | `vendas-por-dia` caiu de 7.587,1 para 3.698,9 ms e o p95 geral caiu, mas quatro rotas ficaram mais lentas e o banco ficou instável sob o limite de memória |
| 08 | `top-produtos` lê a view materializada `vendas_por_produto` | [PostgreSQL 16, 41.3 Materialized Views](https://www.postgresql.org/docs/16/rules-materializedviews.html) | Aplicada e medida | 20,52 req/s, p95 2.718,4 ms | 41,45 req/s, p95 1.644,1 ms | Antes: as 5 pastas `resultados/20261119-*-07-indice-pedidos-criado-em` listadas na seção 07. Depois: `resultados/20261119-19*-08-top-produtos-view` (3) | `top-produtos` caiu de 32.719,5 para 415,3 ms e o req/s dobrou, mas `cliente` e `pedidos-do-cliente` ficaram mais lentas |
| 09 | `/pedidos` lê o total da view materializada `contagem_pedidos_por_status` | [PostgreSQL 16, 41.3 Materialized Views](https://www.postgresql.org/docs/16/rules-materializedviews.html) | Aplicada e medida | 41,45 req/s, p95 1.644,1 ms | 46,39 req/s, p95 1.532,5 ms | Antes: `resultados/20261119-19*-08-top-produtos-view` (3). Depois: `resultados/20261119-20*-09-pedidos-total-view` (3) | O req/s subiu e a mediana de `pedidos-por-status` caiu de 870,8 para 276,3 ms, mas o p95 da rota e o geral ficaram na mesma faixa |
| 10 | Índice `(status, criado_em DESC, id DESC) INCLUDE (cliente_id)` no lugar do `indice_pedidos`, e a página de `/pedidos` só com as 4 colunas da resposta | [PostgreSQL 16, 11.9 Index-Only Scans and Covering Indexes](https://www.postgresql.org/docs/16/indexes-index-only-scans.html) e [PostgreSQL 16, CREATE INDEX](https://www.postgresql.org/docs/16/sql-createindex.html) | Aplicada e medida | 46,39 req/s, p95 1.532,5 ms | 52,09 req/s, p95 1.298,8 ms | Antes: `resultados/20261119-20*-09-pedidos-total-view` (3). Depois: `resultados/20261119-22*-10-pedidos-indice-cobrindo` (3) | O p95 de `pedidos-por-status` caiu de 2.026,7 para 683,4 ms e o p95 geral também caiu, mas `cliente`, `pedidos-do-cliente` e `busca-produtos` ficaram mais lentas |
| 11 | Índice `(lower(email), id)` em `clientes` | [PostgreSQL 16, 11.7](https://www.postgresql.org/docs/16/indexes-expressional.html) e [PostgreSQL 16, 11.3](https://www.postgresql.org/docs/16/indexes-multicolumn.html) | Aplicada e medida | 52,09 req/s, p95 1.298,8 ms | 60,43 req/s, p95 972,5 ms | Antes: `resultados/20261119-22*-10-pedidos-indice-cobrindo` (3). Depois: `resultados/20261119-22*-11-clientes-indice-email` (3) | O p95 de `cliente-por-email` caiu de 1.616,0 para 709,6 ms e o p95 geral também caiu, mas `pedidos-por-status`, `cliente` e `pedidos-do-cliente` ficaram mais lentas |

## 01 Índice em `itens_pedido(pedido_id)`

**Rótulo:** `01-indice-itens-pedido`

**Ideia e fonte:** criar um índice em `itens_pedido(pedido_id)`. Fonte: [PostgreSQL 16, 11.1 Introduction](https://www.postgresql.org/docs/16/indexes-intro.html), acesso em 2026-11-18.

**Status:** Aplicada e medida.

**Hipótese** (commit `b572ea1`): criar um índice em `itens_pedido(pedido_id)` deve reduzir muito o p95 de `/clientes/:id/pedidos`, porque cada consulta de itens deixa de ler as 1,5 milhão de linhas da tabela. Deve reduzir menos o de `/relatorios/vendas-por-dia`, conforme o tamanho da janela, porque a leitura de `pedidos` continua inteira. Não deve mudar `/relatorios/top-produtos`, que lê quase toda a tabela e mantém a varredura sequencial.

**Antes usado:** linha de base.
- `resultados/20261114-221918-00-linha-de-base`
- `resultados/20261114-222114-00-linha-de-base`
- `resultados/20261114-222316-00-linha-de-base`

**Depois:**
- `resultados/20261118-170530-01-indice-itens-pedido`
- `resultados/20261118-170703-01-indice-itens-pedido`
- `resultados/20261118-170835-01-indice-itens-pedido`

**Resultado** (medianas das três execuções, antes → depois):
- Requisições por segundo: 4,21 → 7,59
- p95 geral: 14.698,7 → 7.672,0 ms
- p95 de `pedidos-do-cliente`: 15.928,5 → 6.402,3 ms
- p95 de `vendas-por-dia`: 9.371,5 → 8.556,8 ms
- p95 de `top-produtos`: 15.304,3 → 27.371,0 ms
- Memória média do banco: 296,5 → 331,8 MiB. Da API: 54,3 → 68,9 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado (ver `diagnostico/00-cpu-por-cgroup-linha-de-base.txt`)

**Conclusão:** o índice reduziu o p95 de `pedidos-do-cliente`, mas o número de consultas do N+1 continua o mesmo, e o p95 da rota ainda é 6.402,3 ms. A explicação provável é que cada consulta de itens passou a usar uma busca em árvore em vez de ler as 1,5 milhão de linhas. É só provável porque não há `EXPLAIN` da consulta de itens com o índice em `diagnostico/`. `vendas-por-dia` melhorou pouco, e as faixas das execuções se sobrepõem (índice 8.282,2 a 9.777,6 ms, linha de base 9.331,0 a 10.427,0 ms). `top-produtos` piorou, com só 6 ou 7 requisições por execução, e a causa ainda é hipótese: o banco, limitado a 1 CPU, atende mais requisições das outras rotas.

**Contra a hipótese do commit:** `pedidos-do-cliente` caiu como previsto (15.928,5 para 6.402,3 ms). A mediana de `vendas-por-dia` também caiu, mas as faixas se sobrepõem, então a queda não se distingue da variação, e a relação com o tamanho da janela não foi medida, porque o resumo não separa a rota por janela. A previsão de que `top-produtos` não mudaria errou: ele foi de 15.304,3 para 27.371,0 ms, com faixas sem sobreposição (13.543,5 a 19.539,9 ms antes e 24.936,9 a 29.205,5 ms depois). Sobre o critério do commit (`top-produtos` melhorar, ou o plano da consulta de itens continuar em `Seq Scan`): a primeira condição não se cumpriu, porque `top-produtos` piorou em vez de melhorar, e a segunda não foi avaliada, porque não há `EXPLAIN` da consulta de itens com o índice. Pela parte medida, a hipótese não foi refutada.

**O que refutaria:** `top-produtos` melhorar, ou o plano da consulta de itens continuar em `Seq Scan`.

## 02 Pool de conexões

**Rótulo:** `02-pool-de-conexoes`

**Ideia e fonte:** trocar a conexão nova a cada consulta por um `pg.Pool` com `max` 10, o padrão. Fontes: [node-postgres, Pooling](https://node-postgres.com/features/pooling), que afirma que conectar um cliente novo exige um handshake que "can take 20-30 milliseconds", sem dizer como mediu, e [node-postgres, Pool](https://node-postgres.com/apis/pool), que diz sobre o `max` que "By default this is set to 10". Acesso em 2026-11-18. O número de 20 a 30 milissegundos não é uma medição deste trabalho.

**Status:** Aplicada e medida.

**Hipótese** (commit `e3fe8e5`): trocar a conexão nova a cada consulta por um pool (`max` 10, o padrão do `pg`) deve reduzir o custo fixo que vem antes de cada consulta (rede, CPU e processo novo no banco). O ganho deve ser maior nas rotas que fazem mais consultas por requisição, como `/clientes/:id/pedidos` (1 + 1 + P + I consultas), e pequeno nas rotas de uma consulta única e pesada, como `top-produtos` e `vendas-por-dia`.

**Antes usado:** mudança 01.
- `resultados/20261118-170530-01-indice-itens-pedido`
- `resultados/20261118-170703-01-indice-itens-pedido`
- `resultados/20261118-170835-01-indice-itens-pedido`

**Depois:**
- `resultados/20261118-181942-02-pool-de-conexoes`
- `resultados/20261118-182111-02-pool-de-conexoes`
- `resultados/20261118-182243-02-pool-de-conexoes`

**Execuções descartadas:** seis execuções anteriores com o mesmo rótulo não entraram na mediana nem no repositório, porque a checagem de memória do banco acusou uso de swap. A leitura bruta dessa checagem não foi salva, então este registro não cita o valor. As três execuções acima foram feitas depois de reiniciar os containers.

**Resultado** (medianas das três execuções, antes → depois):
- Requisições por segundo: 7,59 → 9,12
- p95 geral: 7.672,0 → 6.918,9 ms
- p95 de `pedidos-do-cliente`: 6.402,3 → 8.513,6 ms
- p95 de `cliente`: 198,9 → 610,5 ms
- p95 de `busca-produtos`: 640,2 → 830,9 ms
- p95 de `cliente-por-email`: 1.361,7 → 1.220,5 ms
- p95 de `pedidos-por-status`: 9.200,1 → 5.685,2 ms
- p95 de `vendas-por-dia`: 8.556,8 → 4.511,2 ms
- p95 de `top-produtos`: 27.371,0 → 16.655,4 ms
- Memória média do banco: 331,8 → 274,7 MiB. Da API: 68,9 → 36,7 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** o req/s subiu de 7,59 para 9,12 e o p95 geral caiu de 7.672,0 para 6.918,9 ms. O ganho apareceu nas rotas pesadas (`vendas-por-dia` e `top-produtos`, de uma consulta, e `pedidos-por-status`, de duas), e `pedidos-do-cliente`, `cliente` e `busca-produtos` pioraram, com `cliente-por-email` na mesma faixa. Provavelmente o ganho vem de o banco, limitado a 1 CPU, ter deixado de gastar CPU criando um processo por consulta, e essa CPU ter ido para as consultas pesadas. Provavelmente a piora das rotas leves vem de que, com `max` 10 e 20 usuários, as consultas esperam numa fila por uma conexão, e as leves ficam presas atrás das pesadas, e o pool muda quem espera e onde. Uma conexão destruída a cada erro (`release(true)`) custa uma reconexão, mas só no caminho de erro.

**Contra a hipótese do commit:** refutada pelo critério dela. `pedidos-do-cliente`, que devia ganhar mais, piorou de 6.402,3 para 8.513,6 ms, e `top-produtos` e `vendas-por-dia`, que deviam ganhar pouco, tiveram os maiores ganhos (27.371,0 para 16.655,4 ms e 8.556,8 para 4.511,2 ms). O req/s geral subiu.

**O que refutaria:** o p95 de `top-produtos` e `vendas-por-dia` cair tanto quanto o de `pedidos-do-cliente`, ou o req/s geral não subir.

## 03 Consulta única com `LEFT JOIN` em `/clientes/:id/pedidos`

**Rótulo:** `03-join-pedidos-do-cliente`

**Ideia e fonte:** trocar as 1 + 1 + P + I consultas da rota (cliente, pedidos, itens de cada pedido e produto de cada item) por uma consulta só, com `LEFT JOIN` a partir de `clientes`. Fontes: [Rails Guides, 16.1 N + 1 Queries Problem](https://guides.rubyonrails.org/active_record_querying.html), que define o problema com o exemplo de "11 queries in total" trocadas por 2, e [PostgreSQL 16, 7.2 Table Expressions](https://www.postgresql.org/docs/16/queries-table-expressions.html), que diz que no `LEFT OUTER JOIN` "a joined row is added with null values in columns of T2", por isso o pedido sem itens continua na resposta. Acesso em 2026-11-18. Nenhuma das duas mede latência.

**Status:** Aplicada e medida.

**Hipótese** (commit `1ae7302`): trocar as 1 + 1 + P + I consultas da rota `/clientes/:id/pedidos` por uma única consulta, com `LEFT JOIN` a partir de `clientes`, deve reduzir o p95 dessa rota, porque elimina as idas ao banco e as esperas por uma conexão do pool a cada pedido e a cada item, e cada uma tem custo fixo. As outras rotas só devem mudar por efeito indireto, com menos disputa pelo pool e pelo banco.

**Antes usado:** mudança 02.
- `resultados/20261118-181942-02-pool-de-conexoes`
- `resultados/20261118-182111-02-pool-de-conexoes`
- `resultados/20261118-182243-02-pool-de-conexoes`

**Depois:**
- `resultados/20261118-202034-03-join-pedidos-do-cliente`
- `resultados/20261118-202203-03-join-pedidos-do-cliente`
- `resultados/20261118-202333-03-join-pedidos-do-cliente`

**Resultado** (medianas das três execuções, antes → depois):
- Requisições por segundo: 9,12 → 9,75
- p95 geral: 6.918,9 → 5.123,3 ms
- p95 de `pedidos-do-cliente`: 8.513,6 → 2.773,3 ms
- p95 de `cliente`: 610,5 → 1.542,2 ms
- p95 de `cliente-por-email`: 1.220,5 → 2.152,4 ms
- p95 de `busca-produtos`: 830,9 → 1.754,0 ms
- p95 de `pedidos-por-status`: 5.685,2 → 6.725,9 ms
- p95 de `vendas-por-dia`: 4.511,2 → 5.711,5 ms
- p95 de `top-produtos`: 16.655,4 → 17.205,4 ms
- Memória média do banco: 274,7 → 272,3 MiB. Da API: 36,7 → 34,5 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** a consulta única tirou as idas ao banco por pedido e por item e a espera por uma conexão a cada uma, e o p95 de `pedidos-do-cliente` caiu de 8.513,6 para 2.773,3 ms, puxando o geral para 5.123,3 ms. As rotas leves pioraram de novo (`cliente` foi de 610,5 para 1.542,2 ms). Provavelmente é a mesma fila do pool: passam mais requisições por segundo e as consultas rápidas esperam atrás das pesadas. O contrato mantido não cobre cliente sem pedidos nem pedido sem itens, porque os dados não têm esses casos (em `banco/02-dados.sql`, cada pedido recebe de 1 a 5 itens e cada cliente recebe 5 pedidos). Esses dois casos, mais um produto repetido no mesmo pedido, dois pedidos na mesma data (desempate por id) e três casos de erro (404 e 400), foram comparados, rota antiga contra rota nova, num banco descartável com dados escritos à mão, e as 7 respostas foram iguais (`diagnostico/10-casos-de-borda-do-join.txt`).

**Contra a hipótese do commit:** a primeira parte se confirmou, porque `pedidos-do-cliente` caiu de 8.513,6 para 2.773,3 ms. A segunda, de que as outras rotas só mudariam por efeito indireto e com menos disputa, errou o sentido: o p95 das seis outras rotas subiu (`cliente` de 610,5 para 1.542,2 ms, `cliente-por-email` de 1.220,5 para 2.152,4 ms e `busca-produtos` de 830,9 para 1.754,0 ms, com faixas sem sobreposição, e `pedidos-por-status`, `vendas-por-dia` e `top-produtos` com a mediana mais alta e faixas sobrepostas). Pelo critério do commit, a segunda parte foi refutada: `cliente`, `cliente-por-email` e `busca-produtos` mudaram, sem sobreposição das faixas, no sentido oposto ao de menos disputa. A causa provável da piora é outra, a fila do pool, e não foi medida.

**O que refutaria:** o p95 de `pedidos-do-cliente` não cair, ou outra rota mudar sem esse efeito indireto.

## 04 Pool com `max` 20

**Rótulo:** `04-pool-max-20`

**Ideia e fonte:** subir o `max` do pool de 10 para 20, igual aos 20 usuários da carga. Fontes: [node-postgres, Pooling](https://node-postgres.com/features/pooling) e [node-postgres, Pool sizing](https://node-postgres.com/guides/pool-sizing), acesso em 2026-11-18. A segunda diz que "I don’t bother setting it to anything other than the default of `10`" e não é uma medição deste trabalho, então não prova ganho ao subir o `max`. A ideia vem da explicação provável das mudanças 02 e 03: as rotas leves esperariam na fila do pool.

**Status:** Aplicada, sem ganho.

**Hipótese** (commit `79e301d`): subir o `max` do pool de 10 para 20 (igual aos 20 usuários da carga) deve reduzir o p95 das rotas leves (`cliente`, `cliente-por-email` e `busca-produtos`) e subir o req/s geral, porque com 10 conexões as requisições leves esperam na fila do pool atrás das pesadas. O ganho deve ser menor nas rotas pesadas (`pedidos-por-status` e `vendas-por-dia`), porque o banco já está no teto de 1 CPU e mais conexões só dividem a mesma CPU.

**Antes usado:** mudança 03.
- `resultados/20261118-202034-03-join-pedidos-do-cliente`
- `resultados/20261118-202203-03-join-pedidos-do-cliente`
- `resultados/20261118-202333-03-join-pedidos-do-cliente`

**Depois:**
- `resultados/20261118-205438-04-pool-max-20`
- `resultados/20261118-205607-04-pool-max-20`
- `resultados/20261118-205739-04-pool-max-20`

**Resultado** (medianas das três execuções, antes → depois):
- Requisições por segundo: 9,75 → 9,66
- p95 geral: 5.123,3 → 7.399,6 ms
- p95 de `cliente`: 1.542,2 → 85,8 ms
- p95 de `busca-produtos`: 1.754,0 → 505,2 ms
- p95 de `cliente-por-email`: 2.152,4 → 1.325,7 ms
- p95 de `pedidos-do-cliente`: 2.773,3 → 3.491,7 ms
- p95 de `vendas-por-dia`: 5.711,5 → 7.662,3 ms
- p95 de `pedidos-por-status`: 6.725,9 → 9.358,0 ms
- p95 de `top-produtos`: 17.205,4 → 25.370,1 ms
- Memória média do banco: 272,3 → 340,3 MiB. Da API: 34,5 → 41,9 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** não valeu para o p95 geral. O `max` 20 voltou a deixar as rotas leves rápidas (`cliente` de 1.542,2 para 85,8 ms), mas as rotas pesadas pioraram e o p95 geral subiu de 5.123,3 para 7.399,6 ms, com o req/s na mesma faixa (9,75 contra 9,66, com faixas sobrepostas). A média do tempo de resposta do k6 ficou na mesma faixa (1.995,6 ms na 03 e 1.997,8 ms na 04, medianas das médias de cada execução em `resumo-k6.json`), o que combina com a lei de Little para 20 usuários fixos: o tempo médio fica igual e muda quem espera. Provavelmente, sem a fila do pool, as 20 consultas dividem a CPU do banco ao mesmo tempo, e as pesadas demoram mais. O `max` 20 continua no código nas mudanças seguintes, porque voltar ao 10 seria uma mudança própria, com medição.

**Contra a hipótese do commit:** pelo critério do commit (o p95 das rotas leves não cair, ou o req/s geral cair por disputa de CPU no banco), a hipótese não foi refutada: as rotas leves caíram (`cliente`, `cliente-por-email` e `busca-produtos`) e o req/s ficou na mesma faixa, mas não subiu como previsto. A previsão de que as pesadas ganhariam menos errou, porque elas pioraram (`pedidos-por-status` de 6.725,9 para 9.358,0 ms e `vendas-por-dia` de 5.711,5 para 7.662,3 ms).

**O que refutaria:** o p95 das rotas leves não cair, ou o req/s geral cair por disputa de CPU no banco.

## 05 Índice `(status, criado_em DESC, id DESC)` em `pedidos`

**Rótulo:** `05-indice-pedidos-status`

**Ideia e fonte:** criar o índice composto `(status, criado_em DESC, id DESC)` em `pedidos`, em `banco/04-indice-pedidos.sql`. Fontes: [PostgreSQL 16, 11.4 Indexes and ORDER BY](https://www.postgresql.org/docs/16/indexes-ordering.html), que diz que um índice B-tree permite que o `ORDER BY` seja atendido "without a separate sorting step", e [PostgreSQL 16, 11.3 Multicolumn Indexes](https://www.postgresql.org/docs/16/indexes-multicolumn.html), que diz que "equality constraints on leading columns" limitam "the portion of the index that is scanned". Acesso em 2026-11-18. Nenhuma das duas mede desempenho.

**Status:** Aplicada e medida.

**Hipótese** (commit `97781f7`): criar o índice `(status, criado_em DESC, id DESC)` em `pedidos` deve reduzir o p95 de `/pedidos?status=&pagina=`, porque o PostgreSQL passa a ler as linhas do status já na ordem pedida, sem a ordenação em disco e sem ler os outros status. O ganho deve ser maior nas páginas fundas do que nas primeiras. As outras rotas só devem mudar por efeito indireto, com menos disputa pela CPU do banco.

**Antes usado:** mudança 04.
- `resultados/20261118-205438-04-pool-max-20`
- `resultados/20261118-205607-04-pool-max-20`
- `resultados/20261118-205739-04-pool-max-20`

**Depois:**
- `resultados/20261118-212211-05-indice-pedidos-status`
- `resultados/20261118-212339-05-indice-pedidos-status`
- `resultados/20261118-212508-05-indice-pedidos-status`

**Commit medido:** os `contexto.txt` das três execuções citam `a623459`, que é o `97781f7` mais o arquivo `diagnostico/08-pedidos-por-status-com-indice.txt`. O código e o banco medidos são os do `97781f7`.

**Plano da consulta com o índice:** `diagnostico/08-pedidos-por-status-com-indice.txt`. A página funda usa `Index Scan using indice_pedidos` e não tem `Sort`. A contagem continua em `Parallel Seq Scan`.

**Execuções não usadas:** três execuções anteriores com o mesmo rótulo ficaram fora do repositório, porque não houve leitura do contador `max` de `memory.events` do banco antes de cada uma. Uma execução extra, com o rótulo `05-indice-pedidos-status-verificacao`, foi feita só para ver se o contador subia durante a carga, e também ficou fora (as leituras dela estão em `diagnostico/09-memory-events-da-05.txt`: 45 antes e 45 depois). As três execuções acima foram feitas com o contador lido antes e depois de cada uma, e o resultado está no mesmo arquivo: 45 nas seis leituras e swap zero.

**Resultado** (medianas das três execuções, antes → depois):
- Requisições por segundo: 9,66 → 13,64
- p95 geral: 7.399,6 → 4.738,1 ms
- p95 de `pedidos-por-status`: 9.358,0 → 3.259,3 ms
- p95 de `vendas-por-dia`: 7.662,3 → 7.288,1 ms
- p95 de `pedidos-do-cliente`: 3.491,7 → 3.673,6 ms
- p95 de `top-produtos`: 25.370,1 → 26.775,9 ms
- p95 de `cliente-por-email`: 1.325,7 → 1.507,6 ms
- p95 de `busca-produtos`: 505,2 → 589,5 ms
- p95 de `cliente`: 85,8 → 90,3 ms
- Memória média do banco: 340,3 → 357,6 MiB. Da API: 41,9 → 48,2 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** valeu. O índice `(status, criado_em DESC, id DESC)` tirou o `Sort` em disco do plano medido (`pago`, página 1000), e o p95 de `pedidos-por-status` caiu de 9.358,0 para 3.259,3 ms. O req/s geral subiu de 9,66 para 13,64 e o p95 geral caiu de 7.399,6 para 4.738,1 ms. Provavelmente o banco, limitado a 1 CPU, gasta menos CPU nessa rota e a deixa para as outras consultas, mas não há medição de CPU confiável neste ambiente. Entre as outras rotas, `cliente-por-email` (1.325,7 para 1.507,6 ms) e `busca-produtos` (505,2 para 589,5 ms) subiram, com faixas sem sobreposição, `top-produtos` subiu de 25.370,1 para 26.775,9 ms, também sem sobreposição, mas com poucas requisições por execução, e `cliente`, `pedidos-do-cliente` e `vendas-por-dia` ficaram na mesma faixa. A contagem da rota continua em leitura sequencial e é o próximo custo dela.

**Contra a hipótese do commit:** pelo critério do commit (o p95 de `pedidos-por-status` não cair, ou o plano continuar com `Sort`), a hipótese não foi refutada: `pedidos-por-status` caiu e o plano da página funda não tem `Sort`, como previsto. A previsão de que o ganho seria maior nas páginas fundas do que nas primeiras não foi medida, porque o resumo da carga não separa a rota por página. A previsão de que as outras rotas só mudariam por efeito indireto da CPU livre não se confirmou em `cliente-por-email`, `busca-produtos` e `top-produtos`, que ficaram mais lentas.

**O que refutaria:** o p95 de `pedidos-por-status` não cair, ou o plano da consulta continuar com `Sort`.

## 06 Índice `(cliente_id, criado_em DESC, id DESC)` em `pedidos`

**Rótulo:** `06-indice-pedidos-cliente`

**Ideia e fonte:** criar o índice composto `(cliente_id, criado_em DESC, id DESC)` em `pedidos`, em `banco/05-indice-pedidos-cliente.sql`. Fontes: as mesmas da 05, [PostgreSQL 16, 11.3 Multicolumn Indexes](https://www.postgresql.org/docs/16/indexes-multicolumn.html) e [PostgreSQL 16, 11.4 Indexes and ORDER BY](https://www.postgresql.org/docs/16/indexes-ordering.html), acesso em 2026-11-18. Nenhuma das duas mede desempenho.

**Status:** Aplicada e medida.

**Hipótese** (commit `b9a29c6`): criar o índice deve reduzir o p95 de `/clientes/:id/pedidos`, porque o banco passa a achar os pedidos do cliente pelo índice, já em ordem (log N + k), em vez de ler as 500 mil linhas de `pedidos`. Previsão: essa rota é a que mais ganha. As outras não ganham diretamente, mas podem melhorar de carona se o banco, no teto de 1 CPU, passar a ter menos trabalho. O que refutaria: o plano continuar com varredura sequencial em `pedidos`, ou o p95 da rota não cair. Se o ganho vier quase todo do `cliente_id`, isso é esperado, porque com cerca de 5 pedidos por cliente o `Sort` já custava pouco.

**Antes usado:** mudança 05.
- `resultados/20261118-212211-05-indice-pedidos-status`
- `resultados/20261118-212339-05-indice-pedidos-status`
- `resultados/20261118-212508-05-indice-pedidos-status`

**Depois:**
- `resultados/20261119-125052-06-indice-pedidos-cliente`
- `resultados/20261119-125633-06-indice-pedidos-cliente`
- `resultados/20261119-125805-06-indice-pedidos-cliente`

**Commit medido:** os `contexto.txt` das três execuções citam `b9a29c6`.

**Plano da consulta com o índice:** `diagnostico/11-pedidos-do-cliente-com-indice.txt`. A consulta usa `Index Scan using indice_pedidos_cliente` em `pedidos`, sem varredura sequencial, e ainda tem um `Sort` no topo (10 linhas, quicksort em memória). O índice ocupa 19 MB, contra 163 MB da tabela.

**Execuções não usadas:** duas execuções com o mesmo rótulo foram descartadas e apagadas, porque o banco terminou com swap diferente de zero. Depois disso os containers foram reiniciados com `docker compose restart` e o contrato foi conferido de novo. A primeira execução usada é anterior ao reinício e as outras duas são posteriores. As leituras de swap e de `memory.events` de todas as execuções estão em `diagnostico/12-memory-events-da-06.txt`.

**Resultado** (medianas das três execuções, antes → depois):
- Requisições por segundo: 13,64 → 19,6
- p95 geral: 4.738,1 → 5.303,5 ms
- p95 de `pedidos-do-cliente`: 3.673,6 → 170,9 ms
- p95 de `pedidos-por-status`: 3.259,3 → 3.147,0 ms
- p95 de `vendas-por-dia`: 7.288,1 → 7.587,1 ms
- p95 de `top-produtos`: 26.775,9 → 29.349,1 ms
- p95 de `cliente-por-email`: 1.507,6 → 1.645,4 ms
- p95 de `busca-produtos`: 589,5 → 613,4 ms
- p95 de `cliente`: 90,3 → 94,5 ms
- Memória média do banco: 357,6 → 415,3 MiB. Da API: 48,2 → 63,3 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** valeu para a rota alvo. O p95 de `pedidos-do-cliente` caiu de 3.673,6 para 170,9 ms, com faixas sem sobreposição, e o req/s geral subiu de 13,64 para 19,6, também sem sobreposição (as três execuções ficaram entre 19,44 e 20,13). O plano passou a usar o índice e não lê mais a tabela inteira. O `Sort` continua no plano, então as colunas `criado_em DESC, id DESC` não tiraram a ordenação. Explicação provável, ainda sem prova: o `ORDER BY` da consulta inclui `ite.id`, que vem da junção com `itens_pedido`, e o índice não cobre essa coluna. Se for isso, o ganho vem só do `cliente_id`, e um índice só nessa coluna seria menor e daria o mesmo plano, o que não foi testado. O p95 geral subiu na mediana, de 4.738,1 para 5.303,5 ms, mas as faixas das execuções se sobrepõem (4.626,7 a 4.864,5 contra 4.659,7 a 5.560,0), então não dá para dizer que piorou. Explicação provável, ainda sem prova: o p95 geral é decidido pelas rotas mais lentas, `vendas-por-dia` e `top-produtos`, que juntas pesam 10% da carga e não ganharam com esta mudança. Entre as outras rotas, `cliente-por-email` e `top-produtos` subiram, com faixas sem sobreposição, e `cliente`, `pedidos-por-status`, `busca-produtos` e `vendas-por-dia` ficaram na mesma faixa. A memória média do banco subiu de 357,6 para 415,3 MiB, e a da API de 48,2 para 63,3 MiB, ambas sem sobreposição. O índice tem 19 MB, mas não medi quanto da alta de memória vem dele.

**Contra a hipótese do commit:** pelo critério do commit (o plano continuar com varredura sequencial em `pedidos`, ou o p95 de `pedidos-do-cliente` não cair), a hipótese não foi refutada: o plano usa o índice e o p95 da rota caiu. A parte "já em ordem" se confirmou só em parte: o índice acha os pedidos do cliente, mas o plano ainda ordena. A previsão de que as outras rotas poderiam melhorar de carona não se confirmou: nenhuma caiu sem sobreposição e duas subiram. A ressalva do commit, de que o ganho viria quase todo do `cliente_id`, é compatível com o plano, mas não foi testada.

**O que refutaria:** o plano continuar com varredura sequencial em `pedidos`, ou o p95 de `pedidos-do-cliente` não cair.

## 07 Filtro por intervalo em `criado_em` e índice em `pedidos(criado_em)`

**Rótulo:** `07-indice-pedidos-criado-em`

**Ideia e fonte:** reescrever o filtro de `/relatorios/vendas-por-dia` como intervalo na coluna pura (`criado_em >= $1::date AND criado_em < $2::date + 1`) e criar o índice comum `(criado_em)` em `pedidos`, em `banco/06-indice-pedidos-criado-em.sql`. Fontes: [PostgreSQL 16, 11.1 Introduction](https://www.postgresql.org/docs/16/indexes-intro.html), que diz que o sistema usa o índice "when it thinks doing so would be more efficient than a sequential table scan", e [PostgreSQL 16, 11.7 Indexes on Expressions](https://www.postgresql.org/docs/16/indexes-expressional.html), cujo exemplo é um índice em `lower(col1)` para consultas que usam essa mesma expressão. Acesso em 2026-11-18. Nenhuma das duas mede desempenho.

**Status:** Aplicada e medida.

**Hipótese** (commit `5b537fd`): criar o índice em `pedidos(criado_em)` e reescrever o filtro como intervalo na coluna pura deve reduzir o p95 de `/relatorios/vendas-por-dia`, porque o banco passa a ler só os pedidos do período, e não as 500 mil linhas de `pedidos`. O `criado_em::date` do filtro antigo impedia o uso de índice. Previsão: essa rota é a que mais ganha, com ganho limitado, porque a resposta ainda lê os itens dos pedidos do período e soma tudo no Node. As outras rotas não mudam diretamente. O que refutaria: o plano continuar com varredura sequencial em `pedidos`, ou o p95 da rota não cair.

**Antes usado:** mudança 06.
- `resultados/20261119-125052-06-indice-pedidos-cliente`
- `resultados/20261119-125633-06-indice-pedidos-cliente`
- `resultados/20261119-125805-06-indice-pedidos-cliente`

**Depois:**
- `resultados/20261119-142513-07-indice-pedidos-criado-em`
- `resultados/20261119-142816-07-indice-pedidos-criado-em`
- `resultados/20261119-143159-07-indice-pedidos-criado-em`
- `resultados/20261119-143333-07-indice-pedidos-criado-em`
- `resultados/20261119-151943-07-indice-pedidos-criado-em`

**Commit medido:** os `contexto.txt` das cinco execuções citam `5b537fd`.

**Equivalência e plano:** `diagnostico/14-vendas-por-dia-filtro-e-indice.txt`. O filtro novo devolveu a mesma contagem e a mesma soma de ids de pedidos que o antigo em 404 janelas de 1 a 31 dias, incluindo o primeiro e o último dia dos dados (a comparação é de pedidos, e não da resposta inteira, e o contrato de 42 respostas foi conferido depois da mudança). O plano com o índice usa `Bitmap Index Scan on indice_pedidos_criado_em` e a consulta isolada levou 204,996 ms na 1ª execução e 41,354 ms na 2ª. Sem o índice o plano é `Parallel Seq Scan` em `pedidos`, com 240,644 ms na 1ª execução e 207,182 ms na 2ª.

**Execuções usadas e não usadas:** foram feitas 13 tentativas com o mesmo rótulo, 11 com pasta e 2 sem pasta. Valem as cinco com 0,00% de erros, contrato mantido e sem `oom_kill`, um critério definido por erros e falta de memória, e nunca pelo desempenho. As outras seis pastas ficaram fora, com erros de 0,07% a 82,24%, e as duas tentativas feitas com o swap do banco desligado nem geraram pasta. As cinco usadas tiveram swap diferente de zero no banco (de 16.429.056 a 30.023.680 bytes), o que é uma exceção à regra que valeu na 05 e na 06, em que só entraram execuções com swap zero. O banco chegou ao limite de 512 MiB (`memory.peak` igual ao limite) nas execuções 7 e 10 a 13, as únicas em que `memory.peak` foi lido, e na execução 6, que foi usada, houve `max 2` em `memory.events`. A tentativa de desligar o swap do banco fez o banco ser encerrado por falta de memória e foi desfeita. Todas as leituras estão em `diagnostico/13-memoria-do-banco-na-07.txt`.

**Resultado** (medianas, antes → depois, com a faixa das execuções da 07 entre parênteses):
- Requisições por segundo: 19,6 → 20,52 (19,97 a 21,59)
- p95 geral: 5.303,5 → 2.718,4 ms (2.476,3 a 3.139,2)
- p95 de `vendas-por-dia`: 7.587,1 → 3.698,9 ms (3.514,3 a 3.948,2)
- p95 de `pedidos-por-status`: 3.147,0 → 4.381,6 ms
- p95 de `top-produtos`: 29.349,1 → 32.719,5 ms
- p95 de `busca-produtos`: 613,4 → 711,5 ms
- p95 de `cliente`: 94,5 → 101,0 ms
- p95 de `cliente-por-email`: 1.645,4 → 1.687,7 ms
- p95 de `pedidos-do-cliente`: 170,9 → 188,5 ms
- Memória média do banco: 415,3 → 431,8 MiB. Da API: 63,3 → 46,0 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** valeu para a rota alvo. O p95 de `vendas-por-dia` caiu de 7.587,1 para 3.698,9 ms, com faixas sem sobreposição (7.372,0 a 7.644,2 contra 3.514,3 a 3.948,2), e o plano deixou de ler `pedidos` inteira. O p95 geral também caiu, de 5.303,5 para 2.718,4 ms, sem sobreposição (4.659,7 a 5.560,0 contra 2.476,3 a 3.139,2). Explicação provável, ainda sem prova: o p95 geral é decidido pelas rotas mais lentas, e `vendas-por-dia` era uma delas. O req/s não mudou de forma clara, porque as faixas se sobrepõem (19,44 a 20,13 contra 19,97 a 21,59). Quatro rotas ficaram mais lentas, com faixas sem sobreposição: `pedidos-por-status`, `top-produtos`, `busca-produtos` e `cliente`. `cliente-por-email` ficou na mesma faixa, e `pedidos-do-cliente` ficou com pouca sobreposição (177,1 a 179,5 ms), com a mediana de 170,9 para 188,5 ms. Explicação provável, ainda sem prova: com `vendas-por-dia` mais rápida, o banco, limitado a 1 CPU, atende mais consultas das outras rotas ao mesmo tempo, e elas demoram mais. Não há medição de CPU confiável neste ambiente. A memória média do banco subiu de 415,3 para 431,8 MiB, mas a comparação sofre com o swap, e a da API caiu de 63,3 para 46,0 MiB, sem causa conhecida. Não medi o tamanho do índice novo nem separei quanto do ganho vem do filtro e quanto vem do índice. Nesta mudança o banco ficou instável sob o limite de 512 MiB, com erros de requisição em 6 das 11 execuções, e não isolei se a causa é o índice, a carga mais rápida ou outro fator.

**Contra a hipótese do commit:** pelo critério do commit (o plano continuar com varredura sequencial em `pedidos`, ou o p95 da rota não cair), a hipótese não foi refutada: o plano usa o índice e o p95 de `vendas-por-dia` caiu. A previsão de ganho limitado não foi medida, porque não separei quanto do tempo restante vem da leitura dos itens e da soma no Node. A previsão de que as outras rotas não mudariam diretamente não impede o que se viu, porque o efeito nelas é indireto, mas quatro ficaram mais lentas.

**O que refutaria:** o plano continuar com varredura sequencial em `pedidos`, ou o p95 de `vendas-por-dia` não cair.

## 08 `top-produtos` lê a view materializada `vendas_por_produto`

**Rótulo:** `08-top-produtos-view`

**Ideia e fonte:** criar em `banco/07-top-produtos.sql` a view materializada `vendas_por_produto`, com a soma de unidades e de receita por produto (sem pedidos cancelados), e fazer `/relatorios/top-produtos` ler essa view em vez de somar os itens de pedido a cada requisição. A rota continua ordenando e cortando o limite. Fonte: [PostgreSQL 16, 41.3 Materialized Views](https://www.postgresql.org/docs/16/rules-materializedviews.html), que diz que a view materializada guarda o resultado da consulta ("persist the results in a table-like form") e que "the data is not always current; yet sometimes current data is not needed". Para a ordem, a rota mantém o `ORDER BY`, e a fonte é [PostgreSQL 16, 7.5 Sorting Rows](https://www.postgresql.org/docs/16/queries-order.html): "A particular output ordering can only be guaranteed if the sort step is explicitly chosen". Acesso em 2026-11-19. Nenhuma das duas mede desempenho.

**Status:** Aplicada e medida.

**Hipótese** (commit `0e05c03`): a rota deixa de somar 1,5 milhão de itens a cada requisição. A soma por produto é feita uma vez, na criação do banco, e a rota só lê as linhas prontas, então `top-produtos` deve ficar bem mais rápida e o p95 geral deve cair. O custo é que a view não se atualiza sozinha: serve aqui porque a API só tem rotas `GET` e os dados não mudam durante o uso. O que refutaria: `top-produtos` não cair claramente da mediana anterior (32.719,5 ms de p95 na 07), ou o p95 geral não melhorar.

**Antes usado:** mudança 07, as cinco pastas usadas na seção 07.
- `resultados/20261119-142513-07-indice-pedidos-criado-em`
- `resultados/20261119-142816-07-indice-pedidos-criado-em`
- `resultados/20261119-143159-07-indice-pedidos-criado-em`
- `resultados/20261119-143333-07-indice-pedidos-criado-em`
- `resultados/20261119-151943-07-indice-pedidos-criado-em`

**Depois:**
- `resultados/20261119-195347-08-top-produtos-view`
- `resultados/20261119-195507-08-top-produtos-view`
- `resultados/20261119-195628-08-top-produtos-view`

**Commit medido:** os `contexto.txt` das três execuções citam `0e05c03`, com `arquivos alterados sem commit: 0`. O banco foi recriado (`docker compose down -v` e `up -d --build`) para criar a view, e o contrato terminou em "Contrato mantido" (42 respostas) ao fim de cada uma das três medições.

**Equivalência e plano:** `diagnostico/15-top-produtos-view-e-consulta-antiga.txt`. Num banco de teste, com a view criada numa transação desfeita, a view tem 19.206 linhas, as mesmas da consulta antiga, sem nenhuma linha só de um lado ou só do outro, e a lista dos 50 primeiros na ordem da rota tem o mesmo `md5` nas duas, o que cobre os limites de 1 a 50. A consulta antiga isolada, com o banco ocioso, levou 1.627,912 ms na 1ª execução e 1.588,793 ms na 2ª, lendo `itens_pedido` inteira com `Parallel Seq Scan`. A nova levou 4,778 ms e 3,253 ms, lendo a view com `Seq Scan`.

**Execuções usadas e não usadas:** três tentativas, três pastas, todas usadas. As três tiveram 0,00% de erros, contrato mantido, swap do banco e da API em 0 ao fim de cada execução e nenhum evento em `memory.events` (`diagnostico/16-memoria-do-banco-na-08.txt`; o `memory.peak` não foi lido, então o que se sabe é o swap ao fim de cada execução, e não durante a carga). Diferente da 07, em que as cinco execuções usadas tiveram swap no banco.

**Resultado** (medianas, antes → depois, com a faixa das execuções da 08 entre parênteses):
- Requisições por segundo: 20,52 → 41,45 (41,19 a 41,87)
- p95 geral: 2.718,4 → 1.644,1 ms (1.579,4 a 1.659,8)
- p95 de `top-produtos`: 32.719,5 → 415,3 ms (412,1 a 568,2)
- p95 de `pedidos-por-status`: 4.381,6 → 2.222,9 ms (2.211,0 a 2.305,4)
- p95 de `vendas-por-dia`: 3.698,9 → 2.505,4 ms (2.460,0 a 2.582,9)
- p95 de `cliente-por-email`: 1.687,7 → 1.535,2 ms (1.403,7 a 1.537,4)
- p95 de `busca-produtos`: 711,5 → 731,0 ms (697,7 a 759,1)
- p95 de `cliente`: 101,0 → 353,9 ms (304,2 a 399,4)
- p95 de `pedidos-do-cliente`: 188,5 → 422,3 ms (403,4 a 438,3)
- Memória média do banco: 431,8 → 275,6 MiB (274,2 a 275,7). Da API: 46,0 → 49,2 MiB (49,0 a 50,0)
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** valeu. O p95 de `top-produtos` caiu de 32.719,5 para 415,3 ms, com faixas sem sobreposição (30.986,1 a 34.682,7 contra 412,1 a 568,2). O p95 geral também caiu, de 2.718,4 para 1.644,1 ms (2.476,3 a 3.139,2 contra 1.579,4 a 1.659,8), e o req/s foi de 20,52 para 41,45 (19,97 a 21,59 contra 41,19 a 41,87), os dois sem sobreposição. Explicação provável, ainda sem prova: `top-produtos` era a rota mais lenta e na 07 cada requisição dela prendia um dos 20 usuários da carga, com mediana de 15.079,0 a 17.496,3 ms e p95 de 30.986,1 a 34.682,7 ms por execução, então, com ela rápida, os usuários passam a fazer mais requisições por segundo. `pedidos-por-status`, `vendas-por-dia` e `cliente-por-email` também caíram, sem sobreposição, sem que a mudança as tocasse. Explicação provável, ainda sem prova: a soma de 1,5 milhão de itens deixou de disputar com elas a CPU e a memória do banco. `busca-produtos` ficou na mesma faixa. `cliente` e `pedidos-do-cliente` ficaram mais lentas, com faixas sem sobreposição (97,6 a 141,9 contra 304,2 a 399,4 ms, e 177,1 a 214,0 contra 403,4 a 438,3 ms). Explicação provável, ainda sem prova: com o dobro de requisições por segundo, o banco, limitado a 1 CPU, atende mais consultas ao mesmo tempo e as rotas leves esperam mais, o mesmo padrão (rotas leves pioram quando o req/s sobe) já registrado nas mudanças 02, 03 e 07, com explicação provável diferente nas duas primeiras. Não há medição de CPU confiável neste ambiente para confirmar isso. `top-produtos` tem poucas amostras por execução (22 a 24 requisições na 07 e 42 a 44 na 08), então o p95 dela e as faixas vêm de poucas requisições. A memória média do banco caiu de 431,8 para 275,6 MiB e o swap estava em 0 ao fim das três execuções, mas a comparação com a 07 sofre porque a 07 teve swap, e três execuções sem swap não bastam para dizer que o problema de memória da 07 acabou, nem de que mudança ele vem. Custo: a view não se atualiza sozinha e só serve porque os dados não mudam durante o uso, e em produção precisaria de um `REFRESH MATERIALIZED VIEW` agendado ou de outro jeito de manter a soma em dia. Não medi o tamanho nem o tempo de criação da view.

**Contra a hipótese do commit:** pelos dois critérios do commit, a hipótese não foi refutada: `top-produtos` caiu claramente de 32.719,5 ms, e o p95 geral melhorou. A previsão de que o p95 geral cairia se confirmou. O req/s dobrar não estava na hipótese. Não havia previsão sobre as outras rotas, e duas delas ficaram mais lentas.

**O que refutaria:** `top-produtos` não cair claramente da mediana da 07 (32.719,5 ms de p95), ou o p95 geral não melhorar.

## 09 `/pedidos` lê o total da view materializada `contagem_pedidos_por_status`

**Rótulo:** `09-pedidos-total-view`

**Ideia e fonte:** criar em `banco/08-contagem-pedidos.sql` a view materializada `contagem_pedidos_por_status`, com uma linha por status e o total de pedidos, e fazer a rota `/pedidos` ler o `total` dela em vez de contar as linhas a cada requisição. A consulta da página (`ORDER BY` e `OFFSET`) não mudou. Fonte: [PostgreSQL 16, 41.3 Materialized Views](https://www.postgresql.org/docs/16/rules-materializedviews.html), a mesma da 08, que diz que a view materializada guarda o resultado da consulta ("persist the results in a table-like form") e que "the data is not always current; yet sometimes current data is not needed". Acesso em 2026-11-19. A fonte não mede desempenho.

**Status:** Aplicada e medida.

**Hipótese** (commit `572195a`): a rota deixa de contar de 25 mil a 300 mil pedidos a cada requisição, porque mesmo com índice o `count` visita cada linha do status (O(n)). A contagem por status é feita uma vez, na criação do banco, e a rota só lê o total pronto, então `pedidos-por-status` deve ficar mais rápida e o p95 geral deve cair. O custo é que a view não se atualiza sozinha: serve aqui porque a API só tem rotas `GET` e os dados não mudam durante o uso. O que refutaria: `pedidos-por-status` não cair claramente da mediana anterior (2.222,9 ms de p95 na 08), ou o p95 geral não melhorar.

**Antes usado:** mudança 08.
- `resultados/20261119-195347-08-top-produtos-view`
- `resultados/20261119-195507-08-top-produtos-view`
- `resultados/20261119-195628-08-top-produtos-view`

**Depois:**
- `resultados/20261119-203628-09-pedidos-total-view`
- `resultados/20261119-203747-09-pedidos-total-view`
- `resultados/20261119-203908-09-pedidos-total-view`

**Commit medido:** os `contexto.txt` das três execuções citam `572195a`, com `arquivos alterados sem commit: 0`. O banco foi recriado (`docker compose down -v` e `up -d --build`) para criar a view, e o contrato terminou em "Contrato mantido" (42 respostas) ao fim de cada uma das três medições.

**Planos:** `diagnostico/17-pedidos-contagem-e-pagina.txt`, tirado antes da mudança, com o banco ocioso. O `count(*)` de `pago` (300.000 pedidos) usa `Parallel Index Only Scan using indice_pedidos`, com `Heap Fetches: 0`, e levou 53,058 ms na 1ª execução e 25,652 ms na 2ª. A consulta da página 1000 (`OFFSET 19980`) usa `Index Scan using indice_pedidos`, lê 20.000 linhas e levou 11,631 ms e 59,664 ms. A tentativa de juntar a contagem na consulta da página com `SELECT *, count(*)` dá erro de SQL, e a alternativa com `count(*) OVER ()` levou 513,409 ms e devolve 0 linhas, sem total, para uma página fora do intervalo. A view tem as mesmas 4 contagens que o `count(*)` direto (50.000, 125.000, 300.000 e 25.000, sem diferença nos dois sentidos), conferido depois das medições em `diagnostico/19-contagem-view-igual-ao-count.txt`.

**Execuções usadas e não usadas:** três tentativas, três pastas, todas usadas. As três tiveram 0,00% de erros, contrato mantido, swap do banco e da API em 0 ao fim de cada execução e nenhum evento em `memory.events` (`diagnostico/18-memoria-do-banco-na-09.txt`; o `memory.peak` não foi lido, então o que se sabe é o swap ao fim de cada execução, e não durante a carga).

**Resultado** (medianas, antes → depois, com a faixa das execuções da 09 entre parênteses):
- Requisições por segundo: 41,45 → 46,39 (46,26 a 46,86)
- p95 geral: 1.644,1 → 1.532,5 ms (1.516,4 a 1.616,9)
- Mediana geral: 259,2 → 198,5 ms (196,3 a 220,5)
- p95 de `pedidos-por-status`: 2.222,9 → 2.026,7 ms (1.892,8 a 2.217,2)
- Mediana de `pedidos-por-status`: 870,8 → 276,3 ms (259,5 a 295,6)
- Requisições de `pedidos-por-status` por execução: 351 → 394 (393 a 397)
- p95 de `vendas-por-dia`: 2.505,4 → 2.311,1 ms (2.239,9 a 2.328,4)
- p95 de `busca-produtos`: 731,0 → 819,3 ms (792,6 a 834,2)
- p95 de `cliente`: 353,9 → 419,7 ms (395,3 a 443,0)
- p95 de `cliente-por-email`: 1.535,2 → 1.578,3 ms (1.487,5 a 1.606,4)
- p95 de `pedidos-do-cliente`: 422,3 → 417,1 ms (402,2 a 485,7)
- p95 de `top-produtos`: 415,3 → 604,4 ms (396,8 a 659,0)
- Memória média do banco: 275,6 → 236,4 MiB (227,8 a 239,7). Da API: 49,2 → 51,5 MiB (49,6 a 53,9)
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** valeu em parte. O req/s subiu de 41,45 para 46,39, com faixas sem sobreposição (41,19 a 41,87 contra 46,26 a 46,86), e a mediana de `pedidos-por-status` caiu de 870,8 para 276,3 ms, sem sobreposição (787,5 a 888,7 contra 259,5 a 295,6). A mediana geral também caiu, de 259,2 para 198,5 ms (234,4 a 286,7 contra 196,3 a 220,5). Mas o p95 da rota (2.211,0 a 2.305,4 contra 1.892,8 a 2.217,2) e o p95 geral (1.579,4 a 1.659,8 contra 1.516,4 a 1.616,9) ficaram na mesma faixa, com sobreposição. Explicação provável, ainda sem prova: o `count` pesava na requisição típica, e por isso a mediana caiu, mas o p95 vem das páginas com `OFFSET` grande, em que a consulta da página ainda lê e descarta até 19.980 linhas, e isso não mudou. O bloco B de `diagnostico/17` só mostra que a página 1000 lê 20.000 linhas, com 11,631 e 59,664 ms no banco ocioso. A ligação disso com o p95 de cerca de 2 s sob carga (a disputa por CPU, por exemplo) não foi medida, e eu não separei o tempo por número de página. `vendas-por-dia` caiu sem sobreposição e `busca-produtos` subiu sem sobreposição, sem que a mudança as tocasse. As demais rotas ficaram na mesma faixa, e `top-produtos` tem 47 a 48 requisições por execução, então o p95 dela vem de poucas amostras. A memória média do banco caiu de 275,6 para 236,4 MiB, sem causa conhecida. Custo: a view não se atualiza sozinha e só serve porque os dados não mudam durante o uso. Não medi o tamanho nem o tempo de criação da view.

**Contra a hipótese do commit:** o commit tinha dois critérios de refutação. No primeiro, o p95 de `pedidos-por-status` caiu da mediana de 2.222,9 para 2.026,7 ms e as três execuções da 09 ficaram abaixo dela (1.892,8, 2.026,7 e 2.217,2), mas a execução 2 ficou só 5,7 ms abaixo e as faixas se sobrepõem em um trecho pequeno (2.211,0 a 2.217,2). Usei a sobreposição das faixas como regra de "claramente", então a condição de refutação se cumpriu: a queda do p95 da rota não é clara. No segundo, o p95 geral melhorou na mediana, de 1.644,1 para 1.532,5 ms, com as três execuções da 09 abaixo da mediana da 08, embora as faixas se sobreponham, então a condição de refutação não se cumpriu. Em resumo, a hipótese foi refutada só pelo primeiro critério, com a ressalva de que a queda do p95 da rota existe e está dentro do ruído, e a previsão de que a rota ficaria mais rápida se confirmou na mediana. O req/s subir não estava na hipótese.

**O que refutaria:** `pedidos-por-status` não cair claramente da mediana anterior (2.222,9 ms de p95 na 08), ou o p95 geral não melhorar.

## 10 Índice com `INCLUDE (cliente_id)` e página de `/pedidos` só com as 4 colunas da resposta

**Rótulo:** `10-pedidos-indice-cobrindo`

**Ideia e fonte:** trocar o `indice_pedidos` `(status, criado_em DESC, id DESC)` por um índice com a mesma chave e `INCLUDE (cliente_id)`, em `banco/09-indice-pedidos-incluindo-cliente-id.sql` (cria o novo e depois apaga o antigo), e pedir na consulta da página de `/pedidos` só as 4 colunas que a rota já devolvia (`id`, `cliente_id`, `status`, `criado_em`) em vez de `SELECT *`. Fontes: [PostgreSQL 16, 11.9 Index-Only Scans and Covering Indexes](https://www.postgresql.org/docs/16/indexes-index-only-scans.html), que diz "The query must reference only columns stored in the index" e que o `INCLUDE` serve a consultas que só leem o índice, e [PostgreSQL 16, CREATE INDEX](https://www.postgresql.org/docs/16/sql-createindex.html), que diz que as colunas do `INCLUDE` são "non-key columns", que "an index-only scan can return the contents of non-key columns without having to visit the index's table" e que "It's wise to be conservative about adding non-key columns to an index". Acesso em 2026-11-19. Nenhuma das duas mede desempenho.

**Status:** Aplicada e medida.

**Hipótese** (commit `883beec`): a página de `/pedidos` deixa de buscar na tabela as até 19.980 linhas que o `OFFSET` pula. Com o `cliente_id` guardado só como carga nas folhas do índice, as 4 colunas da rota saem do próprio índice (`Index Only Scan`), então o p95 de `pedidos-por-status` deve cair. O custo é um índice que também guarda o `cliente_id`, e o índice antigo é apagado em seguida para não ficar repetido. O que refutaria: o p95 de `pedidos-por-status` não cair claramente da mediana anterior (2.026,7 ms na 09), ou o p95 geral não melhorar.

**Antes usado:** mudança 09.
- `resultados/20261119-203628-09-pedidos-total-view`
- `resultados/20261119-203747-09-pedidos-total-view`
- `resultados/20261119-203908-09-pedidos-total-view`

**Depois:**
- `resultados/20261119-221323-10-pedidos-indice-cobrindo`
- `resultados/20261119-221442-10-pedidos-indice-cobrindo`
- `resultados/20261119-221602-10-pedidos-indice-cobrindo`

**Commit medido:** os `contexto.txt` das três execuções citam `883beec`, com `arquivos alterados sem commit: 0`. O banco foi recriado (`docker compose down -v` e `up -d --build`) para aplicar o `.sql`, o `pedidos` ficou com 4 índices (`indice_pedidos_cliente`, `indice_pedidos_criado_em`, `indice_pedidos_incluindo_cliente_id` e `pedidos_pkey`, listados em `diagnostico/22-indices-de-pedidos-na-10.txt`), e o contrato terminou em "Contrato mantido" (42 respostas) ao fim de cada uma das três medições.

**Planos:** `diagnostico/20-pedidos-pagina-e-indice-cobrindo.txt`, tirados antes da mudança, com o banco ocioso e na página 1000 de `pago` (`OFFSET 19980`). A consulta de 4 colunas com o índice antigo usa `Index Scan` e lê 20.000 linhas na tabela, e levou 14,869 e 10,969 ms (1ª e 2ª execução). Com o mesmo índice, a consulta sem o `cliente_id` usa `Index Only Scan` com `Heap Fetches: 0` e levou 3,870 e 3,807 ms, o que mostra que o `cliente_id` fora do índice era o que forçava a ida à tabela. Com o índice com `INCLUDE (cliente_id)` no lugar do antigo (criado numa transação desfeita), a consulta de 4 colunas passou a usar `Index Only Scan`, com `Heap Fetches: 0`, em 3,745 e 3,321 ms. O índice com `INCLUDE` teve o mesmo tamanho do antigo, 22.118.400 bytes (21 MB), e levou 1.032,762 ms para ser criado. No banco recriado com a mudança, o índice novo também tem 22.118.400 bytes (`diagnostico/22-indices-de-pedidos-na-10.txt`), e a documentação avisa que colunas do `INCLUDE` "bloat the size of the index", então esse tamanho igual vale só para estes dados. Também testei uma subconsulta de `id` seguida de 20 buscas pela chave, que levou 9,476 e 3,878 ms e não foi a escolhida. Criar o índice novo sem apagar o antigo também foi testado: o planejador escolhe o novo, e os dois ocupam 22.118.400 bytes cada, por isso o antigo é apagado no mesmo arquivo.

**Execuções usadas e não usadas:** três tentativas, três pastas, todas usadas. As três tiveram 0,00% de erros, contrato mantido, swap do banco e da API em 0 ao fim de cada execução e nenhum evento em `memory.events` (`diagnostico/21-memoria-do-banco-na-10.txt`; o `memory.peak` não foi lido, então o que se sabe é o swap ao fim de cada execução, e não durante a carga).

**Resultado** (medianas, antes → depois, com a faixa das execuções da 10 entre parênteses):
- Requisições por segundo: 46,39 → 52,09 (52,01 a 52,86)
- p95 geral: 1.532,5 → 1.298,8 ms (1.188,7 a 1.313,4)
- Mediana geral: 198,5 → 223,0 ms (189,1 a 241,8)
- p95 de `pedidos-por-status`: 2.026,7 → 683,4 ms (640,1 a 761,5)
- Mediana de `pedidos-por-status`: 276,3 → 97,5 ms (95,2 a 108,6)
- Requisições de `pedidos-por-status` por execução: 394 → 459 (453 a 461)
- p95 de `vendas-por-dia`: 2.311,1 → 1.693,7 ms (1.618,7 a 1.723,8)
- p95 de `busca-produtos`: 819,3 → 873,1 ms (861,1 a 1.026,6)
- p95 de `cliente`: 419,7 → 585,8 ms (481,8 a 599,0)
- p95 de `cliente-por-email`: 1.578,3 → 1.616,0 ms (1.577,6 a 1.619,4)
- p95 de `pedidos-do-cliente`: 417,1 → 533,5 ms (499,7 a 599,1)
- p95 de `top-produtos`: 604,4 → 597,5 ms (407,1 a 642,3)
- Memória média do banco: 236,4 → 215,1 MiB (215,0 a 215,6). Da API: 51,5 → 48,2 MiB (44,8 a 48,5)
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** valeu. O p95 de `pedidos-por-status` caiu de 2.026,7 para 683,4 ms, com faixas sem sobreposição (1.892,8 a 2.217,2 contra 640,1 a 761,5), e a mediana da rota caiu de 276,3 para 97,5 ms. O p95 geral também caiu, de 1.532,5 para 1.298,8 ms (1.516,4 a 1.616,9 contra 1.188,7 a 1.313,4), e o req/s subiu de 46,39 para 52,09 (46,26 a 46,86 contra 52,01 a 52,86), os dois sem sobreposição. Explicação provável, ainda sem prova: o `OFFSET` deixou de buscar na tabela as linhas puladas, e isso pesava na cauda da rota, que vem das páginas com `OFFSET` grande. Não separei o tempo por número de página, e a ligação entre o plano de banco ocioso e o p95 sob carga não foi medida. `vendas-por-dia` também caiu sem sobreposição (2.239,9 a 2.328,4 contra 1.618,7 a 1.723,8), sem que a mudança a tocasse, e a mediana geral subiu de 198,5 para 223,0 ms, mas na mesma faixa, porque as faixas se sobrepõem (196,3 a 220,5 contra 189,1 a 241,8). Três rotas ficaram mais lentas, com faixas sem sobreposição: `cliente` (395,3 a 443,0 contra 481,8 a 599,0), `pedidos-do-cliente` (402,2 a 485,7 contra 499,7 a 599,1, com margem de 14 ms) e `busca-produtos` (792,6 a 834,2 contra 861,1 a 1.026,6). Explicação provável, ainda sem prova: com mais requisições por segundo, o banco, limitado a 1 CPU, atende mais consultas ao mesmo tempo e as rotas leves esperam mais, o mesmo padrão registrado nas mudanças anteriores. Não há medição de CPU confiável neste ambiente para confirmar isso. `cliente-por-email` e `top-produtos` ficaram na mesma faixa, e `top-produtos` tem 49 a 50 requisições por execução, então o p95 dela vem de poucas amostras. A memória média do banco caiu de 236,4 para 215,1 MiB e a da API de 51,5 para 48,2 MiB, sem causa conhecida. Custo: o índice guarda o `cliente_id` a mais, e o tamanho ficou igual ao do índice antigo (22.118.400 bytes). A API só tem rotas `GET`, então não medi o custo em escrita.

**Contra a hipótese do commit:** pelos dois critérios do commit, a hipótese não foi refutada: o p95 de `pedidos-por-status` caiu claramente da mediana anterior (2.026,7 ms), com faixas sem sobreposição, e o p95 geral melhorou, de 1.532,5 para 1.298,8 ms, também sem sobreposição. A previsão de que o p95 da rota cairia se confirmou. Não havia previsão sobre as outras rotas, e três delas ficaram mais lentas.

**O que refutaria:** o p95 de `pedidos-por-status` não cair claramente da mediana anterior (2.026,7 ms na 09), ou o p95 geral não melhorar.

## 11 Índice `(lower(email), id)` em `clientes`

**Rótulo:** `11-clientes-indice-email`

**Ideia e fonte:** criar o índice `(lower(email), id)` em `clientes`, em `banco/10-indice-clientes-email.sql`, para a busca de `/clientes?email=`, que filtra por `lower(email) = lower($1)` e ordena por `id`. A rota não mudou. O índice não é `UNIQUE`, porque nada garante que o e-mail seja único, e o `id` como segunda coluna deixa o `ORDER BY id` no mesmo índice. Fontes: [PostgreSQL 16, 11.7 Indexes on Expressions](https://www.postgresql.org/docs/16/indexes-expressional.html), cujo exemplo é um índice em `lower(col1)` para consultas que usam essa mesma expressão, e [PostgreSQL 16, 11.3 Multicolumn Indexes](https://www.postgresql.org/docs/16/indexes-multicolumn.html), que diz que "equality constraints on leading columns" limitam "the portion of the index that is scanned". Acesso em 2026-11-18, com as duas páginas reconferidas em 2026-11-19. Nenhuma das duas mede desempenho.

**Status:** Aplicada e medida.

**Hipótese** (commit `c5fbeda`): a busca por e-mail deixa de ler as 100 mil linhas de `clientes`. O filtro `lower(email) = lower($1)` só usa índice se o índice for sobre essa mesma expressão, então o banco passa a achar o cliente pela árvore (log N) em vez de varrer a tabela (N), e o p95 de `cliente-por-email` deve cair. O índice não é `UNIQUE` porque nada garante que o e-mail seja único, e o `id` como segunda coluna deixa o `ORDER BY id` da rota no mesmo índice. O custo é um índice a mais em `clientes`. O que refutaria: o p95 de `cliente-por-email` não cair claramente da mediana anterior (1.616,0 ms na 10), ou o p95 geral não melhorar.

**Antes usado:** mudança 10.
- `resultados/20261119-221323-10-pedidos-indice-cobrindo`
- `resultados/20261119-221442-10-pedidos-indice-cobrindo`
- `resultados/20261119-221602-10-pedidos-indice-cobrindo`

**Depois:**
- `resultados/20261119-223843-11-clientes-indice-email`
- `resultados/20261119-224002-11-clientes-indice-email`
- `resultados/20261119-224120-11-clientes-indice-email`

**Commit medido:** os `contexto.txt` das três execuções citam `c5fbeda`, com `arquivos alterados sem commit: 0`. O banco foi recriado (`docker compose down -v` e `up -d --build`) para aplicar o `.sql`, e o contrato terminou em "Contrato mantido" (42 respostas) ao fim de cada uma das três medições. Os índices de `clientes` depois da mudança e os tamanhos estão em `diagnostico/24-memoria-e-indices-de-clientes-na-11.txt`: `indice_clientes_email` tem 4.997.120 bytes, contra 2.260.992 da chave primária.

**Planos:** `diagnostico/23-clientes-por-email-e-indice.txt`, tirados antes da mudança, com o banco ocioso, para a busca de `Cliente3@Exemplo.com`, que está gravado com maiúsculas. Sem índice novo, o plano é `Seq Scan` em `clientes`, com 99.999 linhas descartadas, e a consulta levou 41,105 e 43,552 ms (1ª e 2ª execução). Com o índice `(lower(email), id)` o plano é `Bitmap Index Scan` e levou 0,081 e 0,026 ms. O primeiro rascunho do arquivo tinha a chave `(id, lower(email))`, com o `id` na frente, e esse índice não é usado: o plano continuou em `Seq Scan`, com 41,146 e 44,612 ms. O rascunho foi corrigido antes do commit. Os dados têm 33.333 e-mails com alguma maiúscula entre 100.000 (`diagnostico/25-emails-de-clientes-com-maiuscula.txt`), então a ideia de trocar o filtro por `email = $1` e fazer o `lower` na API, com um índice comum em `email`, foi descartada: ela deixaria de achar esses clientes.

**Execuções usadas e não usadas:** três tentativas, três pastas, todas usadas. As três tiveram 0,00% de erros, contrato mantido, swap do banco e da API em 0 ao fim de cada execução e nenhum evento em `memory.events` (`diagnostico/24-memoria-e-indices-de-clientes-na-11.txt`; o `memory.peak` não foi lido, então o que se sabe é o swap ao fim de cada execução, e não durante a carga).

**Resultado** (medianas, antes → depois, com a faixa das execuções da 11 entre parênteses):
- Requisições por segundo: 52,09 → 60,43 (58,15 a 60,55)
- p95 geral: 1.298,8 → 972,5 ms (911,6 a 990,5)
- Mediana geral: 223,0 → 250,3 ms (238,1 a 265,8)
- p95 de `cliente-por-email`: 1.616,0 → 709,6 ms (709,1 a 726,0)
- Mediana de `cliente-por-email`: 876,1 → 169,5 ms (144,9 a 198,6)
- Requisições de `cliente-por-email` por execução: 457 → 526 (504 a 526)
- p95 de `vendas-por-dia`: 1.693,7 → 1.395,0 ms (1.289,1 a 1.417,4)
- p95 de `pedidos-por-status`: 683,4 → 873,4 ms (839,5 a 1.093,6)
- p95 de `cliente`: 585,8 → 692,7 ms (656,1 a 709,6)
- p95 de `pedidos-do-cliente`: 533,5 → 696,8 ms (676,1 a 780,1)
- p95 de `busca-produtos`: 873,1 → 982,3 ms (975,1 a 1.016,1)
- p95 de `top-produtos`: 597,5 → 580,9 ms (578,6 a 592,5)
- Memória média do banco: 215,1 → 213,1 MiB (212,5 a 218,1). Da API: 48,2 → 44,3 MiB (43,6 a 44,6)
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** valeu. O p95 de `cliente-por-email` caiu de 1.616,0 para 709,6 ms, com faixas sem sobreposição (1.577,6 a 1.619,4 contra 709,1 a 726,0), e a mediana da rota caiu de 876,1 para 169,5 ms. O p95 geral também caiu, de 1.298,8 para 972,5 ms (1.188,7 a 1.313,4 contra 911,6 a 990,5), e o req/s subiu de 52,09 para 60,43 (52,01 a 52,86 contra 58,15 a 60,55), os dois sem sobreposição. O p95 de `cliente-por-email` ainda é 709,6 ms, embora a consulta isolada leve 0,026 a 0,081 ms com índice. Explicação provável, ainda sem prova: sob a carga, a rota espera pela fila de conexões e pela disputa por CPU, e não pela consulta, e não medi essa espera. `vendas-por-dia` também caiu sem sobreposição (1.618,7 a 1.723,8 contra 1.289,1 a 1.417,4), sem que a mudança a tocasse, então o ganho do p95 geral não pode ser atribuído por inteiro ao índice. A mediana geral subiu de 223,0 para 250,3 ms, mas na mesma faixa, porque as faixas se sobrepõem (189,1 a 241,8 contra 238,1 a 265,8). Três rotas ficaram mais lentas, com faixas sem sobreposição: `pedidos-por-status` (640,1 a 761,5 contra 839,5 a 1.093,6), `cliente` (481,8 a 599,0 contra 656,1 a 709,6) e `pedidos-do-cliente` (499,7 a 599,1 contra 676,1 a 780,1). Explicação provável, ainda sem prova: com mais requisições por segundo, as rotas leves esperam mais pelos recursos limitados do banco (1 CPU) e da API (0,5 CPU), o mesmo padrão (rotas leves pioram quando o req/s sobe) já visto nas mudanças anteriores. Não há medição de CPU confiável neste ambiente para confirmar isso, e não sei se o limite que pesa é o do banco ou o da API. `busca-produtos` e `top-produtos` ficaram na mesma faixa, e `top-produtos` tem 59 a 63 requisições por execução, então o p95 dela vem de poucas amostras. A memória média do banco ficou na mesma faixa, e a da API caiu de 48,2 para 44,3 MiB, sem causa conhecida. Custo: um índice de 4.997.120 bytes a mais em `clientes`. A API só tem rotas `GET`, então não medi o custo em escrita.

**Contra a hipótese do commit:** pelos dois critérios do commit, a hipótese não foi refutada: o p95 de `cliente-por-email` caiu claramente da mediana anterior (1.616,0 ms), com faixas sem sobreposição, e o p95 geral melhorou, de 1.298,8 para 972,5 ms, também sem sobreposição. A previsão de que o p95 da rota cairia se confirmou. Não havia previsão sobre as outras rotas, e três delas ficaram mais lentas.

**O que refutaria:** o p95 de `cliente-por-email` não cair claramente da mediana anterior (1.616,0 ms na 10), ou o p95 geral não melhorar.
