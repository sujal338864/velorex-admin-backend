const express = require("express");
const router = express.Router();
const pool = require("../models/db");

/* ===============================
   CREATE
   =============================== */
router.post("/", async (req, res) => {
  try {
    const { title, message, image_url, imageurl } = req.body;
    const finalImage = image_url || imageurl || null;

    if (!title || !message)
      return res.status(400).json({ error: "Required fields missing" });

    await pool.query(
      `
      INSERT INTO notifications
      (title, description, image_url, send_date, is_active, created_at)
      VALUES ($1, $2, $3, NOW(), true, NOW())
      `,
      [title, message, finalImage]
    );
   console.log("🔥 LIVE NOTIFICATION ROUTE EXECUTING");
console.log("🔥 BODY =", req.body);

    console.log("🔥 POST /notifications BODY:", req.body);
    res.status(201).json({ success: true });

  } catch (e) {
    console.error("❌ CREATE:", e);
    res.status(500).json({ error: e.message });
  }
});


/* ===============================
   UPDATE
   =============================== */
router.put("/:id", async (req, res) => {
  try {
    const { title, message, image_url, imageurl } = req.body;
    const finalImage = image_url || imageurl || null;

    await pool.query(
      `
      UPDATE notifications
      SET title=$1, description=$2, image_url=$3, updated_at=NOW()
      WHERE notification_id=$4
      `,
      [title, message, finalImage, req.params.id]
    );

    res.json({ success: true });

  } catch (e) {
    console.error("❌ UPDATE:", e);
    res.status(500).json({ error: e.message });
  }
});


/* ===============================
   GET
   =============================== */
router.get("/", async (_, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        notification_id,
        title,
        description,
        image_url,
        send_date,
        is_active,
        created_at
      FROM notifications
      WHERE is_active=true
      ORDER BY notification_id DESC
    `);

    res.json(rows);
  } catch (e) {
    console.error("❌ FETCH:", e);
    res.status(500).json({ error: "Fetch failed" });
  }
});

/* ===============================
   DELETE (soft)
   =============================== */
router.delete("/:id", async (req, res) => {
  try {
    await pool.query(
      `UPDATE notifications SET is_active=false WHERE notification_id=$1`,
      [req.params.id]
    );

    res.json({ success: true });
  } catch (e) {
    console.error("❌ DELETE:", e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;



// // routes/notifications.js
// const express = require("express");
// const router = express.Router();
// const { sql, poolPromise } = require("../models/db");

// // ✅ CREATE Notification
// router.post("/", async (req, res) => {
//   try {
//     const { title, message, imageUrl } = req.body;
//     if (!title || !message) {
//       return res.status(400).json({ error: "Title and message are required" });
//     }

//     const pool = await poolPromise;
//     const request = pool.request();
//     request.input("Title", sql.NVarChar, title);
//     request.input("Description", sql.NVarChar, message);
//     request.input("ImageUrl", sql.NVarChar, imageUrl || "");
//     request.input("SendDate", sql.DateTime, new Date());
//     request.input("IsActive", sql.Bit, true);
//     request.input("CreatedAt", sql.DateTime, new Date());

//     await request.query(`
//       INSERT INTO Notifications (Title, Description, ImageUrl, SendDate, IsActive, CreatedAt)
//       VALUES (@Title, @Description, @ImageUrl, @SendDate, @IsActive, @CreatedAt)
//     `);

//     res.status(201).json({ message: "✅ Notification created successfully" });
//   } catch (err) {
//     console.error("❌ Error creating notification:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// // ✅ GET all active notifications
// router.get("/", async (req, res) => {
//   try {
//     const pool = await poolPromise;
//     const result = await pool.request().query(`
//       SELECT NotificationID, Title, Description, ImageUrl,
//              FORMAT(CreatedAt, 'yyyy-MM-dd HH:mm:ss') AS CreatedAt
//       FROM Notifications
//       WHERE IsActive = 1
//       ORDER BY CreatedAt DESC
//     `);
//     res.json(result.recordset);
//   } catch (err) {
//     console.error("❌ Error fetching notifications:", err);
//     res.status(500).json({ error: err.message });
//   }
// });


// // ==========================================================
// // ✅ DELETE (Deactivate Notification)
// // ==========================================================
// router.delete("/:id", async (req, res) => {
//   try {
//     const { id } = req.params;
//     const pool = await poolPromise;
//     const request = pool.request();

//     request.input("NotificationID", sql.Int, id);
//     await request.query(`
//       UPDATE Notifications 
//       SET IsActive = 0 
//       WHERE NotificationID = @NotificationID
//     `);

//     res.json({ message: "🗑 Notification deactivated successfully" });
//   } catch (err) {
//     console.error("❌ Error deleting notification:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;



// const express = require("express");
// const router = express.Router();
// const db = require("../models/db_postgres");

// /* ==========================================================
//    CREATE Notification
// ========================================================== */
// router.post("/", async (req, res) => {
//   try {
//     const { title, message, imageUrl } = req.body;

//     if (!title || !message) {
//       return res.status(400).json({
//         error: "Title and message are required",
//       });
//     }

//     await db.query(
//       `INSERT INTO notifications (title, description, imageurl, senddate, isactive, createdat)
//        VALUES ($1, $2, $3, NOW(), TRUE, NOW())`,
//       [title, message, imageUrl || ""]
//     );

//     res.status(201).json({
//       message: "Notification created successfully",
//     });
//   } catch (err) {
//     console.error("❌ Error creating notification:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ==========================================================
//    GET All Active Notifications
// ========================================================== */
// router.get("/", async (_, res) => {
//   try {
//     const result = await db.query(
//       `SELECT notificationid, title, description, imageurl, createdat
//        FROM notifications
//        WHERE isactive = TRUE
//        ORDER BY createdat DESC`
//     );

//     res.json(result.rows);
//   } catch (err) {
//     console.error("❌ Error fetching notifications:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// /* ==========================================================
//    DEACTIVATE Notification
// ========================================================== */
// router.delete("/:id", async (req, res) => {
//   try {
//     await db.query(
//       `UPDATE notifications SET isactive = FALSE WHERE notificationid = $1`,
//       [req.params.id]
//     );

//     res.json({ message: "Notification deactivated successfully" });
//   } catch (err) {
//     console.error("❌ Error deactivating notification:", err);
//     res.status(500).json({ error: err.message });
//   }
// });

// module.exports = router;


