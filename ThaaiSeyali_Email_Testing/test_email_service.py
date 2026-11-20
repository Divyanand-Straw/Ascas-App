import os
import unittest
from unittest.mock import patch

from fastapi import HTTPException

from email_service import send_otp_email
import main


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


class EmailOtpFlowTests(unittest.TestCase):
    def setUp(self):
        main.otp_store.clear()

    @patch("main.send_otp_email")
    def test_requested_otp_is_sent_and_can_be_verified(self, send_otp_email):
        email = "patient@example.com"

        response = main.request_email_otp(main.OTPRequest(email=email))

        self.assertTrue(response["success"])
        send_otp_email.assert_called_once()
        sent_email, otp = send_otp_email.call_args.args
        self.assertEqual(sent_email, email)
        self.assertRegex(otp, r"^[0-9]{6}$")

        verified = main.verify_email_otp(
            main.OTPVerification(email=email, otp=otp)
        )

        self.assertTrue(verified["verified"])

    @patch("main.send_otp_email")
    def test_incorrect_otp_is_rejected(self, send_otp_email):
        email = "patient@example.com"
        main.request_email_otp(main.OTPRequest(email=email))

        with self.assertRaises(HTTPException) as error:
            main.verify_email_otp(
                main.OTPVerification(email=email, otp="000000")
            )

        self.assertEqual(error.exception.status_code, 400)


if __name__ == "__main__":
    unittest.main()
