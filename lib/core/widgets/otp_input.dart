import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final int length;
  final double boxWidth;
  final double boxHeight;
  final TextStyle? textStyle;
  final Color fillColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final MainAxisAlignment mainAxisAlignment;
  final bool autofocus;
  final Color borderColor;
  final Color focusedBorderColor;
  final String? fieldKeyPrefix;

  const OtpInput({
    super.key,
    this.onChanged,
    this.onCompleted,
    this.length = 6,
    this.boxWidth = 48,
    this.boxHeight = 60,
    this.textStyle,
    this.fillColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(11)),
    this.contentPadding = EdgeInsets.zero,
    this.mainAxisAlignment = MainAxisAlignment.spaceEvenly,
    this.autofocus = true,
    this.borderColor = const Color(0xFFE0E0E0),
    this.focusedBorderColor = const Color(0xFF8A1538),
    this.fieldKeyPrefix,
  });

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _updatingControllers = false;
  bool _completionNotified = false;

  String get value => _controllers.map((controller) => controller.text).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void clear() {
    _updatingControllers = true;
    for (final controller in _controllers) {
      controller.clear();
    }
    _updatingControllers = false;
    _completionNotified = false;
    _notifyChanged();
    _focusNodes.first.requestFocus();
  }

  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }

    final controller = _controllers[index];
    _updatingControllers = true;
    if (controller.text.isNotEmpty) {
      controller.clear();
    } else if (index > 0) {
      final previousController = _controllers[index - 1];
      if (previousController.text.isNotEmpty) {
        previousController.clear();
      }
      _focusNodes[index - 1].requestFocus();
    }
    _updatingControllers = false;
    _notifyChanged();
    return KeyEventResult.handled;
  }

  void _onChanged(String value, int index) {
    if (_updatingControllers) return;

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 1) {
      _distribute(digits, index);
      return;
    }

    if (digits != value) {
      _setControllerText(index, digits);
    }
    if (digits.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _notifyChanged();
  }

  void _distribute(String digits, int startIndex) {
    _updatingControllers = true;
    for (
      var offset = 0;
      offset < digits.length && startIndex + offset < widget.length;
      offset++
    ) {
      _controllers[startIndex + offset].text = digits[offset];
    }
    _updatingControllers = false;

    final nextIndex = (startIndex + digits.length)
        .clamp(0, widget.length - 1)
        .toInt();
    _focusNodes[nextIndex].requestFocus();
    _notifyChanged();
  }

  void _setControllerText(int index, String value) {
    _updatingControllers = true;
    _controllers[index].text = value;
    _updatingControllers = false;
  }

  void _notifyChanged() {
    final currentValue = value;
    widget.onChanged?.call(currentValue);
    final isComplete =
        currentValue.length == widget.length &&
        !currentValue.contains(RegExp(r'[^0-9]'));
    if (isComplete && !_completionNotified) {
      _completionNotified = true;
      widget.onCompleted?.call(currentValue);
    } else if (!isComplete) {
      _completionNotified = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumGap = 4 * (widget.length - 1);
        final availableWidth = constraints.maxWidth - minimumGap;
        final fittedWidth = availableWidth / widget.length;
        final boxWidth = fittedWidth < widget.boxWidth
            ? fittedWidth
            : widget.boxWidth;
        return Row(
          mainAxisAlignment: widget.mainAxisAlignment,
          children: List.generate(widget.length, (index) {
            return SizedBox(
              width: boxWidth,
              height: widget.boxHeight,
              child: Focus(
                onKeyEvent: (_, event) => _handleKeyEvent(index, event),
                child: TextField(
                  key: widget.fieldKeyPrefix == null
                      ? null
                      : ValueKey('${widget.fieldKeyPrefix}-$index'),
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  autofocus: widget.autofocus && index == 0,
                  keyboardType: TextInputType.number,
                  textInputAction: index == widget.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  autofillHints: index == 0
                      ? const [AutofillHints.oneTimeCode]
                      : null,
                  textAlign: TextAlign.center,
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: widget.textStyle,
                  onTap: () {
                    if (_controllers[index].text.isNotEmpty) {
                      _controllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _controllers[index].text.length,
                      );
                    }
                  },
                  onChanged: (value) => _onChanged(value, index),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: widget.fillColor,
                    contentPadding: widget.contentPadding,
                    border: OutlineInputBorder(
                      borderRadius: widget.borderRadius,
                      borderSide: BorderSide(color: widget.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: widget.borderRadius,
                      borderSide: BorderSide(color: widget.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: widget.borderRadius,
                      borderSide: BorderSide(
                        color: widget.focusedBorderColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
