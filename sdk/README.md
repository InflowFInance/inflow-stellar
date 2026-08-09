# `@inflow/sdk`

TypeScript SDK for integrating **inFlow payment streaming** on the Stellar network.

---

## 📦 Installation

```bash
npm install @inflow/sdk @stellar/stellar-sdk
```

---

## 🚀 Quick Usage

```typescript
import { InFlowClient, NETWORKS } from "@inflow/sdk";

const client = new InFlowClient({
  network: "testnet",
  contractId: "C...",
  workerUrl: "https://inflow-relay.your-domain.workers.dev"
});

// Calculate current withdrawable balance for a stream
const available = await client.availableToWithdraw(1n);
console.log(`Available: ${available} stroops`);
```

---

## 📄 License

Apache-2.0
