-- só pedido_id basta: o ORDER BY id da consulta incide sobre poucas linhas (media de 3 por pedido), entao ordenar em memoria (k log k) custa quase nada. (pedido_id, id) evitaria o sort, mas o ganho não paga um indice maior
CREATE INDEX indice_itens_pedido ON itens_pedido USING btree (pedido_id);
