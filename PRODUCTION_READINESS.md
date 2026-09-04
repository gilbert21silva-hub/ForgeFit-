# ForgeFit production readiness checklist

## Automated checks

- [x] Public-page load test reaches 50 concurrent visitors
- [x] Error rate threshold is below 1%
- [x] Response-time thresholds are enforced
- [x] High-traffic database indexes are installed
- [x] Supabase security audit returns only OK results
- [x] Anonymous SECURITY DEFINER execution is removed
- [x] Trigger functions cannot be called directly
- [ ] Authenticated dashboard load test is completed on staging

## Supabase dashboard settings

- [ ] Security Advisor has no unresolved critical findings
- [x] Query Performance reviewed: 99.95% cache hit rate; no slow ForgeFit application query identified
- [x] Supabase API monitoring is available and currently shows no response-error data
- [ ] Row Level Security is enabled on every application table
- [ ] Configure custom SMTP before a public signup campaign (currently using limited Supabase default email)
- [ ] CAPTCHA is enabled for signup, sign-in, and password recovery
- [ ] Leaked-password protection is enabled after upgrading Supabase to Pro (not available on Free)
- [x] Production URL and auth recovery redirect URLs are allow-listed
- [ ] Upgrade Supabase to Pro before real-user launch; Free currently has no project backups
- [ ] Confirm at least 7 days of daily backup retention after upgrade
- [ ] Point-in-Time Recovery is enabled before storing critical paid-member data
- [ ] Storage usage and maximum upload sizes are monitored

## Vercel settings

- [ ] Production deployment is connected to `main`
- [ ] Deployment protection and account 2FA are enabled
- [ ] Observability is reviewed after each launch
- [ ] A known-good deployment rollback is identified
- [ ] Custom domain and HTTPS checks pass

## Launch process

- [ ] Start with a small invite-only beta
- [ ] Test client, professional, and dual-mode accounts
- [ ] Test signup, confirmation, reset password, and sign-out
- [ ] Test RLS with two unrelated accounts
- [ ] Confirm support and incident contact information
- [ ] Review metrics daily during the first launch week
