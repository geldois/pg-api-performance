-- a rota evita vasculhar as 500 mil linhas O(N) e o Sort k log k: pelo indice acha os pedidos do cliente ja em ordem, com log N + k
CREATE INDEX indice_pedidos_cliente ON pedidos USING btree (cliente_id ASC, criado_em DESC, id DESC);
