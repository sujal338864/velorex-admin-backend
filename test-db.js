const pool = require("./models/db");

(async () => {
  try {
    const res = await pool.query("select 1");
    console.log("✅ DB connected:", res.rows);
    process.exit(0);
  } catch (err) {
    console.error("❌ DB error:", err.message);
    process.exit(1);
  }
})();
