import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.baseUrl;
  static const Duration timeoutDuration = Duration(seconds: 30);

  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userId';
  static const String _rememberMeKey = 'rememberMe';
  static const String _hiddenUsersKey = 'hiddenUsers';

  static bool _pushTokenListenerConfigured = false;

  static String? _sessionToken;
  static String? _sessionUserId;

  static Map<String, dynamic> _parseResponse(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️ JSON Parse Error: $e');
      print('📄 Response body: $body');

      return {
        'success': false,
        'message': 'Invalid server response',
        'error': true,
      };
    }
  }

  static Future<Map<String, String>> _buildHeaders({String? token}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Map<String, dynamic> _handleError(dynamic error) {
    return {
      'success': false,
      'message': 'Network error. Please check your connection.',
      'error': true,
      'details': error.toString(),
    };
  }

  String _extractUserId(Map<String, dynamic> data) {
    final user = data['user'];

    return data['userId']?.toString() ??
        (user is Map ? user['id']?.toString() : null) ??
        (user is Map ? user['_id']?.toString() : null) ??
        '';
  }

  String _extractUserName(Map<String, dynamic> data) {
    final user = data['user'];

    return (user is Map ? user['name']?.toString() : null) ??
        data['name']?.toString() ??
        '';
  }

  String _extractUserEmail(Map<String, dynamic> data, String fallbackEmail) {
    final user = data['user'];

    return (user is Map ? user['email']?.toString() : null) ??
        data['email']?.toString() ??
        fallbackEmail;
  }

  String _extractUserRole(Map<String, dynamic> data) {
    final user = data['user'];

    return (user is Map ? user['role']?.toString() : null) ??
        data['role']?.toString() ??
        'user';
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: await _buildHeaders(),
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'password': password.trim(),
              'role': 'user',
            }),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();

        final token = data['token']?.toString() ?? '';
        final userId = _extractUserId(data);

        _sessionToken = token;
        _sessionUserId = userId;

        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userIdKey, userId);
        await prefs.setString('chefId', data['chefId']?.toString() ?? '');
        await prefs.setString('userName', _extractUserName(data));
        await prefs.setString('userEmail', _extractUserEmail(data, email));
        await prefs.setString('userRole', _extractUserRole(data));
        await prefs.setBool(_rememberMeKey, true);

        await registerDeviceToken();

        return {
          'success': true,
          ...data,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Register failed',
        ...data,
      };
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: await _buildHeaders(),
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'password': password.trim(),
            }),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);

      print("LOGIN STATUS => ${response.statusCode}");
      print("LOGIN DATA => $data");

      if (response.statusCode != 200 || data['token'] == null) {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
          ...data,
        };
      }

      final prefs = await SharedPreferences.getInstance();

      final token = data['token']?.toString() ?? '';
      final userId = _extractUserId(data);

      _sessionToken = token;
      _sessionUserId = userId;

      if (rememberMe) {
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userIdKey, userId);
      } else {
        await prefs.remove(_tokenKey);
        await prefs.remove(_userIdKey);
      }

      await prefs.setBool(_rememberMeKey, rememberMe);

      await prefs.setString('chefId', data['chefId']?.toString() ?? '');
      await prefs.setString('userName', _extractUserName(data));
      await prefs.setString('userEmail', _extractUserEmail(data, email));
      await prefs.setString('userRole', _extractUserRole(data));

      print("TOKEN SAVED => $token");
      print("USER ID SAVED => $userId");

      await registerDeviceToken();

      return {
        'success': true,
        ...data,
      };
    } catch (e) {
      print("LOGIN ERROR => $e");
      return _handleError(e);
    }
  }

  Future<String?> getToken() async {
    if (_sessionToken != null && _sessionToken!.trim().isNotEmpty) {
      return _sessionToken;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String> getUserId() async {
    if (_sessionUserId != null && _sessionUserId!.trim().isNotEmpty) {
      return _sessionUserId!;
    }

    final prefs = await SharedPreferences.getInstance();

    final savedUserId = prefs.getString(_userIdKey) ?? '';

    print("🔥 GET USER ID => $savedUserId");

    return savedUserId;
  }

  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName') ?? '';
  }

  Future<bool> getRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? true;
  }

  Future<void> setRememberMePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<void> logout() async {
    _sessionToken = null;
    _sessionUserId = null;

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove('chefId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userRole');

    // نخلي rememberMe والـ hidden users عادي، ما نمسحهم
  }

  Future<void> registerDeviceToken() async {
    try {
      final authToken = await getToken();

      if (authToken == null || authToken.trim().isEmpty) {
        print('⚠️ No auth token, cannot register FCM token');
        return;
      }

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('🔔 Notification permission: ${settings.authorizationStatus}');

      String? fcmToken;

      if (kIsWeb) {
        fcmToken = await FirebaseMessaging.instance.getToken(
          vapidKey:
              'BH6dtgwzQsyLAMbNVkELiI99n-kedBjhhCWSqBujXEQr3XDNS_QEtkzf4e6mZDBjfy4YkywZDn8rxlIpU8-RoXk',
        );
      } else {
        fcmToken = await FirebaseMessaging.instance.getToken();
      }

      print('🔥 FCM Token: $fcmToken');

      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        await _sendDeviceTokenToBackend(fcmToken.trim(), authToken);
      }

      if (!_pushTokenListenerConfigured) {
        _pushTokenListenerConfigured = true;

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          final token = await getToken();

          if (token == null || token.trim().isEmpty) {
            return;
          }

          await _sendDeviceTokenToBackend(newToken.trim(), token);
        });
      }
    } catch (e) {
      print('⚠️ registerDeviceToken failed: $e');
    }
  }

  Future<void> _sendDeviceTokenToBackend(
    String fcmToken,
    String authToken,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/device-token'),
            headers: await _buildHeaders(token: authToken),
            body: jsonEncode({
              'token': fcmToken,
            }),
          )
          .timeout(timeoutDuration);

      print('📤 Save FCM token status: ${response.statusCode}');
      print('📤 Save FCM token body: ${response.body}');

      if (response.statusCode >= 400) {
        print('⚠️ Saving device token failed: ${response.body}');
      }
    } catch (e) {
      print('⚠️ _sendDeviceTokenToBackend failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHiddenUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_hiddenUsersKey) ?? <String>[];

    return rawList
        .map((item) {
          try {
            final decoded = jsonDecode(item);

            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}

          return <String, dynamic>{};
        })
        .where((item) => (item['id']?.toString() ?? '').trim().isNotEmpty)
        .toList();
  }

  Future<void> hideUser({
    required String userId,
    required String name,
    String? imageUrl,
  }) async {
    final normalizedId = userId.trim();

    if (normalizedId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await getHiddenUsers();

    final updated = <Map<String, dynamic>>[
      ...current.where((item) => item['id']?.toString() != normalizedId),
      {
        'id': normalizedId,
        'name': name.trim().isEmpty ? 'User' : name.trim(),
        'imageUrl': (imageUrl ?? '').trim(),
      },
    ];

    await prefs.setStringList(
      _hiddenUsersKey,
      updated.map(jsonEncode).toList(),
    );
  }

  Future<void> unhideUser(String userId) async {
    final normalizedId = userId.trim();

    if (normalizedId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await getHiddenUsers();

    final updated = current
        .where((item) => item['id']?.toString() != normalizedId)
        .toList();

    await prefs.setStringList(
      _hiddenUsersKey,
      updated.map(jsonEncode).toList(),
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateUserName({
    String? userId,
    required String name,
  }) async {
    try {
      final token = await getToken();

      final body = <String, dynamic>{
        'name': name,
      };

      if (userId != null && userId.trim().isNotEmpty) {
        body['userId'] = userId;
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/auth/update-name'),
            headers: token == null
                ? await _buildHeaders()
                : await _buildHeaders(token: token),
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);

      if (data['success'] == true || response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', name);
      }

      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> saveProfile({
    required String name,
    String? email,
    File? imageFile,
    required String goal,
    required String gender,
    required String dateOfBirth,
    required int heightValue,
    required String heightUnit,
    required double weightValue,
    required String weightUnit,
    required String activityLevel,
    required List<String> allergies,
    required List<String> medicalConditions,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      if (imageFile != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/user-profile'),
        );

        request.headers['Authorization'] = 'Bearer $token';

        request.fields['name'] = name;
        request.fields['goal'] = goal;
        request.fields['gender'] = gender;
        request.fields['date_of_birth'] = dateOfBirth;
        request.fields['height_value'] = heightValue.toString();
        request.fields['height_unit'] = heightUnit;
        request.fields['weight_value'] = weightValue.toString();
        request.fields['weight_unit'] = weightUnit;
        request.fields['activity_level'] = activityLevel;
        request.fields['allergies'] = jsonEncode(allergies);
        request.fields['medical_conditions'] = jsonEncode(medicalConditions);

        if (email != null && email.trim().isNotEmpty) {
          request.fields['email'] = email.trim();
        }

        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );

        final streamedResponse = await request.send().timeout(timeoutDuration);
        final response = await http.Response.fromStream(streamedResponse);

        return _parseResponse(response.body);
      }

      final requestBody = <String, dynamic>{
        'name': name,
        'goal': goal,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'height_value': heightValue,
        'height_unit': heightUnit,
        'weight_value': weightValue,
        'weight_unit': weightUnit,
        'activity_level': activityLevel,
        'allergies': allergies,
        'medical_conditions': medicalConditions,
      };

      if (email != null && email.trim().isNotEmpty) {
        requestBody['email'] = email.trim();
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/user-profile'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateStreak({
    required int streakCount,
    required List<DateTime> streakDates,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/user-profile/streak'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({
              'streak_count': streakCount,
              'streak_dates': streakDates
                  .map(
                    (date) => DateTime(
                      date.year,
                      date.month,
                      date.day,
                    ).toIso8601String(),
                  )
                  .toList(),
            }),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUsersStreaks() async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/user-profile/users-streaks'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> searchUsers(String query) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No token',
          'error': true,
        };
      }

      final uri = Uri.parse(
        '$baseUrl/user-profile/search?q=${Uri.encodeQueryComponent(query)}',
      );

      final response = await http
          .get(
            uri,
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPosts() async {
    try {
      final token = await getToken();

      final response = await http
          .get(
            Uri.parse('$baseUrl/posts'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String authorName,
    String? authorImageUrl,
    String? text,
    File? imageFile,
    double? calories,
    double? fat,
    double? carbs,
    double? protein,
    String visibility = 'public',
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No token',
          'error': true,
        };
      }

      print('🔗 POST $baseUrl/posts');

      if (imageFile != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/posts'),
        );

        request.headers['Authorization'] = 'Bearer $token';

        if (text != null) request.fields['text'] = text;
        if (authorName.isNotEmpty) request.fields['authorName'] = authorName;
        if (authorImageUrl != null) {
          request.fields['authorImageUrl'] = authorImageUrl;
        }

        if (calories != null) request.fields['calories'] = calories.toString();
        if (fat != null) request.fields['fat'] = fat.toString();
        if (carbs != null) request.fields['carbs'] = carbs.toString();
        if (protein != null) request.fields['protein'] = protein.toString();

        request.fields['visibility'] = visibility == 'followers_only'
            ? 'followers_only'
            : 'public';

        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );

        final streamed = await request.send().timeout(timeoutDuration);
        final response = await http.Response.fromStream(streamed);

        return _parseResponse(response.body);
      }

      final body = {
        'authorName': authorName,
        if (authorImageUrl != null) 'authorImageUrl': authorImageUrl,
        if (text != null) 'text': text,
        if (calories != null) 'calories': calories,
        if (fat != null) 'fat': fat,
        if (carbs != null) 'carbs': carbs,
        if (protein != null) 'protein': protein,
        'visibility':
            visibility == 'followers_only' ? 'followers_only' : 'public',
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> togglePostLike({
    required String postId,
    required String userId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'error': true,
          'message': 'No token',
        };
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts/$postId/like'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({
              'userId': userId,
            }),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addPostComment({
    required String postId,
    required String authorName,
    String? authorImageUrl,
    required String text,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'error': true,
          'message': 'No token',
        };
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts/$postId/comment'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({
              'authorName': authorName,
              'authorImageUrl': authorImageUrl,
              'text': text,
            }),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deletePost({
    required String postId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'error': true,
          'message': 'No token',
        };
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/posts/$postId'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendResetCode({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/send-code'),
            headers: await _buildHeaders(),
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
            }),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);
      data['statusCode'] = response.statusCode;

      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/verify-code'),
            headers: await _buildHeaders(),
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'code': code.trim(),
            }),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);
      data['statusCode'] = response.statusCode;

      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/reset'),
            headers: await _buildHeaders(),
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);
      data['statusCode'] = response.statusCode;

      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> toggleFollow({
    required String targetUserId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/follow/toggle'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({
              'targetUserId': targetUserId,
            }),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFollowers({
    required String userId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$userId/followers'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFollowing({
    required String userId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$userId/following'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> checkFollowStatus({
    required String targetUserId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$targetUserId/status'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserStats({
    required String userId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$userId/stats'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      print('NOTIFICATIONS STATUS => ${response.statusCode}');
      print('NOTIFICATIONS BODY => ${response.body}');

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> markNotificationAsRead({
    required String notificationId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/notifications/$notificationId/read'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final token = await getToken();

      if (token == null || token.trim().isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'error': true,
        };
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/notifications/read-all'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }
}