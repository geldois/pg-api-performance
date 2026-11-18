# Experimentos

Uma linha por ideia aplicada na tabela, e os detalhes de cada uma na seção logo abaixo. O "antes" de cada mudança é a linha de base ou a mudança anterior, e a seção diz qual. Todo número vem dos arquivos de `resultados/` (medianas das três execuções). Os parâmetros de carga são os mesmos em todas as medições: 20 usuários virtuais, 60 s, semente 42.

| # | Ideia | Fonte | Status | Antes | Depois | Pastas | Conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | Índice em `itens_pedido(pedido_id)` | [PostgreSQL 16, 11.1](https://www.postgresql.org/docs/16/indexes-intro.html) | Aplicada e medida | 4,21 req/s, p95 14.698,7 ms | 7,59 req/s, p95 7.672,0 ms | antes: `resultados/20261114-*-00-linha-de-base` (3). Depois: `resultados/20261118-*-01-indice-itens-pedido` (3) | Cada consulta de itens ficou barata, mas o N+1 continua |
| 02 | Pool de conexões (`pg.Pool`, `max` 10) | [node-postgres, Pooling](https://node-postgres.com/features/pooling) | Aplicada e medida | 7,59 req/s, p95 7.672,0 ms | 9,12 req/s, p95 6.918,9 ms | antes: `resultados/20261118-17*-01-indice-itens-pedido` (3). Depois: `resultados/20261118-18*-02-pool-de-conexoes` (3) | Melhorou o geral, mas as rotas leves ficaram mais lentas |

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
