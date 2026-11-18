# Experimentos

Uma linha por ideia aplicada na tabela, e os detalhes de cada uma na seção logo abaixo. O "antes" de cada mudança é a linha de base ou a mudança anterior, e a seção diz qual. Todo número vem dos arquivos de `resultados/` (medianas das três execuções). Os parâmetros de carga são os mesmos em todas as medições: 20 usuários virtuais, 60 s, semente 42.

| # | Ideia | Fonte | Status | Antes | Depois | Pastas | Conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | Índice em `itens_pedido(pedido_id)` | [PostgreSQL 16, 11.1](https://www.postgresql.org/docs/16/indexes-intro.html) | Aplicada e medida | 4,21 req/s, p95 14.698,7 ms | 7,59 req/s, p95 7.672,0 ms | antes: `resultados/20261114-*-00-linha-de-base` (3). Depois: `resultados/20261118-*-01-indice-itens-pedido` (3) | Cada consulta de itens ficou barata, mas o N+1 continua |

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
