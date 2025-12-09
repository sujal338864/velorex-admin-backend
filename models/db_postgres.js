// models/db_postgres.js

// Load .env ONLY in development
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
    rejectUnauthorized: false, // Required for Render + Supabase
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

// IMPORTANT: Add query function
async function query(text, params) {
  return pool.query(text, params);
}

module.exports = { pool, query };
