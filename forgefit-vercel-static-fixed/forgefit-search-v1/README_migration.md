
# ForgeFit Trainer Search — Option 1 → Option 3

This is a static search (Option 1) that can later plug into a real database and Next.js (Option 3).

## Files
- `/trainers.html` — search UI
- `/data/trainers.json` — seed data (mirror this shape in your DB later)
- `/js/search.js` — client-side filter (replace fetch with `/api/trainers` later)
- `/assets/forgefit-logo.png` — logo (optional)

## Migrate later (quick outline)
1) Create a Supabase project; make a `trainers` table that mirrors trainers.json fields.
2) Build an endpoint `/api/trainers` in Next.js that queries by city/state, rate, in_home, etc.
3) Replace `fetch('/data/trainers.json')` with `fetch('/api/trainers?...')` in `search.js`.
4) Add auth (Clerk or NextAuth) so trainers can manage profiles.
5) Add Stripe for payments and booking logic.
