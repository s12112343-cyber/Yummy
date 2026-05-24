import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '/../../features/screen/page_recipe_screen/youtube_video_model.dart';

class YoutubeRecipeService {
  static const String _baseUrl = "https://www.googleapis.com/youtube/v3";

  final List<String> _randomQueries = [
    "easy chicken recipe",
    "healthy dinner recipe",
    "pasta recipe",
    "arabic food recipe",
    "quick breakfast recipe",
    "vegetarian recipe",
  ];

  Future<List<YoutubeVideoModel>> fetchRecipeVideos({
    String searchText = "",
    String cuisine = "All",
  }) async {
    final randomQuery = _randomQueries[Random().nextInt(_randomQueries.length)];

    String query = searchText.trim().isEmpty
        ? randomQuery
        : "${searchText.trim()} recipe";

    if (cuisine != "All") {
      query = "$cuisine $query";
    }

    final searchUrl = Uri.parse(
      "$_baseUrl/search"
      "?part=snippet"
      "&type=video"
      "&maxResults=15"
      "&q=${Uri.encodeComponent(query)}"
      "&key=${AppConfig.youtubeApiKey}",
    );

    final searchResponse = await http.get(searchUrl);

    if (searchResponse.statusCode != 200) {
      throw Exception("Failed to load YouTube videos");
    }

    final searchData = jsonDecode(searchResponse.body);

    final items = searchData["items"] as List;

    final videoIds = items
        .map((item) => item["id"]["videoId"])
        .where((id) => id != null)
        .join(",");

    if (videoIds.isEmpty) return [];

    final detailsUrl = Uri.parse(
      "$_baseUrl/videos"
      "?part=contentDetails"
      "&id=$videoIds"
      "&key=${AppConfig.youtubeApiKey}",
    );

    final detailsResponse = await http.get(detailsUrl);

    if (detailsResponse.statusCode != 200) {
      throw Exception("Failed to load video details");
    }

    final detailsData = jsonDecode(detailsResponse.body);
    final detailsItems = detailsData["items"] as List;

    final Map<String, String> durationMap = {};

    for (final item in detailsItems) {
      final id = item["id"];
      final isoDuration = item["contentDetails"]["duration"];
      durationMap[id] = _formatDuration(isoDuration);
    }

    return items.map((item) {
      final snippet = item["snippet"];
      final videoId = item["id"]["videoId"];

      return YoutubeVideoModel(
        videoId: videoId,
        title: snippet["title"] ?? "Recipe Video",
        channelTitle: snippet["channelTitle"] ?? "YouTube",
        thumbnailUrl:
            snippet["thumbnails"]["high"]?["url"] ??
            snippet["thumbnails"]["medium"]?["url"] ??
            "",
        duration: durationMap[videoId] ?? "",
        cuisine: cuisine,
      );
    }).toList();
  }

  String _formatDuration(String isoDuration) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(isoDuration);

    if (match == null) return "";

    final hours = int.tryParse(match.group(1) ?? "0") ?? 0;
    final minutes = int.tryParse(match.group(2) ?? "0") ?? 0;
    final seconds = int.tryParse(match.group(3) ?? "0") ?? 0;

    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }

    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
