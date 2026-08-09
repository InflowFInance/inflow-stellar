import {
  Contract,
  rpc as StellarRpc,
  TransactionBuilder,
  BASE_FEE,
  Keypair,
  nativeToScVal,
  scValToNative,
  xdr,
} from "@stellar/stellar-sdk";
import { NETWORKS, type Network } from "./network.js";
import type {
  Stream,
  CreateStreamParams,
  InFlowClientConfig,
  StreamCreateResult,
  TransactionResult,
} from "./types.js";

function hexToUint8Array(hexString: string): Uint8Array {
  const bytes = new Uint8Array(hexString.length / 2);
  for (let i = 0; i < hexString.length; i += 2) {
    bytes[i / 2] = parseInt(hexString.substring(i, i + 2), 16);
  }
  return bytes;
}

export class InFlowClient {
  private rpc: StellarRpc.Server;
  private contractId: string;
  private networkConfig: (typeof NETWORKS)[Network];
  private keypair?: Keypair;
  private workerUrl?: string;

  constructor(config: InFlowClientConfig) {
    this.networkConfig = NETWORKS[config.network];
    this.rpc = new StellarRpc.Server(
      config.rpcUrl ?? this.networkConfig.rpcUrl,
      { allowHttp: true }
    );
    this.contractId = config.contractId;
    this.workerUrl = config.workerUrl;

    if (config.keypair) {
      this.keypair = Keypair.fromSecret(config.keypair.secretKey);
    }
  }

  async createStream(params: CreateStreamParams): Promise<StreamCreateResult> {
    if (!params.recipient && !params.claimHash) {
      throw new Error("Must provide either recipient or claimHash");
    }
    if (params.recipient && params.claimHash) {
      throw new Error("Cannot provide both recipient and claimHash");
    }

    const args = [
      nativeToScVal(params.sender, { type: "address" }),
      params.recipient
        ? nativeToScVal(params.recipient, { type: "address" })
        : xdr.ScVal.scvVoid(),
      nativeToScVal(params.tokenAddress, { type: "address" }),
      nativeToScVal(params.depositAmount, { type: "i128" }),
      nativeToScVal(params.startTime, { type: "u64" }),
      nativeToScVal(params.stopTime, { type: "u64" }),
      params.claimHash
        ? nativeToScVal(hexToUint8Array(params.claimHash), { type: "bytes" })
        : xdr.ScVal.scvVoid(),
    ];

    const result = await this.invokeContract("create_stream", args, params.sender);
    const streamId = BigInt(scValToNative(result as unknown as xdr.ScVal));
    return { txHash: "", success: true, streamId };
  }

  async claimStream(streamId: bigint, secret: string): Promise<TransactionResult> {
    const args = [
      nativeToScVal(streamId, { type: "u64" }),
      nativeToScVal(new TextEncoder().encode(secret), { type: "bytes" }),
    ];
    const invoker = this.keypair?.publicKey() ?? "";
    return this.invokeContract("claim_stream", args, invoker);
  }

  async withdraw(
    streamId: bigint,
    amount: bigint,
    recipientAddress: string
  ): Promise<TransactionResult> {
    const args = [
      nativeToScVal(streamId, { type: "u64" }),
      nativeToScVal(amount, { type: "i128" }),
    ];
    return this.invokeContract("withdraw", args, recipientAddress);
  }

  async cancelStream(
    streamId: bigint,
    callerAddress: string
  ): Promise<TransactionResult> {
    const args = [nativeToScVal(streamId, { type: "u64" })];
    return this.invokeContract("cancel_stream", args, callerAddress);
  }

  async extendStreamTtl(streamId: bigint): Promise<TransactionResult> {
    const args = [nativeToScVal(streamId, { type: "u64" })];
    const invoker = this.keypair?.publicKey() ?? "";
    return this.invokeContract("extend_stream_ttl", args, invoker);
  }

  async unlockedBalance(streamId: bigint): Promise<bigint> {
    const args = [nativeToScVal(streamId, { type: "u64" })];
    const result = await this.simulateContract("unlocked_balance", args);
    return BigInt(scValToNative(result as xdr.ScVal));
  }

  async availableToWithdraw(streamId: bigint): Promise<bigint> {
    const args = [nativeToScVal(streamId, { type: "u64" })];
    const result = await this.simulateContract("available_to_withdraw", args);
    return BigInt(scValToNative(result as xdr.ScVal));
  }

  async waitForTransaction(txHash: string, maxAttempts = 20): Promise<void> {
    for (let i = 0; i < maxAttempts; i++) {
      await new Promise((r) => setTimeout(r, 1500));
      const result = await this.rpc.getTransaction(txHash);
      if (result.status === StellarRpc.Api.GetTransactionStatus.SUCCESS) return;
      if (result.status === StellarRpc.Api.GetTransactionStatus.FAILED) {
        throw new Error(`Transaction failed: ${txHash}`);
      }
    }
    throw new Error(`Timeout waiting for transaction: ${txHash}`);
  }

  private async invokeContract(
    method: string,
    args: xdr.ScVal[],
    signerAddress: string
  ): Promise<TransactionResult> {
    const account = await this.rpc.getAccount(signerAddress);
    const contract = new Contract(this.contractId);

    const tx = new TransactionBuilder(account, {
      fee: BASE_FEE,
      networkPassphrase: this.networkConfig.networkPassphrase,
    })
      .addOperation(contract.call(method, ...args))
      .setTimeout(30)
      .build();

    const simResult = await this.rpc.simulateTransaction(tx);
    if (StellarRpc.Api.isSimulationError(simResult)) {
      throw new Error(`Simulation failed: ${simResult.error}`);
    }

    const preparedTx = StellarRpc.assembleTransaction(tx, simResult).build();

    if (this.workerUrl) {
      const res = await fetch(`${this.workerUrl}/fee-bump`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          xdr: preparedTx.toXDR(),
          signerPublicKey: signerAddress,
        }),
      });
      return (await res.json()) as TransactionResult;
    }

    if (!this.keypair) throw new Error("No keypair configured for signing");
    preparedTx.sign(this.keypair);

    const sendResult = await this.rpc.sendTransaction(preparedTx);
    await this.waitForTransaction(sendResult.hash);
    return { txHash: sendResult.hash, success: true };
  }

  private async simulateContract(
    method: string,
    args: xdr.ScVal[]
  ): Promise<unknown> {
    const account = await this.rpc.getAccount(this.contractId);
    const contract = new Contract(this.contractId);

    const tx = new TransactionBuilder(account, {
      fee: BASE_FEE,
      networkPassphrase: this.networkConfig.networkPassphrase,
    })
      .addOperation(contract.call(method, ...args))
      .setTimeout(30)
      .build();

    const result = await this.rpc.simulateTransaction(tx);
    if (StellarRpc.Api.isSimulationError(result)) {
      throw new Error(`Simulation failed: ${result.error}`);
    }
    return (result as StellarRpc.Api.SimulateTransactionSuccessResponse).result
      ?.retval;
  }
}
