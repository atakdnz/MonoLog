import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockProvider with ChangeNotifier, WidgetsBindingObserver {
  AppLockProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  static const String _enabledKey = 'app_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _isEnabled = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  bool _isLoading = true;
  bool _canAuthenticate = false;

  bool get isEnabled => _isEnabled;
  bool get isLocked => _isLocked;
  bool get isAuthenticating => _isAuthenticating;
  bool get isLoading => _isLoading;
  bool get canAuthenticate => _canAuthenticate;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _canAuthenticate = await _checkCanAuthenticate();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    _isLocked = _isEnabled;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _checkCanAuthenticate() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> enableAppLock() async {
    _canAuthenticate = await _checkCanAuthenticate();
    if (!_canAuthenticate) {
      notifyListeners();
      return false;
    }

    final authenticated = await authenticate(
      reason: 'Authenticate to enable App Lock',
      unlockOnSuccess: false,
    );
    if (!authenticated) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    _isEnabled = true;
    _isLocked = false;
    notifyListeners();
    return true;
  }

  Future<void> disableAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    _isEnabled = false;
    _isLocked = false;
    notifyListeners();
  }

  Future<bool> authenticate({
    String reason = 'Unlock MonoLog',
    bool unlockOnSuccess = true,
  }) async {
    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    notifyListeners();

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated && unlockOnSuccess) {
        _isLocked = false;
      }

      return authenticated;
    } catch (_) {
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  void lock() {
    if (!_isEnabled || _isLocked) return;
    _isLocked = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
