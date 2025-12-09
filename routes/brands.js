require("dotenv").config();
const express = require("express");
const router = express.Router();
const db = require("../models/db_postgres");

console.log("🟣 Using PostgreSQL for Brands");

/* =====================================================
   GET ALL BRANDS
===================================================== */
router.get("/", async (_, res) => {
  try {
    const result = await db.query(`
      SELECT 
        b.id AS BrandID,
        b.name AS Name,
        b.category_id AS CategoryID,
        b.subcategory_id AS SubcategoryID,
        b.created_at AS CreatedAt,
        COALESCE(c.name, '') AS CategoryName,
        COALESCE(s.name, '') AS SubcategoryName
      FROM brands b
      LEFT JOIN categories c ON b.category_id = c.id
      LEFT JOIN subcategories s ON b.subcategory_id = s.id
      ORDER BY b.id ASC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("❌ GET /brands:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =====================================================
   CREATE BRAND
===================================================== */
router.post("/", async (req, res) => {
  try {
    const { name, categoryId, subcategoryId } = req.body;

    if (!name || !subcategoryId) {
      return res.status(400).json({ error: "Name and subcategoryId required" });
    }

    await db.query(
      `
      INSERT INTO brands (name, category_id, subcategory_id, created_at)
      VALUES ($1, $2, $3, NOW())
      `,
      [name, categoryId || null, subcategoryId]
    );

    res.status(201).json({ message: "Brand created" });
  } catch (err) {
    console.error("❌ POST /brands:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =====================================================
   UPDATE BRAND
===================================================== */
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { name, categoryId, subcategoryId } = req.body;

  try {
    await db.query(
      `
      UPDATE brands
      SET name = $1,
          category_id = $2,
          subcategory_id = $3
      WHERE id = $4
      `,
      [name, categoryId || null, subcategoryId, id]
    );

    res.json({ message: "Brand updated" });
  } catch (err) {
    console.error("❌ UPDATE /brands:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =====================================================
   DELETE BRAND
===================================================== */
router.delete("/:id", async (req, res) => {
  try {
    await db.query(`DELETE FROM brands WHERE id = $1`, [req.params.id]);
    res.json({ message: "Brand deleted" });
  } catch (err) {
    console.error("❌ DELETE /brands:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

// // routes/brands.js
// const express = require('express');
// const sql = require('mssql');
// const path = require('path');
// const multer = require('multer');
// const router = express.Router();
// const { poolPromise } = require('../models/db');

// // ⚠️ Make sure your Brands table has:
// // BrandID (PK), Name, CategoryID (INT, NULL OK), SubcategoryID (INT), CreatedAt (default GETDATE())

// // Multer setup (if you later add images)
// const storage = multer.diskStorage({
//   destination: function (req, file, cb) {
//     cb(null, 'uploads/brands/');
//   },
//   filename: function (req, file, cb) {
//     cb(null, 'brand-' + Date.now() + path.extname(file.originalname));
//   },
// });
// const upload = multer({ storage });

// /**
//  * ===============================
//  *  GET /api/brands  → List brands
//  * ===============================
//  */
// router.get('/', async (_, res) => {
//   try {
//     const pool = await poolPromise;

//     const result = await pool.request().query(`
//       SELECT 
//         b.BrandID,
//         b.Name,
//         b.CategoryID,
//         b.SubcategoryID,
//         b.CreatedAt,
//         ISNULL(c.Name, '') AS CategoryName,
//         ISNULL(s.Name, '') AS SubcategoryName
//       FROM Brands b
//       LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
//       LEFT JOIN Subcategories s ON b.SubcategoryID = s.SubcategoryID
//       ORDER BY b.BrandID ASC;
//     `);

//     res.status(200).json(result.recordset);
//   } catch (err) {
//     console.error('❌ GET /brands:', err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /**
//  * ===============================
//  *  POST /api/brands  → Create brand
//  * ===============================
//  * body: { name, categoryId, subcategoryId }
//  */
// router.post('/', async (req, res) => {
//   try {
//     const { name, categoryId, subcategoryId } = req.body;

//     if (!name || !subcategoryId) {
//       return res
//         .status(400)
//         .json({ message: 'Name and subcategoryId are required' });
//     }

//     const pool = await poolPromise;

//     await pool
//       .request()
//       .input('name', sql.NVarChar, name)
//       .input('categoryId', sql.Int, categoryId || null)
//       .input('subcategoryId', sql.Int, subcategoryId)
//       .query(`
//         INSERT INTO Brands (Name, CategoryID, SubcategoryID, CreatedAt)
//         VALUES (@name, @categoryId, @subcategoryId, GETDATE());
//       `);

//     res.status(201).json({ message: 'Brand created successfully' });
//   } catch (err) {
//     console.error('❌ POST /brands:', err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /**
//  * ===============================
//  *  PUT /api/brands/:id  → Update brand
//  * ===============================
//  * body: { name, categoryId, subcategoryId }
//  */
// router.put('/:id', async (req, res) => {
//   const { id } = req.params;
//   const { name, categoryId, subcategoryId } = req.body;

//   if (!name || !subcategoryId) {
//     return res
//       .status(400)
//       .json({ message: 'Name and subcategoryId are required' });
//   }

//   try {
//     const pool = await poolPromise;

//     await pool
//       .request()
//       .input('id', sql.Int, id)
//       .input('name', sql.NVarChar, name)
//       .input('categoryId', sql.Int, categoryId || null)
//       .input('subcategoryId', sql.Int, subcategoryId)
//       .query(`
//         UPDATE Brands 
//         SET 
//           Name = @name,
//           CategoryID = @categoryId,
//           SubcategoryID = @subcategoryId
//         WHERE BrandID = @id;
//       `);

//     res.json({ message: 'Brand updated successfully' });
//   } catch (err) {
//     console.error('❌ PUT /brands:', err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /**
//  * ===============================
//  *  DELETE /api/brands/:id
//  * ===============================
//  */
// router.delete('/:id', async (req, res) => {
//   const { id } = req.params;

//   try {
//     const pool = await poolPromise;

//     await pool
//       .request()
//       .input('id', sql.Int, id)
//       .query(`DELETE FROM Brands WHERE BrandID = @id;`);

//     res.json({ message: 'Brand deleted successfully' });
//   } catch (err) {
//     console.error('❌ DELETE /brands:', err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;
