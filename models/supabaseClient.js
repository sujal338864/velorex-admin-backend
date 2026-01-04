require("dotenv").config();
const { createClient } = require("@supabase/supabase-js");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// ✅ HARD ASSERT (VERY IMPORTANT)
if (!supabase?.storage) {
  console.error("❌ Supabase storage NOT initialized");
  process.exit(1);
}

console.log("✅ Supabase client ready");
console.log("✅ Storage exists:", !!supabase.storage);

module.exports = supabase; // ⚠️ NOT { supabase }


// require("dotenv").config();
// const { createClient } = require("@supabase/supabase-js");

// console.log("ENV CHECK:");
// console.log(" SUPABASE_URL:", process.env.SUPABASE_URL ? "YES" : "NO");
// console.log(
//   " SUPABASE_SERVICE_ROLE_KEY:",
//   process.env.SUPABASE_SERVICE_ROLE_KEY ? "YES" : "NO"
// );

// const supabase = createClient(
//   process.env.SUPABASE_URL,
//   process.env.SUPABASE_SERVICE_ROLE_KEY
// );

// console.log("CLIENT CHECK:");
// console.log(" supabase exists:", !!supabase);
// console.log(" storage exists:", !!supabase?.storage);

// module.exports = supabase;



// require("dotenv").config();
// const { createClient } = require("@supabase/supabase-js");

// const supabase = createClient(
//   process.env.SUPABASE_URL,
//   process.env.SUPABASE_SERVICE_ROLE_KEY
// );

// module.exports = supabase;


