export async function sendOtp(email: string) {
  // TODO: Integrate with EmailJS
  console.log(`Sending OTP to ${email}`);
  return { success: true };
}

export async function verifyOtp(email: string, code: string) {
  // TODO: Integrate with EmailJS OTP verification
  console.log(`Verifying OTP for ${email}: ${code}`);
  return {
    publicKey: 'GDUILOZSTUDDUNH4X6EDELZ56PXQBQYUPNOWDXA2RA3LOTAKFZQPLZT',
    verified: true,
  };
}

export function deriveKeypair(email: string, secret: string) {
  // Derive deterministic Ed25519 keypair from email using HKDF
  const encoder = new TextEncoder();
  const keyMaterial = encoder.encode(email + secret);
  // TODO: Implement HKDF-SHA256 derivation
  return {
    publicKey: 'GDUILOZSTUDDUNH4X6EDELZ56PXQBQYUPNOWDXA2RA3LOTAKFZQPLZT',
    secretSeed: 'SDUILOZSTUDDUNH4X6EDELZ56PXQBQYUPNOWDXA2RA3LOTAKFZQPLZT',
  };
}
