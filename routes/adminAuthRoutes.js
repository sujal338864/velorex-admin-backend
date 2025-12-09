const express = require("express");
const router = express.Router();
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const pg = require("../models/db_postgres"); // PostgreSQL

/* ======================================================
   🟣 ADMIN SIGNUP
====================================================== */
router.post("/signup", async (req, res) => {
  const { username, email, password } = req.body;

  if (!username || !email || !password)
    return res.status(400).json({ message: "All fields required" });

  try {
    // Check if email already exists
    const exist = await pg.query(
      "SELECT adminid FROM admins WHERE email = $1",
      [email]
    );

    if (exist.rowCount > 0) {
      return res.status(400).json({ message: "Admin already exists" });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create admin
    await pg.query(
      `
      INSERT INTO admins (username, email, passwordhash, isactive, createdat)
      VALUES ($1, $2, $3, TRUE, NOW())
      `,
      [username, email, hashedPassword]
    );

    res.status(201).json({ message: "Signup successful" });
  } catch (err) {
    console.error("Signup error:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

/* ======================================================
   🟢 ADMIN LOGIN
====================================================== */
router.post("/login", async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password)
    return res.status(400).json({ message: "Username and password required" });

  try {
    // Fetch admin
    const result = await pg.query(
      `
      SELECT adminid, username, email, passwordhash
      FROM admins
      WHERE username = $1 AND isactive = TRUE
      `,
      [username]
    );

    if (result.rowCount === 0)
      return res.status(401).json({ message: "Invalid username or password" });

    const admin = result.rows[0];

    // Compare password hash
    const isMatch = await bcrypt.compare(password, admin.passwordhash);
    if (!isMatch)
      return res.status(401).json({ message: "Invalid username or password" });

    // Create JWT Token
    const token = jwt.sign(
      { adminId: admin.adminid, username: admin.username },
      process.env.JWT_SECRET,
      { expiresIn: "2h" }
    );

    // Update last login time
    await pg.query("UPDATE admins SET lastlogin = NOW() WHERE adminid = $1", [
      admin.adminid,
    ]);

    res.json({
      success: true,
      message: "Login successful",
      token,
      admin: {
        username: admin.username,
        email: admin.email,
      },
    });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;


// const express = require("express");
// const sql = require("mssql");
// const jwt = require("jsonwebtoken");
// require("dotenv").config();

// const router = express.Router();

// const dbConfig = {
//   user: process.env.DB_USER,
//   password: process.env.DB_PASSWORD,
//   server: process.env.DB_SERVER,
//   database: process.env.DB_DATABASE,
//   port: parseInt(process.env.DB_PORT),
//   options: { encrypt: false, trustServerCertificate: true },
// };

// // Admin Signup
// router.post("/signup", async (req, res) => {
//   const { username, email, password } = req.body;

//   if (!username || !email || !password)
//     return res.status(400).json({ message: "All fields required" });

//   try {
//     const pool = await sql.connect(dbConfig);

//     const existing = await pool
//       .request()
//       .input("email", sql.NVarChar, email)
//       .query("SELECT * FROM Admins WHERE Email = @email");

//     if (existing.recordset.length > 0)
//       return res.status(400).json({ message: "Admin already exists" });

//     await pool
//       .request()
//       .input("username", sql.NVarChar, username)
//       .input("email", sql.NVarChar, email)
//       .input("password", sql.NVarChar, password)
//       .query(
//         `INSERT INTO Admins (Username, Email, PasswordHash, IsActive, CreatedAt)
//          VALUES (@username, @email, @password, 1, GETDATE())`
//       );

//     res.status(201).json({ message: "Signup successful" });
//   } catch (err) {
//     console.error("Signup error:", err);
//     res.status(500).json({ message: "Internal server error" });
//   }
// });

// // Admin Login
// router.post("/login", async (req, res) => {
//   const { username, password } = req.body;

//   if (!username || !password)
//     return res.status(400).json({ message: "Username and password required" });

//   try {
//     const pool = await sql.connect(dbConfig);

//     const result = await pool
//       .request()
//       .input("username", sql.NVarChar, username)
//       .input("password", sql.NVarChar, password)
//       .query(
//         `SELECT * FROM Admins 
//          WHERE Username = @username 
//          AND PasswordHash = @password 
//          AND IsActive = 1`
//       );

//     if (result.recordset.length === 0)
//       return res.status(401).json({ message: "Invalid username or password" });

//     const admin = result.recordset[0];

//     const token = jwt.sign(
//       { adminId: admin.AdminID, username: admin.Username },
//       process.env.JWT_SECRET || "secret_key",
//       { expiresIn: "2h" }
//     );

//     await pool
//       .request()
//       .input("AdminID", sql.Int, admin.AdminID)
//       .query("UPDATE Admins SET LastLogin = GETDATE() WHERE AdminID = @AdminID");

//     res.json({
//       success: true,
//       message: "Login successful",
//       token,
//       admin: {
//         username: admin.Username,
//         email: admin.Email,
//       },
//     });
//   } catch (err) {
//     console.error("Login error:", err);
//     res.status(500).json({ message: "Server error" });
//   }
// });

// module.exports = router;
