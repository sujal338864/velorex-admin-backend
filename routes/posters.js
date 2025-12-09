const express = require("express");
const router = express.Router();
const multer = require("multer");
const upload = multer({ storage: multer.memoryStorage() });
const supabase = require("../models/supabaseClient");
const { sql, poolPromise } = require("../models/db");

// ===========================
// Helper: Upload to Supabase
// ===========================
async function uploadToSupabase(file) {
  const fileName = `${Date.now()}_${file.originalname}`;
  const { data, error } = await supabase.storage
    .from("posters")
    .upload(`posters/${fileName}`, file.buffer, {
      contentType: file.mimetype,
      upsert: false,
    });
  if (error) throw error;
  return `https://zyryndjeojrzvoubsqsg.supabase.co/storage/v1/object/public/${data.fullPath}`;
}

// ===========================
// POST /api/posters
// ===========================
router.post("/", upload.array("images", 5), async (req, res) => {
  try {
    const { title, imageUrls } = req.body;
    const pool = await poolPromise;
    let finalImageUrls = [];

    // Case 1: Multipart file upload
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        const url = await uploadToSupabase(file);
        finalImageUrls.push(url);
      }
    }
    // Case 2: Image URLs from Flutter
    else if (imageUrls) {
      if (typeof imageUrls === "string") {
        try {
          const parsed = JSON.parse(imageUrls);
          finalImageUrls = Array.isArray(parsed) ? parsed : [parsed];
        } catch {
          finalImageUrls = [imageUrls];
        }
      } else {
        finalImageUrls = Array.isArray(imageUrls) ? imageUrls : [imageUrls];
      }
    }

    if (!title || finalImageUrls.length === 0) {
      return res.status(400).json({ error: "Title and image are required" });
    }

    const request = pool.request();
    request.input("title", sql.NVarChar, title);
    request.input("imageUrl", sql.NVarChar, finalImageUrls[0]);
    await request.query(`
      INSERT INTO posters (title, imageUrl, createdAt)
      VALUES (@title, @imageUrl, GETDATE());
    `);

    res.status(201).json({
      message: "✅ Poster added successfully",
      imageUrl: finalImageUrls[0],
    });
  } catch (err) {
    console.error("❌ Error adding poster:", err);
    res.status(500).json({ error: err.message });
  }
});

// ===========================
// GET /api/posters
// ===========================
router.get("/", async (req, res) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request().query("SELECT * FROM posters ORDER BY id DESC");
    res.status(200).json(result.recordset);
  } catch (err) {
    console.error("❌ Error fetching posters:", err.message);
    res.status(500).json({ error: "Failed to fetch posters" });
  }
});

// ✅ DELETE poster
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const pool = await poolPromise;
    await pool.request().query(`DELETE FROM posters WHERE id = ${id}`);
    res.status(200).json({ message: "Poster deleted successfully" });
  } catch (err) {
    console.error("❌ Error deleting poster:", err.message);
    res.status(500).json({ error: "Failed to delete poster" });
  }
});

module.exports = router;


// // routes/posters.js
// const express = require("express");
// const router = express.Router();
// const multer = require("multer");
// const upload = multer({ storage: multer.memoryStorage() });
// const supabase = require("../models/supabaseClient");
// const { poolPromise } = require("../models/db");

// // ✅ Upload to Supabase
// async function uploadToSupabase(file) {
//   try {
//     const fileName = `${Date.now()}_${file.originalname}`;
//     const { data, error } = await supabase.storage
//       .from("posters")
//       .upload(`posters/${fileName}`, file.buffer, {
//         contentType: file.mimetype,
//         upsert: false,
//       });

//     if (error) throw error;
//     return `https://zyryndjeojrzvoubsqsg.supabase.co/storage/v1/object/public/${data.fullPath}`;
//   } catch (err) {
//     console.error("❌ Supabase upload error:", err.message);
//     throw new Error("Failed to upload image to Supabase");
//   }
// }

// // ✅ POST /api/posters - Add new poster
// router.post("/", upload.array("images", 5), async (req, res) => {
//   try {
//     const { title, imageUrls } = req.body;
//     const pool = await poolPromise;
//     let finalImageUrls = [];

//     // ✅ CASE 1: Multipart upload from admin
//     if (req.files && req.files.length > 0) {
//       for (const file of req.files) {
//         const url = await uploadToSupabase(file);
//         finalImageUrls.push(url);
//       }
//     }
//     // ✅ CASE 2: JSON-based Supabase URLs from Flutter
//     else if (imageUrls) {
//       if (typeof imageUrls === "string") {
//         finalImageUrls = JSON.parse(imageUrls);
//       } else {
//         finalImageUrls = imageUrls;
//       }
//     }

//     if (!title || finalImageUrls.length === 0) {
//       return res.status(400).json({ error: "Title and image are required" });
//     }

//     // ✅ Insert poster record
//     const query = `
//       INSERT INTO posters (title, imageUrl, createdAt)
//       VALUES (@title, @imageUrl, GETDATE());
//     `;

//     const request = pool.request();
//     request.input("title", sql.NVarChar, title);
//     request.input("imageUrl", sql.NVarChar, finalImageUrls[0]); // Save first image
//     await request.query(query);

//     res.status(201).json({
//       message: "✅ Poster added successfully",
//       imageUrl: finalImageUrls[0],
//     });
//   } catch (err) {
//     console.error("❌ Error adding poster:", err);
//     res.status(500).json({ error: err.message });
//   }
// });



// // ✅ GET all posters
// router.get("/", async (req, res) => {
//   try {
//     const pool = await poolPromise;
//     const result = await pool.request().query("SELECT * FROM posters ORDER BY id DESC");
//     res.status(200).json(result.recordset);
//   } catch (err) {
//     console.error("❌ Error fetching posters:", err.message);
//     res.status(500).json({ error: "Failed to fetch posters" });
//   }
// });

// // ✅ DELETE poster
// router.delete("/:id", async (req, res) => {
//   try {
//     const { id } = req.params;
//     const pool = await poolPromise;
//     await pool.request().query(`DELETE FROM posters WHERE id = ${id}`);
//     res.status(200).json({ message: "Poster deleted successfully" });
//   } catch (err) {
//     console.error("❌ Error deleting poster:", err.message);
//     res.status(500).json({ error: "Failed to delete poster" });
//   }
// });

// module.exports = router;


// const express = require("express");
// const router = express.Router();
// const multer = require("multer");
// const { sql } = require("../models/db");
// const supabase = require("../models/supabaseClient");

// // Multer for memory storage
// const upload = multer({ storage: multer.memoryStorage() });

// // Upload helper
// async function uploadToSupabase(file) {
//   const fileName = `posters/${Date.now()}_${file.originalname}`;
//   const { data, error } = await supabase.storage
//     .from("posters")
//     .upload(fileName, file.buffer, {
//       contentType: file.mimetype,
//       upsert: false,
//     });

//   if (error) throw error;
//   return `https://zyryndjeojrzvoubsqsg.supabase.co/storage/v1/object/public/${data.fullPath}`;
// }

// // ✅ Get all posters
// router.get("/", async (req, res) => {
//   try {
//     const pool = await sql.connect();
//     const result = await pool.request().query("SELECT * FROM Posters ORDER BY id DESC");
//     res.json(result.recordset);
//   } catch (err) {
//     console.error("Error fetching posters:", err);
//     res.status(500).json({ error: "Failed to fetch posters" });
//   }
// });

// // ✅ Add new poster
// router.post("/", upload.single("image"), async (req, res) => {
//   try {
//     if (!req.file) return res.status(400).json({ error: "No image uploaded" });
//     const { title } = req.body;

//     const imageUrl = await uploadToSupabase(req.file);

//     const pool = await sql.connect();
//     await pool
//       .request()
//       .input("title", sql.NVarChar, title)
//       .input("imageUrl", sql.NVarChar, imageUrl)
//       .query("INSERT INTO Posters (title, imageUrl) VALUES (@title, @imageUrl)");

//     res.status(201).json({ message: "Poster added successfully", imageUrl });
//   } catch (err) {
//     console.error("Error saving poster:", err);
//     res.status(500).json({ error: "Failed to save poster" });
//   }
// });

// // ✅ Delete poster
// router.delete("/:id", async (req, res) => {
//   try {
//     const pool = await sql.connect();
//     await pool.request().input("id", sql.Int, req.params.id).query("DELETE FROM Posters WHERE id=@id");
//     res.json({ message: "Poster deleted successfully" });
//   } catch (err) {
//     console.error("Error deleting poster:", err);
//     res.status(500).json({ error: "Failed to delete poster" });
//   }
// });

// module.exports = router;




// const express = require("express");
// const router = express.Router();
// const multer = require("multer");
// const fs = require("fs");
// const supabase = require("../models/supabaseClient");
// const { sql } = require("../models/db");

// // Use Multer memory storage (no temp file)
// const upload = multer({ storage: multer.memoryStorage() });

// // ===========================
// // Helper: Upload to Supabase
// // ===========================
// async function uploadToSupabase(file) {
//   try {
//     console.log("📦 Uploading file:", file.originalname);

//     const fileName = `posters/${Date.now()}_${file.originalname}`;

//     const { data, error } = await supabase.storage
//       .from("posters") // 👈 your Supabase bucket name
//       .upload(fileName, file.buffer, {
//         contentType: file.mimetype,
//         upsert: false,
//       });

//     if (error) {
//       console.error("❌ Supabase upload failed:", error);
//       throw error;
//     }

//     const publicUrl = `https://zyryndjeojrzvoubsqsg.supabase.co/storage/v1/object/public/${data.fullPath}`;
//     console.log("✅ Uploaded successfully:", publicUrl);
//     return publicUrl;
//   } catch (err) {
//     console.error("❌ Supabase upload error:", err.message);
//     throw new Error("Failed to upload image to Supabase");
//   }
// }

// // ===========================
// // ✅ GET all posters
// // ===========================
// router.get("/", async (req, res) => {
//   try {
//     const pool = await sql.connect();
//     const result = await pool.request().query("SELECT * FROM Posters ORDER BY id DESC");
//     res.json(result.recordset);
//   } catch (err) {
//     console.error("❌ Error fetching posters:", err);
//     res.status(500).json({ error: "Failed to fetch posters" });
//   }
// });

// // ===========================
// // ✅ POST new poster (with image)
// // ===========================
// router.post("/", upload.single("image"), async (req, res) => {
//   const { title, description } = req.body;

//   try {
//     if (!req.file) {
//       return res.status(400).json({ error: "No image uploaded" });
//     }

//     // ✅ Upload to Supabase
//     const imageUrl = await uploadToSupabase(req.file);

//     // ✅ Save to SQL Server
//     const pool = await sql.connect();
//     await pool
//       .request()
//       .input("title", sql.NVarChar, title)
//       .input("description", sql.NVarChar, description)
//       .input("imageUrl", sql.NVarChar, imageUrl)
//       .query(`
//         INSERT INTO Posters (title, description, imageUrl)
//         VALUES (@title, @description, @imageUrl)
//       `);

//     res.status(201).json({ message: "Poster saved successfully", imageUrl });
//   } catch (err) {
//     console.error("❌ Error saving poster:", err);
//     res.status(500).json({ error: "Failed to save poster" });
//   }
// });

// // ===========================
// // ✅ DELETE poster by ID
// // ===========================
// router.delete("/:id", async (req, res) => {
//   const { id } = req.params;

//   try {
//     const pool = await sql.connect();
//     await pool.request().input("id", sql.Int, id).query("DELETE FROM Posters WHERE id = @id");
//     res.json({ message: "Poster deleted successfully" });
//   } catch (err) {
//     console.error("❌ Error deleting poster:", err);
//     res.status(500).json({ error: "Failed to delete poster" });
//   }
// });

// module.exports = router;


// const express = require("express");
// const multer = require("multer");
// const { createClient } = require("@supabase/supabase-js");
// const sql = require("mssql");
// const router = express.Router();

// // 🔹 Supabase config (replace with your values)
// const supabase = createClient(
//   "https://zyryndjeojrzvoubsqsg.supabase.co",
//   "YOUR_SUPABASE_ANON_KEY"
// );

// // 🔹 Multer setup for image upload
// const storage = multer.memoryStorage();
// const upload = multer({ storage });

// // GET posters
// router.get('/api/posters', async (req, res) => {
//   try {
//     const result = await pool.request().query('SELECT * FROM Posters');
//     res.json(result.recordset);
//   } catch (err) {
//     console.error('❌ Error fetching posters:', err);
//     res.status(500).json({ message: 'Failed to fetch posters' });
//   }
// });

// // ADD poster
// router.post('/api/posters', async (req, res) => {
//   try {
//     const { poster_name, image_url } = req.body;
//     if (!poster_name || !image_url) {
//       return res.status(400).json({ message: 'Missing name or image' });
//     }

//     await pool
//       .request()
//       .input('PosterName', sql.VarChar, poster_name)
//       .input('ImageUrl', sql.VarChar, image_url)
//       .query(`
//         INSERT INTO Posters (PosterName, ImageUrl)
//         VALUES (@PosterName, @ImageUrl)
//       `);

//     res.status(201).json({ message: 'Poster added successfully' });
//   } catch (err) {
//     console.error('❌ Error saving poster:', err);
//     res.status(500).json({ message: 'Failed to save poster' });
//   }
// });

// // UPDATE poster
// router.put('/api/posters/:id', async (req, res) => {
//   try {
//     const { id } = req.params;
//     const { poster_name, image_url } = req.body;

//     await pool
//       .request()
//       .input('Id', sql.Int, id)
//       .input('PosterName', sql.VarChar, poster_name)
//       .input('ImageUrl', sql.VarChar, image_url)
//       .query(`
//         UPDATE Posters
//         SET PosterName = @PosterName, ImageUrl = @ImageUrl
//         WHERE Id = @Id
//       `);

//     res.status(200).json({ message: 'Poster updated' });
//   } catch (err) {
//     console.error('❌ Error updating poster:', err);
//     res.status(500).json({ message: 'Failed to update poster' });
//   }
// });

// // DELETE poster
// router.delete('/api/posters/:id', async (req, res) => {
//   try {
//     const { id } = req.params;
//     await pool.request().input('Id', sql.Int, id).query('DELETE FROM Posters WHERE Id = @Id');
//     res.status(200).json({ message: 'Poster deleted' });
//   } catch (err) {
//     console.error('❌ Error deleting poster:', err);
//     res.status(500).json({ message: 'Failed to delete poster' });
//   }
// });

// export default router;
// // // 🟢 GET all posters
// // router.get("/", async (req, res) => {
// //   try {
// //     const result = await sql.query`SELECT * FROM Posters`;
// //     res.json(result.recordset);
// //   } catch (err) {
// //     res.status(500).send("Error fetching posters: " + err.message);
// //   }
// // });

// // // 🟢 POST (Add new poster)
// // router.post("/", upload.single("image"), async (req, res) => {
// //   try {
// //     const { poster_name } = req.body;
// //     const file = req.file;

// //     if (!poster_name || !file)
// //       return res.status(400).send("Name and image required.");

// //     const fileName = `poster_${Date.now()}.png`;

// //     // Upload to Supabase bucket
// //     const { error } = await supabase.storage
// //       .from("posters")
// //       .upload(fileName, file.buffer, {
// //         contentType: file.mimetype,
// //         upsert: false,
// //       });

// //     if (error) throw error;

// //     // Get public URL
// //     const { data: publicUrl } = supabase.storage
// //       .from("posters")
// //       .getPublicUrl(fileName);

// //     // Save record to SQL Server
// //     await sql.query`
// //       INSERT INTO Posters (poster_name, image_url)
// //       VALUES (${poster_name}, ${publicUrl.publicUrl})
// //     `;

// //     res.status(201).json({
// //       message: "Poster added successfully!",
// //       image_url: publicUrl.publicUrl,
// //     });
// //   } catch (err) {
// //     res.status(500).send("Error adding poster: " + err.message);
// //   }
// // });

// // // 🟢 PUT (Update poster)
// // router.put("/:id", upload.single("image"), async (req, res) => {
// //   try {
// //     const { id } = req.params;
// //     const { poster_name } = req.body;
// //     let imageUrl = req.body.image_url;

// //     if (req.file) {
// //       const fileName = `poster_${Date.now()}.png`;
// //       const { error } = await supabase.storage
// //         .from("posters")
// //         .upload(fileName, req.file.buffer, {
// //           contentType: req.file.mimetype,
// //           upsert: false,
// //         });
// //       if (error) throw error;
// //       const { data: publicUrl } = supabase.storage
// //         .from("posters")
// //         .getPublicUrl(fileName);
// //       imageUrl = publicUrl.publicUrl;
// //     }

// //     await sql.query`
// //       UPDATE Posters 
// //       SET poster_name = ${poster_name}, image_url = ${imageUrl}
// //       WHERE id = ${id}
// //     `;

// //     res.send("Poster updated successfully!");
// //   } catch (err) {
// //     res.status(500).send("Error updating poster: " + err.message);
// //   }
// // });

// // // 🟢 DELETE (Remove poster)
// // router.delete("/:id", async (req, res) => {
// //   try {
// //     const { id } = req.params;
// //     await sql.query`DELETE FROM Posters WHERE id = ${id}`;
// //     res.send("Poster deleted successfully!");
// //   } catch (err) {
// //     res.status(500).send("Error deleting poster: " + err.message);
// //   }
// // });

// // module.exports = router;
