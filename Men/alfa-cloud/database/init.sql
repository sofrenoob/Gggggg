-- Create Users Table
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,
  password TEXT NOT NULL,
  limit INTEGER DEFAULT 0,
  expiration_date DATE DEFAULT NULL
);

-- Create Proxies Table
CREATE TABLE IF NOT EXISTS proxies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  ip TEXT NOT NULL,
  port INTEGER NOT NULL,
  mode TEXT NOT NULL,
  operator TEXT DEFAULT NULL,
  status TEXT DEFAULT 'Inactive'
);
