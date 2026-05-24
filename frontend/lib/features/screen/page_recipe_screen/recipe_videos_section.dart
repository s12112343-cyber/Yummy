import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '/../../core/services/youtube_recipe_service.dart';
import 'youtube_video_model.dart';

class RecipeVideosSection extends StatefulWidget {
  final String searchText;
  final String selectedCuisine;

  const RecipeVideosSection({
    super.key,
    required this.searchText,
    this.selectedCuisine = "All",
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
  String _lastCuisine = "All";

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadVideos();
  }

  @override
  void didUpdateWidget(covariant RecipeVideosSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchText != widget.searchText ||
        oldWidget.selectedCuisine != widget.selectedCuisine) {
      _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    final search = widget.searchText.trim();
    final cuisine = widget.selectedCuisine;

    if (_lastSearch == search &&
        _lastCuisine == cuisine &&
        _videos.isNotEmpty) {
      return;
    }

    _lastSearch = search;
    _lastCuisine = cuisine;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final videos = await _service.fetchRecipeVideos(
        searchText: search,
        cuisine: cuisine,
      );

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

    if (_videos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      color: const Color(0xff1B3C73),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];

          return _buildVideoCard(video);
        },
      ),
    );
  }

  Widget _buildVideoCard(YoutubeVideoModel video) {
    final isFavorite = _favoriteVideoIds.contains(video.videoId);

    return GestureDetector(
      onTap: () async {
        final Uri youtubeAppUrl = Uri.parse(
          "youtube://www.youtube.com/watch?v=${video.videoId}",
        );

        final Uri youtubeWebUrl = Uri.parse(
          "https://www.youtube.com/watch?v=${video.videoId}",
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
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffDDE7F3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff93B4DF).withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: const Color(0xffEAF1FA),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff1B3C73),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: const Color(0xffEAF1FA),
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: Color(0xff6B7A90),
                        size: 40,
                      ),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.45),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xff1B3C73),
                      size: 34,
                    ),
                  ),
                ),

                if (video.duration.isNotEmpty)
                  Positioned(
                    right: 14,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        video.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff1B3C73),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.ondemand_video_rounded,
                    color: Color(0xff6B7A90),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      video.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff6B7A90),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffEAF1FA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      video.cuisine,
                      style: const TextStyle(
                        color: Color(0xff1B3C73),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          height: 285,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xffDDE7F3)),
          ),
          child: Column(
            children: [
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  color: Color(0xffEAF1FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xffEAF1FA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xffEAF1FA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.video_library_outlined,
              size: 70,
              color: Color(0xff6B7A90),
            ),
            SizedBox(height: 14),
            Text(
              "No recipe videos found",
              style: TextStyle(
                color: Color(0xff1B3C73),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "Try searching for another recipe.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff6B7A90),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 70,
              color: Color(0xff6B7A90),
            ),
            const SizedBox(height: 14),
            const Text(
              "Something went wrong",
              style: TextStyle(
                color: Color(0xff1B3C73),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please check your internet connection or API key.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff6B7A90),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadVideos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1B3C73),
                foregroundColor: Colors.white,
              ),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
