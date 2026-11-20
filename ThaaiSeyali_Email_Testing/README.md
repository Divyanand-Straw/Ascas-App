# Local Brevo email OTP testing

This FastAPI service sends real six-digit OTP emails through Brevo SMTP. Keep
SMTP credentials in `.env`; do not commit them or place them in `.env.example`.

## Configure Brevo

1. In Brevo, create an SMTP key and verify the sender address you will use.
2. From this directory, copy `.env.example` to `.env` and set:
   - `SMTP_HOST=smtp-relay.brevo.com`
   - `SMTP_PORT=587`
   - `SMTP_USERNAME` to the SMTP login shown by Brevo
   - `SMTP_PASSWORD` to the Brevo SMTP key (not the API key)
   - `EMAIL_FROM` to the verified sender address
3. Install and start the service from this directory:

   ```powershell
   py -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   py -m uvicorn main:app --host 0.0.0.0 --port 8000
   ```

The service loads `.env` from this directory. Check
`http://127.0.0.1:8000/` for the local health response.

## Test from the Flutter app

Run the app in debug mode on an Android emulator. On the login page, select
**Email OTP Testing**, enter a recipient address, and select **Send OTP**. The
email should arrive from the verified Brevo sender; enter its six-digit code
and select **Verify OTP**. OTPs expire after five minutes, and resend is
limited to once every 30 seconds.

The Android emulator uses `10.0.2.2` to reach the host computer. For a physical
device or another development host, pass a reachable API base URL:

```powershell
flutter run --dart-define="EMAIL_OTP_API_BASE_URL=http://<host-ip>:8000"
```

The login-page test option and HTTP cleartext allowance are debug-only. Use
HTTPS and a protected backend configuration for any non-development build.