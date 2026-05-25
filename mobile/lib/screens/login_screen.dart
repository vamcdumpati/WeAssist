import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

enum _LoginStep { enterPhone, enterOtp }

class SlideFadeTransition extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const SlideFadeTransition({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1.0 - value) * 24), child: childWidget),
        );
      },
      child: child,
    );
  }
}

class ElderlyWalkingPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  ElderlyWalkingPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    final double scaleX = size.width / 100;
    final double scaleY = size.height / 100;
    final double groundY = 82 * scaleY;
    final double hipX = 40 * scaleX;
    final double hipY = 52 * scaleY;
    final double shoulderX = 46 * scaleX;
    final double shoulderY = 32 * scaleY;
    final double neckX = 50 * scaleX;
    final double neckY = 26 * scaleY;
    final double swing = sin(animationValue * 2 * pi);
    final double foot1X = (43 + swing * 11) * scaleX;
    final double foot2X = (43 - swing * 11) * scaleX;
    final double caneX = (64 + swing * 6) * scaleX;
    final double handX = 56 * scaleX;
    final double handY = 44 * scaleY;
    canvas.drawLine(Offset(hipX, hipY), Offset(foot2X, groundY), paint);
    canvas.drawLine(Offset(hipX, hipY), Offset(foot1X, groundY), paint);
    final spinePath = Path()
      ..moveTo(hipX, hipY)
      ..quadraticBezierTo(30 * scaleX, 40 * scaleY, shoulderX, shoulderY)
      ..lineTo(neckX, neckY);
    canvas.drawPath(spinePath, paint);
    canvas.drawCircle(Offset(54 * scaleX, 18 * scaleY), 5.5 * scaleX, fillPaint);
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(handX, handY), paint);
    canvas.drawLine(Offset(handX, handY), Offset(caneX, groundY), paint);
    final handlePath = Path()
      ..moveTo(handX, handY)
      ..quadraticBezierTo(handX - 3 * scaleX, handY - 5 * scaleY, handX - 7 * scaleX, handY - 1 * scaleY);
    canvas.drawPath(handlePath, paint);
  }

  @override
  bool shouldRepaint(covariant ElderlyWalkingPainter old) =>
      old.animationValue != animationValue || old.color != color;
}

class ElderlyWalkingAnimation extends StatefulWidget {
  const ElderlyWalkingAnimation({super.key});
  @override
  State<ElderlyWalkingAnimation> createState() => _ElderlyWalkingAnimationState();
}

class _ElderlyWalkingAnimationState extends State<ElderlyWalkingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => SizedBox(
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, spreadRadius: 2)],
              ),
            ),
            CustomPaint(
              size: const Size(90, 90),
              painter: ElderlyWalkingPainter(animationValue: _controller.value, color: AppTheme.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();

  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  _LoginStep _step = _LoginStep.enterPhone;
  String? _localError;

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _handleSendOtp() {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() => _localError = null);
    final mobile = '+91${_mobileController.text.trim()}';
    Provider.of<AuthProvider>(context, listen: false).sendOtp(
      mobile: mobile,
      onOtpSent: () { if (mounted) setState(() => _step = _LoginStep.enterOtp); },
      onFailure: (err) { if (mounted) setState(() => _localError = err); },
    );
  }

  void _handleVerifyOtp() {
    if (!_otpFormKey.currentState!.validate()) return;
    setState(() => _localError = null);
    Provider.of<AuthProvider>(context, listen: false).verifyOtpCode(
      smsCode: _otpController.text.trim(),
      onSuccess: () { if (mounted) Navigator.pushReplacementNamed(context, '/dashboard'); },
      onFailure: (err) { if (mounted) setState(() => _localError = err); },
    );
  }

  String get _subtitle {
    switch (_step) {
      case _LoginStep.enterPhone: return 'Enter your mobile number to receive a verification code';
      case _LoginStep.enterOtp: return 'Enter the 6-digit code sent to +91 ${_mobileController.text}';
    }
  }

  Widget _buildStepIndicator() {
    final steps = ['Phone', 'OTP'];
    final currentIndex = _LoginStep.values.indexOf(_step);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final done = i < currentIndex;
        final active = i == currentIndex;
        return Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: active ? 28 : 20,
            height: 20,
            decoration: BoxDecoration(
              color: done || active ? AppTheme.primaryBlue : AppTheme.textSecondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : Text('${i + 1}',
                    style: TextStyle(color: active ? Colors.white : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          if (i < steps.length - 1)
            Container(
              width: 32, height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: done ? AppTheme.primaryBlue : AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
        ]);
      }),
    );
  }

  Widget _buildErrorBox() {
    if (_localError == null) return const SizedBox.shrink();
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.errorRed, width: 0.8),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_localError!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13))),
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildPhoneStep(AuthProvider auth) {
    return Form(
      key: _phoneFormKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SlideFadeTransition(
          delayMs: 300,
          child: TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: InputDecoration(
              labelText: 'Mobile Number',
              hintText: '10-digit mobile number',
              prefixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(width: 12),
                  Icon(Icons.phone_iphone, color: AppTheme.primaryBlue),
                  SizedBox(width: 8),
                  Text('+91 ', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Mobile number is required';
              if (val.trim().length != 10) return 'Must be exactly 10 digits';
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(val.trim())) return 'Enter a valid Indian mobile number';
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
        SlideFadeTransition(
          delayMs: 400,
          child: auth.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send OTP'),
                  onPressed: _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildOtpStep(AuthProvider auth) {
    return Form(
      key: _otpFormKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SlideFadeTransition(
          delayMs: 300,
          child: TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              hintText: '------',
              hintStyle: TextStyle(letterSpacing: 8, fontSize: 24),
              prefixIcon: Icon(Icons.lock_clock, color: AppTheme.secondaryCyan),
            ),
            validator: (val) {
              if (val == null || val.trim().length != 6) return 'Enter the 6-digit OTP';
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
        SlideFadeTransition(
          delayMs: 400,
          child: auth.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Verify & Continue'),
                  onPressed: _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        SlideFadeTransition(
          delayMs: 500,
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Change mobile number'),
            onPressed: () => setState(() { _step = _LoginStep.enterPhone; _localError = null; _otpController.clear(); }),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2F2F7), Color(0xFFFFFFFF)],
            ),
          ),
          child: Stack(children: [
            Positioned(
              top: -80, right: -80,
              child: Container(width: 250, height: 250, decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppTheme.primaryBlue.withValues(alpha: 0.06), Colors.transparent]),
              )),
            ),
            Positioned(
              bottom: -80, left: -80,
              child: Container(width: 250, height: 250, decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppTheme.secondaryCyan.withValues(alpha: 0.06), Colors.transparent]),
              )),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SlideFadeTransition(delayMs: 0, child: ElderlyWalkingAnimation()),
                      const SizedBox(height: 16),
                      SlideFadeTransition(
                        delayMs: 100,
                        child: Text('We Assist',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5),
                          textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 8),
                      SlideFadeTransition(
                        delayMs: 200,
                        child: Text(_subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 20),
                      SlideFadeTransition(delayMs: 250, child: _buildStepIndicator()),
                      const SizedBox(height: 24),
                      _buildErrorBox(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _step == _LoginStep.enterPhone
                              ? _buildPhoneStep(auth)
                              : _buildOtpStep(auth),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
