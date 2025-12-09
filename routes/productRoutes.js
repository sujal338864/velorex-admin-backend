const express = require('express');
const router = express.Router();
const { sql, poolPromise } = require('../db');
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: (_, __, cb) => cb(null, 'uploads/'),
  filename: (_, file, cb) => cb(null, Date.now() + path.extname(file.originalname)),
});
const upload = multer({ storage });

router.post('/', upload.array('images'), async (req, res) => {
  const { name, description, price, stock, brandId, subcategoryId } = req.body;
  const images = req.files.map(f => f.filename).join(',');

  try {
    const pool = await poolPromise;
    await pool.request()
      .input('name', sql.NVarChar, name)
      .input('description', sql.NVarChar, description)
      .input('price', sql.Decimal, price)
      .input('stock', sql.Int, stock)
      .input('brandId', sql.Int, brandId)
      .input('subcategoryId', sql.Int, subcategoryId)
      .input('images', sql.NVarChar, images)
      .query(`INSERT INTO Products (Name, Description, Price, Stock, BrandID, SubcategoryID, ImageURL) 
              VALUES (@name, @description, @price, @stock, @brandId, @subcategoryId, @images)`);
    res.status(201).send('✅ Product created');
  } catch (err) {
    res.status(500).send(err.message);
  }
});

module.exports = router;
