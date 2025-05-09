const { testProxy } = require('../backend/services/proxyService');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '../database/alfa-cloud.db');
const db = new sqlite3.Database(dbPath);

const checkProxies = async () => {
  db.all('SELECT * FROM proxies', [], async (err, rows) => {
    if (err) {
      console.error('Error fetching proxies:', err.message);
      return;
    }

    for (const proxy of rows) {
      try {
        const isActive = await testProxy(proxy.ip, proxy.port);
        const status = isActive ? 'Active' : 'Inactive';

        db.run(
          `UPDATE proxies SET status = ? WHERE id = ?`,
          [status, proxy.id],
          (err) => {
            if (err) {
              console.error(`Error updating status for proxy ${proxy.name}:`, err.message);
            } else {
              console.log(`Proxy ${proxy.name} status updated to ${status}`);
            }
          }
        );
      } catch (error) {
        console.error(`Proxy ${proxy.name} test failed:`, error.message);
      }
    }
  });
};

// Check proxies every 30 seconds
setInterval(checkProxies, 30000);