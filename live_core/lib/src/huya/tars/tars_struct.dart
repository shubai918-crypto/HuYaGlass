/// Tars 结构类型枚举
enum TarsStructType {
  BYTE,       // 0
  SHORT,      // 1
  INT32,      // 2
  INT64,      // 3
  FLOAT,      // 4
  DOUBLE,     // 5
  STRING1,    // 6
  STRING4,    // 7
  MAP,        // 8
  LIST,       // 9
  STRUCT_BEGIN, // 10
  STRUCT_END, // 11
  ZERO,       // 12
  SIMPLE_LIST, // 13
}

class HeadData {
  int type = 0;
  int tag = 0;
}

class TarsDecodeException implements Exception {
  final String message;
  TarsDecodeException(this.message);
  @override
  String toString() => 'TarsDecodeException: $message';
}

class TarsEncodeException implements Exception {
  final String message;
  TarsEncodeException(this.message);
  @override
  String toString() => 'TarsEncodeException: $message';
}
