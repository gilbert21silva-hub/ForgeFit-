# ForgeFit load testing

This smoke test simulates visitors moving through the public ForgeFit pages without creating accounts or changing production data.

## Run

Install [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/) and run:

```bash
FORGEFIT_BASE_URL=https://your-preview-url.vercel.app k6 run tests/load/forgefit-smoke.js
```

The test gradually reaches 50 simultaneous visitors. It fails if more than 1% of requests fail, if the 95th percentile exceeds 2 seconds, or if the 99th percentile exceeds 4 seconds.

Run against a Vercel preview first. Do not run destructive or signup tests against the production database.
