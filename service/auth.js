import { betterAuth } from 'better-auth';
import { emailOTP, magicLink } from 'better-auth/plugins';
import { APIError } from 'better-auth/api';
import { passkey } from '@better-auth/passkey';
import { dash } from '@better-auth/infra';
import { sendEmail as infraEmail } from '@better-auth/infra/email';

export const allowed = env => (env.ALLOWED_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);
export const isAllowed = (env, email) => typeof email === 'string' && allowed(env).includes(email.toLowerCase());
export const origins = env => (env.AUTH_ORIGINS || '').split(',').map(o => o.trim()).filter(Boolean);

export const mailConfigured = env => Boolean((env.EMAIL && typeof env.EMAIL.send === 'function') || env.RESEND_API_KEY || infraKey(env));
export const infraKey = env => (env.BETTER_AUTH_API_KEY || '').trim();
export const googleConfigured = env => Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET);
export const sendCode = (env, email, otp) => sendMail(env, email,
  `${otp} is your multiprompt sign-in code`,
  `Your multiprompt sign-in code is ${otp}\n\nIt expires in 5 minutes. If you did not try to sign in, ignore this email.`,
  { template: 'sign-in-otp', variables: { otpCode: otp, userEmail: email, appName: 'multiprompt', expirationMinutes: '5' } });
export const sendLink = (env, email, url) => sendMail(env, email,
  'Your multiprompt sign-in link',
  `Open this link to sign in to multiprompt:\n\n${url}\n\nIt works once and expires in 5 minutes. If you did not try to sign in, ignore this email.`,
  { template: 'magic-link', variables: { magicLink: url, userEmail: email, appName: 'multiprompt', expirationMinutes: '5' } });
async function sendMail(env, email, subject, text, infra) {
  const from = env.EMAIL_FROM || 'multiprompt <login@example.com>';
  if (env.EMAIL && typeof env.EMAIL.send === 'function') {
    await env.EMAIL.send({ to: email, from, subject, text });
    return;
  }
  if (env.RESEND_API_KEY) {
    const response = await fetch(env.EMAIL_API_URL || 'https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from, to: [email], subject, text })
    });
    if (!response.ok) throw new APIError('SERVICE_UNAVAILABLE', { message: 'email_unavailable' });
    return;
  }
  if (infraKey(env)) {
    const result = await infraEmail({ to: email, ...infra }, { apiKey: infraKey(env) });
    if (!result?.success) throw new APIError('SERVICE_UNAVAILABLE', { message: 'email_unavailable' });
    return;
  }
  throw new APIError('SERVICE_UNAVAILABLE', { message: 'email_not_configured' });
}

export function makeAuth(env, origin) {
  const google = googleConfigured(env)
    ? { google: { clientId: env.GOOGLE_CLIENT_ID, clientSecret: env.GOOGLE_CLIENT_SECRET, prompt: 'select_account' } } : {};
  return betterAuth({
    appName: 'multiprompt',
    database: env.DB,
    baseURL: origin,
    basePath: '/api/auth',
    secret: env.BETTER_AUTH_SECRET,
    trustedOrigins: origins(env),
    emailAndPassword: { enabled: false },
    socialProviders: google,
    session: { expiresIn: 60 * 60 * 24 * 30, updateAge: 60 * 60 * 24, freshAge: 60 * 15 },
    advanced: env.COOKIE_DOMAIN ? { crossSubDomainCookies: { enabled: true, domain: env.COOKIE_DOMAIN } } : {},
    databaseHooks: {
      user: { create: { before: async user => {
        if (!isAllowed(env, user.email)) throw new APIError('FORBIDDEN', { message: 'account_not_allowed' });
        return { data: { ...user, email: user.email.toLowerCase() } };
      } } }
    },
    plugins: [
      emailOTP({
        otpLength: 6, expiresIn: 300, allowedAttempts: 5, storeOTP: 'hashed',
        async sendVerificationOTP({ email, otp, type }) {
          if (type !== 'sign-in' || !isAllowed(env, email)) return;
          await sendCode(env, email, otp);
        }
      }),
      magicLink({
        expiresIn: 300, storeToken: 'hashed',
        async sendMagicLink({ email, url }) {
          if (!isAllowed(env, email)) return;
          await sendLink(env, email, url);
        }
      }),
      passkey({ rpID: env.RP_ID, rpName: 'multiprompt', origin: origins(env) }),
      ...(infraKey(env) ? [dash({ apiKey: infraKey(env) })] : [])
    ]
  });
}
