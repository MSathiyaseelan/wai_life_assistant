# MSG91 SendOTP Integration

---

## Purpose

WAI uses **phone number + OTP** as the only sign-in method. MSG91 delivers the 6-digit OTP via SMS to the user's Indian mobile number. After verification, a Supabase session is created using an internal synthetic email — the user never sees or manages a password.

---

## Authentication Method

**API key in request header** (`authkey: MSG91_AUTH_KEY`). Stored as a Supabase secret, passed from the edge function — never shipped to the Flutter client.

---

## Full Auth Flow

```
Flutter             /send-otp (Edge Function)       MSG91
  │                           │                        │
  │ POST { phone }            │                        │
  │──────────────────────────>│                        │
  │                           │ POST /api/v5/otp        │
  │                           │──────────────────────>│
  │                           │    { request_id }       │
  │                           │<──────────────────────│
  │   { request_id }          │                   SMS sent
  │<──────────────────────────│
  │
  │ POST { phone, otp, request_id }
  │──────────────────────────> /verify-otp
  │                           │ GET /api/v5/otp/verify
  │                           │──────────────────────>│
  │                           │    { type: "success" } │
  │                           │<──────────────────────│
  │                           │
  │                           │ supabaseAdmin.auth.signInWithPassword
  │                           │   (or createUser if new)
  │                           │   email: phone_919876543210@waiapp.internal
  │                           │   password: WAI_INTERNAL_AUTH_PASS
  │   { access_token,         │
  │     refresh_token,        │
  │     user.id }             │
  │<──────────────────────────│
```

---

## Internal Email Convention

Because MSG91 handles the OTP, Supabase Auth is used with email+password internally. The email is derived from the phone number:

```
phone: +91 98765 43210
→ digits: 919876543210
→ email:  phone_919876543210@waiapp.internal
→ password: WAI_INTERNAL_AUTH_PASS (server-side secret, never sent to client)
```

This ensures the same user always gets the same `auth.uid()` regardless of device.

**Try sign-in first; if it fails (new user), createUser then sign-in.** This avoids a separate "is user registered?" check.

---

## OTP Configuration

```typescript
// supabase/functions/send-otp/index.ts
body: JSON.stringify({
  template_id: MSG91_TEMPLATE_ID,  // MSG91 Flow ID (DLT-approved template)
  mobile,                           // e.g. "919876543210"
  otp_length:  6,
  otp_expiry:  30,                  // minutes
})
```

---

## API Reference

**Send OTP** (`POST /functions/v1/send-otp`):
```json
// Request
{ "phone": "+919876543210" }

// Success
{ "success": true, "request_id": "MSG91-request-id" }

// Error
{ "error": "Invalid phone number" }
```

**Verify OTP** (`POST /functions/v1/verify-otp`):
```json
// Request
{ "phone": "+919876543210", "otp": "123456", "request_id": "MSG91-request-id" }

// Success
{
  "access_token":  "eyJhbGciOi...",
  "refresh_token": "v1.abc...",
  "expires_in":    3600,
  "user":          { "id": "uuid", "phone": "+919876543210" }
}

// Error
{ "error": "Invalid OTP" }
```

---

## Error Handling

| Error | HTTP Status | Behaviour |
|---|---|---|
| MSG91 returns error type | 502 | Returns MSG91's error message to client |
| Invalid/expired OTP | 401 | Returns "Invalid OTP" from MSG91 |
| User creation fails | 500 | Returns "Failed to create user account" |
| Missing fields | 400 | Returns field validation error |
| MSG91 non-JSON response | 502 | Returns "Unexpected response from OTP provider" |

No automatic retry on the server. The client must call `/send-otp` again to get a fresh OTP.

---

## Cost

| Item | Cost |
|---|---|
| SMS OTP (Indian numbers) | ~₹0.15–0.25 per OTP (MSG91 DLT pricing) |
| Rate limit | ~5 OTPs/phone/hour (configurable in MSG91 dashboard) |
| OTP validity | 30 minutes |

MSG91 requires **DLT registration** for Indian numbers (TRAI regulation). The `MSG91_TEMPLATE_ID` corresponds to a pre-approved DLT template.

---

## Setup

```
1. Create a MSG91 account at https://msg91.com

2. Complete DLT registration (required for Indian SMS):
   - Register sender ID (e.g. WAIAPP)
   - Submit OTP template for DLT approval (~3–5 business days)
   - Note the approved template content (e.g. "Your WAI OTP is ##OTP##. Valid for 30 minutes.")

3. In MSG91 dashboard → SMS → OTP → Create Flow
   - Select your DLT template
   - Copy the Flow ID (this is MSG91_TEMPLATE_ID)

4. Copy your Auth Key from MSG91 → API → Auth Key
```

```bash
5. Set Supabase secrets:
supabase secrets set MSG91_AUTH_KEY=<your-auth-key>
supabase secrets set MSG91_TEMPLATE_ID=<your-flow-id>
supabase secrets set WAI_INTERNAL_AUTH_PASS=<strong-random-password>

6. Deploy edge functions:
supabase functions deploy send-otp
supabase functions deploy verify-otp
```

```
7. Test: run the app, enter a real Indian mobile number, verify OTP arrives within 30 seconds.
```

---

## Security Notes

- `WAI_INTERNAL_AUTH_PASS` is never returned to the client. It exists only inside the edge function.
- All synthetic `@waiapp.internal` emails are effectively inaccessible via normal Supabase Auth flows — only the edge function knows the password.
- If `WAI_INTERNAL_AUTH_PASS` is ever compromised, rotate it in Supabase secrets AND update all existing user passwords via a migration script.

---

## Related Documentation

- [Supabase Integration](supabase.md) — edge function deployment and secrets
- [Architecture](../architecture.md) — authentication flow diagram
