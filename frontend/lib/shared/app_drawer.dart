//side Menu
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../features/meal_history/meal_history_screen.dart';
import '../features/profile/personal_details_screen.dart';
import '../features/profile/user_profile_screen.dart';
import '../features/screen/page_cook_screen/my_orders_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/about/about_us_page.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onPersonalDetailsTap;
  final VoidCallback? onOrdersTap;
  final VoidCallback? onFavoritesTap;
  final VoidCallback? onAboutTap;
  final VoidCallback? onLogoutTap;

  const AppDrawer({
    super.key,
    required this.user,
    this.onProfileTap,
    this.onPersonalDetailsTap,
    this.onOrdersTap,
    this.onFavoritesTap,
    this.onAboutTap,
    this.onLogoutTap,
  });

  String getInitials(String name) {
    if (name.trim().isEmpty) return "U";

    final parts = name.trim().split(" ");
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  String? _resolveImageUrl(dynamic value) {
    final raw = (value?.toString() ?? "").trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) return raw;

    final authority = baseUri.hasPort
        ? "${baseUri.host}:${baseUri.port}"
        : baseUri.host;
    final origin = "${baseUri.scheme}://$authority";

    if (raw.startsWith("/")) {
      return "$origin$raw";
    }

    return "$origin/$raw";
  }

  String? _extractUserImageUrl() {
    final profile = user?["profile"] as Map<String, dynamic>?;
    final rawImageValue =
        profile?["image_url"] ??
        profile?["image"] ??
        profile?["imageUrl"] ??
        user?["image_url"] ??
        user?["image"] ??
        user?["imageUrl"];

    return _resolveImageUrl(rawImageValue);
  }

  @override
  Widget build(BuildContext context) {
    final userName = user?["name"] ?? "User";
    final userEmail = user?["email"] ?? "";
    final userImageUrl = _extractUserImageUrl();

    return Drawer(
      backgroundColor: const Color(0xFFF5F8FC),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            /// Top title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    "Menu",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            /// User card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.royalBlue.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.deepBlue, AppColors.royalBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: userImageUrl != null
                            ? Image.network(
                                userImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) {
                                  return Center(
                                    child: Text(
                                      getInitials(userName),
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  getInitials(userName),
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Welcome back",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.blueGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              color: AppColors.deepBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.blueGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      "ACCOUNT",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: AppColors.blueGray,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  _menuTile(
                    context,
                    icon: Icons.account_circle_outlined,
                    title: "My Profile",
                    subtitle: "View your public profile",
                    onTap: () {
                      Navigator.pop(context);
                      if (onProfileTap != null) {
                        onProfileTap!.call();
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserProfileScreen(),
                        ),
                      );
                    },
                  ),

                  _menuTile(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: "Personal Details",
                    subtitle: "View and manage your information",
                    onTap: () {
                      Navigator.pop(context);
                      if (onPersonalDetailsTap != null) {
                        onPersonalDetailsTap!.call();
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PersonalDetailsScreen(),
                        ),
                      );
                    },
                  ),

                  _menuTile(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: "My Order",
                    subtitle: "See current and past orders",
                    onTap: () {
                      Navigator.pop(context);
                      if (onOrdersTap != null) {
                        onOrdersTap!.call();
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyOrdersScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      "NUTRITION",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: AppColors.blueGray,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  _menuTile(
                    context,
                    icon: Icons.restaurant_menu_rounded,
                    title: "Meal History",
                    subtitle: "Today and previous dishes by date",
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MealHistoryScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      "SUPPORT",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: AppColors.blueGray,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  _menuTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: "About Us",
                    subtitle: "Learn more about the app",
                    onTap: () {
                      Navigator.pop(context);
                      if (onAboutTap != null) {
                        onAboutTap!.call();
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutUsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 20, right: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "ACTION",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: AppColors.blueGray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.25)),
                    foregroundColor: Colors.red.shade700,
                    backgroundColor: Colors.red.shade50,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);

                    if (onLogoutTap != null) {
                      onLogoutTap!.call();
                      return;
                    }

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    "Logout",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.royalBlue.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.royalBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.deepBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.blueGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: AppColors.blueGray,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
