import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/widgets/main_shell.dart';

/// Email + password login / signup. Friendly offline error when
/// Firebase is not configured yet.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLogin = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (!email.contains('@')) {
      setState(() => _error = 'Email theek likho.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password kam az kam 6 harf ka ho.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      if (_isLogin) {
        await auth.signIn(email, pass);
      } else {
        await auth.signUp(email, pass);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthService>();
    final emailCtrl = TextEditingController(text: _email.text.trim());
    bool sending = false;
    String? dialogError;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Password reset',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Apni email likho — hum tumhe reset link bhej denge.',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(
                  dialogError!,
                  style: const TextStyle(
                      color: AppTheme.accent2, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() {
                        sending = true;
                        dialogError = null;
                      });
                      try {
                        await auth.sendPasswordReset(emailCtrl.text);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Reset link tumhari Gmail par bhej di hai — wahan se naya password banao.'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          sending = false;
                          dialogError = e
                              .toString()
                              .replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Reset link bhejo'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Chaska',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin ? 'Wapas khush aamdeed!' : 'Naya account banao',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
              const SizedBox(height: 32),
              if (!AuthService.firebaseReady)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Offline mode: Firebase abhi setup nahi hua, is liye login kaam nahi karega.',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password'),
              ),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: const Text(
                      'Password bhool gaye?',
                      style: TextStyle(color: AppTheme.accent2),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.accent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isLogin ? 'Login karo' : 'Account banao'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  _isLogin = !_isLogin;
                  _error = null;
                }),
                child: Text(
                  _isLogin
                      ? 'Naya ho? Account banao'
                      : 'Pehle se account hai? Login karo',
                  style: const TextStyle(color: AppTheme.accent2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
