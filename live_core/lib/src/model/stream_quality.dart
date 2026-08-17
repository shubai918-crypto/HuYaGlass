class StreamQuality {
  final String name;
  final int bitrate;
  final String flvUrl;
  final String hlsUrl;
  final String suffix;
  final String antiCode;

  StreamQuality({
    required this.name,
    required this.bitrate,
    required this.flvUrl,
    this.hlsUrl = '',
    this.suffix = '',
    this.antiCode = '',
  });
}
