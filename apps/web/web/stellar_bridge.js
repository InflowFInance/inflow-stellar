// stellar_bridge.js — inFlow Stellar JavaScript Bridge for Flutter Web
(function () {
  'use strict';

  class StellarBridge {
    constructor() {
      this.workerUrl = null;
      this.network = 'testnet';
      this.publicKey = null;
      this.contractId = null;
    }

    async initBridge() {
      this.workerUrl =
        document.querySelector('meta[name="worker-url"]')?.content ||
        'https://inflow-relay.inflowfinance.workers.dev';
      this.contractId =
        document.querySelector('meta[name="contract-id"]')?.content ||
        'CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2';

      this.network =
        window.location.hostname === 'localhost' ? 'testnet' : 'mainnet';
      console.log('[StellarBridge] Initialized on network:', this.network);
      return true;
    }

    async sendEmailOtp(email) {
      const res = await fetch(`${this.workerUrl}/send-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      if (!res.ok) throw new Error('Failed to send OTP code');
      return true;
    }

    async verifyOtpAndConnect(otp, network) {
      const email = window._inflowCurrentEmail;
      const res = await fetch(`${this.workerUrl}/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, otp, network }),
      });
      if (!res.ok) throw new Error('Invalid OTP verification code');
      const data = await res.json();
      this.publicKey = data.publicKey;
      this.network = data.network || network;
      return this.publicKey;
    }

    async logout() {
      this.publicKey = null;
      return true;
    }

    async createStream(
      tokenAddress,
      amountStr,
      durationSecs,
      recipientOrEmail,
      isEmailGated
    ) {
      const now = Math.floor(Date.now() / 1000);
      const startTime = now + 30;
      const stopTime = startTime + Number(durationSecs);

      let claimHash = null;
      let recipient = null;

      if (isEmailGated) {
        const secret = crypto.getRandomValues(new Uint8Array(16));
        const hashBuf = await crypto.subtle.digest('SHA-256', secret);
        claimHash = Array.from(new Uint8Array(hashBuf))
          .map((b) => b.toString(16).padStart(2, '0'))
          .join('');
        window._inflowStreamSecret = Array.from(secret)
          .map((b) => b.toString(16).padStart(2, '0'))
          .join('');
      } else {
        recipient = recipientOrEmail;
      }

      const res = await fetch(`${this.workerUrl}/invoke`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          method: 'create_stream',
          signerPublicKey: this.publicKey,
          args: {
            sender: this.publicKey,
            recipient,
            claimHash,
            tokenAddress,
            depositAmount: amountStr,
            startTime,
            stopTime,
          },
        }),
      });

      const data = await res.json();
      return data.streamId || 1;
    }

    async claimSecureStream(streamId) {
      const secret = window._inflowClaimSecret;
      if (!secret) throw new Error('No claim secret available');

      const res = await fetch(`${this.workerUrl}/invoke`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          method: 'claim_stream',
          signerPublicKey: this.publicKey,
          args: { streamId: String(streamId), secret },
        }),
      });
      return res.json();
    }

    async withdrawFromStream(streamId, amountStr) {
      const res = await fetch(`${this.workerUrl}/invoke`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          method: 'withdraw',
          signerPublicKey: this.publicKey,
          args: { streamId: String(streamId), amount: amountStr },
        }),
      });
      return res.json();
    }

    async cancelStream(streamId) {
      const res = await fetch(`${this.workerUrl}/invoke`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          method: 'cancel_stream',
          signerPublicKey: this.publicKey,
          args: { streamId: String(streamId) },
        }),
      });
      return res.json();
    }

    async getStream(streamId) {
      const res = await fetch(`${this.workerUrl}/stream-info?id=${streamId}`);
      return res.json();
    }

    async getBalance(tokenAddress) {
      const horizonUrl =
        this.network === 'mainnet'
          ? 'https://horizon.stellar.org'
          : 'https://horizon-testnet.stellar.org';

      const res = await fetch(`${horizonUrl}/accounts/${this.publicKey}`);
      const data = await res.json();
      const balance = data.balances?.find(
        (b) => b.asset_issuer && tokenAddress.includes(b.asset_issuer)
      );
      return balance?.balance || '0';
    }

    async getNextStreamId() {
      return 1;
    }

    async waitForTransaction(txHash) {
      const rpcUrl =
        this.network === 'mainnet'
          ? 'https://rpc.stellar.org'
          : 'https://soroban-testnet.stellar.org';

      for (let i = 0; i < 20; i++) {
        await new Promise((r) => setTimeout(r, 1500));
        const res = await fetch(rpcUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            jsonrpc: '2.0',
            id: 1,
            method: 'getTransaction',
            params: { hash: txHash },
          }),
        });
        const data = await res.json();
        if (data.result?.status === 'SUCCESS') return data.result;
        if (data.result?.status === 'FAILED')
          throw new Error('Transaction failed');
      }
      throw new Error('Timeout waiting for transaction');
    }

    async checkAndTriggerSponsorship(address, network) {
      const res = await fetch(`${this.workerUrl}/trigger-sponsorship`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ address, network }),
      });
      return res.json();
    }
  }

  window.StellarBridge = new StellarBridge();
  console.log('[StellarBridge] Bridge loaded');
})();
