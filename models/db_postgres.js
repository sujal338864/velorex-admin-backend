// models/db_postgres.js

if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.PG_HOST,        // force IPv4 host
  port: Number(process.env.PG_PORT) || 5432,
  user: process.env.PG_USER,
  password: process.env.PG_PASSWORD,
  database: process.env.PG_DATABASE,
  ssl: {
    rejectUnauthorized: false       // REQUIRED for Supabase
  },
  keepAlive: true                   // prevents IPv6 ENETUNREACH
});

// Test connection
pool.connect()
  .then(client => {
    console.log("🟣 Connected to PostgreSQL (Supabase)");
    client.release();
  })
  .catch(err => {
    console.error("❌ PostgreSQL connection error:", err.message);
  });

// Query helper
async function query(text, params) {
  const res = await pool.query(text, params);
  return res;
}

module.exports = { pool, query };
