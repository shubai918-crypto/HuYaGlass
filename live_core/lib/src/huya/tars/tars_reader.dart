import 'dart:typed_data';
import 'dart:convert';

class TarsReader {
  final Uint8List data;
  int pos = 0;

  TarsReader(this.data);

  bool get hasRemaining => pos < data.length;

  int readByte() {
    if (pos >= data.length) throw Exception('Buffer overflow');
    return data[pos++];
  }

  int peekByte() {
    if (pos >= data.length) throw Exception('Buffer overflow');
    return data[pos];
  }

  int readInt16() {
    var b0 = readByte();
    var b1 = readByte();
    return (b0 << 8) | b1;
  }

  int readInt32() {
    var b0 = readByte();
    var b1 = readByte();
    var b2 = readByte();
    var b3 = readByte();
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
  }

  int readInt64() {
    var high = readInt32();
    var low = readInt32();
    return (high << 32) | (low & 0xFFFFFFFF);
  }

  /// Tars Tag/Type 读取
  /// 返回 (tag, type)
  (int, int) readTagType() {
    var b = readByte();
    int tag = (b >> 4) & 0x0F;
    int type = b & 0x0F;
    if (tag == 15) {
      tag = readByte();
    }
    return (tag, type);
  }

  /// 跳转到指定 tag，跳过中间字段
  bool skipToTag(int targetTag) {
    while (hasRemaining) {
      var savedPos = pos;
      var (tag, type) = readTagType();
      if (tag == targetTag) return true;
      if (tag > targetTag) {
        pos = savedPos;
        return false;
      }
      _skipType(type);
    }
    return false;
  }

  void _skipType(int type) {
    switch (type) {
      case 0: // INT8
        pos += 1;
        break;
      case 1: // INT16
        pos += 2;
        break;
      case 2: // INT32
        pos += 4;
        break;
      case 3: // INT64
        pos += 8;
        break;
      case 4: // FLOAT
        pos += 4;
        break;
      case 5: // DOUBLE
        pos += 8;
        break;
      case 6: // STRING1
        var len = readByte();
        pos += len;
        break;
      case 7: // STRING4
        var len = readInt32();
        pos += len;
        break;
      case 8: // MAP
        var size = _readHead();
        for (var i = 0; i < size * 2; i++) {
          var (_, t) = readTagType();
          _skipType(t);
        }
        break;
      case 9: // LIST
        var size = _readHead();
        var (_, t) = readTagType();
        for (var i = 0; i < size; i++) {
          _skipType(t);
        }
        break;
      case 10: // STRUCT_BEGIN
        while (true) {
          var (_, t) = readTagType();
          if (t == 11) break; // STRUCT_END
          _skipType(t);
        }
        break;
      case 11: // STRUCT_END
        break;
      case 12: // ZERO
        break;
      case 13: // SIMPLE_LIST (bytes)
        readTagType(); // head
        var len = _readHead();
        pos += len;
        break;
    }
  }

  int _readHead() {
    var (_, type) = readTagType();
    if (type == 0) return readByte();
    if (type == 1) return readInt16();
    if (type == 2) return readInt32();
    return 0;
  }

  int readInt(int tag, {int defaultValue = 0}) {
    if (!skipToTag(tag)) return defaultValue;
    var (_, type) = readTagType();
    switch (type) {
      case 0: return readByte();
      case 1: return readInt16();
      case 2: return readInt32();
      case 3: return readInt64();
      case 12: return 0;
      default: return defaultValue;
    }
  }

  String readString(int tag, {String defaultValue = ''}) {
    if (!skipToTag(tag)) return defaultValue;
    var (_, type) = readTagType();
    if (type == 6) {
      var len = readByte();
      var bytes = data.sublist(pos, pos + len);
      pos += len;
      return utf8.decode(bytes, allowMalformed: true);
    } else if (type == 7) {
      var len = readInt32();
      var bytes = data.sublist(pos, pos + len);
      pos += len;
      return utf8.decode(bytes, allowMalformed: true);
    }
    return defaultValue;
  }

  Uint8List readBytes(int tag) {
    if (!skipToTag(tag)) return Uint8List(0);
    var (_, type) = readTagType();
    if (type == 13) { // SIMPLE_LIST
      readTagType(); // head
      var len = _readHead();
      var bytes = data.sublist(pos, pos + len);
      pos += len;
      return bytes;
    }
    return Uint8List(0);
  }
}
