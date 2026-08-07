# ForgeFit account and database foundation

This folder contains the first production data model for ForgeFit. It is designed for Supabase (PostgreSQL + Auth) and establishes the security boundary before real accounts are connected to the public site.

## Included

- Client, professional, and admin account roles
- Shared public profile data
- Private client preferences
- Professional categories, specialties, services, and credentials
- Professional publishing and verification states
- Free-beta memberships and future paid-plan metadata
- Plan-based feature entitlements
- Stripe customer, subscription, price, and billing-period references
- Private early-access contact storage
- Automatic profile creation after authentication signup
- Row-level security policies that keep client data private

## Activation sequence

1. Create or connect a Supabase project.
2. Run `schema.sql` in the project SQL editor.
3. Configure the public site URL and approved redirect URLs in Supabase Auth.
4. Add the Supabase project URL and publishable/anonymous key to the frontend configuration.
5. Build and test signup, email verification, login, logout, password reset, and role redirects.
6. Connect professional onboarding to `profiles`, `professional_profiles`, `certifications`, `professional_specialties`, and `services`.
7. Connect client onboarding to `profiles` and `client_profiles`.
8. Replace the early-access browser-only demonstration with inserts into `early_access_signups`.
9. Keep new memberships in `free_beta` until billing is intentionally launched.
10. When billing launches, create Stripe products/prices and store their identifiers in `membership_plans`.
11. Use a verified Stripe webhook to synchronize `memberships`; never update paid access directly from browser requests.

## Security notes

- Never expose the Supabase service-role key in browser code or Vercel public environment variables.
- The browser may use only the public publishable/anonymous key; row-level security remains mandatory.
- `early_access_signups` intentionally has no client-facing read policy.
- Certification documents should be stored in a private bucket and accessed with short-lived signed URLs.
- Admin privileges should be assigned server-side, never from signup metadata.
- Membership records have no browser write policy. Only trusted server code or verified billing webhooks may change access.
- Stripe secret keys and webhook signing secrets belong only in server-side secret storage.
- Prices are stored as integer cents, while Stripe price IDs remain empty until billing is activated.
- Health data, precise progress measurements, payments, and messaging require separate migrations and privacy review before implementation.

## Initial membership strategy

- Professional plan target price: $10/month (`1000` cents)
- Client plan target price: $5/month (`500` cents)
- All initial accounts receive `free_beta` status and `free_beta` access source.
- Early users can later be marked `grandfathered`, `complimentary`, or `promotional` without changing account roles.
- Billing status and feature access are separate concepts, allowing pricing and plan contents to evolve independently.
- Professionals accepting payments from clients is a separate marketplace-payments project and is not covered by these membership tables.

## Required project decisions

- Whether email confirmation is mandatory before onboarding
- Whether professional profiles require manual approval before publication
- Which certification types require verification
- Data-retention and account-deletion periods
- Initial launch geography and supported professional categories
