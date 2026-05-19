import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  bool _isLoading = false;
  String? _token;
  String? _userId;
  bool _rememberMe = true;

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get token => _token;
  String? get userId => _userId;
  bool get rememberMe => _rememberMe;

  Future<void> initialize() async {
    _rememberMe = await _authService.getRememberMePreference();
    _token = await _authService.getToken();
    _userId = await _authService.getUserId();

    final hasSession = _rememberMe && _token != null && _token!.isNotEmpty;
    _status = hasSession
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    if (_status == AuthStatus.authenticated) {
      await _authService.registerDeviceToken();
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    _setLoading(true);

    final result = await _authService.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );

    _rememberMe = rememberMe;
    _token = await _authService.getToken();
    _userId = await _authService.getUserId();
    _status = (_token != null && _token!.isNotEmpty)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    if (_status == AuthStatus.authenticated) {
      await _authService.registerDeviceToken();
    }

    _setLoading(false);
    return result;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    final result = await _authService.register(
      email: email,
      password: password,
    );

    _token = await _authService.getToken();
    _userId = await _authService.getUserId();
    _status = (_token != null && _token!.isNotEmpty)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    if (_status == AuthStatus.authenticated) {
      await _authService.registerDeviceToken();
    }

    _setLoading(false);
    return result;
  }

  Future<void> setRememberMePreference(bool value) async {
    _rememberMe = value;
    await _authService.setRememberMePreference(value);
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    await _authService.setRememberMePreference(false);

    _token = null;
    _userId = null;
    _rememberMe = false;
    _status = AuthStatus.unauthenticated;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
