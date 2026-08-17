class LiveRoom {
  final String roomId;
  final String title;
  final String streamerName;
  final String streamerAvatar;
  final int fansCount;
  final bool isLive;
  final String coverUrl;
  final String platform;
  final String categoryName;
  final int presenterUid;

  LiveRoom({
    required this.roomId,
    required this.title,
    required this.streamerName,
    required this.streamerAvatar,
    required this.fansCount,
    required this.isLive,
    required this.coverUrl,
    this.platform = 'huya',
    this.categoryName = '',
    this.presenterUid = 0,
  });

  factory LiveRoom.fromJson(Map<String, dynamic> json) {
    return LiveRoom(
      roomId: json['roomId']?.toString() ?? '',
      title: json['title'] ?? '',
      streamerName: json['streamerName'] ?? '',
      streamerAvatar: json['streamerAvatar'] ?? '',
      fansCount: json['fansCount'] ?? 0,
      isLive: json['isLive'] ?? false,
      coverUrl: json['coverUrl'] ?? '',
      categoryName: json['categoryName'] ?? '',
      presenterUid: json['presenterUid'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'title': title,
    'streamerName': streamerName,
    'streamerAvatar': streamerAvatar,
    'fansCount': fansCount,
    'isLive': isLive,
    'coverUrl': coverUrl,
    'platform': platform,
    'categoryName': categoryName,
    'presenterUid': presenterUid,
  };
}
