const express = require("express");
const router = express.Router();
const pool = require("../models/db");

// -------------------------------------------------------------
// GET: ALL VARIANTS (WITH TYPE NAME)
// -------------------------------------------------------------
router.get("/", async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        v.variant_id        AS "VariantID",
        v.variant           AS "Variant",
        vt.variant_name     AS "VariantType",   -- ✅ THIS IS THE FIX
        v.variant_type_id   AS "VariantTypeID",
        v.added_date        AS "AddedDate"
      FROM variants v
      LEFT JOIN variant_types vt
        ON vt.variant_type_id = v.variant_type_id
      ORDER BY v.variant_id DESC
    `);

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});



// -------------------------------------------------------------
// GET: VARIANTS BY TYPE ID
// -------------------------------------------------------------
router.get("/by-type/:typeId", async (req, res) => {
  try {
    const { typeId } = req.params;

    const { rows } = await pool.query(
      `
      SELECT 
        v.variant_id AS "VariantID",
        v.variant    AS "Variant",
        v.variant_type_id AS "VariantTypeID",
        v.added_date AS "AddedDate"
      FROM variants v
      WHERE v.variant_type_id = $1
      ORDER BY v.variant_id DESC
      `,
      [typeId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// POST: ADD VARIANT
// -------------------------------------------------------------
router.post("/", async (req, res) => {
  try {
    const { Variant, VariantTypeID } = req.body;

    if (!Variant || !VariantTypeID) {
      return res.status(400).json({
        error: "Variant and VariantTypeID are required",
      });
    }

    // Validate Variant Type
    const typeCheck = await pool.query(
      `SELECT 1 FROM variant_types WHERE variant_type_id = $1`,
      [VariantTypeID]
    );

    if (typeCheck.rows.length === 0) {
      return res.status(400).json({ error: "Invalid VariantTypeID" });
    }

    await pool.query(
      `
      INSERT INTO variants (variant, variant_type_id, added_date)
      VALUES ($1, $2, NOW())
      `,
      [Variant, VariantTypeID]
    );

    res.status(201).json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// PUT: UPDATE VARIANT
// -------------------------------------------------------------
router.put("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { Variant, VariantTypeID } = req.body;

    if (!Variant || !VariantTypeID) {
      return res.status(400).json({
        error: "Variant and VariantTypeID are required",
      });
    }

    const typeCheck = await pool.query(
      `SELECT 1 FROM variant_types WHERE variant_type_id = $1`,
      [VariantTypeID]
    );

    if (typeCheck.rows.length === 0) {
      return res.status(400).json({ error: "Invalid VariantTypeID" });
    }

    await pool.query(
      `
      UPDATE variants
      SET variant = $1,
          variant_type_id = $2
      WHERE variant_id = $3
      `,
      [Variant, VariantTypeID, id]
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// DELETE: VARIANT (FK SAFE)
// -------------------------------------------------------------
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const used = await pool.query(
      `SELECT 1 FROM product_variants WHERE variant_id = $1 LIMIT 1`,
      [id]
    );

    if (used.rows.length > 0) {
      return res.status(400).json({
        error: "Variant is used by products and cannot be deleted",
      });
    }

    await pool.query(`DELETE FROM variants WHERE variant_id = $1`, [id]);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;



// const express = require("express");
// const sql = require("mssql");
// const { poolPromise } = require("../models/db");

// const router = express.Router();


// // -------------------------------------------------------------
// // GET: ALL VARIANT VALUES (DEBUG ADDED)
// // -------------------------------------------------------------
// router.get("/", async (req, res) => {
//   console.log("👉 GET /variants called");

//   try {
//     const pool = await poolPromise;

//     const query = `
//       SELECT VariantID, Variant, VariantType, VariantTypeID, AddedDate
//       FROM Variants
//       ORDER BY VariantID DESC
//     `;
//     console.log("🟦 QUERY:", query);

//     const result = await pool.request().query(query);

//     console.log("🟩 RESULT LENGTH:", result.recordset.length);
//     console.log("🟩 SAMPLE ROW:", result.recordset[0]);

//     res.json(result.recordset);
//   } catch (err) {
//     console.log("❌ ERROR in GET /variants:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// // -------------------------------------------------------------
// // GET variant values by typeId (DEBUG ADDED)
// // -------------------------------------------------------------
// router.get("/by-type/:typeId", async (req, res) => {
//   console.log("👉 GET /variants/by-type called");

//   try {
//     const { typeId } = req.params;
//     console.log("🔵 RECEIVED typeId:", typeId);

//     const pool = await poolPromise;

//     const query = `
//       SELECT VariantID, Variant, VariantTypeID
//       FROM Variants
//       WHERE VariantTypeID = @typeId
//       ORDER BY VariantID DESC
//     `;
//     console.log("🟦 QUERY:", query);

//     const result = await pool.request()
//       .input("typeId", sql.Int, typeId)
//       .query(query);

//     console.log("🟩 RESULT LENGTH:", result.recordset.length);
//     console.log("🟩 RESULT ROWS:", result.recordset);

//     res.json(result.recordset);
//   } catch (err) {
//     console.log("❌ ERROR in GET /variants/by-type:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// // -------------------------------------------------------------
// // POST: Add Variant Value (DEBUG ADDED)
// // -------------------------------------------------------------
// router.post("/", async (req, res) => {
//   console.log("👉 POST /variants called");
//   console.log("🟦 BODY RECEIVED:", req.body);

//   try {
//     const { Variant, VariantTypeID } = req.body;

//     if (!Variant || !VariantTypeID) {
//       console.log("❌ MISSING FIELDS");
//       return res.status(400).json({ error: "Variant & VariantTypeID required" });
//     }

//     const pool = await poolPromise;

//     // get type name
//     console.log("🔵 Fetching VariantType for ID:", VariantTypeID);
//     const typeResult = await pool.request()
//       .input("id", sql.Int, VariantTypeID)
//       .query(`
//         SELECT VariantType FROM VariantTypes WHERE VariantTypeID = @id
//       `);

//     console.log("🟩 typeResult:", typeResult.recordset);

//     if (typeResult.recordset.length === 0) {
//       console.log("❌ INVALID VariantTypeID");
//       return res.status(400).json({ error: "Invalid VariantTypeID" });
//     }

//     const typeName = typeResult.recordset[0].VariantType;
//     console.log("🟦 INSERTING Variant:", Variant, "| Type:", typeName);

//     await pool.request()
//       .input("Variant", sql.NVarChar, Variant)
//       .input("VariantType", sql.NVarChar, typeName)
//       .input("VariantTypeID", sql.Int, VariantTypeID)
//       .query(`
//         INSERT INTO Variants (Variant, VariantType, VariantTypeID, AddedDate)
//         VALUES (@Variant, @VariantType, @VariantTypeID, GETDATE())
//       `);

//     console.log("🟩 Variant inserted successfully");
//     res.status(201).json({ message: "Variant value added" });

//   } catch (err) {
//     console.log("❌ ERROR in POST /variants:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// // -------------------------------------------------------------
// // PUT: Update Variant Value (DEBUG)
// // -------------------------------------------------------------
// router.put("/:id", async (req, res) => {
//   console.log("👉 PUT /variants/:id called");
//   console.log("🟦 PARAM id:", req.params.id);
//   console.log("🟦 BODY:", req.body);

//   try {
//     const { id } = req.params;
//     const { Variant, VariantTypeID } = req.body;

//     const pool = await poolPromise;

//     console.log("🔵 Fetching VariantType for:", VariantTypeID);
//     const typeResult = await pool.request()
//       .input("id", sql.Int, VariantTypeID)
//       .query(`
//         SELECT VariantType FROM VariantTypes WHERE VariantTypeID = @id
//       `);

//     console.log("🟩 typeResult:", typeResult.recordset);

//     if (typeResult.recordset.length === 0) {
//       return res.status(400).json({ error: "Invalid VariantTypeID" });
//     }

//     const typeName = typeResult.recordset[0].VariantType;

//     console.log("🟦 UPDATING variant:", id);

//     await pool.request()
//       .input("id", sql.Int, id)
//       .input("Variant", sql.NVarChar, Variant)
//       .input("VariantType", sql.NVarChar, typeName)
//       .input("VariantTypeID", sql.Int, VariantTypeID)
//       .query(`
//         UPDATE Variants
//         SET Variant = @Variant,
//             VariantType = @VariantType,
//             VariantTypeID = @VariantTypeID
//         WHERE VariantID = @id
//       `);

//     console.log("🟩 Updated!");
//     res.json({ message: "Variant updated successfully" });
//   } catch (err) {
//     console.log("❌ ERROR in PUT /variants/:id:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// // -------------------------------------------------------------
// // DELETE: Variant Value (DEBUG)
// // -------------------------------------------------------------
// router.delete("/:id", async (req, res) => {
//   console.log("👉 DELETE /variants/:id called");
//   console.log("🟦 DELETE id:", req.params.id);

//   try {
//     const { id } = req.params;

//     const pool = await poolPromise;

//     const q = `DELETE FROM Variants WHERE VariantID = @id`;
//     console.log("🟦 QUERY:", q);

//     await pool.request()
//       .input("id", sql.Int, id)
//       .query(q);

//     console.log("🟩 Variant deleted");
//     res.json({ message: "Variant deleted successfully" });
//   } catch (err) {
//     console.log("❌ ERROR in DELETE /variants:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;
