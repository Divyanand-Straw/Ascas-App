import os
import unittest
from unittest.mock import patch

from email_service import send_otp_email


class SendOtpEmailTests(unittest.TestCase):
    @patch.dict(
        os.environ,
        {
            "SMTP_HOST": "smtp.example.test",
            "SMTP_PORT": "2525",
            "SMTP_USERNAME": "test-user",
            "SMTP_PASSWORD": "test-password",
            "EMAIL_FROM": "no-reply@example.test",
        },
    )
    @patch("email_service.smtplib.SMTP")
    def test_subject_and_html_prominently_include_otp(self, smtp_factory):
        smtp = smtp_factory.return_value.__enter__.return_value

        send_otp_email("patient@example.test", "123456")

        message = smtp.send_message.call_args.args[0]
        self.assertEqual(
            message["Subject"],
            "Thaai Seyali | Email Verification Code: 123456",
        )
        plain_body = message.get_body(preferencelist=("plain",)).get_content()
        self.assertIn("\n123456\n", plain_body)
        self.assertIn("expires in 5 minutes", plain_body)
        html_body = message.get_body(preferencelist=("html",)).get_content()
        self.assertIn("Email Verification", html_body)
        self.assertIn("Your verification code is:", html_body)
        self.assertIn(">123456</span>", html_body)
        self.assertIn("5 minutes", html_body)
        self.assertIn("never share this OTP with anyone", html_body)
        self.assertIn("Thaai Seyali", html_body)


if __name__ == "__main__":
    unittest.main()
