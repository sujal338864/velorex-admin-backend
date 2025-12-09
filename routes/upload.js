const express = require("express");
const multer = require("multer");
const { createClient } = require("@supabase/supabase-js");
require("dotenv").config();

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

// Supabase service role
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

router.post("/upload-multiple", upload.array("files", 10), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0)
      return res.status(400).json({ error: "No files uploaded" });

    const uploadedFiles = [];

    for (const file of req.files) {
      const ext = file.originalname.split(".").pop();
      const fileName = `${Date.now()}_${Math.floor(Math.random() * 1000)}.${ext}`;
      const path = `product/${fileName}`;

      const { error } = await supabase.storage
        .from("product")
        .upload(path, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (error) throw error;

      const { data } = supabase.storage.from("product").getPublicUrl(path);

      uploadedFiles.push({ filename: fileName, url: data.publicUrl });
    }

    res.json({ uploadedFiles });
  } catch (err) {
    console.error("❌ Upload error:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

// const express = require('express');
// const multer = require('multer');
// const sql = require('mssql'); // optional if you save filenames in SQL Server
// const { createClient } = require('@supabase/supabase-js');
// require('dotenv').config();

// const router = express.Router();

// // Multer memory storage
// const upload = multer({ storage: multer.memoryStorage() });

// // Supabase client with service role
// const supabase = createClient(
//   process.env.SUPABASE_URL,
//   process.env.SUPABASE_SERVICE_ROLE_KEY
// );

// // Multiple files upload route
// router.post('/upload-multiple', upload.array('files', 10), async (req, res) => {
//   try {
//     if (!req.files || req.files.length === 0)
//       return res.status(400).json({ error: 'No files uploaded' });

//     const uploadedFiles = [];

//     for (const file of req.files) {
//       const fileExt = file.originalname.split('.').pop();
//       const fileName = `${Date.now()}_${Math.floor(Math.random() * 1000)}.${fileExt}`;
//       const filePath = `product/${fileName}`;

//       // Upload each file to Supabase
//       const { error } = await supabase.storage
//         .from('product')
//         .upload(filePath, file.buffer, {
//           contentType: file.mimetype,
//           upsert: false,
//         });

//       if (error) throw error;

//       // Optional: Save filename in SQL Server
//       // const pool = await sql.connect(/* your SQL config */);
//       // await pool.request()
//       //   .input('ImagePath', sql.NVarChar, fileName)
//       //   .query('INSERT INTO ProductImages (ImagePath) VALUES (@ImagePath)');

//       // Get public URL
//       const { data } = supabase.storage.from('product').getPublicUrl(filePath);

//       uploadedFiles.push({
//         filename: fileName,
//         url: data.publicUrl,
//       });
//     }

//     res.json({ uploadedFiles });
//   } catch (err) {
//     console.error(err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;


// const express = require('express');
// const multer = require('multer');
// const { createClient } = require('@supabase/supabase-js');
// require('dotenv').config();

// const router = express.Router();
// const upload = multer({ storage: multer.memoryStorage() });

// // Create Supabase client with service role
// const supabase = createClient(
//   process.env.SUPABASE_URL,
//   process.env.SUPABASE_SERVICE_ROLE_KEY
// );


// router.post('/upload', upload.single('file'), async (req, res) => {
//   try {
//     if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

//     const fileExt = req.file.originalname.split('.').pop();
//     const fileName = `${Date.now()}.${fileExt}`;
//     const filePath = `product/${fileName}`;

//     // Upload to Supabase storage
//     const { error } = await supabase.storage
//       .from('product') // your bucket name
//       .upload(filePath, req.file.buffer, {
//         contentType: req.file.mimetype,
//         upsert: false,
//       });

//     if (error) throw error;

//     // Get public URL
//     const { data } = supabase.storage.from('product').getPublicUrl(filePath);

//     res.json({ url: data.publicUrl });
//   } catch (err) {
//     console.error(err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;
