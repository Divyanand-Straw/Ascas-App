# Ascas-App

# ASCAS Fertility Care Companion

A patient-focused mobile application designed to simplify and support the fertility treatment journey at **ASCAS Fertility and Women's Centre**.

The application aims to provide patients with a centralized platform to manage appointments, follow treatment progress, access medical records, receive medication reminders, and stay connected with the clinic throughout their fertility journey.

## 🎯 Project Overview

The ASCAS Fertility Care Companion is being developed to improve the patient experience by making fertility treatment information and essential clinic services more accessible through a mobile application.

From initial registration and consultations to treatment procedures, follow-ups, and post-treatment care, the application aims to guide patients through each stage of their journey.

## ✨ Planned Features

- **Patient Authentication** – Registration, login, OTP verification, and profile management.
- **Dashboard** – Personalized overview of appointments, upcoming tasks, reminders, and treatment progress.
- **My Fertility Journey** – Track treatment stages such as IVF, ICSI, IUI, and FET.
- **Appointment Management** – View, book, reschedule, and manage appointments.
- **Medication Management** – Medication schedules, dosage reminders, and injection guidance based on clinic instructions.
- **Medical Records** – Access laboratory reports, prescriptions, scan results, and other medical documents.
- **Embryology Updates** – View clinic-published embryo development updates during treatment.
- **Procedure Management** – Access preparation instructions, procedure details, and recovery guidance.
- **Billing and Payments** – View treatment packages, invoices, payment history, and outstanding balances.
- **Partner Access** – Controlled access to selected patient information with appropriate permissions.
- **Notifications** – Receive appointment, medication, treatment, and clinic-related notifications.
- **Patient Support** – Contact the clinic and raise queries.
- **Fertility Education** – Access educational resources and guidance related to fertility treatments.

## 🛠️ Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform mobile application development |
| Dart | Application programming language |
| GoRouter | Navigation and route management |
| Riverpod | State management |
| REST API | Backend communication |
| Git & GitHub | Version control and collaboration |

*The technology stack and integrations may evolve during development.*

## 📁 Project Structure

```text
mobile/
├── assets/
│   ├── images/
│   ├── icons/
│   ├── fonts/
│   └── animations/
├── lib/
│   ├── main.dart
│   ├── app/
│   ├── core/
│   ├── features/
│   │   ├── splash/
│   │   ├── onboarding/
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── appointments/
│   │   ├── treatment/
│   │   ├── medical_records/
│   │   ├── medications/
│   │   ├── notifications/
│   │   ├── payments/
│   │   └── profile/
│   └── shared/
├── test/
├── pubspec.yaml
└── analysis_options.yaml
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- Android Emulator or a physical Android device

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
```

2. Navigate to the project directory:

```bash
cd <repository-folder>
```

3. Install dependencies:

```bash
flutter pub get
```

4. Run the application:

```bash
flutter run
```

## 🔐 Privacy and Security

Since the application handles sensitive patient information, privacy and security are important development considerations.

- Secure patient authentication.
- Controlled access to medical records.
- Explicit and revocable partner permissions.
- Protection of sensitive medical information.
- Secure communication between the mobile application and backend services.

## 📌 Development Status

<sub>Currently in the initial development stage.</sub>

- [x] Initial project planning
- [x] Feature identification and requirement planning
- [x] UI/UX concept and prototype exploration
- [ ] Flutter application implementation
- [ ] Backend and database integration
- [ ] Authentication and patient record integration
- [ ] Testing and deployment

## ⚠️ Important Note

This application is intended to support patient engagement and access to clinic-related information. It does not replace professional medical consultation, diagnosis, or treatment decisions.

Clinical instructions, medication information, and treatment updates must be provided or verified by authorized clinic personnel.

## 👨‍💻 Project

**ASCAS Fertility and Women's Centre**

Developed as a patient-focused digital initiative to enhance the fertility care experience through technology.