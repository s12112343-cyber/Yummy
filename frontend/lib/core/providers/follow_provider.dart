import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class FollowProvider extends ChangeNotifier {
  FollowProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  final Map<String, bool> _followStatusCache = {};
  final Map<String, int> _followerCountCache = {};
  final Map<String, int> _followingCountCache = {};
  final Map<String, List<dynamic>> _followersListCache = {};
  final Map<String, List<dynamic>> _followingListCache = {};
  bool _isLoading = false;

  Map<String, bool> get followStatusCache => _followStatusCache;
  Map<String, int> get followerCountCache => _followerCountCache;
  Map<String, int> get followingCountCache => _followingCountCache;
  bool get isLoading => _isLoading;

  bool isFollowing(String userId) {
    return _followStatusCache[userId] ?? false;
  }

  int getFollowerCount(String userId) {
    return _followerCountCache[userId] ?? 0;
  }

  int getFollowingCount(String userId) {
    return _followingCountCache[userId] ?? 0;
  }

  Future<Map<String, dynamic>> toggleFollow({
    required String targetUserId,
  }) async {
    _isLoading = true;
    notifyListeners();

    Map<String, dynamic> response = {'error': true, 'message': 'Unknown error'};

    try {
      print('🔄 FollowProvider.toggleFollow called with: $targetUserId');
      response = await _authService.toggleFollow(targetUserId: targetUserId);

      print('📥 Response: $response');

      if (response['error'] != true) {
        _followStatusCache[targetUserId] = response['isFollowing'] ?? false;
        _followerCountCache[targetUserId] = response['followerCount'] ?? 0;
        _followingCountCache[targetUserId] = response['followingCount'] ?? 0;
        print('✅ Cache updated');
      } else {
        print('❌ Error response: ${response['message']}');
      }
    } catch (e) {
      print('❌ Exception in toggleFollow: $e');
      response = {'error': true, 'message': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return response;
  }

  Future<void> fetchFollowers({required String userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.getFollowers(userId: userId);

      if (response['error'] != true) {
        _followersListCache[userId] = response['followers'] ?? [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFollowing({required String userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.getFollowing(userId: userId);

      if (response['error'] != true) {
        _followingListCache[userId] = response['following'] ?? [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkFollowStatus({required String targetUserId}) async {
    try {
      final response = await _authService.checkFollowStatus(
        targetUserId: targetUserId,
      );

      if (response['error'] != true) {
        _followStatusCache[targetUserId] = response['isFollowing'] ?? false;
      }
    } catch (_) {
      // Keep previous state on error
    }
  }

  Future<void> fetchUserStats({required String userId}) async {
    try {
      final response = await _authService.getUserStats(userId: userId);

      if (response['error'] != true) {
        _followerCountCache[userId] = response['followerCount'] ?? 0;
        _followingCountCache[userId] = response['followingCount'] ?? 0;
      }
    } catch (_) {
      // Keep previous state on error
    }
    notifyListeners();
  }

  List<dynamic> getFollowers(String userId) {
    return _followersListCache[userId] ?? [];
  }

  List<dynamic> getFollowing(String userId) {
    return _followingListCache[userId] ?? [];
  }

  void clearCache() {
    _followStatusCache.clear();
    _followerCountCache.clear();
    _followingCountCache.clear();
    _followersListCache.clear();
    _followingListCache.clear();
    notifyListeners();
  }
}
