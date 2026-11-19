-- a rota deixa de somar 1,5 milhao de itens a cada requisicao: a soma por produto e feita uma vez, na criação do banco, e a rota só lê as linhas prontas, então top-produtos deve ficar bem mais rápida. Porém, o custo é que a view não se atualiza sozinha
CREATE MATERIALIZED VIEW vendas_por_produto AS
SELECT pr.id, pr.nome, pr.categoria, sum(i.quantidade) AS unidades, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
FROM itens_pedido i
JOIN pedidos p ON p.id = i.pedido_id
JOIN produtos pr ON pr.id = i.produto_id
WHERE p.status <> 'cancelado'
GROUP BY pr.id, pr.nome, pr.categoria;
