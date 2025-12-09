const express = require("express");
const router = express.Router();
const db = require("../models/db_postgres");

// ===============================
// GET all variant types
// ===============================
router.get("/", async (_, res) => {
  try {
    const { rows } = await db.query(
      `SELECT id, variant_name, variant_type, added_date
       FROM variant_types
       ORDER BY id DESC`
    );
    res.json(rows);
  } catch (err) {
    console.error("❌ GET variant types:", err);
    res.status(500).json({ error: err.message });
  }
});

// ===============================
// CREATE variant type
// ===============================
router.post("/", async (req, res) => {
  const { variantName, variantType } = req.body;

  if (!variantName || !variantType)
    return res.status(400).json({ error: "variantName & variantType required" });

  try {
    const { rows } = await db.query(
      `
      INSERT INTO variant_types (variant_name, variant_type, added_date)
      VALUES ($1, $2, NOW())
      RETURNING id
      `,
      [variantName, variantType]
    );

    res.json({ success: true, id: rows[0].id });
  } catch (err) {
    console.error("❌ POST variantTypes:", err);
    res.status(500).json({ error: err.message });
  }
});

// ===============================
// UPDATE variant type
// ===============================
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { variantName, variantType } = req.body;

  try {
    await db.query(
      `
      UPDATE variant_types
      SET variant_name = $1,
          variant_type = $2
      WHERE id = $3
      `,
      [variantName, variantType, id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error("❌ UPDATE variantTypes:", err);
    res.status(500).json({ error: err.message });
  }
});

// ===============================
// DELETE variant type
// ===============================
router.delete("/:id", async (req, res) => {
  try {
    await db.query(
      `DELETE FROM variant_types WHERE id = $1`,
      [req.params.id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error("❌ DELETE variantTypes:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;


// const express = require('express');
// const sql = require('mssql');
// const router = express.Router();
// const { poolPromise } = require('../models/db'); // Make sure this points to your db config

// // ---------------- GET all variant types ----------------
// router.get('/', async (req, res) => {
//   try {
//     const pool = await poolPromise;
//     const result = await pool.request()
//       .query("SELECT * FROM VariantTypes ORDER BY VariantTypeID DESC");
//     res.json(result.recordset);
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ---------------- POST add new variant type ----------------
// router.post('/', async (req, res) => {
//   try {
//     const { variantName, variantType } = req.body;
//     const pool = await poolPromise;

//     await pool.request()
//       .input("VariantName", sql.NVarChar, variantName)
//       .input("VariantType", sql.NVarChar, variantType)
//       .query("INSERT INTO VariantTypes (VariantName, VariantType, AddedDate) VALUES (@VariantName, @VariantType, GETDATE())");

//     res.status(201).json({ success: true });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ---------------- PUT update variant type ----------------
// router.put('/:id', async (req, res) => {
//   try {
//     const { id } = req.params;
//     const { variantName, variantType } = req.body;
//     const pool = await poolPromise;

//     await pool.request()
//       .input("id", sql.Int, id)
//       .input("VariantName", sql.NVarChar, variantName)
//       .input("VariantType", sql.NVarChar, variantType)
//       .query("UPDATE VariantTypes SET VariantName = @VariantName, VariantType = @VariantType WHERE VariantTypeID = @id");

//     res.json({ success: true });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ---------------- DELETE variant type ----------------
// router.delete('/:id', async (req, res) => {
//   try {
//     const { id } = req.params;
//     const pool = await poolPromise;

//     await pool.request()
//       .input('id', sql.Int, id)
//       .query("DELETE FROM VariantTypes WHERE VariantTypeID = @id");

//     res.json({ success: true });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;