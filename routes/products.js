// routes/products.js (PostgreSQL)

const express = require("express");
const router = express.Router();
const multer = require("multer");
const XLSX = require("xlsx");

const upload = multer({ storage: multer.memoryStorage() });

const pool = require("../models/db"); // pg Pool
const supabase = require("../models/supabaseClient");
console.log("🚀 Supabase instance:", supabase?.constructor?.name);
console.log("🔍 Has storage:", !!supabase?.storage);

/* ===========================
   HELPERS
=========================== */
async function uploadToSupabase(file, folder = "product/single") {
  console.log("🟡 uploadToSupabase() called");
  console.log("📂 Folder:", folder);
  console.log("📄 Field:", file?.fieldname);
  console.log("📄 Original name:", file?.originalname);
  console.log("📦 Buffer exists:", !!file?.buffer);
  console.log("📦 Buffer size:", file?.buffer?.length);

  if (!file || !file.buffer) {
    throw new Error("❌ Invalid file or empty buffer");
  }

  const fileName = `${Date.now()}_${Math.random()
    .toString(36)
    .slice(2, 8)}_${(file.originalname || "image").replace(/\s+/g, "_")}`;

  const key = `${folder}/${fileName}`;
  console.log("🔑 Upload key:", key);

  const { error } = await supabase.storage
    .from("product")
    .upload(key, file.buffer, {
      contentType: file.mimetype || "image/jpeg",
      upsert: true,
    });

  if (error) {
    console.error("❌ Supabase upload error:", error);
    throw new Error(error.message);
  }

  const url =
    supabase.storage.from("product").getPublicUrl(key).data.publicUrl;

  console.log("✅ Uploaded URL:", url);
  return url;
}

// async function uploadToSupabase(file, folder = "product/single") {
//   if (!file) throw new Error("No file");

//   const fileName = `${Date.now()}_${Math.random()
//     .toString(36)
//     .slice(2, 8)}_${file.originalname.replace(/\s+/g, "_")}`;

//   const key = `${folder}/${fileName}`;

//   const { data, error } = await supabase.storage
//     .from("product")
//     .upload(key, file.buffer, {
//       contentType: file.mimetype,
//       upsert: true
//     });

//   if (error) {
//     console.error("Supabase upload failed:", error);
//     throw new Error("Image upload failed");
//   }

//   return supabase.storage.from("product").getPublicUrl(key).data.publicUrl;
// }

// async function uploadToSupabase(file, folder = "product/single") {
//   if (!file) throw new Error("No file");

//   const fileName = `${Date.now()}_${Math.random()
//     .toString(36)
//     .slice(2, 8)}_${file.originalname.replace(/\s+/g, "_")}`;

//   const key = `${folder}/${fileName}`;

//   const { error } = await supabase.storage
//     .from("product")
//     .upload(key, file.buffer, {
//       contentType: file.mimetype,
//       upsert: false,
//     });

//   if (error) throw error;

//   return supabase.storage.from("product").getPublicUrl(key).data.publicUrl;
// }

function sanitizeComboKey(k = "") {
  return k.toString().replace(/[^a-zA-Z0-9_-]/g, "_");
}

function generateVariantProductName(parent, selections = []) {
  const vals = selections.map(v => v.value || v).filter(Boolean);
  return vals.length ? `${parent} (${vals.join(", ")})` : parent;
}

function generateSKU(parent, selections = []) {
  const base = parent
    .replace(/[^A-Za-z0-9]/g, "")
    .slice(0, 6)
    .toUpperCase();

  const part = selections
    .map(v => (typeof v === "string" ? v[0] : v?.value?.[0]))
    .filter(Boolean)
    .join("")
    .toUpperCase();

  return `${base}-${part}-${Math.floor(1000 + Math.random() * 9000)}`;
}


/* =======================================================
   BULK UPLOAD (XLSX)
======================================================= */

router.post("/bulk-upload", upload.single("file"), async (req, res) => {
  const client = await pool.connect();
  try {
    if (!req.file) return res.status(400).json({ error: "No file" });

    const wb = XLSX.read(req.file.buffer, { type: "buffer" });
    const sheet = wb.Sheets[wb.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(sheet, { defval: "" });

    await client.query("BEGIN");

    for (const r of rows) {
      if (!r.Name) continue;

      const cat = await client.query(
        "SELECT category_id FROM categories WHERE name=$1",
        [r.CategoryName]
      );

      const sub = await client.query(
        "SELECT subcategory_id FROM subcategories WHERE name=$1",
        [r.SubcategoryName]
      );

      const brand = await client.query(
        "SELECT brand_id FROM brands WHERE name=$1",
        [r.BrandName]
      );

      const product = await client.query(
        `
        INSERT INTO products
        (name, description, price, offer_price, quantity, stock,
         category_id, subcategory_id, brand_id, sku, created_at, updated_at)
        VALUES
        ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW(),NOW())
        RETURNING product_id
        `,
        [
          r.Name,
          r.Description,
          r.Price,
          r.OfferPrice,
          r.Quantity || 0,
          r.Stock || 0,
          cat.rows[0]?.category_id || null,
          sub.rows[0]?.subcategory_id || null,
          brand.rows[0]?.brand_id || null,
          r.SKU,
        ]
      );

      const pid = product.rows[0].product_id;

      for (const img of [r.Image1, r.Image2, r.Image3]) {
        if (!img) continue;
        await client.query(
          "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
          [pid, img]
        );
      }
    }

    await client.query("COMMIT");
    res.json({ success: true });
  } catch (e) {
    await client.query("ROLLBACK");
    res.status(500).json({ error: e.message });
  } finally {
    client.release();
  }
});

/* =======================================================
   GET ALL PRODUCTS
======================================================= */
router.get("/", async (req, res) => {
  try {
    const q = await pool.query(`
      SELECT
        p.product_id,
        p.name,
        p.description,
        p.price,
        p.offer_price,
        p.quantity,
        p.stock,
        p.sku,
        p.created_at,

        p.category_id,
        c.name AS category_name,

        p.subcategory_id,
        s.name AS subcategory_name,

        p.brand_id,
        b.name AS brand_name,

        (
          SELECT ARRAY_AGG(image_url)
          FROM product_images
          WHERE product_id = p.product_id
        ) AS images

      FROM products p
      LEFT JOIN categories c ON p.category_id = c.category_id
      LEFT JOIN subcategories s ON p.subcategory_id = s.subcategory_id
      LEFT JOIN brands b ON p.brand_id = b.brand_id
      ORDER BY p.product_id DESC
    `);

    res.json(q.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});


/* =======================================================
   CREATE PRODUCT (NON VARIANT)
======================================================= */

router.post("/", upload.array("images", 20), async (req, res) => {
  try {
    const {
      name,
      description,
      price,
      offerPrice,
      quantity,
      stock,
      categoryId,
      subcategoryId,
      brandId,
      isSponsored,
      sku,
    } = req.body;

    if (!name) return res.status(400).json({ error: "Name required" });

    const groupId = Date.now();

    const product = await pool.query(
      `
      INSERT INTO products
      (name, description, price, offer_price, quantity, stock,
       category_id, subcategory_id, brand_id,
       is_sponsored, sku, group_id, created_at, updated_at)
      VALUES
      ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW(),NOW())
      RETURNING product_id
      `,
      [
        name,
        description,
        price,
        offerPrice,
        quantity || 0,
        stock || 0,
        categoryId,
        subcategoryId,
        brandId,
        isSponsored || false,
        sku,
        groupId,
      ]
    );

    const productId = product.rows[0].product_id;

    if (req.files) {
      for (const f of req.files) {
        const url = await uploadToSupabase(f);
        await pool.query(
          "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
          [productId, url]
        );
      }
    }

    res.json({ success: true, productId });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/* =======================================================
   UPDATE PRODUCT
======================================================= */

router.put("/:id", upload.array("images", 20), async (req, res) => {
  const id = Number(req.params.id);
  if (!id) return res.status(400).json({ error: "Invalid ID" });

  try {
    const {
      name,
      description,
      price,
      offerPrice,
      quantity,
      stock,
      categoryId,
      subcategoryId,
      brandId,
      isSponsored,
      sku,
    } = req.body;

    await pool.query(
      `
      UPDATE products SET
        name=$1,
        description=$2,
        price=$3,
        offer_price=$4,
        quantity=$5,
        stock=$6,
        category_id=$7,
        subcategory_id=$8,
        brand_id=$9,
        is_sponsored=$10,
        sku=$11,
        updated_at=NOW()
      WHERE product_id=$12
      `,
      [
        name,
        description,
        price,
        offerPrice,
        quantity,
        stock,
        categoryId,
        subcategoryId,
        brandId,
        isSponsored,
        sku,
        id,
      ]
    );

    if (req.files) {
      for (const f of req.files) {
        const url = await uploadToSupabase(f);
        await pool.query(
          "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
          [id, url]
        );
      }
    }

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/* =======================================================
   DELETE PRODUCT
======================================================= */

router.delete("/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: "Invalid product ID" });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 🔍 Check product exists
    const check = await client.query(
      "SELECT product_id FROM products WHERE product_id = $1",
      [id]
    );

    if (check.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Product not found" });
    }

    // 🧹 DELETE CHILD RECORDS FIRST
    await client.query(
      "DELETE FROM order_items WHERE product_id = $1",
      [id]
    );

    await client.query(
      "DELETE FROM product_variant_selections WHERE product_id = $1",
      [id]
    );

    await client.query(
      "DELETE FROM product_images WHERE product_id = $1",
      [id]
    );

    // 🗑️ DELETE PRODUCT
    await client.query(
      "DELETE FROM products WHERE product_id = $1",
      [id]
    );

    await client.query("COMMIT");

    res.json({ success: true, message: "Product deleted successfully" });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("❌ DELETE product failed:", e.message);
    res.status(500).json({ error: e.message });
  } finally {
    client.release();
  }
});


// router.post("/with-variants", upload.any(), async (req, res) => {
//   console.log("🔥🔥 /with-variants HIT 🔥🔥");
//   console.log("📦 Files count:", req.files?.length || 0);
//   console.log("📦 File fields:",
//     (req.files || []).map(f => f.fieldname)
//   );
//   console.log("🧾 Body keys:", Object.keys(req.body || {}));

  
//   const client = await pool.connect();
//   console.log("FILES RECEIVED: ", req.files?.length || 0);
// console.log("BODY KEYS: ", Object.keys(req.body || {}));
//   const files = req.files || [];

//   const filesByField = {};
//   for (const f of files) {
//     if (!filesByField[f.fieldname]) filesByField[f.fieldname] = [];
//     filesByField[f.fieldname].push(f);
//   }

// let parentJson = null;
// let variantsPayload = [];

// try {
//   console.log("📥 RAW parent:", req.body.parent);
//   console.log("📥 RAW variantsPayload:", req.body.variantsPayload);

//   parentJson = req.body.parent ? JSON.parse(req.body.parent) : null;
//   variantsPayload = req.body.variantsPayload
//     ? JSON.parse(req.body.variantsPayload)
//     : [];
// } catch (err) {
//   console.error("❌ JSON parse failed:", err.message);
//   return res.status(400).json({ error: "Invalid JSON payload" });
// }

// if (!parentJson || !parentJson.name) {
//   console.error("❌ parentJson missing or invalid:", parentJson);
//   return res.status(400).json({
//     error: "Parent JSON with name required",
//   });
// }

//   const createdChildIds = [];
//   const groupId = Date.now();

//   try {
//     await client.query("BEGIN");

//     const parentPrice = parentJson.price ? Number(parentJson.price) : null;
//     const parentOfferPrice = parentJson.offerPrice ? Number(parentJson.offerPrice) : null;
//     const parentStock = parentJson.stock ? Number(parentJson.stock) : 0;
//     const parentQuantity = parentJson.quantity ? Number(parentJson.quantity) : 0;

//     const parentRes = await client.query(
//       `
//       INSERT INTO products
//       (name, description, price, offer_price, quantity, stock,
//        category_id, subcategory_id, brand_id, is_sponsored,
//        sku, group_id, video_url, created_at, updated_at)
//       VALUES
//       ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW(),NOW())
//       RETURNING product_id
//       `,
//       [
//         parentJson.name,
//         parentJson.description || null,
//         parentPrice,
//         parentOfferPrice,
//         parentQuantity,
//         parentStock,
//         parentJson.categoryId || null,
//         parentJson.subcategoryId || null,
//         parentJson.brandId || null,
//         parentJson.isSponsored || false,
//         parentJson.sku || null,
//         groupId,
//         parentJson.videoUrl || null,
//       ]
//     );

//     const parentProductId = parentRes.rows[0].product_id;

 
//     /* Parent images */
//  /* Parent images */
// const parentImages = filesByField["parentImages"];
// console.log("🖼 Parent images count:", parentImages?.length || 0);

// if (!Array.isArray(parentImages)) {
//   console.warn("⚠️ No parentImages field received");
// }

// if (Array.isArray(parentImages)) {
//   for (const f of parentImages) {
//     if (!f?.buffer) continue;

//     const url = await uploadToSupabase(f, "products/parent");
//     await client.query(
//       "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
//       [parentProductId, url]
//     );
//   }
// }

// console.log("✅ Parent inserted");
// console.log("🆔 Parent ID:", parentProductId);
// console.log("🧩 Group ID:", groupId);

//     // for (const f of filesByField["parentImages"] || []) {
//     //   const url = await uploadToSupabase(f, "products/parent");
//     //   await client.query(
//     //     "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
//     //     [parentProductId, url]
//     //   );
//     // }

//     /* Child variants */
//     for (const combo of variantsPayload) {
//       const selections = Array.isArray(combo.selections) ? combo.selections : [];

//       const childPrice = combo.price ? Number(combo.price) : parentPrice;
//       const childOfferPrice = combo.offerPrice ? Number(combo.offerPrice) : parentOfferPrice;
//       const childStock = combo.stock ? Number(combo.stock) : 0;
//       const childQuantity = combo.quantity ? Number(combo.quantity) : 0;

//       const childName = generateVariantProductName(
//         parentJson.name,
//         selections.map(s => s?.value || s?.Variant || s?.VariantName || "")
//       );

//       const skuToUse =
//         combo.sku ||
//         generateSKU(parentJson.name, selections.map(s => s?.value));

//       const childRes = await client.query(
//         `
//         INSERT INTO products
//         (name, description, price, offer_price, quantity, stock,
//          category_id, subcategory_id, brand_id, is_sponsored,
//          sku, parent_product_id, group_id, video_url,
//          created_at, updated_at)
//         VALUES
//         ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,NOW(),NOW())
//         RETURNING product_id
//         `,
//         [
//           childName,
//           combo.description || null,
//           childPrice,
//           childOfferPrice,
//           childQuantity,
//           childStock,
//           parentJson.categoryId || null,
//           parentJson.subcategoryId || null,
//           parentJson.brandId || null,
//           parentJson.isSponsored || false,
//           skuToUse,
//           parentProductId,
//           groupId,
//           combo.videoUrl || null,
//         ]
//       );

//       const childProductId = childRes.rows[0].product_id;
//       createdChildIds.push(childProductId);

//       /* Variant selections */
//       for (const sel of selections) {
//         const vt = sel?.VariantTypeID ?? sel?.variantTypeId ?? sel?.typeId;
//         const vv = sel?.VariantID ?? sel?.variantValueId ?? sel?.variantId;
//         if (!vt || !vv) continue;

//         await client.query(
//           `
//           INSERT INTO product_variant_selections
//           (product_id, variant_type_id, variant_id, added_date)
//           VALUES ($1,$2,$3,NOW())
//           `,
//           [childProductId, vt, vv]
//         );
//       }

// console.log("✅ Child product inserted");
// console.log("🆔 Child ID:", childProductId);

// console.log("\n➡️ Processing variant");
// console.log("🧩 Combo object:", combo);
// console.log("🧩 Selections:", combo.selections);
//       /* Child images */
// /* Child images */
// const rawKey =
//   combo.comboKey ||
//   combo.combinationKey ||
//   combo.label ||
//   "";

// console.log("🔑 Raw combo key:", rawKey);

// if (!rawKey) {
//   console.warn("⚠️ Variant has NO comboKey → skipping images");
// }

// const sanitizedKey = sanitizeComboKey(rawKey);
// const fieldName = `images_${sanitizedKey}`;

// console.log("🧼 Sanitized key:", sanitizedKey);
// console.log("📂 Image field expected:", fieldName);

// const variantImages = filesByField[fieldName];

// console.log(
//   "🖼 Variant images found:",
//   variantImages?.length || 0
// );

// if (Array.isArray(variantImages)) {
//   for (const f of variantImages) {
//     console.log("⬆️ Uploading variant image:", f.originalname);

//     if (!f?.buffer) {
//       console.warn("⚠️ Variant image missing buffer, skipping");
//       continue;
//     }

//     const url = await uploadToSupabase(f, "products/variants");

//     await client.query(
//       "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
//       [childProductId, url]
//     );

//     console.log("✅ Variant image saved:", url);
//   }
// }


//       // for (const f of filesByField[fieldName] || []) {
//       //   const url = await uploadToSupabase(f, "products/variants");
//       //   await client.query(
//       //     "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
//       //     [childProductId, url]
//       //   );
//       // }
//     }

//     await client.query("COMMIT");

//     res.json({
//       success: true,
//       parentProductId,
//       groupId,
//       childProductIds: createdChildIds,
//     });
// } catch (err) {
//   console.error("❌ TRANSACTION FAILED ❌");
//   console.error("❌ Error message:", err.message);
//   console.error("❌ Stack:", err.stack);

//   await client.query("ROLLBACK");
//   res.status(500).json({
//     error: err.message,
//     stack: err.stack,
//   });
// }

// });
  router.post("/with-variants", upload.any(), async (req, res) => {
  console.log("🔥🔥 /with-variants HIT 🔥🔥");

  const client = await pool.connect();

  try {
    console.log("📦 Files count:", req.files?.length || 0);
    console.log(
      "📦 File fields:",
      (req.files || []).map(f => f.fieldname)
    );
    console.log("🧾 Body keys:", Object.keys(req.body || {}));

    /* ---------------- FILE MAP ---------------- */
    const files = req.files || [];
    const filesByField = {};
    for (const f of files) {
      if (!filesByField[f.fieldname]) filesByField[f.fieldname] = [];
      filesByField[f.fieldname].push(f);
    }

    /* ---------------- JSON PARSE ---------------- */
    let parentJson = null;
    let variantsPayload = [];

    try {
      console.log("📥 RAW parent:", req.body.parent);
      console.log("📥 RAW variantsPayload:", req.body.variantsPayload);

      parentJson = req.body.parent ? JSON.parse(req.body.parent) : null;
      variantsPayload = req.body.variantsPayload
        ? JSON.parse(req.body.variantsPayload)
        : [];
    } catch (err) {
      console.error("❌ JSON parse failed:", err.message);
      return res.status(400).json({ error: "Invalid JSON payload" });
    }

    if (!parentJson || !parentJson.name) {
      console.error("❌ parentJson missing or invalid:", parentJson);
      return res.status(400).json({
        error: "Parent JSON with name required",
      });
    }

    const groupId = Date.now();
    const createdChildIds = [];

    /* ================= TRANSACTION ================= */
    await client.query("BEGIN");

    /* ---------------- PARENT INSERT ---------------- */
    const parentRes = await client.query(
      `
      INSERT INTO products
      (name, description, price, offer_price, quantity, stock,
       category_id, subcategory_id, brand_id, is_sponsored,
       sku, group_id, video_url, created_at, updated_at)
      VALUES
      ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW(),NOW())
      RETURNING product_id
      `,
      [
        parentJson.name,
        parentJson.description || null,
        parentJson.price ? Number(parentJson.price) : null,
        parentJson.offerPrice ? Number(parentJson.offerPrice) : null,
        parentJson.quantity ? Number(parentJson.quantity) : 0,
        parentJson.stock ? Number(parentJson.stock) : 0,
        parentJson.categoryId || null,
        parentJson.subcategoryId || null,
        parentJson.brandId || null,
        parentJson.isSponsored || false,
        parentJson.sku || null,
        groupId,
        parentJson.videoUrl || null,
      ]
    );

    const parentProductId = parentRes.rows[0].product_id;
    console.log("✅ Parent inserted:", parentProductId);

    /* ---------------- PARENT IMAGES ---------------- */
    const parentImages = filesByField["parentImages"];
    console.log("🖼 Parent images:", parentImages?.length || 0);

    if (Array.isArray(parentImages)) {
      for (const f of parentImages) {
        if (!f?.buffer) continue;

        const url = await uploadToSupabase(f, "products/parent");
        await client.query(
          "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
          [parentProductId, url]
        );
        console.log("✅ Parent image saved:", url);
      }
    }

    /* ---------------- CHILD VARIANTS ---------------- */
    for (const combo of variantsPayload) {
      console.log("\n➡️ Processing variant:", combo);

      const selections = Array.isArray(combo.selections)
        ? combo.selections
        : [];

      const childRes = await client.query(
        `
        INSERT INTO products
        (name, description, price, offer_price, quantity, stock,
         category_id, subcategory_id, brand_id, is_sponsored,
         sku, parent_product_id, group_id, video_url,
         created_at, updated_at)
        VALUES
        ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,NOW(),NOW())
        RETURNING product_id
        `,
        [
          generateVariantProductName(
            parentJson.name,
            selections.map(s => s?.value || s)
          ),
          combo.description || null,
          combo.price ? Number(combo.price) : parentJson.price,
          combo.offerPrice ? Number(combo.offerPrice) : parentJson.offerPrice,
          combo.quantity ? Number(combo.quantity) : 0,
          combo.stock ? Number(combo.stock) : 0,
          parentJson.categoryId || null,
          parentJson.subcategoryId || null,
          parentJson.brandId || null,
          parentJson.isSponsored || false,
          combo.sku ||
            generateSKU(parentJson.name, selections.map(s => s?.value)),
          parentProductId,
          groupId,
          combo.videoUrl || null,
        ]
      );

      const childProductId = childRes.rows[0].product_id;
      createdChildIds.push(childProductId);
      console.log("✅ Child inserted:", childProductId);

      /* -------- Variant selections -------- */
      for (const sel of selections) {
        const vt = sel?.VariantTypeID ?? sel?.variantTypeId;
        const vv = sel?.VariantID ?? sel?.variantId;
        if (!vt || !vv) continue;

        await client.query(
          `
          INSERT INTO product_variant_selections
          (product_id, variant_type_id, variant_id, added_date)
          VALUES ($1,$2,$3,NOW())
          `,
          [childProductId, vt, vv]
        );
      }

      /* -------- Variant images (FIXED) -------- */
      const rawKey =
        combo.comboKey ||
        combo.combinationKey ||
        combo.label ||
        "";

      console.log("🔑 Combo key:", rawKey);

      if (rawKey) {
        const sanitizedKey = sanitizeComboKey(rawKey);
        const fieldName = `images_${sanitizedKey}`;
        const variantImages = filesByField[fieldName];

        console.log(
          "🖼 Variant images:",
          variantImages?.length || 0
        );

        if (Array.isArray(variantImages)) {
          for (const f of variantImages) {
            if (!f?.buffer) continue;

            const url = await uploadToSupabase(
              f,
              "products/variants"
            );

            await client.query(
              "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
              [childProductId, url]
            );

            console.log("✅ Variant image saved:", url);
          }
        }
      }
    }

    await client.query("COMMIT");

    res.json({
      success: true,
      parentProductId,
      groupId,
      childProductIds: createdChildIds,
    });
  } catch (err) {
    console.error("❌ TRANSACTION FAILED ❌");
    console.error(err);

    await client.query("ROLLBACK");
    res.status(500).json({
      error: err.message,
      stack: err.stack,
    });
  } finally {
    client.release(); // ✅ CRITICAL
  }
});

router.get("/:id/with-variants", async (req, res) => {
  const id = Number(req.params.id);
  if (!id) return res.status(400).json({ error: "Invalid id" });

  try {
    const parentQ = await pool.query(
      "SELECT * FROM products WHERE product_id=$1",
      [id]
    );
    if (!parentQ.rows.length) return res.status(404).json({ error: "Parent not found" });

    const parent = parentQ.rows[0];

    const parentImgs = await pool.query(
      "SELECT image_url FROM product_images WHERE product_id=$1",
      [id]
    );
    parent.images = parentImgs.rows;
    parent.videoUrl = parent.video_url || null;

    const childrenQ = await pool.query(
      "SELECT * FROM products WHERE parent_product_id=$1 ORDER BY product_id",
      [id]
    );

    for (const c of childrenQ.rows) {
      const imgs = await pool.query(
        "SELECT image_url FROM product_images WHERE product_id=$1",
        [c.product_id]
      );
      c.images = imgs.rows;

      const sels = await pool.query(
        "SELECT variant_type_id, variant_id FROM product_variant_selections WHERE product_id=$1",
        [c.product_id]
      );
      c.variantSelections = sels.rows;
      c.videoUrl = c.video_url || null;
    }

    res.json({ parent, children: childrenQ.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
  

router.get("/by-group/:groupId", async (req, res) => {
  const groupId = Number(req.params.groupId);
  if (!groupId) return res.status(400).json({ error: "Invalid GroupID" });

  try {
    const productsQ = await pool.query(
      "SELECT * FROM products WHERE group_id=$1 ORDER BY product_id",
      [groupId]
    );

    for (const p of productsQ.rows) {
      const imgs = await pool.query(
        "SELECT image_url FROM product_images WHERE product_id=$1",
        [p.product_id]
      );
      p.images = imgs.rows;

      const sels = await pool.query(
        "SELECT variant_type_id, variant_id FROM product_variant_selections WHERE product_id=$1",
        [p.product_id]
      );
      p.variantSelections = sels.rows;
    }

    res.json({ groupId, products: productsQ.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
  
router.delete("/:id/cascade", async (req, res) => {
  const id = Number(req.params.id);
  if (!id) return res.status(400).json({ error: "Invalid id" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const childrenQ = await client.query(
      "SELECT product_id FROM products WHERE parent_product_id=$1",
      [id]
    );

    for (const c of childrenQ.rows) {
      await client.query("DELETE FROM product_variant_selections WHERE product_id=$1", [c.product_id]);
      await client.query("DELETE FROM product_images WHERE product_id=$1", [c.product_id]);
      await client.query("DELETE FROM products WHERE product_id=$1", [c.product_id]);
    }

    await client.query("DELETE FROM product_variant_selections WHERE product_id=$1", [id]);
    await client.query("DELETE FROM product_images WHERE product_id=$1", [id]);
    await client.query("DELETE FROM products WHERE product_id=$1", [id]);

    await client.query("COMMIT");
    res.json({ success: true, message: "Parent + children deleted" });
  } catch (err) {
    await client.query("ROLLBACK");
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});
 
router.put("/child/:id", upload.array("images", 20), async (req, res) => {
  const id = Number(req.params.id);
  if (!id) return res.status(400).json({ error: "Invalid id" });

  try {
    const { name, price, offerPrice, quantity, stock, sku } = req.body;

    await pool.query(
      `
      UPDATE products SET
        name=$1,
        price=$2,
        offer_price=$3,
        quantity=$4,
        stock=$5,
        sku=$6,
        updated_at=NOW()
      WHERE product_id=$7
      `,
      [name, price, offerPrice, quantity, stock, sku, id]
    );

    for (const f of req.files || []) {
      const url = await uploadToSupabase(f, "products/variants");
      await pool.query(
        "INSERT INTO product_images (product_id, image_url) VALUES ($1,$2)",
        [id, url]
      );
    }

    res.json({ success: true, message: "Child updated" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});




router.post("/spec/section", async (req, res) => {
  try {
    const { name, sortOrder } = req.body;
    if (!name) return res.status(400).json({ error: "Section name required" });

    const q = await pool.query(
      `
      INSERT INTO specification_sections (name, sort_order)
      VALUES ($1, $2)
      RETURNING section_id
      `,
      [name, sortOrder || 0]
    );

    res.json({ success: true, sectionId: q.rows[0].section_id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
 
router.post("/spec/field", async (req, res) => {
  try {
    const { sectionId, name, inputType, sortOrder, options } = req.body;

    if (!sectionId || !name) {
      return res.status(400).json({ error: "sectionId & name required" });
    }

    const q = await pool.query(
      `
      INSERT INTO specification_fields
      (section_id, name, input_type, sort_order, options)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING field_id
      `,
      [
        sectionId,
        name,
        inputType || "text",
        sortOrder || 0,
        options || null,
      ]
    );

    res.json({ success: true, fieldId: q.rows[0].field_id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /products/spec/product/:productId
router.get("/spec/product/:productId", async (req, res) => {
  const { productId } = req.params;

  try {
    const { rows } = await pool.query(
      `
      SELECT field_id, value
      FROM product_specification_values
      WHERE product_id = $1
      `,
      [productId]
    );

    const map = {};
    for (const r of rows) {
      map[r.field_id] = r.value;
    }

    res.json(map);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});




router.get("/spec/sections-with-fields", async (req, res) => {
  try {
    const sectionsQ = await pool.query(
      `
      SELECT *
      FROM specification_sections
      ORDER BY sort_order, section_id
      `
    );

    const fieldsQ = await pool.query(
      `
      SELECT *
      FROM specification_fields
      ORDER BY sort_order, field_id
      `
    );

    const result = sectionsQ.rows.map(sec => ({
      ...sec,
      fields: fieldsQ.rows.filter(f => f.section_id === sec.section_id),
    }));

    res.json({ sections: result });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
router.post("/spec/product/save", async (req, res) => {
  const { productId, specs } = req.body;

  if (!productId || !Array.isArray(specs)) {
    return res.status(400).json({ success: false, error: "Invalid payload" });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    await client.query(
      "DELETE FROM product_specification_values WHERE product_id = $1",
      [productId]
    );

    for (const spec of specs) {
      if (!spec.fieldId) continue;

      await client.query(
        `
        INSERT INTO product_specification_values
          (product_id, field_id, value)
        VALUES ($1, $2, $3)
        `,
        [productId, spec.fieldId, spec.value ?? ""]
      );
    }

    await client.query("COMMIT");
    res.json({ success: true });
  } catch (e) {
    await client.query("ROLLBACK");
    res.status(500).json({ success: false, error: e.message });
  } finally {
    client.release();
  }
});



router.delete("/spec/section/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ error: "Invalid section id" });

    await pool.query(
      "DELETE FROM specification_fields WHERE section_id = $1",
      [id]
    );

    await pool.query(
      "DELETE FROM specification_sections WHERE section_id = $1",
      [id]
    );

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});


router.delete("/spec/field/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ error: "Invalid field id" });

    await pool.query(
      "DELETE FROM specification_fields WHERE field_id = $1",
      [id]
    );

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.put("/spec/section/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const { name, sortOrder } = req.body;

    await pool.query(
      `
      UPDATE specification_sections
      SET name = $1,
          sort_order = $2
      WHERE section_id = $3
      `,
      [name, sortOrder || 0, id]
    );

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.put("/spec/field/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const { name, inputType, sortOrder } = req.body;

    await pool.query(
      `
      UPDATE specification_fields
      SET name = $1,
          input_type = $2,
          sort_order = $3
      WHERE field_id = $4
      `,
      [name, inputType, sortOrder || 0, id]
    );

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});



/* =======================================================
   EXPORT
======================================================= */

module.exports = router;



// // routes/products.js
// const express = require("express");
// const router = express.Router();
// const multer = require("multer");
// const upload = multer({ storage: multer.memoryStorage() });
// const supabase = require("../models/supabaseClient");
// const { sql, poolPromise } = require("../models/db");


// const XLSX = require('xlsx');
// /* ===========================
//    Helpers
//    =========================== */
// async function uploadToSupabase(file, folder = "product/single") {
//   if (!file) throw new Error("No file received");

//   // generate file name
//   const fileName = `${Date.now()}_${Math.random()
//     .toString(36)
//     .slice(2, 8)}_${file.originalname.replace(/\s+/g, "_")}`;

//   // define storage path
//   const key = `${folder}/${fileName}`;

//   // upload to bucket "product"
//   const { error } = await supabase.storage
//     .from("product")
//     .upload(key, file.buffer, {
//       contentType: file.mimetype,
//       upsert: false,
//     });

//   if (error) throw error;

//   // return public URL
//   return supabase.storage.from("product").getPublicUrl(key).data.publicUrl;
// }

// function sanitizeComboKey(k = "") {
//   return k
//     .toString()
//     .replace(/[^a-zA-Z0-9\-_.]/g, "_")
//     .replace(/_+/g, "_");
// }

// function generateVariantProductName(parentName = "", variantSelections = []) {
//   const vals = (variantSelections || [])
//     .map((v) =>
//       typeof v === "string"
//         ? v
//         : v.value || v.Variant || v.VariantName || ""
//     )
//     .filter(Boolean);

//   return vals.length ? `${parentName} (${vals.join(", ")})` : parentName;
// }

// function generateSKU(parentName = "", variantSelections = []) {
//   const parentCode =
//     (parentName || "")
//       .replace(/[^A-Za-z0-9]/g, "")
//       .slice(0, 6)
//       .toUpperCase() || "PRD";

//   const variantPart = (variantSelections || [])
//     .map((v) => {
//       const val =
//         typeof v === "string"
//           ? v
//           : v.value || v.Variant || v.VariantName || "";
//       return val
//         .toString()
//         .split(/\s+/)
//         .map((s) => s[0] || "")
//         .join("")
//         .toUpperCase()
//         .slice(0, 3);
//     })
//     .filter(Boolean)
//     .join("-");

//   const suffix = Math.floor(1000 + Math.random() * 9000);
//   return `${parentCode}${variantPart ? "-" + variantPart : ""}-${suffix}`;
// }


// // =======================================================
// //  BULK UPLOAD PRODUCTS (XLSX ONLY — NO CSV PARSING)
// // =======================================================

// router.post('/bulk-upload', upload.single('file'), async (req, res) => {
//   try {
//     if (!req.file) {
//       return res.status(400).json({ error: "No file uploaded" });
//     }

//     console.log("📥 Excel Uploaded:", req.file.originalname);

//     // Parse XLSX buffer
//     const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
//     const sheet = workbook.Sheets[workbook.SheetNames[0]];

//     // Convert to JSON
//     const rows = XLSX.utils.sheet_to_json(sheet, { defval: "" });

//     console.log(`📚 Loaded ${rows.length} product rows`);

//     const pool = await poolPromise;

//     for (const row of rows) {
//       // Required
//       const name = row["Name"];
//       if (!name) continue;

//       // CATEGORY → ID
//       const categoryName = row["CategoryName"];
//       const subcategoryName = row["SubcategoryName"];
//       const brandName = row["BrandName"];

//       const category = await pool.request()
//         .input("name", sql.NVarChar, categoryName)
//         .query("SELECT CategoryID FROM Categories WHERE Name=@name");

//       const categoryId = category.recordset[0]?.CategoryID || null;

//       const subcat = await pool.request()
//         .input("name", sql.NVarChar, subcategoryName)
//         .query("SELECT SubcategoryID FROM Subcategories WHERE Name=@name");

//       const subcatId = subcat.recordset[0]?.SubcategoryID || null;

//       const brand = await pool.request()
//         .input("name", sql.NVarChar, brandName)
//         .query("SELECT BrandID FROM Brands WHERE Name=@name");

//       const brandId = brand.recordset[0]?.BrandID || null;

//       // INSERT PARENT
//       const parentResult = await pool.request()
//         .input("Name", sql.NVarChar, name)
//         .input("Description", sql.NVarChar, row["Description"])
//         .input("Price", sql.Decimal(10,2), row["Price"])
//         .input("OfferPrice", sql.Decimal(10,2), row["OfferPrice"])
//         .input("Quantity", sql.Int, row["Quantity"])
//         .input("Stock", sql.Int, row["Stock"])
//         .input("CategoryID", sql.Int, categoryId)
//         .input("SubcategoryID", sql.Int, subcatId)
//         .input("BrandID", sql.Int, brandId)
//         .input("SKU", sql.NVarChar, row["SKU"])
//         .input("VideoUrl", sql.NVarChar, row["VideoUrl"])
//         .query(`
//           INSERT INTO Products (Name, Description, Price, OfferPrice, Quantity, Stock, CategoryID, SubcategoryID, BrandID, SKU, VideoUrl)
//           OUTPUT INSERTED.ProductID
//           VALUES (@Name, @Description, @Price, @OfferPrice, @Quantity, @Stock, @CategoryID, @SubcategoryID, @BrandID, @SKU, @VideoUrl)
//         `);

//       const parentProductId = parentResult.recordset[0].ProductID;

//       // INSERT IMAGES
//       const images = [row["Image1"], row["Image2"], row["Image3"]];

//       for (const url of images) {
//         if (!url) continue;
//         await pool.request()
//           .input("ProductID", sql.Int, parentProductId)
//           .input("ImageURL", sql.NVarChar, url)
//           .query("INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)");
//       }

//       console.log(`✅ Added product: ${name}`);
//     }

//     res.json({ success: true, message: "Bulk upload completed" });

//   } catch (err) {
//     console.error("❌ Bulk upload error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// /* ===========================
//    GET ALL PRODUCTS
//    =========================== */
// router.get("/", async (req, res) => {
//   try {
//     const pool = await poolPromise;

//     const result = await pool.request().query(`
//       SELECT 
//         p.ProductID,
//         p.Name,
//         p.Description,
//         p.Price,
//         p.OfferPrice,
//         p.Quantity,
//         p.Stock,
//         p.CategoryID,
//         p.SubcategoryID,
//         p.BrandID,
//         p.IsSponsored,
//         p.ParentProductID,
//         p.GroupID,
//         p.SKU,
        
//         c.Name AS CategoryName,
//         s.Name AS SubcategoryName,
//         b.Name AS BrandName,

//         (
//           SELECT STRING_AGG(pi.ImageURL, ',')
//           FROM ProductImages pi
//           WHERE pi.ProductID = p.ProductID
//         ) AS ImageUrls

//       FROM Products p
//       LEFT JOIN Categories c ON p.CategoryID = c.CategoryID
//       LEFT JOIN Subcategories s ON p.SubcategoryID = s.SubcategoryID
//       LEFT JOIN Brands b ON p.BrandID = b.BrandID

//       ORDER BY p.ProductID DESC;
//     `);

//     const products = result.recordset.map((row) => ({
//       id: row.ProductID,
//       name: row.Name,
//       description: row.Description,
//       price: row.Price,
//       offerPrice: row.OfferPrice,
//       quantity: row.Quantity,
//       stock: row.Stock,
//       categoryId: row.CategoryID,
//       subcategoryId: row.SubcategoryID,
//       brandId: row.BrandID,

//       isSponsored: row.IsSponsored,
//       parentProductId: row.ParentProductID,
//       groupId: row.GroupID,
//       sku: row.SKU,

//       categoryName: row.CategoryName || "",
//       subcategoryName: row.SubcategoryName || "",
//       brandName: row.BrandName || "",

//       images: row.ImageUrls ? row.ImageUrls.split(",") : [],
//     }));

//     res.json(products);
//   } catch (err) {
//     console.error("❌ Products fetch error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// /* ===========================
//    CREATE PRODUCT (NON-VARIANT)
//    =========================== */
// router.post("/", upload.array("images", 20), async (req, res) => {
//   try {
//     const {
//       name,
//       description,
//       price,
//       offerPrice,
//       quantity,
//       categoryId,
//       subcategoryId,
//       brandId,
//       stock,
//       isSponsored,
//       sku,
//     } = req.body;

//     if (!name)
//       return res.status(400).json({ error: "Name is required" });

//     const pool = await poolPromise;

//     /* NEW GROUP ID */
//     const newGroupId = Date.now();

//     const imageUrls = [];
//     if (req.files && req.files.length) {
//       for (const f of req.files) {
//        const url = await uploadToSupabase(f, "product/single");

//         imageUrls.push(url);
//       }
//     }

//     const insertReq = await pool
//       .request()
//       .input("Name", sql.NVarChar, name)
//       .input("Description", sql.NVarChar, description || null)
//       .input("Price", sql.Decimal(10, 2), price || null)
//       .input("OfferPrice", sql.Decimal(10, 2), offerPrice || null)
//       .input("Quantity", sql.Int, quantity || 0)
//       .input("Stock", sql.Int, stock || 0)
//       .input("CategoryID", sql.Int, categoryId || null)
//       .input("SubcategoryID", sql.Int, subcategoryId || null)
//       .input("BrandID", sql.Int, brandId || null)
//       .input("IsSponsored", sql.Bit, isSponsored ? 1 : 0)
//       .input("SKU", sql.NVarChar, sku || null)
//       .input("GroupID", sql.BigInt, newGroupId)
//       .query(`
//         INSERT INTO Products
//         (Name, Description, Price, OfferPrice, Quantity, Stock, CategoryID,
//          SubcategoryID, BrandID, IsSponsored, SKU, GroupID, CreatedAt, UpdatedAt)
//         VALUES
//         (@Name, @Description, @Price, @OfferPrice, @Quantity, @Stock,
//          @CategoryID, @SubcategoryID, @BrandID, @IsSponsored, @SKU, @GroupID,
//          GETDATE(), GETDATE());

//         SELECT SCOPE_IDENTITY() AS ProductID;
//       `);

//     const productId = insertReq.recordset[0].ProductID;

//     for (const url of imageUrls) {
//       await pool
//         .request()
//         .input("ProductID", sql.Int, productId)
//         .input("ImageURL", sql.NVarChar, url)
//         .query(
//           "INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)"
//         );
//     }

//     res.status(201).json({ success: true, productId });
//   } catch (err) {
//     console.error("❌ Create product error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    UPDATE PRODUCT
//    =========================== */
// router.put("/:id", upload.array("images", 20), async (req, res) => {
//   try {
//     const id = Number(req.params.id);
//     if (!id) return res.status(400).json({ error: "Invalid ID" });

//     const pool = await poolPromise;
//     const body = req.body;

//     const newImageUrls = [];
//     if (req.files && req.files.length) {
//       for (const f of req.files) {
//         const url = await uploadToSupabase(f, "products");
//         newImageUrls.push(url);
//       }
//     }

//     const params = pool.request().input("ProductID", sql.Int, id);
//     const fields = [];

//     if (body.name) { fields.push("Name = @Name"); params.input("Name", sql.NVarChar, body.name); }
//     if (body.description) { fields.push("Description = @Description"); params.input("Description", sql.NVarChar, body.description); }
//     if (body.price !== undefined) { fields.push("Price = @Price"); params.input("Price", sql.Decimal(10,2), body.price); }
//     if (body.offerPrice !== undefined) { fields.push("OfferPrice = @OfferPrice"); params.input("OfferPrice", sql.Decimal(10,2), body.offerPrice); }
//     if (body.quantity !== undefined) { fields.push("Quantity = @Quantity"); params.input("Quantity", sql.Int, body.quantity); }
//     if (body.stock !== undefined) { fields.push("Stock = @Stock"); params.input("Stock", sql.Int, body.stock); }
//     if (body.categoryId !== undefined) { fields.push("CategoryID = @CategoryID"); params.input("CategoryID", sql.Int, body.categoryId); }
//     if (body.subcategoryId !== undefined) { fields.push("SubcategoryID = @SubcategoryID"); params.input("SubcategoryID", sql.Int, body.subcategoryId); }
//     if (body.brandId !== undefined) { fields.push("BrandID = @BrandID"); params.input("BrandID", sql.Int, body.brandId); }
//     if (body.isSponsored !== undefined) { fields.push("IsSponsored = @IsSponsored"); params.input("IsSponsored", sql.Bit, body.isSponsored ? 1 : 0); }
//     if (body.sku !== undefined) { fields.push("SKU = @SKU"); params.input("SKU", sql.NVarChar, body.sku); }

//     fields.push("UpdatedAt = GETDATE()");

//     if (fields.length) {
//       await params.query(
//         `UPDATE Products SET ${fields.join(", ")} WHERE ProductID = @ProductID`
//       );
//     }

//     for (const url of newImageUrls) {
//       await pool
//         .request()
//         .input("ProductID", sql.Int, id)
//         .input("ImageURL", sql.NVarChar, url)
//         .query(
//           "INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)"
//         );
//     }

//     /* Replace variant selections */
//     if (body.variantSelections) {
//       const selections =
//         typeof body.variantSelections === "string"
//           ? JSON.parse(body.variantSelections)
//           : body.variantSelections;

//       await pool
//         .request()
//         .input("ProductID", sql.Int, id)
//         .query(
//           "DELETE FROM ProductVariantSelections WHERE ProductID = @ProductID"
//         );

//       for (const sel of selections) {
//         const vt =
//           sel.variantTypeId ??
//           sel.VariantTypeID ??
//           sel.VariantTypeId;

//         const vv =
//           sel.variantId ??
//           sel.VariantID ??
//           sel.VariantValueID; // still accept old key from UI, but DB column is VariantID

//         if (!vt || !vv) continue;

//         await pool
//           .request()
//           .input("ProductID", sql.Int, id)
//           .input("VariantTypeID", sql.Int, vt)
//           .input("VariantID", sql.Int, vv)
//           .query(
//             "INSERT INTO ProductVariantSelections (ProductID, VariantTypeID, VariantID, AddedDate) VALUES (@ProductID, @VariantTypeID, @VariantID, GETDATE())"
//           );
//       }
//     }

//     res.json({ success: true, message: "Product updated" });
//   } catch (err) {
//     console.error("❌ Update error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    DELETE PRODUCT
//    =========================== */
// router.delete("/:id", async (req, res) => {
//   try {
//     const id = Number(req.params.id);
//     if (!id) return res.status(400).json({ error: "Invalid ID" });

//     const pool = await poolPromise;

//     await pool
//       .request()
//       .input("ProductID", sql.Int, id)
//       .query(
//         "DELETE FROM ProductVariantSelections WHERE ProductID = @ProductID"
//       );

//     await pool
//       .request()
//       .input("ProductID", sql.Int, id)
//       .query("DELETE FROM ProductImages WHERE ProductID = @ProductID");

//     await pool
//       .request()
//       .input("ProductID", sql.Int, id)
//       .query("DELETE FROM Products WHERE ProductID = @ProductID");

//     res.json({ success: true, message: "Product deleted" });
//   } catch (err) {
//     console.error("❌ Delete error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    POST /with-variants
//    =========================== */
// router.post("/with-variants", upload.any(), async (req, res) => {
//   const pool = await poolPromise;
//   const files = req.files || [];

//   const filesByField = {};
//   for (const f of files) {
//     if (!filesByField[f.fieldname]) filesByField[f.fieldname] = [];
//     filesByField[f.fieldname].push(f);
//   }

//   let parentJson = null;
//   let variantsPayload = [];

//   try {
//     parentJson = req.body.parent ? JSON.parse(req.body.parent) : null;
//     variantsPayload = req.body.variantsPayload
//       ? JSON.parse(req.body.variantsPayload)
//       : [];
//   } catch (err) {
//     console.error("❌ Invalid JSON:", err);
//     return res.status(400).json({ error: "Invalid JSON in parent or variantsPayload" });
//   }

//   if (!parentJson || !parentJson.name) {
//     return res.status(400).json({ error: "Parent JSON with name required" });
//   }

//   const tx = new sql.Transaction(pool);
//   const createdChildIds = [];

//   const groupId = Date.now(); // NEW GROUP ID

//   try {
//     await tx.begin();

//     /* ===========================
//        FIX: Convert Parent Numbers
//        =========================== */
//     const parentPrice = parentJson.price ? Number(parentJson.price) : null;
//     const parentOfferPrice = parentJson.offerPrice ? Number(parentJson.offerPrice) : null;
//     const parentStock = parentJson.stock ? Number(parentJson.stock) : 0;
//     const parentQuantity = parentJson.quantity ? Number(parentJson.quantity) : 0;

//     /* ===========================
//        INSERT PARENT PRODUCT
//        =========================== */
//     const treq = tx.request();
//     treq.input("Name", sql.NVarChar, parentJson.name);
//     treq.input("Description", sql.NVarChar, parentJson.description || null);
//     treq.input("Price", sql.Decimal(10, 2), parentPrice);
//     treq.input("OfferPrice", sql.Decimal(10, 2), parentOfferPrice);
//     treq.input("Quantity", sql.Int, parentQuantity);
//     treq.input("Stock", sql.Int, parentStock);
//     treq.input("CategoryID", sql.Int, parentJson.categoryId || null);
//     treq.input("SubcategoryID", sql.Int, parentJson.subcategoryId || null);
//     treq.input("BrandID", sql.Int, parentJson.brandId || null);
//     treq.input("VideoUrl", sql.NVarChar, parentJson.videoUrl || null);
//     treq.input("IsSponsored", sql.Bit, parentJson.isSponsored ? 1 : 0);
//     treq.input("SKU", sql.NVarChar, parentJson.sku || null);
//     treq.input("GroupID", sql.BigInt, groupId);

//     const parentInsertSQL = `
//       INSERT INTO Products
//       (Name, Description, Price, OfferPrice, Quantity, Stock, CategoryID,
//        SubcategoryID, BrandID, IsSponsored, SKU, GroupID, VideoUrl,
//        CreatedAt, UpdatedAt)
//       VALUES
//       (@Name, @Description, @Price, @OfferPrice, @Quantity, @Stock,
//        @CategoryID, @SubcategoryID, @BrandID, @IsSponsored, @SKU, @GroupID, @VideoUrl,
//        GETDATE(), GETDATE());
//       SELECT SCOPE_IDENTITY() AS ProductID;
//     `;

//     const parentRes = await treq.query(parentInsertSQL);
//     const parentProductId = parentRes.recordset[0].ProductID;

//     /* ===========================
//        SAVE PARENT IMAGES
//        =========================== */
//     if (filesByField["parentImages"]) {
//       for (const f of filesByField["parentImages"]) {
//         const url = await uploadToSupabase(f, "products/parent");

//         await tx.request()
//           .input("ProductID", sql.Int, parentProductId)
//           .input("ImageURL", sql.NVarChar, url)
//           .query("INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)");
//       }
//     }

//     /* ===========================
//        INSERT CHILD VARIANTS
//        =========================== */
//     for (const combo of variantsPayload) {
//       const selections = Array.isArray(combo.selections) ? combo.selections : [];

//       const comboLabel = combo.label || combo.combinationKey || "";

//       /* ===========================
//          FIX: convert child price/stock
//          =========================== */
//       const childPrice = combo.price ? Number(combo.price) : parentPrice;
//       const childOfferPrice = combo.offerPrice ? Number(combo.offerPrice) : parentOfferPrice;
//       const childStock = combo.stock ? Number(combo.stock) : 0;
//       const childQuantity = combo.quantity ? Number(combo.quantity) : 0;

//       const childName = generateVariantProductName(
//         parentJson.name,
//         selections.map(s => s?.value || s?.Variant || s?.VariantName || "")
//       );

//       const skuToUse =
//         combo.sku ||
//         generateSKU(parentJson.name, selections.map(s => s?.value));

//       const childReq = tx.request();
//       childReq.input("Name", sql.NVarChar, childName);
//       childReq.input("Description", sql.NVarChar, combo.description || null);
//       childReq.input("Price", sql.Decimal(10, 2), childPrice);
//       childReq.input("OfferPrice", sql.Decimal(10, 2), childOfferPrice);
//       childReq.input("Quantity", sql.Int, childQuantity);
//       childReq.input("Stock", sql.Int, childStock);
//       childReq.input("CategoryID", sql.Int, parentJson.categoryId || null);
//       childReq.input("SubcategoryID", sql.Int, parentJson.subcategoryId || null);
//       childReq.input("BrandID", sql.Int, parentJson.brandId || null);
//       childReq.input("IsSponsored", sql.Bit, parentJson.isSponsored ? 1 : 0);
//       childReq.input("SKU", sql.NVarChar, skuToUse);
//       childReq.input("ParentProductID", sql.Int, parentProductId);
//       childReq.input("GroupID", sql.BigInt, groupId);
//       childReq.input("VideoUrl", sql.NVarChar, combo.videoUrl || null);

//       const childInsertSQL = `
//         INSERT INTO Products
//         (Name, Description, Price, OfferPrice, Quantity, Stock, CategoryID,
//          SubcategoryID, BrandID, IsSponsored, SKU, ParentProductID, GroupID, VideoUrl,
//          CreatedAt, UpdatedAt)
//         VALUES
//         (@Name, @Description, @Price, @OfferPrice, @Quantity, @Stock,
//          @CategoryID, @SubcategoryID, @BrandID, @IsSponsored, @SKU,
//          @ParentProductID, @GroupID, @VideoUrl,
//          GETDATE(), GETDATE());
//         SELECT SCOPE_IDENTITY() AS ProductID;
//       `;

//       const childRes = await childReq.query(childInsertSQL);
//       const childProductId = childRes.recordset[0].ProductID;
//       createdChildIds.push(childProductId);

//       /* ===========================
//          INSERT VARIANT SELECTIONS
//          =========================== */
//       for (const sel of selections) {
//         const vt = sel?.VariantTypeID ?? sel?.variantTypeId ?? sel?.typeId;
//         const vv = sel?.VariantID ?? sel?.variantValueId ?? sel?.variantId;
//         if (!vt || !vv) continue;

//         await tx.request()
//           .input("ProductID", sql.Int, childProductId)
//           .input("VariantTypeID", sql.Int, vt)
//           .input("VariantID", sql.Int, vv)
//           .query(
//             "INSERT INTO ProductVariantSelections (ProductID, VariantTypeID, VariantID, AddedDate) VALUES (@ProductID, @VariantTypeID, @VariantID, GETDATE())"
//           );
//       }

//       /* ===========================
//          SAVE CHILD IMAGES
//          =========================== */
//       const sanitizedKey = sanitizeComboKey(combo.combinationKey || comboLabel);
//       const fieldName = `images_${sanitizedKey}`;
//       const comboFiles = filesByField[fieldName] || [];

//       for (const f of comboFiles) {
//         const url = await uploadToSupabase(f, "products/variants");

//         await tx.request()
//           .input("ProductID", sql.Int, childProductId)
//           .input("ImageURL", sql.NVarChar, url)
//           .query(
//             "INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)"
//           );
//       }
//     }

//     await tx.commit();

//     res.json({
//       success: true,
//       parentProductId,
//       groupId,
//       childProductIds: createdChildIds,
//     });
//   } catch (err) {
//     console.error("❌ /with-variants error:", err);
//     try { await tx.rollback(); } catch {}
//     res.status(500).json({ error: err.message });
//   }
// });


// /* ===========================
//    GET /:id/with-variants
//    =========================== */
// /* ===========================
//    GET /:id/with-variants
//    =========================== */
// router.get("/:id/with-variants", async (req, res) => {
//   try {
//     const id = Number(req.params.id);
//     if (!id) return res.status(400).json({ error: "Invalid id" });

//     const pool = await poolPromise;

//     // Fetch parent
//     const parentQ = await pool
//       .request()
//       .input("id", sql.Int, id)
//       .query("SELECT * FROM Products WHERE ProductID = @id");

//     const parent = parentQ.recordset[0];
//     if (!parent) return res.status(404).json({ error: "Parent not found" });

//     // Parent images
//     const parentImgs = await pool
//       .request()
//       .input("id", sql.Int, id)
//       .query("SELECT ProductImageID, ImageURL FROM ProductImages WHERE ProductID = @id");

//     parent.images = parentImgs.recordset;

//     // ⭐ ADD THIS — return parent video URL
//     parent.videoUrl =
//       parent.VideoUrl ||
//       parent.videoUrl ||
//       parent.video_url ||
//       null;

//     // Fetch children
//     const childrenQ = await pool
//       .request()
//       .input("id", sql.Int, id)
//       .query("SELECT * FROM Products WHERE ParentProductID = @id ORDER BY ProductID ASC");

//     const children = childrenQ.recordset;

//     for (const c of children) {

//       // Child images
//       const imgs = await pool
//         .request()
//         .input("id", sql.Int, c.ProductID)
//         .query("SELECT ProductImageID, ImageURL FROM ProductImages WHERE ProductID = @id");

//       c.images = imgs.recordset;

//       // Variant selections
//       const sels = await pool
//         .request()
//         .input("id", sql.Int, c.ProductID)
//         .query("SELECT VariantTypeID, VariantID FROM ProductVariantSelections WHERE ProductID = @id");

//       c.variantSelections = sels.recordset;

//       // ⭐ ADD THIS — return child video URL
//       c.videoUrl =
//         c.VideoUrl ||
//         c.videoUrl ||
//         c.video_url ||
//         null;
//     }

//     res.json({ parent, children });

//   } catch (err) {
//     console.error("❌ fetch with-variants error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    NEW: GET /by-group/:groupId
//    =========================== */
// router.get("/by-group/:groupId", async (req, res) => {
//   try {
//     const groupId = Number(req.params.groupId);
//     if (!groupId)
//       return res.status(400).json({ error: "Invalid GroupID" });

//     const pool = await poolPromise;

//     const productsQ = await pool
//       .request()
//       .input("gid", sql.BigInt, groupId)
//       .query(
//         "SELECT * FROM Products WHERE GroupID = @gid ORDER BY ProductID"
//       );

//     const products = productsQ.recordset;

//     for (const p of products) {
//       const imgs = await pool
//         .request()
//         .input("id", sql.Int, p.ProductID)
//         .query(
//           "SELECT ProductImageID, ImageURL FROM ProductImages WHERE ProductID = @id"
//         );

//       p.images = imgs.recordset;

//       const sels = await pool
//         .request()
//         .input("id", sql.Int, p.ProductID)
//         .query(
//           "SELECT VariantTypeID, VariantID FROM ProductVariantSelections WHERE ProductID = @id"
//         );

//       p.variantSelections = sels.recordset;
//     }

//     res.json({ groupId, products });
//   } catch (err) {
//     console.error("❌ group fetch error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });
// /* ===========================
//    UPDATE PRODUCT WITH VARIANTS
//    =========================== */
// router.put("/with-variants/:id", upload.any(), async (req, res) => {
//   const parentId = Number(req.params.id);
//   if (!parentId) return res.status(400).json({ error: "Invalid parent ID" });

//   const pool = await poolPromise;
//   const files = req.files || [];

//   const filesByField = {};
//   for (const f of files) {
//     if (!filesByField[f.fieldname]) filesByField[f.fieldname] = [];
//     filesByField[f.fieldname].push(f);
//   }

//   let parentJson = null;
//   let variantsPayload = [];

//   try {
//     parentJson = req.body.parent ? JSON.parse(req.body.parent) : null;
//     variantsPayload = req.body.variantsPayload ? JSON.parse(req.body.variantsPayload) : [];

//     if (!parentJson || !parentJson.name) {
//       return res.status(400).json({ error: "Parent JSON invalid" });
//     }
//   } catch (err) {
//     return res.status(400).json({ error: "Invalid JSON" });
//   }

//   const tx = new sql.Transaction(pool);

//   try {
//     await tx.begin();

//     /* ===========================
//        UPDATE PARENT PRODUCT
//        =========================== */

//     const reqP = tx.request();
//     reqP.input("ProductID", sql.Int, parentId);
//     reqP.input("Name", sql.NVarChar, parentJson.name);
//     reqP.input("Description", sql.NVarChar, parentJson.description || null);
//     reqP.input("Price", sql.Decimal(10, 2), parentJson.price || 0);
//     reqP.input("OfferPrice", sql.Decimal(10, 2), parentJson.offerPrice || 0);
//     reqP.input("Quantity", sql.Int, parentJson.quantity ?? 0);
//     reqP.input("Stock", sql.Int, parentJson.stock ?? 0);
//     reqP.input("CategoryID", sql.Int, parentJson.categoryId || null);
//     reqP.input("SubcategoryID", sql.Int, parentJson.subcategoryId || null);
//     reqP.input("BrandID", sql.Int, parentJson.brandId || null);
//     reqP.input("VideoUrl", sql.NVarChar, parentJson.videoUrl || null);
//     reqP.input("IsSponsored", sql.Bit, parentJson.isSponsored ? 1 : 0);
//     reqP.input("SKU", sql.NVarChar, parentJson.sku || null);

//     await reqP.query(`
//       UPDATE Products SET
//         Name = @Name,
//         Description = @Description,
//         Price = @Price,
//         OfferPrice = @OfferPrice,
//         Quantity = @Quantity,
//         Stock = @Stock,
//         CategoryID = @CategoryID,
//         SubcategoryID = @SubcategoryID,
//         BrandID = @BrandID,
//         VideoUrl = @VideoUrl,
//         IsSponsored = @IsSponsored,
//         SKU = @SKU,
//         UpdatedAt = GETDATE()
//       WHERE ProductID = @ProductID
//     `);

//     /* ===========================
//        SAVE NEW PARENT IMAGES
//        =========================== */
//     if (filesByField["parentImages"]) {
//       for (const f of filesByField["parentImages"]) {
//         const url = await uploadToSupabase(f, "products/parent");

//         await tx.request()
//           .input("ProductID", sql.Int, parentId)
//           .input("ImageURL", sql.NVarChar, url)
//           .query(
//             "INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)"
//           );
//       }
//     }

//     /* ===========================
//        DELETE OLD CHILDREN + VARIANTS
//        =========================== */
//     const existingChildren = await tx.request()
//       .input("pid", sql.Int, parentId)
//       .query("SELECT ProductID FROM Products WHERE ParentProductID = @pid");

//     for (const c of existingChildren.recordset) {
//       const cid = c.ProductID;

//       await tx.request().input("cid", sql.Int, cid)
//         .query("DELETE FROM ProductVariantSelections WHERE ProductID = @cid");

//       await tx.request().input("cid", sql.Int, cid)
//         .query("DELETE FROM ProductImages WHERE ProductID = @cid");

//       await tx.request().input("cid", sql.Int, cid)
//         .query("DELETE FROM Products WHERE ProductID = @cid");
//     }

//     /* ===========================
//        INSERT UPDATED VARIANT PRODUCTS
//        =========================== */
//     for (const combo of variantsPayload) {
//       const sels = combo.selections || [];

//       const childName = generateVariantProductName(
//         parentJson.name,
//         sels.map(s => s.Variant || s.VariantName || s.value)
//       );

//       const price = combo.price ?? parentJson.price;
//       const offerPrice = combo.offerPrice ?? parentJson.offerPrice;

//       const childReq = tx.request();
//       childReq.input("Name", sql.NVarChar, childName);
//       childReq.input("Description", sql.NVarChar, combo.description || null);
//       childReq.input("Price", sql.Decimal(10, 2), price);
//       childReq.input("OfferPrice", sql.Decimal(10, 2), offerPrice);
//       childReq.input("Quantity", sql.Int, combo.quantity ?? 0);
//       childReq.input("Stock", sql.Int, combo.stock ?? 0);
//       childReq.input("CategoryID", sql.Int, parentJson.categoryId);
//       childReq.input("SubcategoryID", sql.Int, parentJson.subcategoryId);
//       childReq.input("BrandID", sql.Int, parentJson.brandId);
//       childReq.input("IsSponsored", sql.Bit, parentJson.isSponsored ? 1 : 0);
//       childReq.input("SKU", sql.NVarChar, combo.sku);
//       childReq.input("VideoUrl", sql.NVarChar, combo.videoUrl || null);
//       childReq.input("ParentProductID", sql.Int, parentId);
//       childReq.input("GroupID", sql.BigInt, parentJson.groupId || Date.now());

//       const childInsert = await childReq.query(`
//         INSERT INTO Products
//         (Name, Description, Price, OfferPrice, Quantity, Stock, CategoryID,
//          SubcategoryID, BrandID, IsSponsored, SKU, ParentProductID, GroupID, VideoUrl,
//          CreatedAt, UpdatedAt)
//         VALUES
//         (@Name, @Description, @Price, @OfferPrice, @Quantity, @Stock,
//          @CategoryID, @SubcategoryID, @BrandID, @IsSponsored, @SKU,
//          @ParentProductID, @GroupID, @VideoUrl,
//          GETDATE(), GETDATE());

//          SELECT SCOPE_IDENTITY() AS ProductID;
//       `);

//       const childId = childInsert.recordset[0].ProductID;

//       /* Variant Selections */
//       for (const s of sels) {
//         const vt = s.variantTypeId || s.VariantTypeID;
//         const vv = s.variantId || s.VariantID;

//         if (!vt || !vv) continue;

//         await tx.request()
//           .input("ProductID", sql.Int, childId)
//           .input("VariantTypeID", sql.Int, vt)
//           .input("VariantID", sql.Int, vv)
//           .query(`
//             INSERT INTO ProductVariantSelections
//             (ProductID, VariantTypeID, VariantID, AddedDate)
//             VALUES (@ProductID, @VariantTypeID, @VariantID, GETDATE())
//           `);
//       }

//       /* Child images */
//       const key = combo.combinationKey;
//       const fieldName = `images_${sanitizeComboKey(key)}`;
//       const comboFiles = filesByField[fieldName] || [];

//       for (const f of comboFiles) {
//         const url = await uploadToSupabase(f, "products/variants");

//         await tx
//           .request()
//           .input("ProductID", sql.Int, childId)
//           .input("ImageURL", sql.NVarChar, url)
//           .query(
//             "INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)"
//           );
//       }
//     }

//     await tx.commit();

//     res.json({ success: true, parentProductId: parentId });

//   } catch (err) {
//     console.error("❌ update-with-variants error:", err);
//     await tx.rollback();
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    DELETE /:id/cascade
//    =========================== */
// router.delete("/:id/cascade", async (req, res) => {
//   const id = Number(req.params.id);
//   if (!id) return res.status(400).json({ error: "Invalid id" });

//   const pool = await poolPromise;
//   const tx = new sql.Transaction(pool);

//   try {
//     await tx.begin();

//     const childrenQ = await tx
//       .request()
//       .input("id", sql.Int, id)
//       .query("SELECT ProductID FROM Products WHERE ParentProductID = @id");

//     const childIds = childrenQ.recordset.map((x) => x.ProductID);

//     for (const cid of childIds) {
//       await tx
//         .request()
//         .input("pid", sql.Int, cid)
//         .query(
//           "DELETE FROM ProductVariantSelections WHERE ProductID = @pid"
//         );

//       await tx
//         .request()
//         .input("pid", sql.Int, cid)
//         .query("DELETE FROM ProductImages WHERE ProductID = @pid");

//       await tx
//         .request()
//         .input("pid", sql.Int, cid)
//         .query("DELETE FROM Products WHERE ProductID = @pid");
//     }

//     await tx
//       .request()
//       .input("pid", sql.Int, id)
//       .query(
//         "DELETE FROM ProductVariantSelections WHERE ProductID = @pid"
//       );

//     await tx
//       .request()
//       .input("pid", sql.Int, id)
//       .query("DELETE FROM ProductImages WHERE ProductID = @pid");

//     await tx
//       .request()
//       .input("pid", sql.Int, id)
//       .query("DELETE FROM Products WHERE ProductID = @pid");

//     await tx.commit();

//     res.json({ success: true, message: "Parent + children deleted" });
//   } catch (err) {
//     console.error("❌ cascade delete error:", err);
//     try {
//       await tx.rollback();
//     } catch {}
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ===========================
//    UPDATE CHILD PRODUCT
//    =========================== */
// router.put("/child/:id", upload.array("images", 20), async (req, res) => {
//   const id = Number(req.params.id);
//   if (!id) return res.status(400).json({ error: "Invalid id" });

//   try {
//     const pool = await poolPromise;
//     const body = req.body;

//     const imageUrls = [];
//     if (req.files && req.files.length) {
//       for (const f of req.files) {
//         const url = await uploadToSupabase(f, "products/variants");
//         imageUrls.push(url);
//       }
//     }

//     const params = pool.request().input("ProductID", sql.Int, id);
//     const fields = [];

//     if (body.name) {
//       fields.push("Name = @Name");
//       params.input("Name", sql.NVarChar, body.name);
//     }

//     if (body.price !== undefined) {
//       fields.push("Price = @Price");
//       params.input("Price", sql.Decimal(10, 2), body.price);
//     }

//     if (body.offerPrice !== undefined) {
//       fields.push("OfferPrice = @OfferPrice");
//       params.input("OfferPrice", sql.Decimal(10, 2), body.offerPrice);
//     }

//     if (body.quantity !== undefined) {
//       fields.push("Quantity = @Quantity");
//       params.input("Quantity", sql.Int, body.quantity);
//     }

//     if (body.stock !== undefined) {
//       fields.push("Stock = @Stock");
//       params.input("Stock", sql.Int, body.stock);
//     }

//     if (body.sku !== undefined) {
//       fields.push("SKU = @SKU");
//       params.input("SKU", sql.NVarChar, body.sku);
//     }

//     fields.push("UpdatedAt = GETDATE()");

//     if (fields.length) {
//       await params.query(
//         `UPDATE Products SET ${fields.join(", ")} WHERE ProductID = @ProductID`
//       );
//     }

//     for (const u of imageUrls) {
//       await pool
//         .request()
//         .input("ProductID", sql.Int, id)
//         .input("ImageURL", sql.NVarChar, u)
//         .query(
//           "INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@ProductID, @ImageURL)"
//         );
//     }

//     /* Replace variant selections */
//     if (body.variantSelections) {
//       const selections =
//         typeof body.variantSelections === "string"
//           ? JSON.parse(body.variantSelections)
//           : body.variantSelections;

//       await pool
//         .request()
//         .input("ProductID", sql.Int, id)
//         .query(
//           "DELETE FROM ProductVariantSelections WHERE ProductID = @ProductID"
//         );

//       for (const sel of selections) {
//         const vt =
//           sel.variantTypeId ??
//           sel.VariantTypeID ??
//           sel.VariantTypeId;

//         const vv =
//           sel.variantId ??
//           sel.VariantID ??
//           sel.VariantValueID;

//         if (!vt || !vv) continue;

//         await pool
//           .request()
//           .input("ProductID", sql.Int, id)
//           .input("VariantTypeID", sql.Int, vt)
//           .input("VariantID", sql.Int, vv)
//           .query(
//             "INSERT INTO ProductVariantSelections (ProductID, VariantTypeID, VariantID, AddedDate) VALUES (@ProductID, @VariantTypeID, @VariantID, GETDATE())"
//           );
//       }
//     }

//     res.json({ success: true, message: "Child updated" });
//   } catch (err) {
//     console.error("❌ child update error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// // _------------------------------------------------------
// // / specificaion
// // _______________________________________________________

// router.post("/spec/section", async (req, res) => {
//   try {
//     const { name, sortOrder } = req.body;
//     if (!name) return res.status(400).json({ error: "Section name required" });

//     const pool = await poolPromise;
//     const q = await pool.request()
//       .input("Name", sql.NVarChar, name)
//       .input("SortOrder", sql.Int, sortOrder || 0)
//       .query(`
//         INSERT INTO SpecificationSections (Name, SortOrder)
//         VALUES (@Name, @SortOrder);
//         SELECT SCOPE_IDENTITY() AS SectionID;
//       `);

//     res.json({ success: true, sectionId: q.recordset[0].SectionID });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });


// router.post("/spec/field", async (req, res) => {
//   try {
//     const { sectionId, name, inputType, sortOrder, options } = req.body;

//     if (!sectionId || !name)
//       return res.status(400).json({ error: "sectionId & name required" });

//     const pool = await poolPromise;
//     const q = await pool.request()
//       .input("SectionID", sql.Int, sectionId)
//       .input("Name", sql.NVarChar, name)
//       .input("InputType", sql.NVarChar, inputType || "text")
//       .input("SortOrder", sql.Int, sortOrder || 0)
//       .input("Options", sql.NVarChar, options || null)  // 🔴 NEW
//       .query(`
//         INSERT INTO SpecificationFields (SectionID, Name, InputType, SortOrder, Options)
//         VALUES (@SectionID, @Name, @InputType, @SortOrder, @Options);
//         SELECT SCOPE_IDENTITY() AS FieldID;
//       `);

//     res.json({ success: true, fieldId: q.recordset[0].FieldID });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });

// // GET product specs: /api/products/spec/product/:productId
// router.get("/spec/product/:productId", async (req, res) => {
//   try {
//     const productId = Number(req.params.productId);
//     if (!productId) {
//       return res.status(400).json({ error: "Invalid productId" });
//     }

//     const pool = await poolPromise;

//     const q = await pool
//       .request()
//       .input("ProductID", sql.Int, productId)
//       .query(`
//         SELECT ProductID, FieldID, Value
//         FROM ProductSpecificationValues
//         WHERE ProductID = @ProductID
//       `);

//     // returns: [ { ProductID, FieldID, Value }, ... ]
//     res.json(q.recordset);
//   } catch (e) {
//     console.error("❌ spec/product error:", e);
//     res.status(500).json({ error: e.message });
//   }
// });

// router.get("/spec/sections-with-fields", async (req, res) => {
//   try {
//     const pool = await poolPromise;

//     const sections = await pool.request().query(`
//       SELECT * FROM SpecificationSections ORDER BY SortOrder, SectionID
//     `);

//     const fields = await pool.request().query(`
//       SELECT * FROM SpecificationFields ORDER BY SortOrder, FieldID
//     `);

//     const result = sections.recordset.map(sec => ({
//       ...sec,
//       fields: fields.recordset.filter(f => f.SectionID === sec.SectionID),
//     }));

//     res.json({ sections: result });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });


// router.post("/spec/product/save", async (req, res) => {
//   try {
//     const { productId, specs } = req.body;
//     if (!productId) return res.status(400).json({ error: "productId required" });

//     const pool = await poolPromise;

//     await pool.request()
//       .input("ProductID", sql.Int, productId)
//       .query(`DELETE FROM ProductSpecificationValues WHERE ProductID = @ProductID`);

//     for (const s of specs) {
//       if (!s.value || s.value.trim() === "") continue; // ✔ skip empty values

//       await pool.request()
//         .input("ProductID", sql.Int, productId)
//         .input("FieldID", sql.Int, s.fieldId)
//         .input("Value", sql.NVarChar, s.value)
//         .query(`
//           INSERT INTO ProductSpecificationValues (ProductID, FieldID, Value)
//           VALUES (@ProductID, @FieldID, @Value)
//         `);
//     }

//     res.json({ success: true });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });
// router.delete("/spec/section/:id", async (req, res) => {
//   try {
//     const id = Number(req.params.id);
//     if (!id) return res.status(400).json({ error: "Invalid section id" });

//     const pool = await poolPromise;

//     await pool.request()
//       .input("SectionID", sql.Int, id)
//       .query(`DELETE FROM SpecificationFields WHERE SectionID = @SectionID`);

//     await pool.request()
//       .input("SectionID", sql.Int, id)
//       .query(`DELETE FROM SpecificationSections WHERE SectionID = @SectionID`);

//     res.json({ success: true });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });

// router.delete("/spec/field/:id", async (req, res) => {
//   try {
//     const id = Number(req.params.id);
//     if (!id) return res.status(400).json({ error: "Invalid field id" });

//     const pool = await poolPromise;

//     await pool.request()
//       .input("FieldID", sql.Int, id)
//       .query(`DELETE FROM SpecificationFields WHERE FieldID = @FieldID`);

//     res.json({ success: true });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });

// router.put("/spec/section/:id", async (req, res) => {
//   try {
//     const id = Number(req.params.id);
//     const { name, sortOrder } = req.body;

//     const pool = await poolPromise;

//     await pool.request()
//       .input("SectionID", sql.Int, id)
//       .input("Name", sql.NVarChar, name)
//       .input("SortOrder", sql.Int, sortOrder || 0)
//       .query(`
//         UPDATE SpecificationSections
//         SET Name = @Name, SortOrder = @SortOrder
//         WHERE SectionID = @SectionID
//       `);

//     res.json({ success: true });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });

// router.put("/spec/field/:id", async (req, res) => {
//   try {
//     const id = Number(req.params.id);
//     const { name, inputType, sortOrder } = req.body;

//     const pool = await poolPromise;

//     await pool.request()
//       .input("FieldID", sql.Int, id)
//       .input("Name", sql.NVarChar, name)
//       .input("InputType", sql.NVarChar, inputType)
//       .input("SortOrder", sql.Int, sortOrder || 0)
//       .query(`
//         UPDATE SpecificationFields
//         SET Name = @Name, InputType = @InputType, SortOrder = @SortOrder
//         WHERE FieldID = @FieldID
//       `);

//     res.json({ success: true });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });

// /* ===========================
//    EXPORT ROUTER
//    =========================== */
// module.exports = router;