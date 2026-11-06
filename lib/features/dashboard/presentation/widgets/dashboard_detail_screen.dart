import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class DashboardDetailScreen extends StatelessWidget {
  final String title;
  final String eyebrow;
  final String description;
  final List<DashboardDetailRow> rows;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DashboardDetailScreen({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.description,
    this.rows = const [],
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primaryText,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.dustyPink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < rows.length; index++) ...[
                      _DetailRow(row: rows[index]),
                      if (index < rows.length - 1)
                        const Divider(color: AppColors.divider, height: 24),
                    ],
                  ],
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashboardDetailRow {
  final String label;
  final String value;
  final IconData icon;

  const DashboardDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _DetailRow extends StatelessWidget {
  final DashboardDetailRow row;

  const _DetailRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.blushPink,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(row.icon, color: AppColors.burgundy, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                row.value,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
