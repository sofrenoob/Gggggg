const express = require('express');
const router = express.Router();
const { db } = require('../models/db');

// List Proxies
router.get('/', (req, res) => {
  db.all('SELECT * FROM proxies', [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// Add Proxy
router.post('/', (req, res) => {
  const { name, ip, port, mode, operator } = req.body;
  const sql = `INSERT INTO proxies (name, ip, port, mode, operator) VALUES (?, ?, ?, ?, ?)`;
  db.run(sql, [name, ip, port, mode, operator], function (err) {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json({ id: this.lastID });
  });
});

module.exports = router;
