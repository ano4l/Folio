import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/folio_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _register = false;
  bool _obscure = true;
  int _lastOtpLength = 0;
  Timer? _timer;
  int _remaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    final sent = await state.submitCredentials(
      mode: _register ? 'register' : 'login',
      email: _email.text,
      password: _password.text,
      displayName: _name.text,
    );
    if (sent) _startTimer(state.resendSeconds);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _remaining = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _verify(String code) async {
    if (code.length != 6) return;
    FocusScope.of(context).unfocus();
    final verified = await context.read<AppState>().verifyMfa(code);
    if (verified) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isMfa = state.authStep == 'mfa';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.7, -.85),
            radius: 1.25,
            colors: [Color(0xFFFFFFFF), AppColors.paper],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FolioLogo(size: 42, showTagline: true),
                    const SizedBox(height: 28),
                    Text(
                      isMfa
                          ? 'Check your inbox'
                          : (_register
                              ? 'Create your secure Folio.'
                              : 'Your funding paperwork, finally clear.'),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMfa
                          ? 'Enter the 6-digit verification code sent to ${_email.text.trim()}.'
                          : (_register
                              ? 'One protected place for your student finance documents.'
                              : 'Sign in to understand every letter, deadline and next step.'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.line),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: .06),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: isMfa ? _mfa(state) : _credentials(state),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.slate,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Your data is encrypted in transit and at rest.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _credentials(AppState state) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_register) ...[
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Full name'),
            validator:
                (value) =>
                    (value?.trim().isEmpty ?? true)
                        ? 'Enter your full name'
                        : null,
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email address'),
          validator:
              (value) =>
                  RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter a valid email address',
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          autofillHints:
              _register
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator:
              (value) =>
                  (value?.length ?? 0) < 10
                      ? 'Use at least 10 characters'
                      : null,
          onFieldSubmitted: (_) => _submit(),
        ),
        if (state.authError.isNotEmpty) _error(state.authError),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: state.authLoading ? null : _submit,
          child:
              state.authLoading
                  ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(_register ? 'Create account' : 'Sign in'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed:
              state.authLoading
                  ? null
                  : () => setState(() {
                    _register = !_register;
                    context.read<AppState>().authError = '';
                  }),
          child: Text(
            _register
                ? 'Already have an account? Sign in'
                : 'New to Folio? Create an account',
          ),
        ),
      ],
    ),
  );

  Widget _mfa(AppState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Secure code', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      Pinput(
        length: 6,
        controller: _otp,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofillHints: const [AutofillHints.oneTimeCode],
        separatorBuilder:
            (index) =>
                index == 2
                    ? const SizedBox(
                      width: 28,
                      child: Center(
                        child: SizedBox(
                          width: 10,
                          child: Divider(thickness: 1.5),
                        ),
                      ),
                    )
                    : const SizedBox(width: 7),
        onChanged: (value) {
          if (value.length > _lastOtpLength) HapticFeedback.selectionClick();
          _lastOtpLength = value.length;
        },
        onCompleted: _verify,
        defaultPinTheme: PinTheme(
          width: 48,
          height: 56,
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
        ),
        focusedPinTheme: PinTheme(
          width: 48,
          height: 56,
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.teal, width: 2),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Enter the code from your email. You can paste all six digits at once.',
        style: TextStyle(fontSize: 12, color: AppColors.slate),
      ),
      if (state.authError.isNotEmpty) _error(state.authError),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: state.authLoading ? null : () => _verify(_otp.text),
        child:
            state.authLoading
                ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Text('Verify and open Folio'),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed:
            state.authLoading || _remaining > 0
                ? null
                : () async {
                  if (await state.resendMfa()) _startTimer(state.resendSeconds);
                },
        child: Text(
          _remaining > 0 ? 'Resend code in ${_remaining}s' : 'Resend code',
        ),
      ),
      TextButton(
        onPressed:
            state.authLoading
                ? null
                : () {
                  _otp.clear();
                  _timer?.cancel();
                  state.backToCredentials();
                },
        child: const Text('Use a different account'),
      ),
    ],
  );

  Widget _error(String message) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppColors.danger,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
}
