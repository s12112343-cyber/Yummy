import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../models/youtube_video_model.dart';

class YoutubeRecipeService {
  static const String _baseUrl = "https://www.googleapis.com/youtube/v3";
  static int _currentKeyIndex = 0;
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
  }) async {
    final keys = AppConfig.youtubeApiKeys;
    if (keys.isEmpty) {
      print("YOUTUBE ERROR => Missing YOUTUBE_API_KEYS in .env");
      return [];
    }
    // =========================
    // RANDOM QUERY
    // =========================

    final randomQuery = _randomQueries[Random().nextInt(_randomQueries.length)];

    // =========================
    // BUILD QUERY
    // =========================
    String query = "";

    // SEARCH ONLY

    if (searchText.trim().isNotEmpty) {
      query = "${searchText.trim()} recipe";
    }

    // RANDOM IF EMPTY

    if (query.trim().isEmpty) {
      query = randomQuery;
    }
    // =========================
    // SEARCH URL
    // =========================

    final searchUrl = Uri.parse(
      "$_baseUrl/search"
      "?part=snippet"
      "&type=video"
      "&maxResults=5"
      "&q=${Uri.encodeComponent(query)}"
      "&key=${keys[_currentKeyIndex]}",
    );

    final searchResponse = await http.get(searchUrl);
    print(searchResponse.body);
    // =========================
    // ERROR
    // =========================
    if (searchResponse.statusCode == 429) {
      print("KEY $_currentKeyIndex EXPIRED 😭🔥");

      _currentKeyIndex++;
      if (_currentKeyIndex >= keys.length) {
        _currentKeyIndex = 0;
      }
      // إذا في key ثانية

      if (_currentKeyIndex < keys.length) {
        print("SWITCHING TO NEXT KEY 😭🔥");

        return fetchRecipeVideos(searchText: searchText);
      }

      // إذا خلصوا كلهم

      print("ALL YOUTUBE KEYS EXPIRED 😭🔥");

      return [];
    }
    if (searchResponse.statusCode != 200) {
      print("YOUTUBE ERROR => ${searchResponse.body}");

      return [];
    }

    // =========================
    // DATA
    // =========================

    final searchData = jsonDecode(searchResponse.body);

    final items = searchData["items"] as List;

    // =========================
    // VIDEO IDS
    // =========================

    final videoIds = items
        .map((item) => item["id"]["videoId"])
        .where((id) => id != null)
        .join(",");

    if (videoIds.isEmpty) {
      return [];
    }

    // =========================
    // DETAILS URL
    // =========================

    final detailsUrl = Uri.parse(
      "$_baseUrl/videos"
      "?part=contentDetails"
      "&id=$videoIds"
      "&key=${keys[_currentKeyIndex]}",
    );

    final detailsResponse = await http.get(detailsUrl);

    // =========================
    // DETAILS ERROR
    // =========================

    if (detailsResponse.statusCode != 200) {
      print("DETAILS ERROR => ${detailsResponse.body}");

      return [];
    }

    // =========================
    // DETAILS DATA
    // =========================

    final detailsData = jsonDecode(detailsResponse.body);

    final detailsItems = detailsData["items"] as List;

    final Map<String, String> durationMap = {};

    for (final item in detailsItems) {
      final id = item["id"];

      final isoDuration = item["contentDetails"]["duration"];

      durationMap[id] = _formatDuration(isoDuration);
    }

    // =========================
    // RETURN VIDEOS
    // =========================

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
        cuisine: "",
      );
    }).toList();
  }

  // =========================
  // FORMAT DURATION
  // =========================

  String _formatDuration(String isoDuration) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');

    final match = regex.firstMatch(isoDuration);

    if (match == null) {
      return "";
    }

    final hours = int.tryParse(match.group(1) ?? "0") ?? 0;

    final minutes = int.tryParse(match.group(2) ?? "0") ?? 0;

    final seconds = int.tryParse(match.group(3) ?? "0") ?? 0;

    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }

    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
