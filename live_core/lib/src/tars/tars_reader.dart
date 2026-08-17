import 'dart:typed_data';
import 'dart:convert';
import 'tars_struct.dart';

/// Tars 二进制解码器（参考 dart_simple_live / dtv_mobile 实现）
class TarsReader {
  final Uint8List data;
  int pos = 0;

  TarsReader(this.data);

  bool get hasRemaining => pos < data.length;

  int readByte() {
    if (pos >= data.length) throw TarsDecodeException('Buffer overflow at pos=$pos');
    return data[pos++] & 0xFF;
  }

  int peekByte() {
    if (pos >= data.length) throw TarsDecodeException('Buffer overflow');
    return data[pos] & 0xFF;
  }

  int readInt16() {
    var b0 = readByte();
    var b1 = readByte();
    var result = (b0 << 8) | b1;
    if (result > 32767) result -= 65536;
    return result;
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

  double readFloat() {
    var bytes = ByteData(4);
    for (var i = 0; i < 4; i++) bytes.setUint8(i, readByte());
    return bytes.getFloat32(0, Endian.big);
  }

  double readDouble() {
    var bytes = ByteData(8);
    for (var i = 0; i < 8; i++) bytes.setUint8(i, readByte());
    return bytes.getFloat64(0, Endian.big);
  }

  /// 读取 Tag 和 Type
  void readHead(HeadData hd) {
    var b = readByte();
    hd.type = b & 0x0F;
    hd.tag = (b >> 4) & 0x0F;
    if (hd.tag == 15) {
      hd.tag = readByte();
    }
  }

  /// 跳转到指定 tag
  HeadData? skipToTag(int targetTag) {
    while (hasRemaining) {
      var savedPos = pos;
      var hd = HeadData();
      readHead(hd);
      if (hd.tag == targetTag) {
        return hd;
      }
      if (hd.tag > targetTag) {
        pos = savedPos;
        return null;
      }
      _skipType(hd.type);
    }
    return null;
  }

  void _skipType(int type) {
    switch (type) {
      case 0: // BYTE
        pos += 1;
        break;
      case 1: // SHORT
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
        var size = readInt(0, required: true);
        for (var i = 0; i < size * 2; i++) {
          var hd = HeadData();
          readHead(hd);
          _skipType(hd.type);
        }
        break;
      case 9: // LIST
        var size = readInt(0, required: true);
        var hd = HeadData();
        readHead(hd);
        for (var i = 0; i < size; i++) {
          _skipType(hd.type);
        }
        break;
      case 10: // STRUCT_BEGIN
        while (true) {
          var h = HeadData();
          readHead(h);
          if (h.type == 11) break; // STRUCT_END
          _skipType(h.type);
        }
        break;
      case 11: // STRUCT_END
        break;
      case 12: // ZERO
        break;
      case 13: // SIMPLE_LIST
        readHead(HeadData()); // head
        var size = readInt(0, required: true);
        pos += size;
        break;
    }
  }

  /// 读取整数
  int readInt(int tag, {bool required = false, int defaultValue = 0}) {
    var hd = skipToTag(tag);
    if (hd == null) {
      if (required) throw TarsDecodeException('require field not exist: tag=$tag');
      return defaultValue;
    }
    switch (hd.type) {
      case 0: return readByte();
      case 1: return readInt16();
      case 2: return readInt32();
      case 3: return readInt64();
      case 12: return 0; // ZERO
      default:
        if (required) throw TarsDecodeException('type mismatch: tag=$tag type=${hd.type}');
        return defaultValue;
    }
  }

  /// 读取字符串
  String readString(int tag, {bool required = false, String defaultValue = ''}) {
    var hd = skipToTag(tag);
    if (hd == null) {
      if (required) throw TarsDecodeException('require field not exist: tag=$tag');
      return defaultValue;
    }
    switch (hd.type) {
      case 6: // STRING1
        var len = readByte();
        if (pos + len > data.length) return defaultValue;
        var bytes = data.sublist(pos, pos + len);
        pos += len;
        return utf8.decode(bytes, allowMalformed: true);
      case 7: // STRING4
        var len = readInt32();
        if (pos + len > data.length) return defaultValue;
        var bytes = data.sublist(pos, pos + len);
        pos += len;
        return utf8.decode(bytes, allowMalformed: true);
      default:
        if (required) throw TarsDecodeException('type mismatch: tag=$tag');
        return defaultValue;
    }
  }

  /// 读取字节数组
  Uint8List readBytes(int tag, {bool required = false}) {
    var hd = skipToTag(tag);
    if (hd == null) {
      if (required) throw TarsDecodeException('require field not exist: tag=$tag');
      return Uint8List(0);
    }
    if (hd.type == 13) { // SIMPLE_LIST
      readHead(HeadData()); // head
      var size = readInt(0, required: true);
      if (pos + size > data.length) return Uint8List(0);
      var bytes = data.sublist(pos, pos + size);
      pos += size;
      return bytes;
    }
    return Uint8List(0);
  }

  /// 读取列表
  List<T> readList<T>(int tag, T Function(TarsReader) itemReader, {bool required = false}) {
    var hd = skipToTag(tag);
    if (hd == null) {
      if (required) throw TarsDecodeException('require field not exist: tag=$tag');
      return [];
    }
    if (hd.type != 9) {
      if (required) throw TarsDecodeException('type mismatch: tag=$tag');
      return [];
    }
    var size = readInt(0, required: true);
    if (size < 0) throw TarsDecodeException('size invalid: $size');
    // 跳过元素类型头
    readHead(HeadData());
    var result = <T>[];
    for (var i = 0; i < size; i++) {
      result.add(itemReader(this));
    }
    return result;
  }

  /// 读取 Map
  Map<K, V> readMap<K, V>(
    int tag,
    K Function(TarsReader) keyReader,
    V Function(TarsReader) valueReader, {
    bool required = false,
  }) {
    var hd = skipToTag(tag);
    if (hd == null) {
      if (required) throw TarsDecodeException('require field not exist: tag=$tag');
      return {};
    }
    if (hd.type != 8) {
      if (required) throw TarsDecodeException('type mismatch: tag=$tag');
      return {};
    }
    var size = readInt(0, required: true);
    if (size < 0) throw TarsDecodeException('size invalid: $size');
    var map = <K, V>{};
    for (var i = 0; i < size; i++) {
      readHead(HeadData()); // key head
      var k = keyReader(this);
      readHead(HeadData()); // value head
      var v = valueReader(this);
      map[k] = v;
    }
    return map;
  }

  /// 跳过到 STRUCT_END
  void skipStruct() {
    var hd = HeadData();
    readHead(hd);
    if (hd.type != 10) return; // 不是 STRUCT_BEGIN
    var depth = 1;
    while (depth > 0 && hasRemaining) {
      var h = HeadData();
      readHead(h);
      if (h.type == 10) depth++;
      if (h.type == 11) depth--;
      if (h.type != 10 && h.type != 11) {
        _skipType(h.type);
      }
    }
  }
}
