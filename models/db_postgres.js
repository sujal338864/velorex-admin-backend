// models/db_postgres.js

// Load .env ONLY in development, never in production
if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

const { Pool } = require("pg");

const connectionString = process.env.PG_CONNECTION_STRING;

if (!connectionString) {
  console.error("❌ PG_CONNECTION_STRING NOT FOUND in environment variables");
  process.exit(1);
}

const pool = new Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false,
  },
});

// Test DB connection
pool.connect()
  .then(client => {
    console.log("🟣 Connected to PostgreSQL (Render)");
    client.release();
  })
  .catch(err => {
    console.error("❌ PostgreSQL connection error:", err.message);
  });

module.exports = { pool };
