import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';

class ClinicLocationScreen extends StatelessWidget {
  const ClinicLocationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const LocalizedText('Clinic'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _burgundy,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _burgundy.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _blush,
                child: Icon(
                  Icons.local_hospital_outlined,
                  color: _burgundy,
                  size: 29,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      'Clinic',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    LocalizedText(
                      'Clinic information will appear when provided by your care team.',
                      style: TextStyle(
                        color: _blush,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _InformationCard(
          icon: Icons.info_outline_rounded,
          title: 'Clinic information',
          body: 'No verified clinic address, phone number, email, hours or facilities are available yet.',
        ),
        const SizedBox(height: 12),
        _InformationCard(
          icon: Icons.location_on_outlined,
          title: 'Clinic location',
          body: 'Directions will be enabled after the clinic provides a verified address or coordinates.',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.copy_rounded),
                label: const LocalizedText('Copy address'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.directions_outlined),
                label: const LocalizedText('Get directions'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _InformationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InformationCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: _blush,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _burgundy, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                title,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              LocalizedText(
                body,
                style: const TextStyle(
                  color: _secondaryText,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

const _burgundy = Color(0xFF6B1837);
const _blush = Color(0xFFF8E9EE);
const _primaryText = Color(0xFF30232A);
const _secondaryText = Color(0xFF806D76);
