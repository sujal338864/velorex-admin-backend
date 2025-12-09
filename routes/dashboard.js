// routes/dashboard.routes.js
const express = require("express");
const router = express.Router();
const pg = require("../models/db_postgres"); // PostgreSQL ONLY

function toInt(v, defVal) {
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? defVal : n;
}

/* =========================================================
   GET /api/dashboard
   Simple counts for products, categories, subcategories
========================================================= */
router.get("/", async (_, res) => {
  try {
    const q1 = await pg.query("SELECT COUNT(*) AS count FROM products");
    const q2 = await pg.query("SELECT COUNT(*) AS count FROM categories");
    const q3 = await pg.query("SELECT COUNT(*) AS count FROM subcategories");

    res.json({
      products: Number(q1.rows[0].count),
      categories: Number(q2.rows[0].count),
      subcategories: Number(q3.rows[0].count),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   DELETE product
========================================================= */
router.delete("/:id", async (req, res) => {
  try {
    const id = req.params.id;

    const result = await pg.query(
      "DELETE FROM products WHERE productid = $1",
      [id]
    );

    if (result.rowCount > 0) {
      res.json({ message: `Product ${id} deleted successfully` });
    } else {
      res.status(404).json({ error: "Product not found" });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   GET /api/dashboard/summary
========================================================= */
router.get("/summary", async (req, res) => {
  try {
    // ----- Product Inventory Stats -----
    const productQ = await pg.query(`
      SELECT
        COUNT(*) AS totalProducts,
        SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) AS outOfStockProducts,
        SUM(CASE WHEN stock > 0 AND stock <= 5 THEN 1 ELSE 0 END) AS lowStockProducts,
        SUM(CASE WHEN stock > 5 THEN 1 ELSE 0 END) AS inStockProducts
      FROM products;
    `);

    const p = productQ.rows[0];

    // ----- Order Stats -----
    const orderQ = await pg.query(`
      SELECT
        COUNT(*) AS totalOrders,
        SUM(CASE WHEN orderstatus = 'Pending' THEN 1 ELSE 0 END) AS pendingOrders,
        SUM(CASE WHEN orderstatus = 'Processed' THEN 1 ELSE 0 END) AS processedOrders,
        SUM(CASE WHEN orderstatus = 'Shipped' THEN 1 ELSE 0 END) AS shippedOrders,
        SUM(CASE WHEN orderstatus = 'Delivered' THEN 1 ELSE 0 END) AS deliveredOrders,
        SUM(CASE WHEN orderstatus = 'Cancelled' THEN 1 ELSE 0 END) AS cancelledOrders,
        SUM(CASE WHEN orderstatus IN ('Shipped','Delivered','Processed')
                 THEN totalamount ELSE 0 END) AS totalRevenue
      FROM orders;
    `);

    const o = orderQ.rows[0];

    res.json({
      products: {
        total: Number(p.totalproducts || 0),
        outOfStock: Number(p.outofstockproducts || 0),
        lowStock: Number(p.lowstockproducts || 0),
        inStock: Number(p.instockproducts || 0),
      },
      orders: {
        total: Number(o.totalorders || 0),
        pending: Number(o.pendingorders || 0),
        processed: Number(o.processedorders || 0),
        shipped: Number(o.shippedorders || 0),
        delivered: Number(o.deliveredorders || 0),
        cancelled: Number(o.cancelledorders || 0),
        totalRevenue: Number(o.totalrevenue || 0),
      },
    });
  } catch (err) {
    console.error("❌ summary error:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   GET /api/dashboard/orders-by-day?days=7
========================================================= */
router.get("/orders-by-day", async (req, res) => {
  try {
    const days = toInt(req.query.days, 7);

    const q = await pg.query(
      `
      SELECT
        CAST(createdat AS DATE) AS orderdate,
        COUNT(*) AS ordercount,
        SUM(totalamount) AS totalamount
      FROM orders
      WHERE createdat >= CURRENT_DATE - $1::INT
      GROUP BY CAST(createdat AS DATE)
      ORDER BY orderdate;
      `,
      [days]
    );

    const data = q.rows.map((r) => ({
      date: r.orderdate,
      count: Number(r.ordercount),
      amount: Number(r.totalamount || 0),
    }));

    res.json(data);
  } catch (err) {
    console.error("❌ orders-by-day error:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   GET /api/dashboard/stock-distribution
========================================================= */
router.get("/stock-distribution", async (req, res) => {
  try {
    const q = await pg.query(`
      SELECT
        SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) AS outOfStock,
        SUM(CASE WHEN stock BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS lowStock,
        SUM(CASE WHEN stock BETWEEN 6 AND 20 THEN 1 ELSE 0 END) AS mediumStock,
        SUM(CASE WHEN stock > 20 THEN 1 ELSE 0 END) AS highStock
      FROM products;
    `);

    const r = q.rows[0];

    res.json({
      outOfStock: Number(r.outofstock || 0),
      lowStock: Number(r.lowstock || 0),
      mediumStock: Number(r.mediumstock || 0),
      highStock: Number(r.highstock || 0),
    });
  } catch (err) {
    console.error("❌ stock-distribution error:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   GET /api/dashboard/top-products?limit=5
========================================================= */
router.get("/top-products", async (req, res) => {
  try {
    const limit = toInt(req.query.limit, 5);

    const q = await pg.query(
      `
      SELECT
        p.productid,
        p.name,
        SUM(oi.quantity) AS totalqty,
        SUM(oi.price * oi.quantity) AS totalsales
      FROM orderitems oi
      INNER JOIN products p ON oi.productid = p.productid
      GROUP BY p.productid, p.name
      ORDER BY totalqty DESC
      LIMIT $1;
      `,
      [limit]
    );

    const data = q.rows.map((row) => ({
      productId: row.productid,
      name: row.name,
      totalQty: Number(row.totalqty),
      totalSales: Number(row.totalsales || 0),
    }));

    res.json(data);
  } catch (err) {
    console.error("❌ top-products error:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
