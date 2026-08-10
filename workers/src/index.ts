import { Keypair } from "@stellar/stellar-sdk";
import { generateOtp, verifyOtp } from "./otp.js";
import { deriveKeypairFromEmail, encryptSecretKey } from "./keypair.js";
import { wrapWithFeeBump } from "./fee_bump.js";

interface KVNamespace {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
}

interface Env {
  KEYPAIRS: KVNamespace;
  STREAM_LINKS: KVNamespace;
  TREASURY_SECRET_KEY: string;
  EMAILJS_SERVICE_ID: string;
  EMAILJS_TEMPLATE_ID: string;
  EMAILJS_PUBLIC_KEY: string;
  EMAILJS_PRIVATE_KEY: string;
  OTP_SIGNING_SECRET: string;
  KEYPAIR_ENCRYPTION_KEY: string;
  STELLAR_NETWORK: string;
  INFLOW_CONTRACT_ID: string;
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS });
    }

    const url = new URL(request.url);

    try {
      switch (`${request.method} ${url.pathname}`) {
        case "POST /send-otp":
          return handleSendOtp(request, env);
        case "POST /verify-otp":
          return handleVerifyOtp(request, env);
        case "POST /fee-bump":
          return handleFeeBump(request, env);
        case "GET /stream-info":
          return handleStreamInfo(request, env);
        case "POST /store-stream-secret":
          return handleStoreStreamSecret(request, env);
        case "POST /trigger-sponsorship":
          return handleTriggerSponsorship(request, env);
        default:
          return json({ error: "Not found" }, 404);
      }
    } catch (err) {
      console.error(err);
      return json({ error: "Internal server error" }, 500);
    }
  },
};

async function handleSendOtp(request: Request, env: Env): Promise<Response> {
  const { email } = (await request.json()) as { email: string };
  if (!email || !email.includes("@")) {
    return json({ error: "Invalid email" }, 400);
  }

  const otp = await generateOtp(email, env.OTP_SIGNING_SECRET || "default_otp_secret");
  await sendEmailOtp(email, otp, env);
  return json({ success: true });
}

async function handleVerifyOtp(request: Request, env: Env): Promise<Response> {
  const { email, otp, network } = (await request.json()) as {
    email: string;
    otp: string;
    network: string;
  };

  const valid = await verifyOtp(email, otp, env.OTP_SIGNING_SECRET || "default_otp_secret");
  if (!valid) {
    return json({ error: "Invalid or expired OTP code" }, 401);
  }

  const keypair = await deriveKeypairFromEmail(
    email,
    env.KEYPAIR_ENCRYPTION_KEY || "default_encryption_key_0123456789abcdef"
  );
  const publicKey = keypair.publicKey();

  const emailHash = await sha256(email.toLowerCase());
  const encrypted = await encryptSecretKey(
    keypair.secret(),
    env.KEYPAIR_ENCRYPTION_KEY || "default_encryption_key_0123456789abcdef"
  );

  if (env.KEYPAIRS) {
    await env.KEYPAIRS.put(`kp:${emailHash}`, encrypted, {
      expirationTtl: 86400 * 365,
    });
  }

  if (network === "testnet" || env.STELLAR_NETWORK === "testnet") {
    await fundViaFriendbot(publicKey);
  }

  return json({ publicKey, network: network || env.STELLAR_NETWORK });
}

async function handleFeeBump(request: Request, env: Env): Promise<Response> {
  const { xdr } = (await request.json()) as { xdr: string; signerPublicKey: string };

  if (!env.TREASURY_SECRET_KEY) {
    return json({ error: "Treasury not configured" }, 500);
  }

  const treasury = Keypair.fromSecret(env.TREASURY_SECRET_KEY);
  const networkPassphrase =
    env.STELLAR_NETWORK === "mainnet"
      ? "Public Global Stellar Network ; September 2015"
      : "Test SDF Network ; September 2015";

  const feeBumpXdr = wrapWithFeeBump(xdr, treasury, networkPassphrase);

  const horizonUrl =
    env.STELLAR_NETWORK === "mainnet"
      ? "https://horizon.stellar.org"
      : "https://horizon-testnet.stellar.org";

  const response = await fetch(`${horizonUrl}/transactions`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `tx=${encodeURIComponent(feeBumpXdr)}`,
  });

  const result = (await response.json()) as { hash?: string };
  return json({ txHash: result.hash || "", success: response.ok });
}

async function handleStreamInfo(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const streamId = url.searchParams.get("id");
  if (!streamId) return json({ error: "Missing stream id" }, 400);

  if (!env.STREAM_LINKS) {
    return json({ streamId, status: "active" });
  }

  const info = await env.STREAM_LINKS.get(`stream:${streamId}`);
  if (!info) return json({ found: false });

  return json(JSON.parse(info));
}

async function handleStoreStreamSecret(request: Request, env: Env): Promise<Response> {
  const payload = (await request.json()) as {
    streamId: string;
    recipientEmail: string;
    senderEmail: string;
    network: string;
  };

  if (env.STREAM_LINKS) {
    await env.STREAM_LINKS.put(
      `stream:${payload.streamId}`,
      JSON.stringify({ ...payload, createdAt: Date.now() }),
      { expirationTtl: 86400 * 365 }
    );
  }

  return json({ success: true });
}

async function handleTriggerSponsorship(request: Request, env: Env): Promise<Response> {
  const { address, network } = (await request.json()) as {
    address: string;
    network: string;
  };

  if (network === "testnet" || env.STELLAR_NETWORK === "testnet") {
    await fundViaFriendbot(address);
    return json({ success: true, method: "friendbot" });
  }

  return json({ success: true, method: "treasury" });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

async function sha256(input: string): Promise<string> {
  const buffer = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function fundViaFriendbot(address: string): Promise<void> {
  try {
    await fetch(`https://friendbot.stellar.org?addr=${address}`);
  } catch {
    // Best-effort funding
  }
}

async function sendEmailOtp(
  email: string,
  otp: string,
  env: Env
): Promise<void> {
  if (!env.EMAILJS_SERVICE_ID || !env.EMAILJS_PRIVATE_KEY) {
    console.warn("[sendEmailOtp] EmailJS not configured — skipping send");
    return;
  }

  const payload = {
    service_id: env.EMAILJS_SERVICE_ID,
    template_id: env.EMAILJS_TEMPLATE_ID,
    user_id: env.EMAILJS_PUBLIC_KEY,
    accessToken: env.EMAILJS_PRIVATE_KEY,
    template_params: {
      user_email: email,
      otp_code: otp,
      app_name: "inFlow",
    },
  };

  const res = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Origin": "https://inflowfinance.web.app",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error(`[sendEmailOtp] EmailJS error ${res.status}: ${text}`);
  } else {
    console.log(`[sendEmailOtp] OTP sent to ${email} via EmailJS`);
  }
}
