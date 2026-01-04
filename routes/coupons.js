const express = require("express");
const router = express.Router();
const pool = require("../models/db");

/* =========================
   GET ALL COUPONS
========================= */
router.get("/", async (_, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        coupon_id        AS "CouponID",
        code             AS "Code",
        discount_type    AS "DiscountType",
        discount_amount  AS "DiscountAmount",
        minimum_purchase AS "MinimumPurchase",
        start_date       AS "StartDate",
        end_date         AS "EndDate",
        status           AS "Status",
        category_id      AS "CategoryID",
        subcategory_id   AS "SubcategoryID",
        product_id       AS "ProductID"
      FROM coupons
      ORDER BY coupon_id DESC
    `);

    res.status(200).json(rows);
  } catch (err) {
    console.error("❌ GET /coupons:", err);
    res.status(500).json({ error: err.message });
  }
});


/* =========================
   UPDATE COUPON
========================= */
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const d = req.body;

  try {
    await pool.query(
      `
      UPDATE coupons SET
        code = $1,
        discount_type = $2,
        discount_amount = $3,
        minimum_purchase = $4,
        start_date = $5,
        end_date = $6,
        status = $7,
        category_id = $8,
        subcategory_id = $9,
        product_id = $10
      WHERE coupon_id = $11
      `,
      [
        d.Code,
        d.DiscountType,
        d.DiscountAmount,
        d.MinimumPurchase,
        d.StartDate,
        d.EndDate,
        d.Status,
        d.CategoryID ?? null,
        d.SubcategoryID ?? null,
        d.ProductID ?? null,
        id,
      ]
    );

    res.json({ success: true });
  } catch (err) {
    console.error("❌ UPDATE COUPON:", err);
    res.status(500).json({ error: "Update failed" });
  }
});

/* =========================
   ADD COUPON
========================= */
router.post("/", async (req, res) => {
  const {
    code,
    discountType,
    discountAmount,
    minimumPurchase,
    startDate,
    endDate,
    status,
    categoryId,
    subcategoryId,
    productId,
  } = req.body;

  try {
    await pool.query(
      `
      INSERT INTO coupons
        (code, discount_type, discount_amount, minimum_purchase,
         start_date, end_date, status, category_id, subcategory_id, product_id)
      VALUES
        ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
      `,
      [
        code,
        discountType,
        discountAmount,
        minimumPurchase,
        startDate,
        endDate,
        status,
        categoryId ?? null,
        subcategoryId ?? null,
        productId ?? null,
      ]
    );

    res.status(201).json({ message: "✅ Coupon added successfully" });
  } catch (err) {
    console.error("❌ POST /coupons:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =========================
   DELETE COUPON
========================= */
router.delete("/:id", async (req, res) => {
  const { id } = req.params;

  try {
    await pool.query(`DELETE FROM coupons WHERE coupon_id = $1`, [id]);
    res.status(200).json({ message: "✅ Coupon deleted successfully" });
  } catch (err) {
    console.error("❌ DELETE /coupons:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;



// const express = require('express');
// const router = express.Router();
// const { sql, poolPromise } = require('../models/db');

// // ✅ Get all coupons
// router.get('/', async (_, res) => {
//   try {
//     const pool = await poolPromise;
//     const result = await pool.request().query('SELECT * FROM Coupons');
//     res.status(200).json(result.recordset);
//   } catch (err) {
//     console.error('❌ GET /api/coupons:', err);
//     res.status(500).json({ error: err.message });
//   }
// });
// router.put("/coupons/:id", async (req, res) => {
//   const id = req.params.id;
//   const data = req.body;

//   try {
//     const pool = await poolPromise;

//     await pool.request()
//       .input('Code', sql.NVarChar, data.Code)
//       .input('DiscountType', sql.NVarChar, data.DiscountType)
//       .input('DiscountAmount', sql.Decimal(18,2), data.DiscountAmount)
//       .input('MinimumPurchase', sql.Decimal(18,2), data.MinimumPurchase)
//       .input('StartDate', sql.DateTime, data.StartDate)
//       .input('EndDate', sql.DateTime, data.EndDate)
//       .input('Status', sql.NVarChar, data.Status)
//       .input('CategoryID', sql.Int, data.CategoryID ?? null)
//       .input('SubcategoryID', sql.Int, data.SubcategoryID ?? null)
//       .input('ProductID', sql.Int, data.ProductID ?? null)
//       .input('CouponID', sql.Int, id)
//       .query(`
//         UPDATE Coupons SET
//           Code = @Code,
//           DiscountType = @DiscountType,
//           DiscountAmount = @DiscountAmount,
//           MinimumPurchase = @MinimumPurchase,
//           StartDate = @StartDate,
//           EndDate = @EndDate,
//           Status = @Status,
//           CategoryID = @CategoryID,
//           SubcategoryID = @SubcategoryID,
//           ProductID = @ProductID
//         WHERE CouponID = @CouponID
//       `);

//     res.json({ success: true });
//   } catch (err) {
//     console.log("❌ UPDATE ERROR:", err);
//     res.status(500).json({ error: 'Update failed' });
//   }
// });

// // ✅ Add a coupon
// router.post('/', async (req, res) => {
//   const {
//     code,
//     discountType,
//     discountAmount,
//     minimumPurchase,
//     startDate,
//     endDate,
//     status,
//     categoryId,
//     subcategoryId,
//     productId
//   } = req.body;

//   try {
//     const pool = await poolPromise;
//    await pool.request()
//   .input('Code', sql.NVarChar, code)
//   .input('DiscountType', sql.NVarChar, discountType)
//   .input('DiscountAmount', sql.Decimal(18, 2), discountAmount)
//   .input('MinimumPurchase', sql.Decimal(18, 2), minimumPurchase)
//   .input('StartDate', sql.DateTime, startDate)
//   .input('EndDate', sql.DateTime, endDate)
//   .input('Status', sql.NVarChar, status)
//   .input('CategoryID', sql.Int, categoryId != null ? categoryId : null)
//   .input('SubcategoryID', sql.Int, subcategoryId != null ? subcategoryId : null)
//   .input('ProductID', sql.Int, productId != null ? productId : null)
// .query(`
//   INSERT INTO Coupons
//     (Code, DiscountType, DiscountAmount, MinimumPurchase, StartDate, EndDate, Status, CategoryID, SubcategoryID, ProductID)
//   VALUES
//     (@Code, @DiscountType, @DiscountAmount, @MinimumPurchase, @StartDate, @EndDate, @Status, @CategoryID, @SubcategoryID, @ProductID)
// `);



//     res.status(201).json({ message: '✅ Coupon added successfully' });
//   } catch (err) {
//     console.error('❌ POST /api/coupons:', err);
//     res.status(500).json({ error: err.message });
//   }
// });


// // ✅ Delete a coupon
// router.delete('/:id', async (req, res) => {
//   const { id } = req.params;

//   try {
//     const pool = await poolPromise;
//     await pool.request()
//       .input('ID', sql.Int, id)
//       .query('DELETE FROM Coupons WHERE CouponID = @ID');

//     res.status(200).json({ message: '✅ Coupon deleted successfully' });
//   } catch (err) {
//     console.error('❌ DELETE /api/coupons:', err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;




// const express = require("express");
// const router = express.Router();
// const db = require("../models/db_postgres");

// /* ===========================
//    GET ALL COUPONS
// =========================== */
// router.get("/", async (_, res) => {
//   try {
//     const result = await db.query(`SELECT * FROM coupons ORDER BY couponid DESC`);
//     res.json(result.rows);
//   } catch (err) {
//     console.error("❌ GET /coupons:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    CREATE COUPON
// =========================== */
// router.post("/", async (req, res) => {
//   try {
//     const {
//       code,
//       discountType,
//       discountAmount,
//       minimumPurchase,
//       startDate,
//       endDate,
//       status,
//       categoryId,
//       subcategoryId,
//       productId
//     } = req.body;

//     await db.query(
//       `
//       INSERT INTO coupons
//       (code, discounttype, discountamount, minimumpurchase, startdate, enddate,
//        status, categoryid, subcategoryid, productid, createdat)
//       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, NOW())
//       `,
//       [
//         code,
//         discountType,
//         discountAmount,
//         minimumPurchase,
//         startDate,
//         endDate,
//         status,
//         categoryId || null,
//         subcategoryId || null,
//         productId || null,
//       ]
//     );

//     res.status(201).json({ message: "Coupon added successfully" });
//   } catch (err) {
//     console.error("❌ POST /coupons:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    UPDATE COUPON
// =========================== */
// router.put("/:id", async (req, res) => {
//   try {
//     const id = req.params.id;
//     const data = req.body;

//     await db.query(
//       `
//       UPDATE coupons SET
//         code = $1,
//         discounttype = $2,
//         discountamount = $3,
//         minimumpurchase = $4,
//         startdate = $5,
//         enddate = $6,
//         status = $7,
//         categoryid = $8,
//         subcategoryid = $9,
//         productid = $10,
//         updatedat = NOW()
//       WHERE couponid = $11
//       `,
//       [
//         data.Code,
//         data.DiscountType,
//         data.DiscountAmount,
//         data.MinimumPurchase,
//         data.StartDate,
//         data.EndDate,
//         data.Status,
//         data.CategoryID || null,
//         data.SubcategoryID || null,
//         data.ProductID || null,
//         id,
//       ]
//     );

//     res.json({ success: true });
//   } catch (err) {
//     console.error("❌ UPDATE coupon:", err);
//     res.status(500).json({ error: "Update failed" });
//   }
// });

// /* ===========================
//    DELETE COUPON
// =========================== */
// router.delete("/:id", async (req, res) => {
//   try {
//     await db.query(`DELETE FROM coupons WHERE couponid = $1`, [req.params.id]);
//     res.json({ message: "Coupon deleted successfully" });
//   } catch (err) {
//     console.error("❌ DELETE coupon:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;


