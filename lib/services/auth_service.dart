import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Email/password auth with graceful offline mode.
///
/// Works in two modes:
/// - Firebase ready: real FirebaseAuth (email sign-in/up, sign-out).
/// - Firebase NOT ready (no google-services.json yet): every auth call
///   throws a friendly Roman-Urdu message instead of a raw Firebase error,
///   so the app never crashes and screens stay usable.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Set by main() after the Firebase.initializeApp() attempt.
  static bool firebaseReady = false;

  static const String offlineMsg =
      'Internet/Firebase se rabta nahi ho saka. Pehle Firebase setup hoga, phir login chalega.';

  FirebaseAuth? _auth;
  User? _user;
  bool _initialized = false;

  FirebaseAuth get _authSafe {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  User? get currentUser => _user;
  bool get isSignedIn => _user != null;
  String? get uid => _user?.uid;

  /// Friendly display name: email prefix, or 'chaska_user'.
  String get displayName {
    final email = _user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'chaska_user';
  }

  void _ensureReady() {
    if (!firebaseReady) throw Exception(offlineMsg);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!firebaseReady) return;
    try {
      _user = _authSafe.currentUser;
      _authSafe.authStateChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService.init failed: $e');
    }
  }

  Future<void> signUp(String email, String password) async {
    _ensureReady();
    try {
      final cred = await _authSafe.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = cred.user;
      await _cacheEmail(email.trim());
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> signIn(String email, String password) async {
    _ensureReady();
    try {
      final cred = await _authSafe.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = cred.user;
      await _cacheEmail(email.trim());
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> signOut() async {
    if (!firebaseReady) {
      _user = null;
      notifyListeners();
      return;
    }
    try {
      await _authSafe.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut failed: $e');
    }
    _user = null;
    notifyListeners();
  }

  Future<void> _cacheEmail(String email) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('chaska_last_email', email);
    } catch (_) {}
  }

  Future<String?> lastEmail() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString('chaska_last_email');
    } catch (_) {
      return null;
    }
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Ye email registered nahi hai. Pehle account banao.';
      case 'wrong-password':
        return 'Password ghalat hai. Dobara try karo.';
      case 'invalid-credential':
        return 'Email ya password ghalat hai.';
      case 'email-already-in-use':
        return 'Ye email pehle se registered hai. Login karo.';
      case 'weak-password':
        return 'Password kam az kam 6 harf ka rakho.';
      case 'invalid-email':
        return 'Email theek likho.';
      case 'network-request-failed':
        return 'Internet nahi chal raha. Connection check karo.';
      default:
        return 'Kuch ghalat ho gaya (${e.code}). Dobara try karo.';
    }
  }
}
