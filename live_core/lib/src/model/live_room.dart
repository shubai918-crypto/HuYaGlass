class LiveRoom {
  final String roomId;
  final String title;
  final String streamerName;
  final String streamerAvatar;
  final int fansCount;
  final bool isLive;
  final String coverUrl;
  final String platform;

  LiveRoom({
    required this.roomId,
    required this.title,
    required this.streamerName,
    required this.streamerAvatar,
    required this.fansCount,
    required this.isLive,
    required this.coverUrl,
    this.platform = 'huya',
  });

  factory LiveRoom.fromJson(Map<String, dynamic> json) {
    return LiveRoom(
      roomId: json['roomId'] ?? '',
      title: json['title'] ?? '',
      streamerName: json['streamerName'] ?? '',
      streamerAvatar: json['streamerAvatar'] ?? '',
      fansCount: json['fansCount'] ?? 0,
      isLive: json['isLive'] ?? false,
      coverUrl: json['coverUrl'] ?? '',
    );
  }
}
