import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/follow_provider.dart';
import '../../core/theme/app_colors.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const FollowersScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FollowProvider>().fetchFollowers(userId: widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Followers'),
        backgroundColor: AppColors.deepBlue,
        foregroundColor: AppColors.white,
      ),
      body: Consumer<FollowProvider>(
        builder: (context, followProvider, _) {
          if (followProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final followers = followProvider.getFollowers(widget.userId);

          if (followers.isEmpty) {
            return Center(
              child: Text(
                'No followers yet',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final follower = followers[index];
              return FollowerTile(follower: follower);
            },
          );
        },
      ),
    );
  }
}

class FollowerTile extends StatelessWidget {
  final dynamic follower;

  const FollowerTile({super.key, required this.follower});

  @override
  Widget build(BuildContext context) {
    final profileImage = follower['profileImage'] as String? ?? '';
    final name = follower['name'] as String? ?? 'User';

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
      subtitle: Text(follower['email'] as String? ?? ''),
      trailing: ElevatedButton(
        onPressed: () {
          // Navigate to user profile
          Navigator.of(context).pop();
        },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepBlue),
        child: const Text('View'),
      ),
    );
  }
}
