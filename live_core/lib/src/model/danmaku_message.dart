class DanmakuMessage {
  final String nickname;
  final String content;
  final int uid;
  final int nobleLevel;
  final int fansLevel;
  final String badgeName;
  final String avatarUrl;
  final int gender;
  final DateTime timestamp;

  DanmakuMessage({
    required this.nickname,
    required this.content,
    required this.uid,
    this.nobleLevel = 0,
    this.fansLevel = 0,
    this.badgeName = '',
    this.avatarUrl = '',
    this.gender = 0,
  }) : timestamp = DateTime.now();
}
