import 'dart:typed_data';

extension SmdbByteDataExtensions on ByteData {
  // 1 Byte ကတော့ Endian မလိုပါဘူး
  int getInt1Byte(int byteOffset) => getInt8(byteOffset);
  void setInt1Byte(int byteOffset, int value) => setInt8(byteOffset, value);

  // 4 Bytes (Int32)
  int getInt4Bytes(int byteOffset) => getInt32(byteOffset, Endian.little);
  void setInt4Bytes(int byteOffset, int value) =>
      setInt32(byteOffset, value, Endian.little);

  // 8 Bytes (Int64)
  int getInt8Bytes(int byteOffset) => getInt64(byteOffset, Endian.little);
  void setInt8Bytes(int byteOffset, int value) =>
      setInt64(byteOffset, value, Endian.little);
}
