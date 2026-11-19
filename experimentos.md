# Experimentos

Uma linha por ideia aplicada na tabela, e os detalhes de cada uma na seção logo abaixo. O "antes" de cada mudança é a linha de base ou a mudança anterior, e a seção diz qual. Todo número vem dos arquivos de `resultados/` (medianas das três execuções). Os parâmetros de carga são os mesmos em todas as medições: 20 usuários virtuais, 60 s, semente 42.

| # | Ideia | Fonte | Status | Antes | Depois | Pastas | Conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | Índice em `itens_pedido(pedido_id)` | [PostgreSQL 16, 11.1](https://www.postgresql.org/docs/16/indexes-intro.html) | Aplicada e medida | 4,21 req/s, p95 14.698,7 ms | 7,59 req/s, p95 7.672,0 ms | antes: `resultados/20261114-*-00-linha-de-base` (3). Depois: `resultados/20261118-*-01-indice-itens-pedido` (3) | Cada consulta de itens ficou barata, mas o N+1 continua |
| 02 | Pool de conexões (`pg.Pool`, `max` 10) | [node-postgres, Pooling](https://node-postgres.com/features/pooling) | Aplicada e medida | 7,59 req/s, p95 7.672,0 ms | 9,12 req/s, p95 6.918,9 ms | antes: `resultados/20261118-17*-01-indice-itens-pedido` (3). Depois: `resultados/20261118-18*-02-pool-de-conexoes` (3) | Melhorou o geral, mas as rotas leves ficaram mais lentas |
| 03 | Consulta única com `LEFT JOIN` em `/clientes/:id/pedidos` | [Rails Guides, N+1](https://guides.rubyonrails.org/active_record_querying.html) e [PostgreSQL 16, 7.2](https://www.postgresql.org/docs/16/queries-table-expressions.html) | Aplicada e medida | 9,12 req/s, p95 6.918,9 ms | 9,75 req/s, p95 5.123,3 ms | antes: `resultados/20261118-18*-02-pool-de-conexoes` (3). Depois: `resultados/20261118-20*-03-join-pedidos-do-cliente` (3) | `pedidos-do-cliente` caiu de 8.513,6 para 2.773,3 ms, e as rotas leves pioraram |
| 04 | Pool com `max` 20, igual ao número de usuários da carga | [node-postgres, Pooling](https://node-postgres.com/features/pooling) | Aplicada, sem ganho | 9,75 req/s, p95 5.123,3 ms | 9,66 req/s, p95 7.399,6 ms | antes: `resultados/20261118-20*-03-join-pedidos-do-cliente` (3). Depois: `resultados/20261118-20*-04-pool-max-20` (3) | As rotas leves voltaram a ser rápidas, as pesadas ficaram mais lentas e o p95 geral piorou |

## 01 Índice em `itens_pedido(pedido_id)`

**Rótulo:** `01-indice-itens-pedido`

**Ideia e fonte:** criar um índice em `itens_pedido(pedido_id)`. Fonte: [PostgreSQL 16, 11.1 Introduction](https://www.postgresql.org/docs/16/indexes-intro.html), acesso em 2026-11-18.

**Status:** Aplicada e medida.

**Hipótese** (commit `b572ea1`): criar o índice deve reduzir muito o p95 de `/clientes/:id/pedidos`, porque cada consulta de itens deixa de ler as 1,5 milhão de linhas. Deve reduzir menos o de `vendas-por-dia`, porque a leitura de `pedidos` continua inteira, e não deve mudar `top-produtos`, que lê quase toda a tabela.

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
- CPU média do banco: 6,0% → 48,7%. Da API: 0,3% → 4,9%. O CPU do `podman stats` não é confiável neste ambiente (ver `diagnostico/00-cpu-por-cgroup-linha-de-base.txt`)

**Conclusão:** o índice trocou a leitura inteira de `itens_pedido` por uma busca em árvore em cada consulta, mas o número de consultas do N+1 continua o mesmo, por isso `pedidos-do-cliente` ainda leva 6,4 s. `vendas-por-dia` melhorou pouco, e as faixas das execuções se sobrepõem (índice 8.282,2 a 9.777,6 ms, linha de base 9.331,0 a 10.427,0 ms). `top-produtos` piorou, com só 6 ou 7 requisições por execução, e a causa ainda é hipótese: o banco, limitado a 1 CPU, atende mais requisições das outras rotas.

**O que refutaria:** uma nova medição com as medianas sobrepostas à linha de base.

## 02 Pool de conexões

**Rótulo:** `02-pool-de-conexoes`

**Ideia e fonte:** trocar a conexão nova a cada consulta por um `pg.Pool` com `max` 10, o padrão. Fonte: [node-postgres, Pooling](https://node-postgres.com/features/pooling), acesso em 2026-11-18. A página afirma que conectar um cliente novo exige um handshake que "can take 20-30 milliseconds", sem dizer como mediu. Não é uma medição nossa.

**Status:** Aplicada e medida.

**Hipótese** (commit `e3fe8e5`): trocar a conexão nova a cada consulta por um pool deve reduzir o custo fixo que vem antes de cada consulta (rede, CPU e processo novo no banco). O ganho deve ser maior nas rotas que fazem mais consultas por requisição, como `/clientes/:id/pedidos`, e pequeno nas rotas de uma consulta única e pesada, como `top-produtos` e `vendas-por-dia`.

**Antes usado:** mudança 01.
- `resultados/20261118-170530-01-indice-itens-pedido`
- `resultados/20261118-170703-01-indice-itens-pedido`
- `resultados/20261118-170835-01-indice-itens-pedido`

**Depois:**
- `resultados/20261118-181942-02-pool-de-conexoes`
- `resultados/20261118-182111-02-pool-de-conexoes`
- `resultados/20261118-182243-02-pool-de-conexoes`

**Execuções descartadas:** seis execuções anteriores com o mesmo rótulo não entraram na mediana nem no repositório, porque o banco tinha 1,1 MB em swap por pressão de memória do computador (o uso do container estava abaixo do limite). As três execuções acima foram feitas depois de reiniciar os containers, com swap zero antes e depois de cada uma.

**Resultado** (medianas das três execuções, antes → depois):
- Requisições por segundo: 7,59 → 9,12
- p95 geral: 7.672,0 → 6.918,9 ms
- p95 de `pedidos-do-cliente`: 6.402,3 → 8.513,6 ms
- p95 de `cliente`: 198,9 → 610,5 ms
- p95 de `busca-produtos`: 640,2 → 830,9 ms
- p95 de `pedidos-por-status`: 9.200,1 → 5.685,2 ms
- p95 de `vendas-por-dia`: 8.556,8 → 4.511,2 ms
- p95 de `top-produtos`: 27.371,0 → 16.655,4 ms
- Memória média do banco: 331,8 → 274,7 MiB. Da API: 68,9 → 36,7 MiB
- CPU: o CPU do `podman stats` não é confiável neste ambiente, então não é citado

**Conclusão:** o pool tirou o custo de abrir uma conexão a cada consulta (rede, CPU e processo novo no banco), e o geral melhorou. A hipótese acertou que o custo estava antes da consulta, mas errou onde o ganho aparece: as rotas pesadas de uma consulta melhoraram e as rotas leves e as de várias consultas pioraram. A explicação provável, ainda sem prova, é que com `max` 10 e 20 usuários as consultas esperam numa fila por uma conexão, e as leves ficam presas atrás das pesadas. Sem pool, cada consulta tinha o seu processo no banco e o sistema repartia a CPU entre todos. A CPU limita igualmente nos dois casos, mas o pool muda quem espera e onde. Uma conexão destruída a cada erro (`release(true)`) custa uma reconexão, mas só no caminho de erro.

**O que refutaria:** com `max` igual ao número de usuários (20), as rotas leves não voltarem ao nível anterior ao pool.

## 03 Consulta única com `LEFT JOIN` em `/clientes/:id/pedidos`

**Rótulo:** `03-join-pedidos-do-cliente`

**Ideia e fonte:** trocar as 1 + 1 + P + I consultas da rota (cliente, pedidos, itens de cada pedido e produto de cada item) por uma consulta só, com `LEFT JOIN` a partir de `clientes`. Fontes: [Rails Guides, 16.1 N + 1 Queries Problem](https://guides.rubyonrails.org/active_record_querying.html), que define o problema com o exemplo de "11 queries in total" trocadas por 2, e [PostgreSQL 16, 7.2 Table Expressions](https://www.postgresql.org/docs/16/queries-table-expressions.html), que diz que no `LEFT OUTER JOIN` "a joined row is added with null values in columns of T2", por isso o pedido sem itens continua na resposta. Acesso em 2026-11-18. Nenhuma das duas mede latência.

**Status:** Aplicada e medida.

**Hipótese** (commit `1ae7302`): trocar as consultas por uma única, com `LEFT JOIN` a partir de `clientes`, deve reduzir o p95 de `/clientes/:id/pedidos`, porque elimina as idas ao banco e as esperas por uma conexão do pool a cada pedido e a cada item. As outras rotas só devem mudar por efeito indireto, com menos disputa pelo pool e pelo banco.

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

**Conclusão:** a consulta única tirou as idas ao banco por pedido e por item e a espera por uma conexão a cada uma, e o p95 de `pedidos-do-cliente` caiu de 8.513,6 para 2.773,3 ms, puxando o geral para 5.123,3 ms. As rotas leves pioraram de novo (`cliente` foi de 610,5 para 1.542,2 ms). A explicação provável, ainda sem prova, é a mesma fila do pool: passa mais requisição por segundo e as consultas rápidas esperam atrás das pesadas. A resposta da rota ficou idêntica à anterior, e o contrato mantido não cobre cliente sem pedidos nem pedido sem itens porque os dados não têm esses casos. Esses dois casos foram provados em bancos descartáveis, com os dados escritos à mão, comparando a rota antiga e a nova.

**O que refutaria:** o p95 de `pedidos-do-cliente` não cair.

## 04 Pool com `max` 20

**Rótulo:** `04-pool-max-20`

**Ideia e fonte:** subir o `max` do pool de 10 para 20, igual aos 20 usuários da carga. Fonte: [node-postgres, Pooling](https://node-postgres.com/features/pooling), acesso em 2026-11-18. A ideia vem do achado das mudanças 02 e 03: as rotas leves esperavam na fila do pool.

**Status:** Aplicada, sem ganho.

**Hipótese** (commit `79e301d`): subir o `max` do pool de 10 para 20 deve reduzir o p95 das rotas leves (`cliente`, `cliente-por-email` e `busca-produtos`) e subir o req/s geral, porque com 10 conexões as requisições leves esperam na fila do pool atrás das pesadas. O ganho deve ser menor nas rotas pesadas (`pedidos-por-status` e `vendas-por-dia`), porque o banco já está no teto de 1 CPU e mais conexões só dividem a mesma CPU.

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

**Conclusão:** não valeu. O `max` 20 tirou a fila do pool e as rotas leves voltaram a ser rápidas (`cliente` de 1.542,2 para 85,8 ms), mas as pesadas ficaram mais lentas e o p95 geral subiu de 5.123,3 para 7.399,6 ms, com o req/s praticamente igual (9,75 contra 9,66). Como são 20 usuários fixos, a lei de Little diz que o tempo médio não muda, só mudou quem espera.

**O que refutaria:** o `max` 20 deixar de piorar as pesadas em outra carga.
