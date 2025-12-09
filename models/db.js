// models/db.js
const sql = require("mssql");
require("dotenv").config();

const config = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_DATABASE,
  options: {
    encrypt: process.env.DB_ENCRYPT === "true",
    trustServerCertificate: true, // allow self-signed certs
  },
};

const poolPromise = new sql.ConnectionPool(config)
  .connect()
  .then(pool => {
    console.log("✅ Connected to SQL Server:", process.env.DB_DATABASE);
    return pool;
  })
  .catch(err => {
    console.error("❌ Database Connection Failed:", err);
  });

module.exports = {
  sql,
  poolPromise,
};
