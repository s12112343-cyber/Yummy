import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '/../../core/services/youtube_recipe_service.dart';
import '../../../models/youtube_video_model.dart';

class RecipeVideosSection extends StatefulWidget {
  final String searchText;

  const RecipeVideosSection({super.key, required this.searchText});

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
      return video.title.toLowerCase().contains(
        widget.searchText.toLowerCase(),
      );
    }).toList();

    if (filteredVideos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,

      color: const Color(0xff1B3C73),

      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),

        itemCount: filteredVideos.length,

        itemBuilder: (context, index) {
          final video = filteredVideos[index];

          return _buildVideoCard(video);
        },
      ),
    );
  }

  Widget _buildVideoCard(YoutubeVideoModel video) {
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "No recipe videos found 😭",

        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Text("Something went wrong 😭", style: TextStyle(fontSize: 18)),
    );
  }
}
