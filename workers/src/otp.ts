const OTP_VALID_SECONDS = 600;

export async function generateOtp(email: string, secret: string): Promise<string> {
  const enc = new TextEncoder();
  const slot = Math.floor(Date.now() / (OTP_VALID_SECONDS * 1000));

  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    enc.encode(`${email.toLowerCase()}:${slot}`)
  );

  const hash = Array.from(new Uint8Array(sig));
  const code =
    ((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) % 1_000_000;
  return String(Math.abs(code)).padStart(6, "0");
}

export async function verifyOtp(
  email: string,
  otp: string,
  secret: string
): Promise<boolean> {
  const slot = Math.floor(Date.now() / (OTP_VALID_SECONDS * 1000));
  for (const s of [slot, slot - 1]) {
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      enc.encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const sig = await crypto.subtle.sign(
      "HMAC",
      key,
      enc.encode(`${email.toLowerCase()}:${s}`)
    );
    const hash = Array.from(new Uint8Array(sig));
    const code =
      ((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) % 1_000_000;
    if (String(Math.abs(code)).padStart(6, "0") === otp.trim()) return true;
  }
  return false;
}
