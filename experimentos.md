# Experimentos

Uma linha por ideia aplicada na tabela, e os detalhes de cada uma na seção logo abaixo. O "antes" de cada mudança é a linha de base ou a mudança anterior, e a seção diz qual. Todo número de antes e depois vem dos arquivos de `resultados/` (medianas e faixas das três execuções), e os de diagnóstico vêm de arquivos em `diagnostico/`. Os parâmetros de carga são os mesmos em todas as medições: 20 usuários virtuais, 60 s, semente 42.

| # | Ideia | Fonte | Status | Antes | Depois | Pastas | Conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | Índice em `itens_pedido(pedido_id)` | [PostgreSQL 16, 11.1](https://www.postgresql.org/docs/16/indexes-intro.html) | Aplicada e medida | 4,21 req/s, p95 14.698,7 ms | 7,59 req/s, p95 7.672,0 ms | Antes: `resultados/20261114-*-00-linha-de-base` (3). Depois: `resultados/20261118-*-01-indice-itens-pedido` (3) | `pedidos-do-cliente` caiu de 15.928,5 para 6.402,3 ms, mas o N+1 continua |
| 02 | Pool de conexões (`pg.Pool`, `max` 10) | [node-postgres, Pooling](https://node-postgres.com/features/pooling) e [node-postgres, Pool](https://node-postgres.com/apis/pool) | Aplicada e medida | 7,59 req/s, p95 7.672,0 ms | 9,12 req/s, p95 6.918,9 ms | Antes: `resultados/20261118-17*-01-indice-itens-pedido` (3). Depois: `resultados/20261118-18*-02-pool-de-conexoes` (3) | Melhorou o geral, mas `pedidos-do-cliente`, `cliente` e `busca-produtos` ficaram mais lentas |
| 03 | Consulta única com `LEFT JOIN` em `/clientes/:id/pedidos` | [Rails Guides, N+1](https://guides.rubyonrails.org/active_record_querying.html) e [PostgreSQL 16, 7.2](https://www.postgresql.org/docs/16/queries-table-expressions.html) | Aplicada e medida | 9,12 req/s, p95 6.918,9 ms | 9,75 req/s, p95 5.123,3 ms | Antes: `resultados/20261118-18*-02-pool-de-conexoes` (3). Depois: `resultados/20261118-20*-03-join-pedidos-do-cliente` (3) | `pedidos-do-cliente` caiu de 8.513,6 para 2.773,3 ms, e as rotas leves pioraram |
| 04 | Pool com `max` 20, igual ao número de usuários da carga | [node-postgres, Pooling](https://node-postgres.com/features/pooling) e [node-postgres, Pool sizing](https://node-postgres.com/guides/pool-sizing) | Aplicada, sem ganho | 9,75 req/s, p95 5.123,3 ms | 9,66 req/s, p95 7.399,6 ms | Antes: `resultados/20261118-20*-03-join-pedidos-do-cliente` (3). Depois: `resultados/20261118-20*-04-pool-max-20` (3) | As rotas leves voltaram a ser rápidas, as pesadas ficaram mais lentas e o p95 geral piorou |
| 05 | Índice `(status, criado_em DESC, id DESC)` em `pedidos` | [PostgreSQL 16, 11.4](https://www.postgresql.org/docs/16/indexes-ordering.html) e [PostgreSQL 16, 11.3](https://www.postgresql.org/docs/16/indexes-multicolumn.html) | Aplicada e medida | 9,66 req/s, p95 7.399,6 ms | 13,64 req/s, p95 4.738,1 ms | Antes: `resultados/20261118-20*-04-pool-max-20` (3). Depois: `resultados/20261118-21*-05-indice-pedidos-status` (3) | `pedidos-por-status` caiu de 9.358,0 para 3.259,3 ms e o req/s geral subiu |

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
