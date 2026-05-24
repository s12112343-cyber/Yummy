class YoutubeVideoModel {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String duration;
  final String cuisine;

  YoutubeVideoModel({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.duration,
    required this.cuisine,
  });
}
