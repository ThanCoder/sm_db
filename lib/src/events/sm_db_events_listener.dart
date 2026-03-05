import 'dart:async';

sealed class SmDbEvents {
  final String? message;
  const SmDbEvents({this.message});
}

class SmDbEventsListener {
  static final SmDbEventsListener instance = SmDbEventsListener._();
  SmDbEventsListener._();
  factory SmDbEventsListener() => instance;

  final _streamController = StreamController<SmDbEvents>.broadcast();

  Stream<SmDbEvents> get stream => _streamController.stream;

  void add(SmDbEvents event) {
    _streamController.add(event);
  }
}

class DBRecordDeleteAsMarkError extends SmDbEvents {
  const DBRecordDeleteAsMarkError({super.message});
}
