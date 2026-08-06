# ForgeFit account and database foundation

This folder contains the first production data model for ForgeFit. It is designed for Supabase (PostgreSQL + Auth) and establishes the security boundary before real accounts are connected to the public site.

## Included

- Client, professional, and admin account roles
- Shared public profile data
- Private client preferences
- Professional categories, specialties, services, and credentials
- Professional publishing and verification states
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

## Security notes

- Never expose the Supabase service-role key in browser code or Vercel public environment variables.
- The browser may use only the public publishable/anonymous key; row-level security remains mandatory.
- `early_access_signups` intentionally has no client-facing read policy.
- Certification documents should be stored in a private bucket and accessed with short-lived signed URLs.
- Admin privileges should be assigned server-side, never from signup metadata.
- Health data, precise progress measurements, payments, and messaging require separate migrations and privacy review before implementation.

## Required project decisions

- Whether email confirmation is mandatory before onboarding
- Whether professional profiles require manual approval before publication
- Which certification types require verification
- Data-retention and account-deletion periods
- Initial launch geography and supported professional categories
