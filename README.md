# Ascas-App

## Account identity and partner access prototype

Account identities and patient-partner relationship state are local Flutter
prototypes backed by `SharedPreferences`. New patient retries reuse the local
identity without overwriting its name or patient ID. Different valid mobile
numbers create separate local test accounts with generated patient IDs. The
existing-patient path verifies a patient ID and date of birth against an
identity already saved on this device; it does not fabricate a clinic record.
Partner identities have no patient ID. Linking supports
invitation expiry, patient approval or rejection, category permissions, and
revocation for single-device workflow testing.

This is not production authentication or a production authorization boundary.
The application has no backend, authenticated API, clinic account lookup, or
database integration. OTP validation uses a fixed local demo code and is not
verification of a real account. The local existing-patient flow cannot look up
clinic records or retrieve medical history. Production deployment must move
account creation, record lookup, relationship state, and every patient-data
permission check to an authenticated server before enabling access across
accounts or devices.

The Ovulation Tracker's detailed cycle view derives day phases, period duration,
fertile windows, and dates as estimates from the entered cycle start and length.
It is a local tracker, not a medical result or a clinic-recorded cycle history.

## Medication reminder prototype

The Home and Journey reminder cards use clearly labeled sample-only entries;
they are not clinic prescriptions and do not provide dosage or treatment
instructions. Reminder completion state is stored locally per patient account.
Android and iOS notifications are scheduled locally as daily reminders, with
notification permission requested by the app. Android boot/package-replacement
receivers restore scheduled reminders after a device restart. Delivery timing
may still be affected by OS notification settings, battery restrictions, or a
force-stop. Live prescriptions and clinic-managed schedules require backend
integration.

Run the identity and relationship checks with:

```shell
flutter test test/account_identity_service_test.dart
flutter test test/partner_link_service_test.dart
```