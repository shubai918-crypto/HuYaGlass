class StreamQuality {
  final String name;
  final int bitrate;
  final String flvUrl;
  final String hlsUrl;
  final String suffix;
  final String antiCode;
  final List<String> candidates;

  StreamQuality({
    required this.name,
    required this.bitrate,
    this.flvUrl = '',
    this.hlsUrl = '',
    this.suffix = '',
    this.antiCode = '',
    this.candidates = const [],
  });
}
