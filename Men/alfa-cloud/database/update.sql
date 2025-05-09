-- Add New Columns for Statistics
ALTER TABLE users ADD COLUMN traffic_used INTEGER DEFAULT 0;
ALTER TABLE proxies ADD COLUMN latency INTEGER DEFAULT NULL;
