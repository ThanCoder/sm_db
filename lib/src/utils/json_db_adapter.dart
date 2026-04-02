import 'dart:convert';

abstract class JsonDBAdapter<T> {
  int get getUniqueFieldId;
  int get getParentId => 0;
  int getId(T value);
  Map<String, dynamic> toMap(T value);
  T fromMap(Map<String, dynamic> map);

  String toJson(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  Map<String, dynamic> fromJson(String jsonData) {
    return jsonDecode(jsonData);
  }
}
