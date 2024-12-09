//https://node-postgres.com/
const { Pool } = require('pg');

const clientPool = new Pool({
	user: 'cybertec',
	password: '0Grst5XhQxuzYi8AjqWcHMlTe9SmsKHjCulz0Dw1yLFvu2W2NMVMPWs5GI62YfRE',
	host: '10.16.38.203',
	port: '5432',
	database: 'postgres',
});

exports.query  = async (text, params) => {
    const start = Date.now()
    const res = await clientPool.query(text, params)
    const duration = Date.now() - start
    console.log('executed query', { text, duration, rows: res.rowCount })
    return res
  }
