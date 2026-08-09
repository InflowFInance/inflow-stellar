export interface Stream {
  id: bigint;
  sender: string;
  recipient: string | null;
  token: string;
  deposit: bigint;
  ratePerSecond: bigint;
  startTime: bigint;
  stopTime: bigint;
  withdrawnAmount: bigint;
  remainingBalance: bigint;
  claimHash: string | null;
}

export interface CreateStreamParams {
  sender: string;
  recipient?: string;
  claimHash?: string;
  tokenAddress: string;
  depositAmount: bigint;
  startTime: bigint;
  stopTime: bigint;
}

export interface InFlowClientConfig {
  network: "testnet" | "mainnet";
  contractId: string;
  rpcUrl?: string;
  keypair?: {
    publicKey: string;
    secretKey: string;
  };
  workerUrl?: string;
}

export interface TransactionResult {
  txHash: string;
  success: boolean;
}

export interface StreamCreateResult extends TransactionResult {
  streamId: bigint;
}
