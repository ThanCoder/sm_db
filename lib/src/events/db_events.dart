// ignore_for_file: public_member_api_docs, sort_constructors_first
abstract class DBEvent {}

class CoverOffsetChanged extends DBEvent {
  final int offset;
  CoverOffsetChanged({required this.offset});
}

class IncreLastIndex extends DBEvent {}
