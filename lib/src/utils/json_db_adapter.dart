import 'dart:convert';
import 'dart:typed_data';

import 'package:sm_db/src/indexed/smdb_compressor.dart';

abstract class JsonDBAdapter<T> {
  int get getUniqueFieldId;
  int get getParentId => 0;
  int getId(T value);

  Map<String, dynamic> toMap(T value);
  T fromMap(Map<String, dynamic> map);

  String toJsonString(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  Map<String, dynamic> fromJsonString(String jsonString) {
    return jsonDecode(jsonString);
  }

  Uint8List encodeData(Map<String, dynamic> map) {
    final jsonString = toJsonString(map);
    // String ကို compress လုပ်ပြီး binary အဖြစ် ပြောင်းသိမ်းမယ်
    return SMDBCompressor.compress(jsonString);
  }

  Map<String, dynamic> decodeData(Uint8List bytes) {
    // Binary ကို ပြန်ဖြည်ပြီး JSON string ထုတ်မယ်
    final jsonString = SMDBCompressor.decompress(bytes);
    return fromJsonString(jsonString);
  }
}
