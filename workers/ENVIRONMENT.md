# Cloudflare Worker Environment Variables

Set these as Wrangler Secrets before deploying:

| Secret | Description |
|---|---|
| `MASTER_KEY` | 32-byte hex master key for HKDF keypair derivation. Generate with: `openssl rand -hex 32` |
| `OTP_SECRET` | 32-byte hex key for HMAC-SHA256 OTP generation |
| `RESEND_API_KEY` | Resend.com API key for sending OTP emails |
| `TREASURY_SECRET` | Ed25519 secret key for the treasury account (pays all fee_bump fees) |
| `CONTRACT_ID` | The deployed InFlow Soroban contract ID |

Set secrets via Wrangler:
```bash
wrangler secret put MASTER_KEY
wrangler secret put OTP_SECRET
# etc.
```

**⚠️ Never commit these values to git.** The `wrangler.toml` only defines the *names* of secrets, not their values.
