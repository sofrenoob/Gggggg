const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '../database/alfa-cloud.db');
const db = new sqlite3.Database(dbPath);

// Insert Initial Users
db.serialize(() => {
  db.run(
    `INSERT INTO users (username, password, limit, expiration_date) VALUES 
    ('admin', 'admin123', 100, '2025-12-31'),
    ('testuser', 'test123', 50, '2025-06-30');`
  );

  // Insert Initial Proxies
  db.run(
    `INSERT INTO proxies (name, ip, port, mode, operator, status) VALUES 
    ('Proxy1', '192.168.1.1', 8080, 'HTTP', 'Vivo', 'Active'),
    ('Proxy2', '192.168.1.2', 3128, 'WebSocket', 'Claro', 'Inactive');`
  );

  console.log("Initial data populated successfully!");
});

db.close();