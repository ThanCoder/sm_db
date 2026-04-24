abstract class SmdbBoxInterface<T> {
  ///
  /// ### Add Single
  ///
  /// `parentId` ?? `adapter.getParentId(value)`
  /// 
  Future<T?> add(T value, {int? parentId});

  Future<void> addAll(List<T> values, {int? parentId});

  Future<bool> updateById(int id, T value);
  Future<bool> deleteById(int id);
  Future<void> deleteAll(List<int> idList);
  Future<List<T>> getAll({int? parentId});
  Future<T?> getOne(bool Function(T value) test, {int? parentId});
  // query
  Future<List<T>> getAllQuery(bool Function(T value) test, {int? parentId});

  // Stream
  Stream<T> getAllStream({int? parentId});
  Stream<T> getAllQueryStream(bool Function(T value) test, {int? parentId});
  Stream<T?> getOneStream(bool Function(T value) test, {int? parentId});
}
