import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/follow_provider.dart';
import '../../core/theme/app_colors.dart';
import 'user_profile_screen.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialIndex;

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.initialIndex = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowData();
    });
  }

  Future<void> _loadFollowData() async {
    final followProvider = context.read<FollowProvider>();
    await followProvider.fetchFollowers(userId: widget.userId);
    await followProvider.fetchFollowing(userId: widget.userId);

    // تحديث الـ follow status لكل شخص
    final followers = followProvider.getFollowers(widget.userId);
    final following = followProvider.getFollowing(widget.userId);

    for (var follower in followers) {
      final userId = follower['id'] as String?;
      if (userId != null && userId.isNotEmpty) {
        await followProvider.checkFollowStatus(targetUserId: userId);
      }
    }

    for (var followee in following) {
      final userId = followee['id'] as String?;
      if (userId != null && userId.isNotEmpty) {
        await followProvider.checkFollowStatus(targetUserId: userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: AppColors.white,
          title: Text(widget.userName),
          bottom: const TabBar(
            indicatorColor: AppColors.white,
            labelColor: AppColors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: Consumer<FollowProvider>(
          builder: (context, followProvider, _) {
            final followers = followProvider.getFollowers(widget.userId);
            final following = followProvider.getFollowing(widget.userId);

            return TabBarView(
              children: [
                _FollowListView(
                  isLoading: followProvider.isLoading,
                  emptyText: 'No followers yet',
                  children: followers
                      .map((follower) => _UserRow(user: follower))
                      .toList(),
                ),
                _FollowListView(
                  isLoading: followProvider.isLoading,
                  emptyText: 'Not following anyone yet',
                  children: following
                      .map((followee) => _UserRow(user: followee))
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FollowListView extends StatelessWidget {
  final bool isLoading;
  final String emptyText;
  final List<Widget> children;

  const _FollowListView({
    required this.isLoading,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && children.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (children.isEmpty) {
      return Center(
        child: Text(emptyText, style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    return ListView(children: children);
  }
}

class _UserRow extends StatelessWidget {
  final dynamic user;

  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final profileImage = user['profileImage'] as String? ?? '';
    final name = user['name'] as String? ?? 'User';
    final userId = user['id'] as String? ?? '';

    return Consumer<FollowProvider>(
      builder: (context, followProvider, _) {
        final isFollowing = followProvider.isFollowing(userId);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.babyBlueLight,
            backgroundImage: profileImage.isNotEmpty
                ? NetworkImage(profileImage)
                : null,
            child: profileImage.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBlue,
                    ),
                  )
                : null,
          ),
          title: Text(name),
          subtitle: Text(user['email'] as String? ?? ''),
          onTap: userId.isNotEmpty
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        viewedUserId: userId,
                        viewedUserName: name,
                        viewedUserImageUrl: profileImage,
                      ),
                    ),
                  );
                }
              : null,
          trailing: userId.isEmpty
              ? null
              : ElevatedButton(
                  onPressed: () async {
                    await followProvider.toggleFollow(targetUserId: userId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing
                        ? const Color(0xFFE65100)
                        : AppColors.deepBlue,
                  ),
                  child: Text(
                    isFollowing ? 'Unfollow' : 'Follow',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
        );
      },
    );
  }
}
