import { Router } from 'itty-router';
import { sendOtp } from './email';
import { verifyOtp } from './email';

const router = Router();

router.post('/api/send-otp', async (request: Request) => {
  try {
    const { email } = await request.json();
    await sendOtp(email as string);
    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Failed to send OTP' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

router.post('/api/verify-otp', async (request: Request) => {
  try {
    const { email, code } = await request.json();
    const result = await verifyOtp(email as string, code as string);
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Invalid or expired OTP' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

export const onRequest = router.handle;
