// routes/addProduct.js
const express = require("express");
const router = express.Router();
const multer = require("multer");
const supabase = require("../models/supabaseClient");
const db = require("../models/db_postgres");

// Use memory storage for Supabase upload
const upload = multer({ storage: multer.memoryStorage() });

async function uploadToSupabase(file) {
  const fileName = `${Date.now()}_${file.originalname}`;

  const { data, error } = await supabase.storage
    .from("product")
    .upload(`product/${fileName}`, file.buffer, {
      contentType: file.mimetype,
      upsert: false,
    });

  if (error) throw error;

  return supabase.storage
    .from("product")
    .getPublicUrl(data.fullPath).data.publicUrl;
}

// ====================================================
// POST /api/products  → Create product with images
// ====================================================
router.post("/", upload.array("images"), async (req, res) => {
  try {
    const { name, description, price, stock, brandId, subcategoryId } = req.body;

    if (!name || !price || !brandId || !subcategoryId)
      return res.status(400).json({ error: "Missing required fields" });

    // Upload images to Supabase
    let imageUrls = [];
    for (const file of req.files) {
      const url = await uploadToSupabase(file);
      imageUrls.push(url);
    }

    // Insert product
    const result = await db.query(
      `
      INSERT INTO products
      (name, description, price, stock, brandid, subcategoryid, imageurls, createdat)
      VALUES ($1,$2,$3,$4,$5,$6,$7, NOW())
      RETURNING productid
      `,
      [name, description, price, stock, brandId, subcategoryId, imageUrls]
    );

    res.status(201).json({
      success: true,
      message: "Product created",
      productId: result.rows[0].productid,
      images: imageUrls,
    });
  } catch (err) {
    console.error("❌ Add Product Error:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
