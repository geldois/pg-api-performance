-- a página de /pedidos deixa de buscar na tabela as até 19.980 linhas que o OFFSET pula: com o cliente_id guardado só como carga nas folhas do índice, as 4 colunas da rota saem do próprio índice (Index Only Scan), então o p95 de pedidos-por-status deve cair. O custo é um índice que também guarda o cliente_id, e o antigo é apagado em seguida para não ficar repetido
CREATE INDEX indice_pedidos_incluindo_cliente_id ON pedidos USING btree (status ASC, criado_em DESC, id DESC)
INCLUDE (cliente_id);

DROP INDEX indice_pedidos;
