# Testnet Usage Guide

## Contract Information

| Field | Value |
|---|---|
| Network | Stellar Testnet |
| Contract ID | `CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2` |
| Deployer | `GBFYGDEXSLR23E2R5DHFEMDKWVC5HDCQVD44J4TPREGMMCJ7VNDWY6TG` |
| Explorer | [View on Stellar Expert](https://stellar.expert/explorer/testnet/contract/CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2) |

## Getting Testnet USDC

The USDC SAC on Stellar Testnet is:
`CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA`

You can get testnet XLM from [Friendbot](https://friendbot.stellar.org).

## Testing a Stream via Web App

1. Open https://inflowfinance.web.app
2. Switch to Stellar Testnet using the network pill
3. Sign in with any email address
4. Navigate to the Pay tab
5. Enter recipient email, deposit amount (USDC), and stream duration
6. Confirm — your salary stream begins ticking per-second immediately!

## Direct Contract Interaction via Stellar CLI

```bash
stellar contract invoke \
  --id CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2 \
  --network testnet \
  --source inflow-deployer \
  -- get_next_stream_id
```
