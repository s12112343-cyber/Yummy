import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class LikeProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // Store liked user ids per post
  final Map<String, Set<String>> _likedByUsers = {};
  final Map<String, int> _likeCount = {};

  Set<String> likedByUsersFor(String postId) {
    return _likedByUsers[postId] ?? <String>{};
  }

  int likeCountFor(String postId) {
    return _likeCount[postId] ?? 0;
  }

  bool hasDataFor(String postId) => _likedByUsers.containsKey(postId);

  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async {
    try {
      final resp = await _authService.togglePostLike(
        postId: postId,
        userId: userId,
      );
      if (resp['error'] == true) return false;

      final updatedPost = resp['post'];
      if (updatedPost is! Map) return false;

      final liked =
          (updatedPost['likedByUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};

      _likedByUsers[postId] = liked;
      _likeCount[postId] = liked.length;

      notifyListeners();
      return true;
    } catch (e) {
      // Network error or unexpected exception — fail gracefully
      print('⚠️ LikeProvider.toggleLike error: $e');
      return false;
    }
  }
}
