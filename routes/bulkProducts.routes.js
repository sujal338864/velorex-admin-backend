// routes/bulkProducts.routes.js
const express = require("express");
const router = express.Router();
const multer = require("multer");
const xlsx = require("xlsx");
const pool = require("../models/db");

// ------------------------ MULTER ------------------------
const upload = multer({ storage: multer.memoryStorage() });

// ------------------------ SPEC FIELD NAMES ------------------------
// Excel column name  -> spec_fields.name
const SPEC_FIELD_NAMES = {
  Spec_Brand: "Spec_Brand",
  Spec_ModelName: "Spec_ModelName",
  Spec_ModelNumber: "Spec_ModelNumber",
  Spec_Color: "Spec_Color",
  Spec_Material: "Spec_Material",
  Spec_CountryOfOrigin: "Spec_CountryOfOrigin",
  Spec_Height: "Spec_Height",
  Spec_Width: "Spec_Width",
  Spec_Depth: "Spec_Depth",
  Spec_Weight: "Spec_Weight",
  Spec_Size: "Spec_Size",
  Spec_KeyFeatures: "Spec_KeyFeatures",
  Spec_Usage: "Spec_Usage",
  Spec_WaterResistant: "Spec_WaterResistant",
  Spec_SpecialFeatures: "Spec_SpecialFeatures",
  Spec_Processor: "Spec_Processor",
  Spec_RAM: "Spec_RAM",
  Spec_Storage: "Spec_Storage",
  Spec_BatteryCapacity: "Spec_BatteryCapacity",
  Spec_Connectivity: "Spec_Connectivity",
  Spec_WarrantySummary: "Spec_WarrantySummary",
  Spec_WarrantyDuration: "Spec_WarrantyDuration",
  Spec_WarrantyType: "Spec_WarrantyType",
  Spec_CoveredInWarranty: "Spec_CoveredInWarranty",
  Spec_NotCoveredInWarranty: "Spec_NotCoveredInWarranty",
  Spec_InTheBox: "Spec_InTheBox",
};

// ------------------------ HELPERS ------------------------
const safeNumber = (v) =>
  v === null || v === undefined || v === "" || isNaN(Number(v))
    ? null
    : Number(v);

const safeString = (v) =>
  v === null || v === undefined ? "" : String(v).trim();

// ------------------------ SPEC FIELD ID RESOLVER ------------------------
async function getSpecFieldId(client, fieldName) {
  const res = await client.query(
    `SELECT field_id FROM spec_fields WHERE name = $1`,
    [fieldName]
  );
  return res.rows.length ? res.rows[0].field_id : null;
}

// ------------------------ ENSURE CATEGORY ------------------------
async function ensureCategoryId(client, name) {
  const nm = safeString(name);
  if (!nm) return null;

  const r = await client.query(
    `SELECT category_id FROM categories WHERE name=$1`,
    [nm]
  );
  if (r.rows.length) return r.rows[0].category_id;

  const ins = await client.query(
    `INSERT INTO categories (name) VALUES ($1) RETURNING category_id`,
    [nm]
  );
  return ins.rows[0].category_id;
}

// ------------------------ ENSURE SUBCATEGORY ------------------------
async function ensureSubcategoryId(client, categoryId, name) {
  const nm = safeString(name);
  if (!nm || !categoryId) return null;

  const r = await client.query(
    `SELECT subcategory_id FROM subcategories
     WHERE category_id=$1 AND name=$2`,
    [categoryId, nm]
  );
  if (r.rows.length) return r.rows[0].subcategory_id;

  const ins = await client.query(
    `INSERT INTO subcategories (name, category_id)
     VALUES ($1,$2) RETURNING subcategory_id`,
    [nm, categoryId]
  );
  return ins.rows[0].subcategory_id;
}

// ------------------------ ENSURE BRAND ------------------------
async function ensureBrandId(client, subcategoryId, name) {
  const nm = safeString(name);
  if (!nm || !subcategoryId) return null;

  const catRes = await client.query(
    `SELECT category_id FROM subcategories WHERE subcategory_id=$1`,
    [subcategoryId]
  );
  if (!catRes.rows.length) return null;

  const categoryId = catRes.rows[0].category_id;

  const r = await client.query(
    `SELECT brand_id FROM brands
     WHERE subcategory_id=$1 AND name=$2`,
    [subcategoryId, nm]
  );
  if (r.rows.length) return r.rows[0].brand_id;

  const ins = await client.query(
    `INSERT INTO brands (name, category_id, subcategory_id)
     VALUES ($1,$2,$3) RETURNING brand_id`,
    [nm, categoryId, subcategoryId]
  );
  return ins.rows[0].brand_id;
}

// ------------------------ UPSERT PRODUCT ------------------------
async function upsertProduct(
  client,
  row,
  { isParent, parentProduct, categoryId, subcategoryId, brandId }
) {
  const sku = safeString(row["SKU"]);
  if (!sku) throw new Error("SKU required");

  const existing = await client.query(
    `SELECT product_id, group_id FROM products WHERE sku=$1`,
    [sku]
  );

  const groupId = isParent
    ? Date.now()
    : parentProduct.group_id;

  if (!existing.rows.length) {
    const ins = await client.query(
      `
      INSERT INTO products
      (name, description, price, offer_price, quantity, stock,
       category_id, subcategory_id, brand_id,
       sku, group_id, parent_product_id, video_url)
      VALUES
      ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
      RETURNING product_id, group_id
      `,
      [
        safeString(row["Name"]),
        safeString(row["Description"]),
        safeNumber(row["Price"]) ?? 0,
        safeNumber(row["OfferPrice"]) ?? safeNumber(row["Price"]) ?? 0,
        safeNumber(row["Quantity"]) ?? 0,
        safeNumber(row["Stock"]) ?? 0,
        categoryId,
        subcategoryId,
        brandId,
        sku,
        groupId,
        isParent ? null : parentProduct.product_id,
        safeString(row["VideoUrl"]) || null,
      ]
    );
    return ins.rows[0];
  }

  await client.query(
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
      video_url=$10,
      updated_at=NOW()
    WHERE sku=$11
    `,
    [
      safeString(row["Name"]),
      safeString(row["Description"]),
      safeNumber(row["Price"]) ?? 0,
      safeNumber(row["OfferPrice"]) ?? safeNumber(row["Price"]) ?? 0,
      safeNumber(row["Quantity"]) ?? 0,
      safeNumber(row["Stock"]) ?? 0,
      categoryId,
      subcategoryId,
      brandId,
      safeString(row["VideoUrl"]) || null,
      sku,
    ]
  );

  return existing.rows[0];
}

// ------------------------ IMAGES ------------------------
async function upsertImages(client, productId, row) {
  const imgs = ["Image1", "Image2", "Image3"]
    .map((k) => safeString(row[k]))
    .filter(Boolean);

  for (const url of imgs) {
    await client.query(
      `INSERT INTO product_images (product_id, image_url)
       VALUES ($1,$2)`,
      [productId, url]
    );
  }
}

// ------------------------ SPECS (FIXED) ------------------------
async function upsertSpecs(client, productId, row, specFieldMap) {
  // Remove existing specs
  await client.query(
    `DELETE FROM product_specification_values WHERE product_id = $1`,
    [productId]
  );

  for (const key of Object.keys(row)) {
    if (!key.startsWith("Spec_")) continue;

    const value = safeString(row[key]);
    if (!value) continue;

    // Spec_ModelName → modelname
    const fieldKey = key
      .replace("Spec_", "")
      .replace(/_/g, "")
      .toLowerCase();

    const fieldId = specFieldMap[fieldKey];

    if (!fieldId) {
      // ❌ REMOVE THIS LOG AFTER YOU VERIFY
      console.warn(`⚠ Spec field not found, skipped: ${fieldKey}`);
      continue;
    }

    await client.query(
      `
      INSERT INTO product_specification_values
      (product_id, field_id, value)
      VALUES ($1,$2,$3)
      `,
      [productId, fieldId, value]
    );
  }
}

// ------------------------ LOAD SPEC FIELD MAP ------------------------
async function loadSpecFieldMap(client) {
  const res = await client.query(
    `SELECT field_id, name FROM specification_fields`
  );

  const map = {};
  for (const r of res.rows) {
    const key = r.name
      .replace(/\s+/g, "")   // remove spaces
      .replace(/_/g, "")     // remove underscores
      .toLowerCase();

    map[key] = r.field_id;
  }
  return map;
}



// ------------------------ BULK UPLOAD ------------------------
router.post("/bulk-upload", upload.single("file"), async (req, res) => {
  if (!req.file)
    return res.status(400).json({ success: false, message: "No file uploaded" });

  const client = await pool.connect();
  try {
    const workbook = xlsx.read(req.file.buffer, { type: "buffer" });
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const rows = xlsx.utils.sheet_to_json(sheet, { defval: "" });

    await client.query("BEGIN");
const specFieldMap = await loadSpecFieldMap(client);
    const parentCache = {};

   for (const row of rows) {
  const sku = safeString(row["SKU"]);
  const parentSku = safeString(row["ParentSKU"]);
  if (!sku) continue;

  const isParent = !parentSku;

  const categoryId = await ensureCategoryId(client, row["CategoryName"]);
  const subcategoryId = await ensureSubcategoryId(
    client,
    categoryId,
    row["SubcategoryName"]
  );
  const brandId = await ensureBrandId(
    client,
    subcategoryId,
    row["BrandName"]
  );

  let parentProduct = null;
  if (!isParent) {
    parentProduct = parentCache[parentSku];
    if (!parentProduct)
      throw new Error(`Parent SKU not found: ${parentSku}`);
  }

  const product = await upsertProduct(client, row, {
    isParent,
    parentProduct,
    categoryId,
    subcategoryId,
    brandId,
  });

  if (isParent) parentCache[sku] = product;

  await upsertImages(client, product.product_id, row);

  // ✅ THIS IS THE LINE
  await upsertSpecs(client, product.product_id, row, specFieldMap);
}


    await client.query("COMMIT");
    res.json({ success: true, message: "Bulk upload completed" });
  } catch (err) {
    await client.query("ROLLBACK");
    res.status(500).json({ success: false, error: err.message });
  } finally {
    client.release();
  }
});

module.exports = router;




// // routes/bulkProducts.routes.js
// const express = require("express");
// const router = express.Router();
// const multer = require("multer");
// const xlsx = require("xlsx");
// const { sql, poolPromise } = require("../models/db");

// // ------------------------ MULTER ------------------------
// const upload = multer({ storage: multer.memoryStorage() });

// // ------------------------ SPEC FIELD MAP ------------------------
// // ⚠️ These IDs must match your SpecificationFields.FieldID values.
// // If you created fields in this order, this is fine.
// const SPEC_FIELD_MAP = {
//   Spec_Brand: 3,
//   Spec_ModelName: 4,
//   Spec_ModelNumber: 5,
//   Spec_Color: 6,
//   Spec_Material: 7,
//   Spec_CountryOfOrigin: 8,
//   Spec_Height: 9,
//   Spec_Width: 10,
//   Spec_Depth: 11,
//   Spec_Weight: 12,
//   Spec_Size: 13,
//   Spec_KeyFeatures: 14,
//   Spec_Usage: 15,
//   Spec_WaterResistant: 16,
//   Spec_SpecialFeatures: 17,
//   Spec_Processor: 18,
//   Spec_RAM: 19,
//   Spec_Storage: 20,
//   Spec_BatteryCapacity: 21,
//   Spec_Connectivity: 22,
//   Spec_WarrantySummary: 23,
//   Spec_WarrantyDuration: 24,
//   Spec_WarrantyType: 25,
//   Spec_CoveredInWarranty: 26,
//   Spec_NotCoveredInWarranty: 27,
//   Spec_InTheBox: 28,
// };

// // ------------------------ HELPERS ------------------------
// function safeNumber(v) {
//   if (v === null || v === undefined || v === "") return null;
//   const n = Number(v);
//   return Number.isNaN(n) ? null : n;
// }

// function safeString(v) {
//   if (v === undefined || v === null) return "";
//   return String(v).trim();
// }

// function buildCombinationKey(row) {
//   const parts = [];
//   if (safeString(row["Variant_Color"]))
//     parts.push(`Color:${safeString(row["Variant_Color"])}`);
//   if (safeString(row["Variant_Size"]))
//     parts.push(`Size:${safeString(row["Variant_Size"])}`);
//   if (safeString(row["Variant_TVSize"]))
//     parts.push(`TVSize:${safeString(row["Variant_TVSize"])}`);
//   return parts.length ? parts.join("|") : null;
// }

// // ------------------------ CATEGORY/SUBCATEGORY/BRAND ------------------------
// async function ensureCategoryId(tx, name) {
//   const nm = safeString(name);
//   if (!nm) return null;

//   let r = await new sql.Request(tx)
//     .input("name", sql.NVarChar, nm)
//     .query("SELECT CategoryID FROM Categories WHERE Name=@name");

//   if (r.recordset.length) return r.recordset[0].CategoryID;

//   r = await new sql.Request(tx)
//     .input("name", sql.NVarChar, nm)
//     .query(
//       "INSERT INTO Categories (Name, CreatedAt) OUTPUT INSERTED.CategoryID VALUES (@name, GETDATE())"
//     );

//   return r.recordset[0].CategoryID;
// }

// async function ensureSubcategoryId(tx, categoryId, name) {
//   const nm = safeString(name);
//   if (!nm || !categoryId) return null;

//   let r = await new sql.Request(tx)
//     .input("catId", sql.Int, categoryId)
//     .input("name", sql.NVarChar, nm)
//     .query(
//       "SELECT SubcategoryID FROM Subcategories WHERE CategoryID=@catId AND Name=@name"
//     );

//   if (r.recordset.length) return r.recordset[0].SubcategoryID;

//   r = await new sql.Request(tx)
//     .input("catId", sql.Int, categoryId)
//     .input("name", sql.NVarChar, nm)
//     .query(
//       "INSERT INTO Subcategories (Name, CategoryID, CreatedAt) OUTPUT INSERTED.SubcategoryID VALUES (@name,@catId,GETDATE())"
//     );

//   return r.recordset[0].SubcategoryID;
// }

// async function ensureBrandId(tx, subcategoryId, name) {
//   const nm = safeString(name);
//   if (!nm || !subcategoryId) return null;

//   let r = await new sql.Request(tx)
//     .input("subId", sql.Int, subcategoryId)
//     .input("name", sql.NVarChar, nm)
//     .query("SELECT BrandID FROM Brands WHERE SubcategoryID=@subId AND Name=@name");

//   if (r.recordset.length) return r.recordset[0].BrandID;

//   r = await new sql.Request(tx)
//     .input("subId", sql.Int, subcategoryId)
//     .input("name", sql.NVarChar, nm)
//     .query(
//       "INSERT INTO Brands (Name, SubcategoryID, CreatedAt) OUTPUT INSERTED.BrandID VALUES (@name,@subId,GETDATE())"
//     );

//   return r.recordset[0].BrandID;
// }

// // ------------------------ UPSERT PRODUCT ------------------------
// async function upsertProduct(
//   tx,
//   row,
//   { isParent, parentProduct, categoryId, subcategoryId, brandId }
// ) {
//   const sku = safeString(row["SKU"]);
//   if (!sku) throw new Error("SKU required.");

//   const name = safeString(row["Name"]);
//   const description = safeString(row["Description"]);
//   const price = safeNumber(row["Price"]) ?? 0;
//   const offerPrice = safeNumber(row["OfferPrice"]) ?? price;
//   const qty = safeNumber(row["Quantity"]) ?? 0;
//   const stock = safeNumber(row["Stock"]) ?? 0;
//   const videoUrl = safeString(row["VideoUrl"]);

//   const existing = await new sql.Request(tx)
//     .input("sku", sql.NVarChar, sku)
//     .query("SELECT TOP 1 * FROM Products WHERE SKU=@sku");

//   if (existing.recordset.length === 0) {
//     // INSERT
//     const groupId = isParent
//       ? Date.now() + Math.floor(Math.random() * 999)
//       : parentProduct.GroupID;

//     const r = await new sql.Request(tx)
//       .input("name", sql.NVarChar, name)
//       .input("desc", sql.NVarChar, description)
//       .input("price", sql.Decimal(18, 2), price)
//       .input("offer", sql.Decimal(18, 2), offerPrice)
//       .input("qty", sql.Int, qty)
//       .input("stock", sql.Int, stock)
//       .input("catId", sql.Int, categoryId)
//       .input("subId", sql.Int, subcategoryId)
//       .input("brandId", sql.Int, brandId)
//       .input("sku", sql.NVarChar, sku)
//       .input("groupId", sql.BigInt, groupId)
//       .input("parentId", sql.Int, isParent ? null : parentProduct.ProductID)
//       .input("video", sql.NVarChar, videoUrl || null)
//       .query(`
//         INSERT INTO Products
//         (Name, Description, Price, OfferPrice, Quantity, Stock,
//          CategoryID, SubcategoryID, BrandID,
//          SKU, GroupID, ParentProductID, VideoUrl,
//          CreatedAt, UpdatedAt, IsSponsored)
//         OUTPUT INSERTED.ProductID, INSERTED.GroupID
//         VALUES
//         (@name,@desc,@price,@offer,@qty,@stock,
//          @catId,@subId,@brandId,
//          @sku,@groupId,@parentId,@video,
//          GETDATE(),GETDATE(),0)
//       `);

//     return r.recordset[0];
//   } else {
//     // UPDATE
//     const pid = existing.recordset[0].ProductID;

//     await new sql.Request(tx)
//       .input("pid", sql.Int, pid)
//       .input("name", sql.NVarChar, name)
//       .input("desc", sql.NVarChar, description)
//       .input("price", sql.Decimal(18, 2), price)
//       .input("offer", sql.Decimal(18, 2), offerPrice)
//       .input("qty", sql.Int, qty)
//       .input("stock", sql.Int, stock)
//       .input("catId", sql.Int, categoryId)
//       .input("subId", sql.Int, subcategoryId)
//       .input("brandId", sql.Int, brandId)
//       .input("video", sql.NVarChar, videoUrl || null)
//       .query(`
//         UPDATE Products SET
//           Name=@name,
//           Description=@desc,
//           Price=@price,
//           OfferPrice=@offer,
//           Quantity=@qty,
//           Stock=@stock,
//           CategoryID=@catId,
//           SubcategoryID=@subId,
//           BrandID=@brandId,
//           VideoUrl=@video,
//           UpdatedAt=GETDATE()
//         WHERE ProductID=@pid
//       `);

//     return existing.recordset[0];
//   }
// }

// // ------------------------ IMAGES (ProductImages table) ------------------------
// async function upsertImages(tx, productId, row) {
//   const imgs = [
//     safeString(row["Image1"]),
//     safeString(row["Image2"]),
//     safeString(row["Image3"]),
//   ].filter((x) => x);

//   if (!imgs.length) return;

//   // simple: always INSERT; no CombinationKey
//   for (const url of imgs) {
//     await new sql.Request(tx)
//       .input("pid", sql.Int, productId)
//       .input("url", sql.NVarChar, url)
//       .query(
//         "INSERT INTO ProductImages (ProductID, ImageURL) VALUES (@pid,@url)"
//       );
//   }
// }

// // ------------------------ SPECS (ProductSpecificationValues) ------------------------
// async function upsertSpecs(tx, productId, row) {
//   // delete old values for this product (same as /spec/product/save)
//   await new sql.Request(tx)
//     .input("pid", sql.Int, productId)
//     .query("DELETE FROM ProductSpecificationValues WHERE ProductID=@pid");

//   for (const [key, fieldId] of Object.entries(SPEC_FIELD_MAP)) {
//     const val = safeString(row[key]);
//     if (!val) continue;

//     await new sql.Request(tx)
//       .input("pid", sql.Int, productId)
//       .input("fid", sql.Int, fieldId)
//       .input("v", sql.NVarChar, val)
//       .query(`
//         INSERT INTO ProductSpecificationValues (ProductID, FieldID, Value)
//         VALUES (@pid, @fid, @v)
//       `);
//   }
// }

// // ------------------------ MAIN BULK UPLOAD ROUTE ------------------------
// router.post("/bulk-upload", upload.single("file"), async (req, res) => {
//   if (!req.file)
//     return res.status(400).json({ success: false, message: "No file uploaded" });

//   try {
//     const workbook = xlsx.read(req.file.buffer, { type: "buffer" });
//     const sheet = workbook.Sheets[workbook.SheetNames[0]];
//     const rows = xlsx.utils.sheet_to_json(sheet, { defval: "" });

//     if (!rows.length) {
//       return res
//         .status(400)
//         .json({ success: false, message: "Excel sheet is empty" });
//     }

//     const pool = await poolPromise;
//     const tx = new sql.Transaction(pool);
//     await tx.begin();

//     const parentCache = {}; // SKU -> { ProductID, GroupID }

//     for (const row of rows) {
//       const name = safeString(row["Name"]);
//       const sku = safeString(row["SKU"]);
//       const parentSku = safeString(row["ParentSKU"]);

//       if (!name || !sku) continue;

//       const isParent = !parentSku;

//       // Category / Subcategory / Brand by name
//       const categoryId = await ensureCategoryId(tx, row["CategoryName"]);
//       const subcategoryId = await ensureSubcategoryId(
//         tx,
//         categoryId,
//         row["SubcategoryName"]
//       );
//       const brandId = await ensureBrandId(tx, subcategoryId, row["BrandName"]);

//       // Parent record for child rows
//       let parentProduct = null;
//       if (!isParent) {
//         parentProduct = parentCache[parentSku];
//         if (!parentProduct) {
//           throw new Error(`Parent product with SKU "${parentSku}" not found (row with SKU ${sku})`);
//         }
//       }

//       const inserted = await upsertProduct(tx, row, {
//         isParent,
//         parentProduct,
//         categoryId,
//         subcategoryId,
//         brandId,
//       });

//       if (isParent) parentCache[sku] = inserted;

//       // Images (Supabase URLs already in Excel)
//       await upsertImages(tx, inserted.ProductID, row);

//       // Specs
//       await upsertSpecs(tx, inserted.ProductID, row);
//     }

//     await tx.commit();
//     return res.json({
//       success: true,
//       message: `Bulk upload successful. Processed ${rows.length} rows.`,
//     });
//   } catch (err) {
//     console.log("❌ BULK UPLOAD ERROR:", err);
//     return res
//       .status(500)
//       .json({ success: false, message: "Bulk upload failed", error: err.message });
//   }
// });

// module.exports = router;



// // routes/bulkProducts.routes.js
// const express = require("express");
// const router = express.Router();
// const multer = require("multer");
// const xlsx = require("xlsx");
// const pg = require("../models/db_postgres"); // PostgreSQL ONLY

// // ------------------------ Multer ------------------------
// const upload = multer({ storage: multer.memoryStorage() });

// // ------------------------ SPEC FIELD MAP ------------------------
// const SPEC_FIELD_MAP = {
//   Spec_Brand: 3,
//   Spec_ModelName: 4,
//   Spec_ModelNumber: 5,
//   Spec_Color: 6,
//   Spec_Material: 7,
//   Spec_CountryOfOrigin: 8,
//   Spec_Height: 9,
//   Spec_Width: 10,
//   Spec_Depth: 11,
//   Spec_Weight: 12,
//   Spec_Size: 13,
//   Spec_KeyFeatures: 14,
//   Spec_Usage: 15,
//   Spec_WaterResistant: 16,
//   Spec_SpecialFeatures: 17,
//   Spec_Processor: 18,
//   Spec_RAM: 19,
//   Spec_Storage: 20,
//   Spec_BatteryCapacity: 21,
//   Spec_Connectivity: 22,
//   Spec_WarrantySummary: 23,
//   Spec_WarrantyDuration: 24,
//   Spec_WarrantyType: 25,
//   Spec_CoveredInWarranty: 26,
//   Spec_NotCoveredInWarranty: 27,
//   Spec_InTheBox: 28,
// };

// // ------------------------ Helpers ------------------------
// function safeNumber(v) {
//   if (!v || v === "") return null;
//   const n = Number(v);
//   return Number.isNaN(n) ? null : n;
// }

// function safeString(v) {
//   return v ? String(v).trim() : "";
// }

// // ------------------------ PostgreSQL Helpers ------------------------
// async function ensureCategoryIdPG(client, name) {
//   name = safeString(name);
//   if (!name) return null;

//   const r = await client.query(
//     "SELECT categoryid FROM categories WHERE name = $1",
//     [name]
//   );
//   if (r.rows.length) return r.rows[0].categoryid;

//   const ins = await client.query(
//     "INSERT INTO categories (name, createdat) VALUES ($1, NOW()) RETURNING categoryid",
//     [name]
//   );
//   return ins.rows[0].categoryid;
// }

// async function ensureSubcategoryIdPG(client, categoryId, name) {
//   name = safeString(name);
//   if (!name || !categoryId) return null;

//   const r = await client.query(
//     "SELECT subcategoryid FROM subcategories WHERE categoryid = $1 AND name = $2",
//     [categoryId, name]
//   );
//   if (r.rows.length) return r.rows[0].subcategoryid;

//   const ins = await client.query(
//     "INSERT INTO subcategories (name, categoryid, createdat) VALUES ($1,$2,NOW()) RETURNING subcategoryid",
//     [name, categoryId]
//   );
//   return ins.rows[0].subcategoryid;
// }

// async function ensureBrandIdPG(client, subcategoryId, name) {
//   name = safeString(name);
//   if (!name || !subcategoryId) return null;

//   const r = await client.query(
//     "SELECT brandid FROM brands WHERE subcategoryid = $1 AND name = $2",
//     [subcategoryId, name]
//   );
//   if (r.rows.length) return r.rows[0].brandid;

//   const ins = await client.query(
//     "INSERT INTO brands (name, subcategoryid, createdat) VALUES ($1,$2,NOW()) RETURNING brandid",
//     [name, subcategoryId]
//   );
//   return ins.rows[0].brandid;
// }

// async function upsertProductPG(client, row, { isParent, parentProduct, categoryId, subcategoryId, brandId }) {
//   const sku = safeString(row["SKU"]);
//   if (!sku) throw new Error("SKU required.");

//   const name = safeString(row["Name"]);
//   const description = safeString(row["Description"]);
//   const price = safeNumber(row["Price"]) ?? 0;
//   const offerPrice = safeNumber(row["OfferPrice"]) ?? price;
//   const qty = safeNumber(row["Quantity"]) ?? 0;
//   const stock = safeNumber(row["Stock"]) ?? 0;

//   const existing = await client.query(
//     "SELECT * FROM products WHERE sku = $1 LIMIT 1",
//     [sku]
//   );

//   if (existing.rows.length === 0) {
//     const groupId = isParent
//       ? Date.now() + Math.floor(Math.random() * 999)
//       : parentProduct.groupid;

//     const insert = await client.query(
//       `
//       INSERT INTO products
//       (name, description, price, offerprice, quantity, stock,
//        categoryid, subcategoryid, brandid,
//        sku, groupid, parentproductid,
//        createdat, updatedat, issponsored)
//       VALUES
//       ($1,$2,$3,$4,$5,$6,
//        $7,$8,$9,
//        $10,$11,$12,
//        NOW(),NOW(),false)
//       RETURNING productid, groupid;
//     `,
//       [
//         name,
//         description,
//         price,
//         offerPrice,
//         qty,
//         stock,
//         categoryId,
//         subcategoryId,
//         brandId,
//         sku,
//         groupId,
//         isParent ? null : parentProduct.productid,
//       ]
//     );
//     return insert.rows[0];
//   }

//   // UPDATE
//   const p = existing.rows[0];
//   await client.query(
//     `
//     UPDATE products SET
//       name=$1,
//       description=$2,
//       price=$3,
//       offerprice=$4,
//       quantity=$5,
//       stock=$6,
//       categoryid=$7,
//       subcategoryid=$8,
//       brandid=$9,
//       updatedat=NOW()
//     WHERE productid=$10;
//   `,
//     [
//       name,
//       description,
//       price,
//       offerPrice,
//       qty,
//       stock,
//       categoryId,
//       subcategoryId,
//       brandId,
//       p.productid,
//     ]
//   );

//   return p;
// }

// async function upsertImagesPG(client, productId, row) {
//   const imgs = [row["Image1"], row["Image2"], row["Image3"]]
//     .map(safeString)
//     .filter((x) => x);

//   for (const url of imgs) {
//     await client.query(
//       "INSERT INTO productimages (productid, imageurl) VALUES ($1,$2)",
//       [productId, url]
//     );
//   }
// }

// async function upsertSpecsPG(client, productId, row) {
//   await client.query(
//     "DELETE FROM productspecificationvalues WHERE productid = $1",
//     [productId]
//   );

//   for (const [key, fieldId] of Object.entries(SPEC_FIELD_MAP)) {
//     const val = safeString(row[key]);
//     if (!val) continue;

//     await client.query(
//       "INSERT INTO productspecificationvalues (productid, fieldid, value) VALUES ($1,$2,$3)",
//       [productId, fieldId, val]
//     );
//   }
// }

// // =======================================================
// //  MAIN BULK UPLOAD ROUTE (PostgreSQL ONLY)
// // =======================================================
// router.post("/bulk-upload", upload.single("file"), async (req, res) => {
//   if (!req.file)
//     return res.status(400).json({ success: false, message: "No file uploaded" });

//   try {
//     const workbook = xlsx.read(req.file.buffer);
//     const sheet = workbook.Sheets[workbook.SheetNames[0]];
//     const rows = xlsx.utils.sheet_to_json(sheet, { defval: "" });

//     if (!rows.length)
//       return res.status(400).json({ success: false, message: "Excel sheet is empty" });

//     const client = await pg.pool.connect();
//     try {
//       await client.query("BEGIN");
//       const parentCache = {};

//       for (const row of rows) {
//         const name = safeString(row["Name"]);
//         const sku = safeString(row["SKU"]);
//         const parentSku = safeString(row["ParentSKU"]);

//         if (!name || !sku) continue;

//         const isParent = !parentSku;

//         const categoryId = await ensureCategoryIdPG(client, row["CategoryName"]);
//         const subcategoryId = await ensureSubcategoryIdPG(client, categoryId, row["SubcategoryName"]);
//         const brandId = await ensureBrandIdPG(client, subcategoryId, row["BrandName"]);

//         let parentProduct = null;
//         if (!isParent) {
//           parentProduct = parentCache[parentSku];
//           if (!parentProduct)
//             throw new Error(`Parent SKU "${parentSku}" not found (SKU ${sku})`);
//         }

//         const inserted = await upsertProductPG(client, row, {
//           isParent,
//           parentProduct,
//           categoryId,
//           subcategoryId,
//           brandId,
//         });

//         if (isParent) parentCache[sku] = inserted;

//         await upsertImagesPG(client, inserted.productid, row);
//         await upsertSpecsPG(client, inserted.productid, row);
//       }

//       await client.query("COMMIT");

//       res.json({
//         success: true,
//         message: `Bulk upload successful. Processed ${rows.length} rows.`,
//       });
//     } catch (err) {
//       await client.query("ROLLBACK");
//       console.error("❌ Bulk Upload PG Error:", err);
//       res.status(500).json({
//         success: false,
//         message: "Bulk upload failed (PostgreSQL)",
//         error: err.message,
//       });
//     } finally {
//       client.release();
//     }
//   } catch (err) {
//     console.error("❌ Bulk Upload General Error:", err);
//     res.status(500).json({
//       success: false,
//       message: "Bulk upload failed",
//       error: err.message,
//     });
//   }
// });

// module.exports = router;

