CREATE INDEX indice_pedidos ON pedidos USING btree (status ASC, criado_em DESC, id DESC);
