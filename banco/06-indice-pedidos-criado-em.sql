-- indice comum na coluna pura, para a rota usar um intervalo em criado_em: o criado_em::date do filtro antigo impediria o uso, e este indice serve tambem a outras consultas por essa coluna
CREATE INDEX indice_pedidos_criado_em ON pedidos USING btree (criado_em ASC);
