import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class SMDBCompressor {
  /// String ကို GZip နဲ့ ချုံ့ပြီး Uint8List ပြန်ပေးမယ်
  static Uint8List compress(String text) {
    final bytes = utf8.encode(text);
    return Uint8List.fromList(gzip.encode(bytes));
  }

  /// Compressed bytes ကို မူလ String ပြန်ပြောင်းမယ်
  static String decompress(Uint8List compressedBytes) {
    final decompressed = gzip.decode(compressedBytes);
    return utf8.decode(decompressed);
  }
}
