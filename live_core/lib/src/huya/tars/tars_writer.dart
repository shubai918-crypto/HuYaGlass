import 'dart:typed_data';
import 'dart:convert';

class TarsWriter {
  final List<int> _buffer = [];

  Uint8List get bytes => Uint8List.fromList(_buffer);

  void writeTag(int tag, int type) {
    if (tag < 15) {
      _buffer.add((tag << 4) | type);
    } else {
      _buffer.add((15 << 4) | type);
      _buffer.add(tag);
    }
  }

  void writeInt8(int tag, int value) {
    if (value == 0) {
      writeTag(tag, 12); // ZERO
    } else {
      writeTag(tag, 0);
      _buffer.add(value & 0xFF);
    }
  }

  void writeInt16(int tag, int value) {
    if (value == 0) {
      writeTag(tag, 12);
    } else {
      writeTag(tag, 1);
      _buffer.add((value >> 8) & 0xFF);
      _buffer.add(value & 0xFF);
    }
  }

  void writeInt32(int tag, int value) {
    if (value == 0) {
      writeTag(tag, 12);
    } else {
      writeTag(tag, 2);
      _buffer.add((value >> 24) & 0xFF);
      _buffer.add((value >> 16) & 0xFF);
      _buffer.add((value >> 8) & 0xFF);
      _buffer.add(value & 0xFF);
    }
  }

  void writeInt64(int tag, int value) {
    if (value == 0) {
      writeTag(tag, 12);
    } else {
      writeTag(tag, 3);
      _buffer.add((value >> 56) & 0xFF);
      _buffer.add((value >> 48) & 0xFF);
      _buffer.add((value >> 40) & 0xFF);
      _buffer.add((value >> 32) & 0xFF);
      _buffer.add((value >> 24) & 0xFF);
      _buffer.add((value >> 16) & 0xFF);
      _buffer.add((value >> 8) & 0xFF);
      _buffer.add(value & 0xFF);
    }
  }

  void writeString(int tag, String value) {
    var bytes = utf8.encode(value);
    if (bytes.length < 256) {
      writeTag(tag, 6); // STRING1
      _buffer.add(bytes.length);
    } else {
      writeTag(tag, 7); // STRING4
      writeInt32(0, bytes.length);
    }
    _buffer.addAll(bytes);
  }

  void writeBytes(int tag, Uint8List value) {
    writeTag(tag, 13); // SIMPLE_LIST
    writeTag(0, 0); // head type: byte
    writeInt32(0, value.length);
    _buffer.addAll(value);
  }
}
