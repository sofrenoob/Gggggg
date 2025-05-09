const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '../database/alfa-cloud.db');
const db = new sqlite3.Database(dbPath);

// Create Users Table
db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      password TEXT NOT NULL,
      limit INTEGER DEFAULT 0,
      expiration_date DATE DEFAULT NULL
    );
  `);

  // Create Proxies Table
  db.run(`
    CREATE TABLE IF NOT EXISTS proxies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      ip TEXT NOT NULL,
      port INTEGER NOT NULL,
      mode TEXT NOT NULL,
      operator TEXT DEFAULT NULL,
      status TEXT DEFAULT 'Inactive'
    );
  `);

  console.log("Database initialized successfully!");
});

db.close();