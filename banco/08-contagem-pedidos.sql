-- a rota deixa de contar de 25 mil a 300 mil pedidos a cada requisição, porque mesmo com índice o count visita cada linha do status (O(n)): a contagem por status é feita uma vez, na criação do banco, e a rota só lê o total pronto, então pedidos-por-status deve ficar mais rápida. O custo é que a view não se atualiza sozinha
CREATE MATERIALIZED VIEW contagem_pedidos_por_status AS
SELECT status, count(*) AS total
FROM pedidos
GROUP BY status;
