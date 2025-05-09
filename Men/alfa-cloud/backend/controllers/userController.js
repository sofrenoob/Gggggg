const express = require('express');
const router = express.Router();
const { db } = require('../models/db');

// List Users
router.get('/', (req, res) => {
  db.all('SELECT * FROM users', [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// Add User
router.post('/', (req, res) => {
  const { username, password, limit, expiration_date } = req.body;
  const sql = `INSERT INTO users (username, password, limit, expiration_date) VALUES (?, ?, ?, ?)`;
  db.run(sql, [username, password, limit, expiration_date], function (err) {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json({ id: this.lastID });
  });
});

module.exports = router;
