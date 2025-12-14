const express = require("express");
const jwt = require("jsonwebtoken");
require("dotenv").config();

const pool = require("../models/db");
const router = express.Router();

/* ===========================
   ADMIN LOGIN
   =========================== */
router.post("/login", async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ message: "Username and password required" });
  }

  try {
    const result = await pool.query(
      `
      SELECT admin_id, username, email
      FROM admins
      WHERE username = $1
        AND password_hash = $2
        AND is_active = TRUE
      `,
      [username, password]
    );

    if (result.rowCount === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid username or password",
      });
    }

    const admin = result.rows[0];

    const token = jwt.sign(
      { adminId: admin.admin_id, username: admin.username },
      process.env.JWT_SECRET || "secret_key",
      { expiresIn: "2h" }
    );

    await pool.query(
      "UPDATE admins SET last_login = NOW() WHERE admin_id = $1",
      [admin.admin_id]
    );

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
    res.status(500).json({ message: "Internal server error" });
  }
});


module.exports = router;



// const express = require("express");
// const jwt = require("jsonwebtoken");
// require("dotenv").config();

// const pool = require("../models/db"); // 👈 pg Pool
// const router = express.Router();

// /* ===========================
//    ADMIN SIGNUP
//    =========================== */
// router.post("/signup", async (req, res) => {
//   const { username, email, password } = req.body;

//   if (!username || !email || !password) {
//     return res.status(400).json({ message: "All fields required" });
//   }

//   try {
//     // Check existing admin
//     const existing = await pool.query(
//       "SELECT 1 FROM admins WHERE email = $1",
//       [email]
//     );

//     if (existing.rowCount > 0) {
//       return res.status(400).json({ message: "Admin already exists" });
//     }

//     // Insert admin
//     await pool.query(
//       `
//       INSERT INTO admins
//       (username, email, passwordhash, isactive, createdat)
//       VALUES ($1, $2, $3, TRUE, NOW())
//       `,
//       [username, email, password]
//     );

//     res.status(201).json({ message: "Signup successful" });
//   } catch (err) {
//     console.error("Signup error:", err);
//     res.status(500).json({ message: "Internal server error" });
//   }
// });

// /* ===========================
//    ADMIN LOGIN
//    =========================== */
// router.post("/login", async (req, res) => {
//   const { username, password } = req.body;

//   if (!username || !password) {
//     return res.status(400).json({ message: "Username and password required" });
//   }

//   try {
//     const result = await pool.query(
//       `
//       SELECT *
//       FROM admins
//       WHERE username = $1
//         AND passwordhash = $2
//         AND isactive = TRUE
//       `,
//       [username, password]
//     );

//     if (result.rowCount === 0) {
//       return res.status(401).json({ message: "Invalid username or password" });
//     }

//     const admin = result.rows[0];

//     // JWT token
//     const token = jwt.sign(
//       { adminId: admin.adminid, username: admin.username },
//       process.env.JWT_SECRET || "secret_key",
//       { expiresIn: "2h" }
//     );

//     // Update last login
//     await pool.query(
//       "UPDATE admins SET lastlogin = NOW() WHERE adminid = $1",
//       [admin.adminid]
//     );

//     res.json({
//       success: true,
//       message: "Login successful",
//       token,
//       admin: {
//         username: admin.username,
//         email: admin.email,
//       },
//     });
//   } catch (err) {
//     console.error("Login error:", err);
//     res.status(500).json({ message: "Server error" });
//   }
// });

// module.exports = router;

// // const express = require("express");
// // const sql = require("mssql");
// // const jwt = require("jsonwebtoken");
// // require("dotenv").config();

// // const router = express.Router();

// // const dbConfig = {
// //   user: process.env.DB_USER,
// //   password: process.env.DB_PASSWORD,
// //   server: process.env.DB_SERVER,
// //   database: process.env.DB_DATABASE,
// //   port: parseInt(process.env.DB_PORT),
// //   options: { encrypt: false, trustServerCertificate: true },
// // };

// // // Admin Signup
// // router.post("/signup", async (req, res) => {
// //   const { username, email, password } = req.body;

// //   if (!username || !email || !password)
// //     return res.status(400).json({ message: "All fields required" });

// //   try {
// //     const pool = await sql.connect(dbConfig);

// //     const existing = await pool
// //       .request()
// //       .input("email", sql.NVarChar, email)
// //       .query("SELECT * FROM Admins WHERE Email = @email");

// //     if (existing.recordset.length > 0)
// //       return res.status(400).json({ message: "Admin already exists" });

// //     await pool
// //       .request()
// //       .input("username", sql.NVarChar, username)
// //       .input("email", sql.NVarChar, email)
// //       .input("password", sql.NVarChar, password)
// //       .query(
// //         `INSERT INTO Admins (Username, Email, PasswordHash, IsActive, CreatedAt)
// //          VALUES (@username, @email, @password, 1, GETDATE())`
// //       );

// //     res.status(201).json({ message: "Signup successful" });
// //   } catch (err) {
// //     console.error("Signup error:", err);
// //     res.status(500).json({ message: "Internal server error" });
// //   }
// // });

// // // Admin Login
// // router.post("/login", async (req, res) => {
// //   const { username, password } = req.body;

// //   if (!username || !password)
// //     return res.status(400).json({ message: "Username and password required" });

// //   try {
// //     const pool = await sql.connect(dbConfig);

// //     const result = await pool
// //       .request()
// //       .input("username", sql.NVarChar, username)
// //       .input("password", sql.NVarChar, password)
// //       .query(
// //         `SELECT * FROM Admins 
// //          WHERE Username = @username 
// //          AND PasswordHash = @password 
// //          AND IsActive = 1`
// //       );

// //     if (result.recordset.length === 0)
// //       return res.status(401).json({ message: "Invalid username or password" });

// //     const admin = result.recordset[0];

// //     const token = jwt.sign(
// //       { adminId: admin.AdminID, username: admin.Username },
// //       process.env.JWT_SECRET || "secret_key",
// //       { expiresIn: "2h" }
// //     );

// //     await pool
// //       .request()
// //       .input("AdminID", sql.Int, admin.AdminID)
// //       .query("UPDATE Admins SET LastLogin = GETDATE() WHERE AdminID = @AdminID");

// //     res.json({
// //       success: true,
// //       message: "Login successful",
// //       token,
// //       admin: {
// //         username: admin.Username,
// //         email: admin.Email,
// //       },
// //     });
// //   } catch (err) {
// //     console.error("Login error:", err);
// //     res.status(500).json({ message: "Server error" });
// //   }
// // });

// // module.exports = router;
