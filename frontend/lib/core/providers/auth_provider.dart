import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/cart_service.dart';

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
  String? _sessionMessage;

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get token => _token;
  String? get userId => _userId;
  bool get rememberMe => _rememberMe;
  String? get sessionMessage => _sessionMessage;

  Future<void> initialize() async {
    _rememberMe = await _authService.getRememberMePreference();
    _token = await _authService.getToken();
    _userId = await _authService.getUserId();

    final hasSession = _rememberMe && _token != null && _token!.isNotEmpty;

    if (hasSession) {
      final validation = await _authService.fetchCurrentUser();

      if (validation['success'] == true) {
        _status = AuthStatus.authenticated;
        _sessionMessage = null;
        await _authService.registerDeviceToken();
      } else {
        _status = AuthStatus.unauthenticated;
        _sessionMessage = validation['message']?.toString();
        _token = null;
        _userId = null;
      }
    } else {
      _status = AuthStatus.unauthenticated;
      _sessionMessage = null;
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    _setLoading(true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      debugPrint("LOGIN STATUS => ${response.statusCode}");
      debugPrint("LOGIN DATA => $data");

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        final token = data['token'];

        if (token != null) {
          await prefs.setString('token', token.toString());
          _token = token.toString();
        }

        final user = data['user'];

        if (user != null) {
          final savedUserId = user['id'] ?? user['_id'] ?? data['userId'];

          if (savedUserId != null) {
            await prefs.setString('userId', savedUserId.toString());
            _userId = savedUserId.toString();
          }

          await prefs.setString('userName', user['name']?.toString() ?? '');

          await prefs.setString('userEmail', user['email']?.toString() ?? '');

          await prefs.setString('userRole', user['role']?.toString() ?? '');

          if (user['profileImage'] != null) {
            await prefs.setString(
              'profileImage',
              user['profileImage'].toString(),
            );
          }
        } else if (data['userId'] != null) {
          await prefs.setString('userId', data['userId'].toString());
          _userId = data['userId'].toString();
        }

        _rememberMe = rememberMe;
        await prefs.setBool('rememberMe', rememberMe);
        _sessionMessage = null;

        _status = (_token != null && _token!.isNotEmpty)
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;

        if (_status == AuthStatus.authenticated) {
          await _authService.registerDeviceToken();
          await CartService.init();
        }

        notifyListeners();

        return {'success': true, 'data': data};
      }

      _status = AuthStatus.unauthenticated;
      _sessionMessage = data['message']?.toString();
      notifyListeners();

      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      debugPrint("LOGIN ERROR => $e");

      _status = AuthStatus.unauthenticated;
      _sessionMessage = e.toString();
      notifyListeners();

      return {'success': false, 'message': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    try {
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
        await CartService.init();
      }

      notifyListeners();

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setRememberMePreference(bool value) async {
    _rememberMe = value;
    await _authService.setRememberMePreference(value);
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    await _authService.setRememberMePreference(false);
    CartService.reset();

    _token = null;
    _userId = null;
    _rememberMe = false;
    _status = AuthStatus.unauthenticated;
    _sessionMessage = null;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
