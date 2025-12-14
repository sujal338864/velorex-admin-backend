const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const pool = require("../models/db"); // pg pool

// -------------------- MULTER --------------------
const storage = multer.diskStorage({
  destination: (_, __, cb) => cb(null, "uploads/"),
  filename: (_, file, cb) =>
    cb(null, Date.now() + path.extname(file.originalname)),
});
const upload = multer({ storage });

// -------------------- CREATE PRODUCT --------------------
router.post("/", upload.array("images"), async (req, res) => {
  const { name, description, price, stock, brandId, subcategoryId } = req.body;
  const images = req.files.map(f => f.filename).join(",");

  try {
    await pool.query(
      `
      INSERT INTO products
        (name, description, price, stock, brand_id, subcategory_id, image_urls)
      VALUES
        ($1, $2, $3, $4, $5, $6, $7)
      `,
      [
        name,
        description,
        Number(price),
        Number(stock),
        brandId ? Number(brandId) : null,
        subcategoryId ? Number(subcategoryId) : null,
        images,
      ]
    );

    res.status(201).json({ message: "✅ Product created" });
  } catch (err) {
    console.error("❌ CREATE PRODUCT:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;




// const express = require('express');
// const router = express.Router();
// const { sql, poolPromise } = require('../db');
// const multer = require('multer');
// const path = require('path');

// const storage = multer.diskStorage({
//   destination: (_, __, cb) => cb(null, 'uploads/'),
//   filename: (_, file, cb) => cb(null, Date.now() + path.extname(file.originalname)),
// });
// const upload = multer({ storage });

// router.post('/', upload.array('images'), async (req, res) => {
//   const { name, description, price, stock, brandId, subcategoryId } = req.body;
//   const images = req.files.map(f => f.filename).join(',');

//   try {
//     const pool = await poolPromise;
//     await pool.request()
//       .input('name', sql.NVarChar, name)
//       .input('description', sql.NVarChar, description)
//       .input('price', sql.Decimal, price)
//       .input('stock', sql.Int, stock)
//       .input('brandId', sql.Int, brandId)
//       .input('subcategoryId', sql.Int, subcategoryId)
//       .input('images', sql.NVarChar, images)
//       .query(`INSERT INTO Products (Name, Description, Price, Stock, BrandID, SubcategoryID, ImageURL) 
//               VALUES (@name, @description, @price, @stock, @brandId, @subcategoryId, @images)`);
//     res.status(201).send('✅ Product created');
//   } catch (err) {
//     res.status(500).send(err.message);
//   }
// });

// module.exports = router;
