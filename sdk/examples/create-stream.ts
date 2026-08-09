/**
 * Example: Create a salary stream using @inflow/sdk
 */
import { InFlowClient } from '../src/client';
import { Networks } from '../src/network';

async function main() {
  const client = new InFlowClient({
    network: Networks.TESTNET,
    workerUrl: 'https://inflow-relay.inflowfinance.workers.dev',
  });

  // Create a 30-day stream of 500 USDC
  const streamId = await client.createStream({
    recipientEmail: 'employee@example.com',
    depositAmount: '500',
    durationDays: 30,
  });

  console.log(`Stream created! ID: ${streamId}`);
  console.log(`Share this link: https://inflowfinance.web.app?stream=${streamId}`);
}

main().catch(console.error);
