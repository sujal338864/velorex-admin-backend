require("dotenv").config();
const express = require("express");
const cors = require("cors");
const morgan = require("morgan");

const app = express();
const PORT = process.env.PORT || 3001;
app.get("/db-test", async (req, res) => {
  try {
    const result = await pool.query("SELECT 1 AS ok");
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// =========================
// MIDDLEWARE
// =========================
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(morgan("dev"));

// =========================
// ROUTES
// =========================
const categoriesRoutes = require("./routes/categories");
const subcategoriesRoutes = require("./routes/subcategories");
const productRoutes = require("./routes/products");
const bulkProductsRoutes = require("./routes/bulkProducts.routes");
const couponRoutes = require("./routes/coupons");
const notificationsRoutes = require("./routes/notifications");
const brandRoutes = require("./routes/brands");
const variantTypesRoutes = require("./routes/variantTypes");
const variantRoutes = require("./routes/variants");
const uploadRoutes = require("./routes/upload");
const postersRoutes = require("./routes/posters");
const adminAuthRoutes = require("./routes/adminAuthRoutes");
const adminOrdersRoutes = require("./routes/adminOrders");

// =========================
// USE ROUTES
// =========================
app.use("/api/categories", categoriesRoutes);
app.use("/api/subcategories", subcategoriesRoutes);

// bulk upload FIRST
app.use("/api/products", bulkProductsRoutes);
// normal product routes
app.use("/api/products", productRoutes);

app.use("/api/brands", brandRoutes);
app.use("/api/variantTypes", variantTypesRoutes);
app.use("/api/variants", variantRoutes);
app.use("/api/coupons", couponRoutes);
app.use("/api/notifications", notificationsRoutes);
app.use("/api/posters", postersRoutes);
app.use("/api/upload", uploadRoutes);

app.use("/api/admin", adminAuthRoutes);
app.use("/api/admin/orders", adminOrdersRoutes);

// =========================
// HEALTH CHECK
// =========================
app.get("/", (req, res) => {
  res.send("🚀 VeloreX Admin Backend Running");
});

// =========================
// START SERVER
// =========================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});



// require("dotenv").config();
// const express = require("express");
// const cors = require("cors");
// const morgan = require("morgan");

// const app = express();
// const PORT = process.env.PORT || 3001;

// app.use(cors());
// app.use(express.json());
// app.use(morgan("dev"));

// // ROUTES
// const categoriesRoutes = require('./routes/categories');
// const subcategoriesRoutes = require('./routes/subcategories');
// const productRoutes = require('./routes/products');
// const bulkProductsRoutes = require('./routes/bulkProducts.routes');
// const couponRoutes = require('./routes/coupons');
// const notificationsRouter = require('./routes/notifications');
// const brandRoutes = require('./routes/brands');
// const variantTypesRouter = require('./routes/variantTypes');
// const variantRoutes = require('./routes/variants');
// const uploadRouter = require('./routes/upload');
// const postersRoute = require('./routes/posters');
// const adminAuthRoutes = require('./routes/adminAuthRoutes');
// const adminOrders = require("./routes/adminOrders");

// // USE ROUTES
// // USE ROUTES
// app.use('/api/categories', categoriesRoutes);
// app.use('/api/subcategories', subcategoriesRoutes);

// // FIRST: bulk upload (so /bulk-upload works)
// app.use('/api/products', bulkProductsRoutes);

// // THEN: normal product routes
// app.use('/api/products', productRoutes);

// app.use('/api/coupons', couponRoutes);
// app.use('/api/notifications', notificationsRouter);
// app.use('/api/brands', brandRoutes);
// app.use('/api/variantTypes', variantTypesRouter);
// app.use('/api/variants', variantRoutes);
// app.use('/api', uploadRouter);
// app.use('/api/posters', postersRoute);
// app.use('/api/admin', adminAuthRoutes);
// app.use("/api/admin/orders", adminOrders);
// app.use('/api/coupons', require('./routes/coupons'));



// // DEFAULT
// app.get("/", (req, res) => {
//   res.send("Admin Backend Running 🚀");
// });

// app.listen(PORT, () => {
//   console.log(`🚀 Admin Server running at http://localhost:${PORT}`);
// });