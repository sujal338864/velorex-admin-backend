// utils/uploadToSupabase.js
const { createClient } = require('@supabase/supabase-js');
const path = require('path');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_KEY
);

// Uploads to bucket: `product` and folder: `products/`
async function uploadToSupabase(file, folder = "products") {
  try {
    if (!file) throw new Error("No file provided");

    const ext = path.extname(file.originalname).toLowerCase();
    const fileName =
      `${folder}/${Date.now()}_${Math.floor(Math.random() * 9999)}${ext}`;

    const { data, error } = await supabase.storage
      .from("product") // <-- SAME BUCKET AS BEFORE
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

    if (error) throw error;

    const publicUrl = `${process.env.SUPABASE_URL}/storage/v1/object/public/product/${fileName}`;

    return publicUrl;
  } catch (err) {
    console.error("❌ Supabase upload error:", err);
    return null;
  }
}

module.exports = uploadToSupabase;
