# ForgeFit production readiness checklist

## Automated checks

- [x] Public-page load test reaches 50 concurrent visitors
- [x] Error rate threshold is below 1%
- [x] Response-time thresholds are enforced
- [x] High-traffic database indexes are installed
- [x] Supabase security audit returns only OK results
- [ ] Authenticated dashboard load test is completed on staging

## Supabase dashboard settings

- [ ] Security Advisor has no unresolved critical findings
- [ ] Performance Advisor findings are reviewed
- [ ] Row Level Security is enabled on every application table
- [ ] Custom SMTP is configured before a public signup campaign
- [ ] CAPTCHA is enabled for signup, sign-in, and password recovery
- [ ] Production URL and auth recovery redirect URLs are allow-listed
- [ ] Database backup retention is confirmed
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
