class StreamerInfo {
  final int uid;
  final String nickname;
  final String avatar;
  final int fansCount;
  final int followers;
  final String introduction;
  final bool isLive;

  StreamerInfo({
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.fansCount,
    this.followers = 0,
    this.introduction = '',
    this.isLive = false,
  });
}
