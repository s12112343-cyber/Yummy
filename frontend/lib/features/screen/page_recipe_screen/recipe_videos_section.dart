import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '/../../core/services/youtube_recipe_service.dart';
import '../../../models/youtube_video_model.dart';

class RecipeVideosSection extends StatefulWidget {
  final String searchText;

  const RecipeVideosSection({
    super.key,
    required this.searchText,
  });

  @override
  State<RecipeVideosSection> createState() => _RecipeVideosSectionState();
}

class _RecipeVideosSectionState extends State<RecipeVideosSection> {
  final YoutubeRecipeService _service = YoutubeRecipeService();

  List<YoutubeVideoModel> _videos = [];
  Set<String> _favoriteVideoIds = {};

  bool _isLoading = true;
  String? _errorMessage;
  String _lastSearch = "";

  static const Color navy = Color(0xff102A43);
  static const Color primaryBlue = Color(0xff1B3C73);
  static const Color softBlue = Color(0xffEAF2FF);
  static const Color borderBlue = Color(0xffD9E6F5);
  static const Color mutedText = Color(0xff6B7A90);
  static const Color pageBg = Color(0xffF7FAFD);

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadVideos();
  }

  @override
  void didUpdateWidget(covariant RecipeVideosSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchText != widget.searchText) {
      _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    final search = widget.searchText.trim();

    if (_lastSearch == search && _videos.isNotEmpty) {
      return;
    }

    _lastSearch = search;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final videos = await _service.fetchRecipeVideos(searchText: search);

      if (!mounted) return;

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load videos";
      });
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList("favorite_youtube_videos") ?? [];

    if (!mounted) return;

    setState(() {
      _favoriteVideoIds = saved.toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final filteredVideos = _videos.where((video) {
      final search = widget.searchText.toLowerCase().trim();

      if (search.isEmpty) return true;

      return video.title.toLowerCase().contains(search) ||
          video.channelTitle.toLowerCase().contains(search);
    }).toList();

    if (filteredVideos.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      color: pageBg,
      child: RefreshIndicator(
        onRefresh: _loadVideos,
        color: primaryBlue,
        backgroundColor: Colors.white,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          itemCount: filteredVideos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final video = filteredVideos[index];
            return _buildVideoCard(video);
          },
        ),
      ),
    );
  }

  Widget _buildVideoCard(YoutubeVideoModel video) {
    final isFavorite = _favoriteVideoIds.contains(video.videoId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => _openYoutubeVideo(video.videoId),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: borderBlue,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(video, isFavorite),
              _buildVideoInfo(video),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(YoutubeVideoModel video, bool isFavorite) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(26),
          ),
          child: CachedNetworkImage(
            imageUrl: video.thumbnailUrl,
            height: 205,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 205,
              width: double.infinity,
              color: softBlue,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: primaryBlue,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 205,
              width: double.infinity,
              color: softBlue,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: primaryBlue,
                size: 42,
              ),
            ),
          ),
        ),

        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.58),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: primaryBlue,
              size: 38,
            ),
          ),
        ),

        if (video.duration.isNotEmpty)
          Positioned(
            right: 14,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    video.duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (isFavorite)
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoInfo(YoutubeVideoModel video) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: navy,
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              height: 1.28,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: primaryBlue,
                  size: 18,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  video.channelTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Watch",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openYoutubeVideo(String videoId) async {
    final Uri youtubeAppUrl = Uri.parse(
      "youtube://www.youtube.com/watch?v=$videoId",
    );

    final Uri youtubeWebUrl = Uri.parse(
      "https://www.youtube.com/watch?v=$videoId",
    );

    try {
      if (await canLaunchUrl(youtubeAppUrl)) {
        await launchUrl(
          youtubeAppUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        await launchUrl(
          youtubeWebUrl,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint("Could not launch video: $e");
    }
  }

  Widget _buildLoadingState() {
    return Container(
      color: pageBg,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return Container(
            height: 290,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderBlue),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 205,
                  decoration: const BoxDecoration(
                    color: softBlue,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: primaryBlue,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xffEDF3FA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 13,
                        width: double.infinity,
                        margin: const EdgeInsets.only(right: 80),
                        decoration: BoxDecoration(
                          color: const Color(0xffEDF3FA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: pageBg,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderBlue),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  color: primaryBlue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "No videos found",
                style: TextStyle(
                  color: navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Try searching for another recipe or ingredient.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: pageBg,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderBlue),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xffFFF0F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Something went wrong",
                style: TextStyle(
                  color: navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please check your connection and try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _loadVideos,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    "Try again",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}