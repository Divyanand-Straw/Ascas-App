import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';
import 'linked_member_access_screen.dart';

class LinkedMemberOtpScreen extends StatefulWidget {
  final String mobileNumber;
  final String? challengeId;
  final int initialCountdownSeconds;

  const LinkedMemberOtpScreen({
    super.key,
    required this.mobileNumber,
    this.challengeId,
    this.initialCountdownSeconds = 45,
  });

  @override
  State<LinkedMemberOtpScreen> createState() => _LinkedMemberOtpScreenState();
}

class _LinkedMemberOtpScreenState extends State<LinkedMemberOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  Timer? _timer;
  late int _remainingSeconds;
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isResending = false;

  late String _currentChallengeId;
  int? _remainingAttempts;

  @override
  void initState() {
    super.initState();
    _currentChallengeId = widget.challengeId ?? '';
    _remainingSeconds = widget.initialCountdownSeconds;
    _startTimer();

    if (_currentChallengeId.isEmpty) {
      _requestInitialOtp();
    }
  }

  Future<void> _requestInitialOtp() async {
    try {
      final res = await AuthRepository.instance.sendOtp(
        phone: widget.mobileNumber,
        purpose: OtpPurpose.linkedMember,
      );
      if (mounted) {
        setState(() {
          _currentChallengeId = res.challengeId;
          _remainingSeconds = res.retryAfterSeconds;
        });
        _startTimer();
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredOtp =>
      _controllers.map((controller) => controller.text).join();

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _maskedMobile {
    final mobile = widget.mobileNumber;
    if (mobile.length < 4) return mobile;
    return '${mobile.substring(0, 2)}XXXXXX${mobile.substring(mobile.length - 2)}';
  }

  void _onOtpChanged(String value, int index) {
    setState(() {
      _errorMessage = null;
    });

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _enteredOtp.trim();

    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit OTP.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.verifyOtp(
        challengeId: _currentChallengeId,
        phone: widget.mobileNumber,
        purpose: OtpPurpose.linkedMember,
        otp: otp,
      );

      _timer?.cancel();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LinkedMemberAccessScreen(
            mobileNumber: widget.mobileNumber,
          ),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      if (e.errorCode == 'INVALID_OTP') {
        setState(() {
          _remainingAttempts = e.remainingAttempts;
          _errorMessage = e.remainingAttempts != null
              ? 'Invalid OTP. ${e.remainingAttempts} attempt(s) remaining.'
              : 'Invalid OTP. Please try again.';
        });
      } else if (e.errorCode == 'MAX_ATTEMPTS_EXCEEDED') {
        setState(() {
          _remainingAttempts = 0;
          _errorMessage =
              'Maximum attempts exceeded. Please request a new code.';
        });
      } else {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verification failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_remainingSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthRepository.instance.sendOtp(
        phone: widget.mobileNumber,
        purpose: OtpPurpose.linkedMember,
      );

      for (final controller in _controllers) {
        controller.clear();
      }

      _focusNodes[0].requestFocus();

      setState(() {
        _currentChallengeId = res.challengeId;
        _remainingSeconds = res.retryAfterSeconds;
        _remainingAttempts = null;
      });

      _startTimer();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code has been dispatched.'),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend code: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLockedOut = _remainingAttempts == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primaryText,
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'STEP 3 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mobile verification',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify your mobile',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit verification code sent to $_maskedMobile',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 46,
                    height: 54,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.burgundy,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onOtpChanged(value, index),
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _remainingSeconds == 0 && !_isResending
                        ? _resendOtp
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.burgundy,
                      disabledForegroundColor:
                          AppColors.secondaryText.withValues(alpha: 0.5),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Resend Code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLockedOut || _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Verify and proceed'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
