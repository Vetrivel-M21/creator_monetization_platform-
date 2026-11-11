import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../screens/legal/legal_screen.dart';

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AuthSheet(),
    );
  }

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  // Tab 0: Password Sign In
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  // Tab 1: Email OTP
  final _otpEmailController = TextEditingController();
  final _otpCodeController = TextEditingController();
  bool _otpSent = false;
  int _otpCountdown = 0;
  Timer? _countdownTimer;

  // Tab 2: Create Account
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regChannelController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _obscureRegPassword = true;

  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {
          _selectedTab = _tabController.index;
          _errorMessage = null;
          _infoMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _otpEmailController.dispose();
    _otpCodeController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regMobileController.dispose();
    _regChannelController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _startOtpTimer() {
    _countdownTimer?.cancel();
    setState(() => _otpCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpCountdown > 1) {
        setState(() => _otpCountdown--);
      } else {
        timer.cancel();
        setState(() => _otpCountdown = 0);
      }
    });
  }

  Future<void> _handlePasswordLogin() async {
    final id = _loginIdController.text.trim();
    final password = _loginPasswordController.text;

    if (id.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both your email/phone and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final success = await AuthService.instance.login(
      identifier: id,
      password: password,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = 'Invalid email/phone or password. Please verify credentials.');
      }
    }
  }

  Future<void> _handleSendOtp() async {
    final email = _otpEmailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final res = await AuthService.instance.sendOtp(email);
    if (mounted) {
      setState(() => _isLoading = false);
      if (res != null && res['status'] == 'success') {
        setState(() {
          _otpSent = true;
          _infoMessage = res['message'] as String? ?? '6-digit OTP code dispatched to $email';
        });
        _startOtpTimer();
      } else {
        setState(() => _errorMessage = res?['error'] as String? ?? 'Failed to send OTP code. Please try password login.');
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final email = _otpEmailController.text.trim().toLowerCase();
    final otp = _otpCodeController.text.trim();

    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final res = await AuthService.instance.verifyOtp(email: email, otp: otp);
    if (mounted) {
      setState(() => _isLoading = false);
      if (res != null) {
        if (res['user'] != null) {
          Navigator.of(context).pop(true);
        } else if (res['is_new_user'] == true) {
          _regEmailController.text = email;
          _tabController.animateTo(2);
          setState(() {
            _selectedTab = 2;
            _infoMessage = 'Email verified! Complete your name and password below to finish signup.';
          });
        }
      } else {
        setState(() => _errorMessage = 'Invalid or expired OTP code. Please try again.');
      }
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final mobile = _regMobileController.text.trim();
    final password = _regPasswordController.text;
    final channelName = _regChannelController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Full Name, Email, and Password are required');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final success = await AuthService.instance.register(
      name: name,
      email: email,
      password: password,
      mobile: mobile,
      channelName: channelName.isNotEmpty ? channelName : name,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = 'Registration failed. Email or mobile may already be registered.');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final success = await AuthService.instance.signInWithGoogle();

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = 'Google Sign-In was cancelled or failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxAvailableHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxAvailableHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'ARMSS Creator Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3 Tabs: Password, Email OTP, Create Account
              Container(
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Sign In'),
                    Tab(text: 'Email OTP'),
                    Tab(text: 'Sign Up'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.roseLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.rose),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.rose, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_infoMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.emerald),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _infoMessage!,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.emerald, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Dynamic Tab Content (No fixed height constraint)
              if (_selectedTab == 0) _buildPasswordSignInTab(),
              if (_selectedTab == 1) _buildEmailOtpTab(),
              if (_selectedTab == 2) _buildRegisterTab(),

              const SizedBox(height: 18),

              // OR Divider
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // Real Google Sign-In Button with proper branding
              InkWell(
                onTap: _isLoading ? null : _handleGoogleSignIn,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGoogleLogo(),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Terms & Privacy Agreement Notice
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('By continuing, you agree to our ', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => LegalScreen.show(context, initialTabIndex: 0),
                    child: const Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(' and ', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => LegalScreen.show(context, initialTabIndex: 1),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tab 0: Password Sign In
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPasswordSignInTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginIdController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email or Mobile Number',
            hintText: 'creator@example.com',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isLoading ? null : _handlePasswordLogin,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.darkPill,
            foregroundColor: AppColors.darkPillText,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Sign In', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tab 1: Email OTP Sign In
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildEmailOtpTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _otpEmailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_otpSent,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'creator@example.com',
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        if (!_otpSent)
          FilledButton(
            onPressed: _isLoading ? null : _handleSendOtp,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkPill,
              foregroundColor: AppColors.darkPillText,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send Verification Code', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          )
        else ...[
          TextField(
            controller: _otpCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '000000',
              prefixIcon: Icon(Icons.pin_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkPill,
              foregroundColor: AppColors.darkPillText,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify & Continue', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _otpCountdown > 0 ? null : _handleSendOtp,
              child: Text(
                _otpCountdown > 0 ? 'Resend code in ${_otpCountdown}s' : 'Resend Code',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tab 2: Create Account
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildRegisterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _regNameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'Your legal or display name',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'creator@example.com',
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regMobileController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile Number (Optional)',
            hintText: '+91 98765 43210',
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regChannelController,
          decoration: const InputDecoration(
            labelText: 'Channel / Brand Name (Optional)',
            hintText: 'e.g. Anand Studio',
            prefixIcon: Icon(Icons.live_tv_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regPasswordController,
          obscureText: _obscureRegPassword,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Minimum 6 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.darkPill,
            foregroundColor: AppColors.darkPillText,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create Account', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Canvas Painter for the 4-color Google 'G' icon
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.18;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      w - strokeWidth,
      h - strokeWidth,
    );

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.6, false, paint);

    // Yellow arc (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.3, 1.5, false, paint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.7, 1.6, false, paint);

    // Blue arc & bar (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.8, 1.5, false, paint);

    // Blue crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.45, h * 0.42, w * 0.5, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
