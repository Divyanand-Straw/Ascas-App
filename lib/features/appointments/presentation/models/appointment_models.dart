class Doctor {
  final String name;
  final String initials;
  final String specialty;
  final String languages;
  final String? qualifications;
  final String? experience;
  final String? profileImageUrl;

  const Doctor({
    required this.name,
    required this.initials,
    required this.specialty,
    required this.languages,
    this.qualifications,
    this.experience,
    this.profileImageUrl,
  });
}

class Appointment {
  final String title;
  final DateTime date;
  final String time;
  final String clinic;
  String status;
  final String doctorName;
  final String specialty;
  final String appointmentType;
  final String consultationMode;
  final String patientName;
  final String notes;
  final String reference;

  Appointment({
    required this.title,
    required this.date,
    required this.time,
    required this.clinic,
    required this.status,
    this.doctorName = 'Thaai Seyazhi Clinic',
    this.specialty = 'Fertility care',
    this.appointmentType = 'Monitoring consultation',
    this.consultationMode = 'In clinic',
    this.patientName = 'Registered patient',
    this.notes = 'Prototype appointment data.',
    this.reference = 'PROTOTYPE-001',
  });

  Map<String, Object?> toMap() => {
    'title': title,
    'date': date.toIso8601String(),
    'time': time,
    'clinic': clinic,
    'status': status,
    'doctorName': doctorName,
    'specialty': specialty,
    'appointmentType': appointmentType,
    'consultationMode': consultationMode,
    'patientName': patientName,
    'notes': notes,
    'reference': reference,
  };

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
      time: map['time'] as String,
      clinic: map['clinic'] as String,
      status: map['status'] as String,
      doctorName: map['doctorName'] as String,
      specialty: map['specialty'] as String,
      appointmentType: map['appointmentType'] as String,
      consultationMode: map['consultationMode'] as String,
      patientName: map['patientName'] as String,
      notes: map['notes'] as String,
      reference: map['reference'] as String,
    );
  }
}
