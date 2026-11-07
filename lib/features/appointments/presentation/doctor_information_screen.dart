import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/theme/app_colors.dart';
import 'data/appointment_data.dart';
import 'models/appointment_models.dart';
import 'doctor_profile_screen.dart';

class DoctorInformationScreen extends StatefulWidget {
  final String patientName;
  final String mobileNumber;

  const DoctorInformationScreen({
    super.key,
    required this.patientName,
    required this.mobileNumber,
  });

  @override
  State<DoctorInformationScreen> createState() =>
      _DoctorInformationScreenState();
}

class _DoctorInformationScreenState extends State<DoctorInformationScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Doctor> get _doctors {
    final query = _searchController.text.toLowerCase();
    return sampleDoctors.where((doctor) {
      final matchesSearch =
          doctor.name.toLowerCase().contains(query) ||
          doctor.specialty.toLowerCase().contains(query);
      final matchesFilter =
          _filter == 'All' ||
          (_filter == 'Fertility' &&
              doctor.specialty.toLowerCase().contains('fertility')) ||
          (_filter == 'Andrology' &&
              doctor.specialty.toLowerCase().contains('andrology'));
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: LocalizedText('Our Doctors'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          LocalizedText(
            'Search by doctor or specialty',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: localizedText(context, 'Search doctors'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            children: ['All', 'Fertility', 'Andrology'].map((filter) {
              return ChoiceChip(
                label: Text(filter),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
                selectedColor: AppColors.blushPink,
                labelStyle: const TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          ..._doctors.map(_doctorCard),
          const SizedBox(height: 10),
          LocalizedText(
            'Prototype sample data only. Live doctor availability will be supplied by Thaai Seyazhi.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorCard(Doctor doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.blushPink,
            child: Text(
              doctor.initials,
              style: const TextStyle(
                color: AppColors.burgundy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.specialty,
                  style: const TextStyle(
                    color: AppColors.burgundy,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.languages,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorProfileScreen(
                            doctor: doctor,
                            patientName: widget.patientName,
                            mobileNumber: widget.mobileNumber,
                          ),
                        ),
                      ),
                      child: LocalizedText('View profile'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorProfileScreen(
                            doctor: doctor,
                            patientName: widget.patientName,
                            mobileNumber: widget.mobileNumber,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                      ),
                      child: LocalizedText('Request'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
