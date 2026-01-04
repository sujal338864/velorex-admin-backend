const { Pool } = require("pg");
require("dotenv").config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: Number(process.env.SUPABASE_DB_PORT),
  user: process.env.SUPABASE_DB_USER,
  password: process.env.SUPABASE_DB_PASSWORD,
  database: process.env.SUPABASE_DB_NAME,

  ssl: { rejectUnauthorized: false },

  // ✅ SAFE for Supabase Pooler
  max: 3,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on("connect", () => {
  console.log("✅ PostgreSQL connected");
});

pool.on("error", (err) => {
  console.error("🔥 PG pool error:", err);
});

module.exports = pool;


// const { Pool } = require("pg");
// require("dotenv").config();

// const pool = new Pool({
//   host: process.env.SUPABASE_DB_HOST,
//   port: Number(process.env.SUPABASE_DB_PORT),
//   user: process.env.SUPABASE_DB_USER,
//   password: process.env.SUPABASE_DB_PASSWORD,
//   database: process.env.SUPABASE_DB_NAME,
//   ssl: { rejectUnauthorized: false },
// });

// module.exports = pool;



// // models/db.js
// const sql = require("mssql");
// require("dotenv").config();

// const config = {
//   user: process.env.DB_USER,
//   password: process.env.DB_PASSWORD,
//   server: process.env.DB_SERVER,
//   database: process.env.DB_DATABASE,
//   options: {
//     encrypt: process.env.DB_ENCRYPT === "true",
//     trustServerCertificate: true, // allow self-signed certs
//   },
// };

// const poolPromise = new sql.ConnectionPool(config)
//   .connect()
//   .then(pool => {
//     console.log("✅ Connected to SQL Server:", process.env.DB_DATABASE);
//     return pool;
//   })
//   .catch(err => {
//     console.error("❌ Database Connection Failed:", err);
//   });

// module.exports = {
//   sql,
//   poolPromise,
// };
