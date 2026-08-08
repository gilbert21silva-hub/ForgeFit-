window.FORGEFIT_SUPABASE = Object.freeze({
  url: "https://xieykfpzwikgrerobkta.supabase.co",
  publishableKey: "sb_publishable_3bJH7WTQGRZKYGnhnpT5VQ_4f1poLFV"
});

window.forgefitSupabase = window.supabase.createClient(
  window.FORGEFIT_SUPABASE.url,
  window.FORGEFIT_SUPABASE.publishableKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  }
);
