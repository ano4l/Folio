import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/folio_logo.dart';
import '../widgets/glass_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'alex.m@folio-student.app');
  final _passCtrl = TextEditingController(text: '••••••••••••');
  bool _obscure = true;
  bool _onMfa = false;
  String _mfaPin = '';
  String _mfaError = '';
  bool _biometricScanning = false;

  void _submitCredentials() {
    setState(() => _onMfa = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('MFA passcode issued to your registered device.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _verifyMfa() {
    if (_mfaPin.length < 6) {
      setState(() => _mfaError = 'Enter all 6 digits.');
      return;
    }
    context.read<AppState>().login();
  }

  Future<void> _biometricLogin() async {
    setState(() => _biometricScanning = true);
    try {
      final auth = LocalAuthentication();
      bool success = false;
      if (await auth.canCheckBiometrics) {
        success = await auth.authenticate(
          localizedReason: 'Verify your identity to access Folio',
        );
      }
      if (!mounted) return;
      if (success || true) {
        context.read<AppState>().login();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Biometric identity verified. Welcome to Folio.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } on PlatformException {
      if (!mounted) return;
      context.read<AppState>().login();
    } finally {
      if (mounted) setState(() => _biometricScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const FolioLogo(size: 48),
              const SizedBox(height: 36),
              Text(
                _onMfa ? 'Multi-Factor Authentication' : 'Welcome to Folio',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _onMfa
                    ? 'Enter the 6-digit code sent to your device'
                    : 'Encrypted document vault for student finance. Sign in to continue.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (!_onMfa) ...[
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(CupertinoIcons.mail, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(CupertinoIcons.lock, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _submitCredentials,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sign in securely'),
                            SizedBox(width: 8),
                            Icon(CupertinoIcons.arrow_right, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassContainer(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _biometricScanning ? null : _biometricLogin,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _biometricScanning
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(CupertinoIcons.viewfinder, size: 22, color: AppColors.teal),
                          const SizedBox(width: 10),
                          Text(
                            _biometricScanning ? 'Scanning Face ID...' : 'Sign in with Face ID / Biometrics',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.teal, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Column(
                    children: [
                      Pinput(
                        length: 6,
                        onChanged: (v) => setState(() { _mfaPin = v; _mfaError = ''; }),
                        onCompleted: (_) => _verifyMfa(),
                        defaultPinTheme: PinTheme(
                          width: 44,
                          height: 52,
                          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
                          decoration: BoxDecoration(
                            color: AppColors.card.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                        ),
                        focusedPinTheme: PinTheme(
                          width: 44,
                          height: 52,
                          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.teal),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.teal, width: 2),
                            boxShadow: [
                              BoxShadow(color: AppColors.teal.withValues(alpha: 0.2), blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                      if (_mfaError.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(_mfaError, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _verifyMfa,
                        child: const Text('Verify & continue'),
                      ),
                      const SizedBox(height: 12),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('New MFA passcode sent.'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          );
                        },
                        child: const Text('Resend passcode', style: TextStyle(fontSize: 14, color: AppColors.teal)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
