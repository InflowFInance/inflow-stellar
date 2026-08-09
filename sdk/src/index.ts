import { Networks, Server, TransactionBuilder, Operation, Asset } from '@stellar/stellar-sdk';

export type InflowStream = {
  id: number;
  sender: string;
  recipient: string;
  token: string;
  deposit: string;
  topUp: string;
  startTime: number;
  endTime: number;
  stopTime: number;
  recipientHasClaimed: boolean;
  claimHash?: Uint8Array;
  status: 'active' | 'canceled' | 'completed';
};

export class InflowClient {
  private server: Server;
  private rpcUrl: string;

  constructor(rpcUrl: string, networkPassphrase?: string) {
    this.rpcUrl = rpcUrl;
    this.server = new Server(rpcUrl);
  }

  async getAccount(address: string) {
    return this.server.loadAccount(address);
  }

  async getBalance(address: string) {
    const account = await this.getAccount(address);
    const nativeBalance = account.balances.find(
      (b: any) => b.asset_type === 'native'
    );
    return nativeBalance ? nativeBalance.balance : '0';
  }
}
