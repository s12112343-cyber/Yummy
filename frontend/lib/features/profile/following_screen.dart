import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/follow_provider.dart';
import '../../core/theme/app_colors.dart';

class FollowingScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const FollowingScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FollowProvider>().fetchFollowing(userId: widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName} is Following'),
        backgroundColor: AppColors.deepBlue,
        foregroundColor: AppColors.white,
      ),
      body: Consumer<FollowProvider>(
        builder: (context, followProvider, _) {
          if (followProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final following = followProvider.getFollowing(widget.userId);

          if (following.isEmpty) {
            return Center(
              child: Text(
                'Not following anyone yet',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              final followee = following[index];
              return FolloweeTile(followee: followee);
            },
          );
        },
      ),
    );
  }
}

class FolloweeTile extends StatefulWidget {
  final dynamic followee;

  const FolloweeTile({super.key, required this.followee});

  @override
  State<FolloweeTile> createState() => _FolloweeTileState();
}

class _FolloweeTileState extends State<FolloweeTile> {
  @override
  Widget build(BuildContext context) {
    final profileImage = widget.followee['profileImage'] as String? ?? '';
    final name = widget.followee['name'] as String? ?? 'User';
    final followeeId = widget.followee['id'] as String?;

    return Consumer<FollowProvider>(
      builder: (context, followProvider, _) {
        final isFollowing = followProvider.isFollowing(followeeId ?? '');

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
          subtitle: Text(widget.followee['email'] as String? ?? ''),
          trailing: followeeId != null && followeeId.isNotEmpty
              ? ElevatedButton(
                  onPressed: () async {
                    await followProvider.toggleFollow(targetUserId: followeeId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                  ),
                  child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                )
              : null,
        );
      },
    );
  }
}
