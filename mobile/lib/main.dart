import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/folio_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const FolioApp()));
  await state.initialize();
}

class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Folio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: switch (state.authStep) {
        'checking' => const _LaunchScreen(),
        'authenticated' => const _AuthenticatedGate(),
        _ => const LoginScreen(),
      },
    );
  }
}

class _AuthenticatedGate extends StatefulWidget {
  const _AuthenticatedGate();
  @override
  State<_AuthenticatedGate> createState() => _AuthenticatedGateState();
}

class _AuthenticatedGateState extends State<_AuthenticatedGate>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _authenticating = false;
  bool _biometricPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAvailabilityAndUnlock(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<AppState>().lock();
    }
  }

  Future<void> _checkAvailabilityAndUnlock() async {
    final state = context.read<AppState>();
    try {
      final available =
          await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
      if (!mounted) return;
      state.setBiometricAvailable(available);
      if (state.appLocked && available) await _unlock();
      if (state.appLocked && !available) state.unlock();
      if (!state.appLocked &&
          available &&
          !state.biometricEnabled &&
          !_biometricPromptShown) {
        _biometricPromptShown = true;
        await _offerBiometricSetup();
      }
    } on PlatformException {
      if (mounted) state.setBiometricAvailable(false);
    }
  }

  Future<void> _offerBiometricSetup() async {
    final enable = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Enable biometric unlock?'),
            content: const Text(
              'Protect your Folio vault with Face ID or fingerprint the next time you open the app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enable'),
              ),
            ],
          ),
    );
    if (enable != true || !mounted) return;

    try {
      final verified = await _auth.authenticate(
        localizedReason: 'Confirm your identity to enable biometric unlock',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (verified && mounted) {
        await context.read<AppState>().setBiometricEnabled(true);
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock could not be enabled.')),
      );
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    try {
      final success = await _auth.authenticate(
        localizedReason: 'Unlock your encrypted Folio vault',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (success && mounted) context.read<AppState>().unlock();
    } on PlatformException {
      // Keep the app locked. The user can retry or sign out.
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.appLocked) return const MainShell();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: FolioLogo(size: 48),
              ),
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 46,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Folio is locked',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Verify your fingerprint or face to reopen your private document vault.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _authenticating ? null : _unlock,
                icon:
                    _authenticating
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.fingerprint_rounded),
                label: Text(_authenticating ? 'Verifying…' : 'Unlock Folio'),
              ),
              TextButton(
                onPressed: state.logout,
                child: const Text('Sign out instead'),
              ),
              const Spacer(),
              const Text(
                'Your biometric data stays on this device.',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FolioLogo(size: 56),
          SizedBox(height: 20),
          CircularProgressIndicator(strokeWidth: 2),
        ],
      ),
    ),
  );
}
