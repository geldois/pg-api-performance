const { Pool } = require('pg');

const config = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'loja',
  database: process.env.DB_NAME || 'loja',
};

const pgPool = new Pool(config);

async function consultar(sql, parametros = []) {
  const cliente = await pgPool.connect();

  let released = false;

  try {
    const resultado = await cliente.query(sql, parametros);

    return resultado.rows;
  } catch (error) {
    if (!released) {
      cliente.release(true);

      released = true;
    }

    throw error;
  } finally {
    if (!released) {
      cliente.release();

      released = true;
    }
  }
}

module.exports = { consultar };
