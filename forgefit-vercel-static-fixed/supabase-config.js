window.FORGEFIT_SUPABASE = Object.freeze({
  url: "https://xieykfpzwikgrerobkta.supabase.co",
  publishableKey: "sb_publishable_3bJH7WTQGRZKYGnhnpT5VQ_4f1poLFV"
});

const forgefitTabAuthKey = "forgefit-tab-auth";
const forgefitLegacyAuthKey = "sb-xieykfpzwikgrerobkta-auth-token";
if (!window.sessionStorage.getItem(forgefitTabAuthKey)) {
  const legacySession = window.localStorage.getItem(forgefitLegacyAuthKey);
  if (legacySession) {
    window.sessionStorage.setItem(forgefitTabAuthKey, legacySession);
    window.localStorage.removeItem(forgefitLegacyAuthKey);
  }
}

window.forgefitSupabase = window.supabase.createClient(
  window.FORGEFIT_SUPABASE.url,
  window.FORGEFIT_SUPABASE.publishableKey,
  {
    auth: {
      storage: window.sessionStorage,
      storageKey: "forgefit-tab-auth",
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  }
);
