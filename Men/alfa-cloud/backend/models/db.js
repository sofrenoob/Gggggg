const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('alfa-cloud.db');

module.exports = { db };
  const dbPath = path.resolve(__dirname, '../../database/init.sql');
  const db = new sqlite3.Database('alfa-cloud.db', (err) => {
    if (err) {
      console.error('Erro ao conectar ao banco de dados:', err.message);
    } else {
      console.log('Conectado ao banco de dados SQLite.');
    }
  });

  // Exemplo de uso do script de criação, se necessário
  // db.exec(fs.readFileSync(dbPath, 'utf8'));

  return db;
}

module.exports = { connectDB };
