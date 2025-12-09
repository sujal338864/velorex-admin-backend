require("dotenv").config();
const { createClient } = require("@supabase/supabase-js");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

module.exports = supabase;



// // models/supabaseClient.js
// const { createClient } = require("@supabase/supabase-js");

// const SUPABASE_URL = "https://zyryndjeojrzvoubsqsg.supabase.co"; // your project URL
// const SUPABASE_KEY = "YOUR_SERVICE_ROLE_KEY"; // ⚠️ from Supabase → Project → Settings → API

// const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// module.exports = supabase;
