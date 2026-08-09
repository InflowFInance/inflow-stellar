import { Keypair, TransactionBuilder, Transaction, BASE_FEE } from "@stellar/stellar-sdk";

export function wrapWithFeeBump(
  innerXdr: string,
  treasuryKeypair: Keypair,
  networkPassphrase: string
): string {
  const innerTx = new Transaction(innerXdr, networkPassphrase);
  const feeBumpTx = TransactionBuilder.buildFeeBumpTransaction(
    treasuryKeypair,
    String(parseInt(BASE_FEE) * 10),
    innerTx,
    networkPassphrase
  );

  feeBumpTx.sign(treasuryKeypair);
  return feeBumpTx.toXDR();
}
