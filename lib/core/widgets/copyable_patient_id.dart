import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/localized_text.dart';

class CopyablePatientId extends StatelessWidget {
  final String patientId;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? padding;
  final Decoration? decoration;
  final BorderRadius? borderRadius;
  final bool showCopyIcon;

  const CopyablePatientId({
    super.key,
    required this.patientId,
    this.textStyle,
    this.labelStyle,
    this.padding,
    this.decoration,
    this.borderRadius,
    this.showCopyIcon = false,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: patientId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Patient ID copied successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (patientId.isEmpty) return const SizedBox.shrink();

    final id = Semantics(
      button: true,
      label: 'Copy Patient ID $patientId',
      child: InkWell(
        onTap: () => _copy(context),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(patientId, style: textStyle),
              if (showCopyIcon) ...[
                const SizedBox(width: 4),
                Icon(Icons.copy_outlined, size: 12, color: textStyle?.color),
              ],
            ],
          ),
        ),
      ),
    );

    return Container(
      padding: padding,
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LocalizedText('Patient ID', style: labelStyle),
          const SizedBox(width: 4),
          id,
        ],
      ),
    );
  }
}
