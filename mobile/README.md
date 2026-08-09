# inFlow Mobile

Flutter mobile application for inFlow × Stellar.

## Features

- Email OTP authentication (no wallet required)
- Live per-second earnings ticker
- QR code stream link sharing
- Biometric authentication for subsequent logins
- One-tap withdrawal via fee_bump relay

## Getting Started

```bash
flutter pub get
flutter run
```

## Architecture

The mobile app communicates exclusively with the Cloudflare Worker relay.
It never constructs Stellar transactions directly — all signing and fee_bump
wrapping is handled server-side.
