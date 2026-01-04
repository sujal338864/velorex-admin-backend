const express = require("express");
const router = express.Router();
const pool = require("../models/db");

/**
 * Helper to safely parse integer query params
 */
function toInt(v, defVal) {
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? defVal : n;
}

/* =========================================================
   GET /api/dashboard/basic-counts
   ========================================================= */
router.get("/", async (_, res) => {
  try {
    const products = await pool.query("SELECT COUNT(*) FROM products");
    const categories = await pool.query("SELECT COUNT(*) FROM categories");
    const subcategories = await pool.query("SELECT COUNT(*) FROM subcategories");

    res.json({
      products: Number(products.rows[0].count),
      categories: Number(categories.rows[0].count),
      subcategories: Number(subcategories.rows[0].count),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   DELETE PRODUCT
   ========================================================= */
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      "DELETE FROM products WHERE product_id = $1 RETURNING product_id",
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
router.get("/category-summary", async (req, res) => {
  try {
    const q = await pool.query(`
      SELECT
        c.category_id,
        c.name AS category_name,
        COUNT(p.product_id) AS product_count
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.category_id
      GROUP BY c.category_id, c.name
      ORDER BY product_count DESC;
    `);

    res.json(
      q.rows.map(r => ({
        categoryId: r.category_id,
        categoryName: r.category_name,
        productCount: Number(r.product_count),
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
router.get("/subcategory-summary", async (req, res) => {
  try {
    const q = await pool.query(`
      SELECT
        s.subcategory_id,
        s.name AS subcategory_name,
        c.name AS category_name,
        COUNT(p.product_id) AS product_count
      FROM subcategories s
      JOIN categories c ON s.category_id = c.category_id
      LEFT JOIN products p ON p.subcategory_id = s.subcategory_id
      GROUP BY s.subcategory_id, s.name, c.name
      ORDER BY product_count DESC;
    `);

    res.json(
      q.rows.map(r => ({
        subcategoryId: r.subcategory_id,
        subcategoryName: r.subcategory_name,
        categoryName: r.category_name,
        productCount: Number(r.product_count),
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   GET /api/dashboard/summary
   ========================================================= */
router.get("/summary", async (req, res) => {
  try {
    const productQ = await pool.query(`
      SELECT
        COUNT(*) AS total_products,
        SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) AS out_of_stock,
        SUM(CASE WHEN stock > 0 AND stock <= 5 THEN 1 ELSE 0 END) AS low_stock,
        SUM(CASE WHEN stock > 5 THEN 1 ELSE 0 END) AS in_stock
      FROM products;
    `);

    const orderQ = await pool.query(`
      SELECT
        COUNT(*) AS total_orders,
        SUM(CASE WHEN order_status = 'Pending' THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN order_status = 'Processed' THEN 1 ELSE 0 END) AS processed,
        SUM(CASE WHEN order_status = 'Shipped' THEN 1 ELSE 0 END) AS shipped,
        SUM(CASE WHEN order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered,
        SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
        SUM(
          CASE WHEN order_status IN ('Shipped','Delivered','Processed')
          THEN total_amount ELSE 0 END
        ) AS total_revenue
      FROM orders;
    `);

    const p = productQ.rows[0];
    const o = orderQ.rows[0];

    res.json({
      products: {
        total: Number(p.total_products),
        outOfStock: Number(p.out_of_stock),
        lowStock: Number(p.low_stock),
        inStock: Number(p.in_stock),
      },
      orders: {
        total: Number(o.total_orders),
        pending: Number(o.pending),
        processed: Number(o.processed),
        shipped: Number(o.shipped),
        delivered: Number(o.delivered),
        cancelled: Number(o.cancelled),
        totalRevenue: Number(o.total_revenue || 0),
      },
    });
  } catch (err) {
    console.error("❌ dashboard summary error:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =========================================================
   GET /api/dashboard/orders-by-day?days=7
   ========================================================= */
router.get("/orders-by-day", async (req, res) => {
  try {
    const days = toInt(req.query.days, 7);

    const q = await pool.query(
      `
      SELECT
        DATE(created_at) AS order_date,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_amount
      FROM orders
      WHERE created_at >= CURRENT_DATE - $1::int
      GROUP BY DATE(created_at)
      ORDER BY order_date;
      `,
      [days]
    );

    const data = q.rows.map(r => ({
      date: r.order_date,
      count: Number(r.order_count),
      amount: Number(r.total_amount || 0),
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
router.get("/stock-distribution", async (_, res) => {
  try {
    const q = await pool.query(`
      SELECT
        SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) AS out_of_stock,
        SUM(CASE WHEN stock BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS low_stock,
        SUM(CASE WHEN stock BETWEEN 6 AND 20 THEN 1 ELSE 0 END) AS medium_stock,
        SUM(CASE WHEN stock > 20 THEN 1 ELSE 0 END) AS high_stock
      FROM products;
    `);

    const r = q.rows[0];

    res.json({
      outOfStock: Number(r.out_of_stock),
      lowStock: Number(r.low_stock),
      mediumStock: Number(r.medium_stock),
      highStock: Number(r.high_stock),
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

    const q = await pool.query(
      `
      SELECT
        p.product_id,
        p.name,
        SUM(oi.quantity) AS total_qty,
        SUM(oi.price * oi.quantity) AS total_sales
      FROM order_items oi
      JOIN products p ON oi.product_id = p.product_id
      GROUP BY p.product_id, p.name
      ORDER BY total_qty DESC
      LIMIT $1;
      `,
      [limit]
    );

    res.json(
      q.rows.map(r => ({
        productId: r.product_id,
        name: r.name,
        totalQty: Number(r.total_qty),
        totalSales: Number(r.total_sales || 0),
      }))
    );
  } catch (err) {
    console.error("❌ top-products error:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;



// const express = require('express');
// const router = express.Router();
// const { poolPromise } = require('../db');

// router.get('/', async (_, res) => {
//   try {
//     const pool = await poolPromise;
//     const products = await pool.request().query('SELECT COUNT(*) AS count FROM Products');
//     const categories = await pool.request().query('SELECT COUNT(*) AS count FROM Categories');
//     const subcategories = await pool.request().query('SELECT COUNT(*) AS count FROM Subcategories');

//     res.json({
//       products: products.recordset[0].count,
//       categories: categories.recordset[0].count,
//       subcategories: subcategories.recordset[0].count
//     });
//   } catch (err) {
//     res.status(500).send(err.message);
//   }
// });

// router.delete('/:id', async (req, res) => {
//   try {
//     const { id } = req.params;
//     const pool = await poolPromise;

//     const result = await pool.request()
//       .input('ProductID', sql.Int, id) // ✅ Explicit type
//       .query('DELETE FROM Products WHERE ProductID = @ProductID');

//     if (result.rowsAffected[0] > 0) {
//       res.json({ message: `Product ${id} deleted successfully` });
//     } else {
//       res.status(404).json({ error: 'Product not found' });
//     }
//   } catch (err) {
//     res.status(500).send(err.message);
//   }
// });

// /**
//  * Helper to safely parse integer query params
//  */
// function toInt(v, defVal) {
//   const n = parseInt(v, 10);
//   return Number.isNaN(n) ? defVal : n;
// }

// /* =========================================================
//    GET /api/dashboard/summary
//    - product counts
//    - order counts by status
//    - total revenue
//    ========================================================= */
// router.get("/summary", async (req, res) => {
//   try {
//     const pool = await poolPromise;

//     // ---------- PRODUCT STATS ----------
//     const productQ = await pool.request().query(`
//       SELECT
//         COUNT(*) AS totalProducts,
//         SUM(CASE WHEN Stock <= 0 THEN 1 ELSE 0 END) AS outOfStockProducts,
//         SUM(CASE WHEN Stock > 0 AND Stock <= 5 THEN 1 ELSE 0 END) AS lowStockProducts,
//         SUM(CASE WHEN Stock > 5 THEN 1 ELSE 0 END) AS inStockProducts
//       FROM Products;
//     `);

//     const p = productQ.recordset[0] || {};

//     // ---------- ORDER STATS ----------
//     // adjust status strings if your Orders.Status is different
//     const orderQ = await pool.request().query(`
//       SELECT
//         COUNT(*) AS totalOrders,
//         SUM(CASE WHEN Status = 'Pending'   THEN 1 ELSE 0 END) AS pendingOrders,
//         SUM(CASE WHEN Status = 'Processed' THEN 1 ELSE 0 END) AS processedOrders,
//         SUM(CASE WHEN Status = 'Shipped'   THEN 1 ELSE 0 END) AS shippedOrders,
//         SUM(CASE WHEN Status = 'Delivered' THEN 1 ELSE 0 END) AS deliveredOrders,
//         SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelledOrders,
//         SUM(CASE WHEN Status IN ('Shipped','Delivered','Processed')
//                  THEN TotalAmount ELSE 0 END) AS totalRevenue
//       FROM Orders;
//     `);

//     const o = orderQ.recordset[0] || {};

//     res.json({
//       products: {
//         total: p.totalProducts || 0,
//         outOfStock: p.outOfStockProducts || 0,
//         lowStock: p.lowStockProducts || 0,
//         inStock: p.inStockProducts || 0,
//       },
//       orders: {
//         total: o.totalOrders || 0,
//         pending: o.pendingOrders || 0,
//         processed: o.processedOrders || 0,
//         shipped: o.shippedOrders || 0,
//         delivered: o.deliveredOrders || 0,
//         cancelled: o.cancelledOrders || 0,
//         totalRevenue: Number(o.totalRevenue || 0),
//       },
//     });
//   } catch (err) {
//     console.error("❌ dashboard /summary error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* =========================================================
//    GET /api/dashboard/orders-by-day?days=7
//    - line chart data
//    ========================================================= */
// router.get("/orders-by-day", async (req, res) => {
//   try {
//     const days = toInt(req.query.days, 7); // default last 7 days
//     const pool = await poolPromise;

//     const q = await pool.request()
//       .input("days", sql.Int, days)
//       .query(`
//         SELECT
//           CONVERT(date, CreatedAt) AS OrderDate,
//           COUNT(*) AS OrderCount,
//           SUM(TotalAmount) AS TotalAmount
//         FROM Orders
//         WHERE CreatedAt >= DATEADD(day, -@days, CAST(GETDATE() AS date))
//         GROUP BY CONVERT(date, CreatedAt)
//         ORDER BY OrderDate;
//       `);

//     // map to simple array for Flutter
//     const data = q.recordset.map(row => ({
//       date: row.OrderDate,
//       count: row.OrderCount,
//       amount: Number(row.TotalAmount || 0),
//     }));

//     res.json(data);
//   } catch (err) {
//     console.error("❌ dashboard /orders-by-day error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* =========================================================
//    GET /api/dashboard/stock-distribution
//    - pie chart for stock buckets
//    ========================================================= */
// router.get("/stock-distribution", async (req, res) => {
//   try {
//     const pool = await poolPromise;

//     const q = await pool.request().query(`
//       SELECT
//         SUM(CASE WHEN Stock <= 0 THEN 1 ELSE 0 END) AS outOfStock,
//         SUM(CASE WHEN Stock BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS lowStock,
//         SUM(CASE WHEN Stock BETWEEN 6 AND 20 THEN 1 ELSE 0 END) AS mediumStock,
//         SUM(CASE WHEN Stock > 20 THEN 1 ELSE 0 END) AS highStock
//       FROM Products;
//     `);

//     const r = q.recordset[0] || {};

//     res.json({
//       outOfStock: r.outOfStock || 0,
//       lowStock: r.lowStock || 0,
//       mediumStock: r.mediumStock || 0,
//       highStock: r.highStock || 0,
//     });
//   } catch (err) {
//     console.error("❌ dashboard /stock-distribution error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* =========================================================
//    GET /api/dashboard/top-products?limit=5
//    - best selling products (for table / side widget)
//    ========================================================= */
// router.get("/top-products", async (req, res) => {
//   try {
//     const limit = toInt(req.query.limit, 5);
//     const pool = await poolPromise;

//     // ⚠️ adjust OrderItems table + column names if different
//     const q = await pool.request()
//       .input("limit", sql.Int, limit)
//       .query(`
//         SELECT TOP (@limit)
//           p.ProductID,
//           p.Name,
//           SUM(oi.Quantity) AS TotalQty,
//           SUM(oi.LineTotal) AS TotalSales
//         FROM OrderItems oi
//         INNER JOIN Products p ON oi.ProductID = p.ProductID
//         GROUP BY p.ProductID, p.Name
//         ORDER BY TotalQty DESC;
//       `);

//     const data = q.recordset.map(row => ({
//       productId: row.ProductID,
//       name: row.Name,
//       totalQty: row.TotalQty,
//       totalSales: Number(row.TotalSales || 0),
//     }));

//     res.json(data);
//   } catch (err) {
//     console.error("❌ dashboard /top-products error:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;

