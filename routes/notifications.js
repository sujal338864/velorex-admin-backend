const express = require("express");
const router = express.Router();
const db = require("../models/db_postgres");

/* ==========================================================
   CREATE Notification
========================================================== */
router.post("/", async (req, res) => {
  try {
    const { title, message, imageUrl } = req.body;

    if (!title || !message) {
      return res.status(400).json({
        error: "Title and message are required",
      });
    }

    await db.query(
      `INSERT INTO notifications (title, description, imageurl, senddate, isactive, createdat)
       VALUES ($1, $2, $3, NOW(), TRUE, NOW())`,
      [title, message, imageUrl || ""]
    );

    res.status(201).json({
      message: "Notification created successfully",
    });
  } catch (err) {
    console.error("❌ Error creating notification:", err);
    res.status(500).json({ error: err.message });
  }
});

/* ==========================================================
   GET All Active Notifications
========================================================== */
router.get("/", async (_, res) => {
  try {
    const result = await db.query(
      `SELECT notificationid, title, description, imageurl, createdat
       FROM notifications
       WHERE isactive = TRUE
       ORDER BY createdat DESC`
    );

    res.json(result.rows);
  } catch (err) {
    console.error("❌ Error fetching notifications:", err);
    res.status(500).json({ error: err.message });
  }
});

/* ==========================================================
   DEACTIVATE Notification
========================================================== */
router.delete("/:id", async (req, res) => {
  try {
    await db.query(
      `UPDATE notifications SET isactive = FALSE WHERE notificationid = $1`,
      [req.params.id]
    );

    res.json({ message: "Notification deactivated successfully" });
  } catch (err) {
    console.error("❌ Error deactivating notification:", err);
    res.status(500).json({ error: err.message });
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
