import 'dart:async';

class EventBus {
  final _controller = StreamController<dynamic>.broadcast();

  void add(dynamic event) {
    _controller.add(event);
  }

  Stream<T> on<T>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
