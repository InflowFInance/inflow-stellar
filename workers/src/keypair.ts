import { Keypair } from "@stellar/stellar-sdk";
import { Buffer } from "buffer";

export async function deriveKeypairFromEmail(
  email: string,
  masterSecret: string
): Promise<Keypair> {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    enc.encode(masterSecret),
    "HKDF",
    false,
    ["deriveBits"]
  );

  const bits = await crypto.subtle.deriveBits(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: enc.encode("inflow-stellar-v1"),
      info: enc.encode(email.toLowerCase().trim()),
    },
    keyMaterial,
    256
  );

  return Keypair.fromRawEd25519Seed(Buffer.from(bits));
}

export async function encryptSecretKey(
  secretKey: string,
  encryptionKey: string
): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    Buffer.from(encryptionKey, "hex"),
    "AES-GCM",
    false,
    ["encrypt"]
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    enc.encode(secretKey)
  );

  return JSON.stringify({
    iv: Buffer.from(iv).toString("hex"),
    data: Buffer.from(encrypted).toString("hex"),
  });
}

export async function decryptSecretKey(
  encrypted: string,
  encryptionKey: string
): Promise<string> {
  const { iv, data } = JSON.parse(encrypted);
  const key = await crypto.subtle.importKey(
    "raw",
    Buffer.from(encryptionKey, "hex"),
    "AES-GCM",
    false,
    ["decrypt"]
  );

  const dec = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: Buffer.from(iv, "hex") },
    key,
    Buffer.from(data, "hex")
  );

  return new TextDecoder().decode(dec);
}
