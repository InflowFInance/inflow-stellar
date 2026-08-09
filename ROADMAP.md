# Protocol Roadmap — inFlow for Stellar

---

## 🎯 Phase 1: Core Protocol & Infrastructure (Current)
- [x] Soroban smart contract implementation (`contracts/inflow`)
- [x] Touch-on-read storage TTL management strategy
- [x] TypeScript SDK (`@inflow/sdk`)
- [x] Cloudflare Worker relay for email OTP & `fee_bump` gasless UX
- [x] Flutter Web adaptation with `StellarBridge.js` interop
- [x] Flutter Mobile app (iOS & Android) with biometric authentication
- [x] Automated CI validation pipeline

## 🚀 Phase 2: Ecosystem Integration & Mainnet (Near-Term)
- [ ] Deployed and verified on Stellar Mainnet
- [ ] Blend Protocol integration (yield generation on locked stream deposits)
- [ ] SEP-30 Social Recovery integration for email-derived keypairs
- [ ] On-chain event indexer (REST API for querying historical streams)
- [ ] Multi-token stream support (XLM, ARST, EURC in addition to USDC)

## 🌐 Phase 3: Scaling & Enterprise Features (Long-Term)
- [ ] Enterprise Employer Dashboard (bulk stream creation, CSV payroll import)
- [ ] Cross-chain bridge interface (Stellar ↔ Base)
- [ ] Stream pause/resume contract capability
- [ ] Native mobile app distribution on Apple App Store & Google Play Store
- [ ] Protocol governance mechanism for fee parameters
