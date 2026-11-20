
import os
import smtplib
from html import escape
from email.message import EmailMessage

def send_otp_email(recipient: str, otp: str, expires_minutes: int = 5):
    host = os.getenv("SMTP_HOST")
    port = int(os.getenv("SMTP_PORT", "2525"))
    username = os.getenv("SMTP_USERNAME")
    password = os.getenv("SMTP_PASSWORD")
    sender = os.getenv("EMAIL_FROM")
    if not all([host, username, password, sender]):
        raise RuntimeError("SMTP configuration is incomplete.")
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Thaai Seyali Email Verification</title>
</head>
<body bgcolor="#FCEFF2" style="margin:0;padding:0;background-color:#FCEFF2;font-family:Arial,Helvetica,sans-serif;color:#30232A;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FCEFF2" style="width:100%;border-collapse:collapse;background-color:#FCEFF2;">
  <tr>
    <td align="center" bgcolor="#6B1837" style="padding:28px 16px;background-color:#6B1837;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;border-collapse:collapse;">
        <tr>
          <td align="center" style="font-family:Arial,Helvetica,sans-serif;color:#FFFFFF;">
            <h1 style="margin:0;font-size:26px;line-height:32px;font-weight:bold;color:#FFFFFF;">Thaai Seyali</h1>
            <p style="margin:7px 0 0;font-size:12px;line-height:18px;letter-spacing:1.2px;color:#F8E9EE;">YOUR FERTILITY CARE COMPANION</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td align="center" bgcolor="#FCEFF2" style="padding:26px 14px 18px;background-color:#FCEFF2;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFFFFF" style="width:100%;max-width:560px;border-collapse:separate;background-color:#FFFFFF;border-radius:14px;">
        <tr>
          <td style="padding:30px 24px 28px;font-family:Arial,Helvetica,sans-serif;color:#30232A;">
            <h2 style="margin:0 0 18px;font-size:23px;line-height:29px;font-weight:bold;color:#6B1837;">Email Verification</h2>
            <p style="margin:0 0 12px;font-size:16px;line-height:24px;color:#30232A;">Hello,</p>
            <p style="margin:0 0 22px;font-size:15px;line-height:23px;color:#55464D;">Please verify your email address to continue with your Thaai Seyali account.</p>
            <p style="margin:0 0 12px;text-align:center;font-size:15px;line-height:23px;font-weight:600;color:#30232A;">Your verification code is:</p>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFF5F7" style="width:100%;border-collapse:separate;background-color:#FFF5F7;border:1px solid #F1DCE3;border-radius:10px;">
              <tr>
                <td align="center" nowrap="nowrap" style="padding:20px 8px;text-align:center;white-space:nowrap;">
                  <span style="display:inline-block;white-space:nowrap;font-family:Arial,Helvetica,sans-serif;font-size:30px;line-height:38px;font-weight:bold;letter-spacing:6px;color:#6B1837;user-select:all;-webkit-user-select:all;">{escape(otp)}</span>
                </td>
              </tr>
            </table>
            <p style="margin:12px 0 0;text-align:center;font-size:12px;line-height:18px;color:#806D76;">Tap and hold to copy your OTP</p>
            <p style="margin:22px 0 0;font-size:14px;line-height:21px;color:#55464D;">This code is valid for <strong style="color:#6B1837;">{expires_minutes} minutes</strong>.</p>
            <p style="margin:14px 0 0;font-size:13px;line-height:20px;color:#806D76;">For your security, never share this OTP with anyone. If you did not request it, you can safely ignore this email.</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td align="center" bgcolor="#FCEFF2" style="padding:0 16px 26px;background-color:#FCEFF2;font-family:Arial,Helvetica,sans-serif;color:#806D76;">
      <p style="margin:0;font-size:13px;line-height:20px;font-weight:bold;color:#6B1837;">Thaai Seyali</p>
      <p style="margin:3px 0 0;font-size:12px;line-height:18px;">Your fertility care companion</p>
      <p style="margin:8px 0 0;font-size:11px;line-height:16px;">&copy; Thaai Seyali</p>
    </td>
  </tr>
</table>
</body>
</html>"""
    message = EmailMessage()
    message["Subject"] = f"Thaai Seyali | Email Verification Code: {otp}"
    message["From"] = sender
    message["To"] = recipient
    message.set_content(
        "THAAI SEYALI\n\n"
        "Email Verification\n\n"
        "Your verification code is:\n\n"
        f"{otp}\n\n"
        f"This code expires in {expires_minutes} minutes.\n\n"
        "Please do not share this code with anyone. If you did not request it, "
        "you can safely ignore this email.\n"
    )
    message.add_alternative(html_content, subtype="html")
    with smtplib.SMTP(host, port, timeout=20) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(username, password)
        server.send_message(message)
    return True
