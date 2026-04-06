# Small Database

# sm_db

A lightweight, reactive, and efficient NoSQL database for Flutter and Dart. It supports object storage via adapters, file management, and real-time data streaming.

## Features

- **NoSQL Storage**: Simple key-value style storage for Dart objects.
- **Reactive**: Built-in support for Streams to listen to data changes.
- **Type Safe**: Uses Adapters to handle object-to-JSON transformations.
- **File Support**: Ability to store files and binary data (like covers) directly linked to the database.
- **Maintenance Tools**: Track deleted records, database size, and indices easily.

## Installation

Add `sm_db` to your `pubspec.yaml`:

```yaml
dependencies:
  sm_db: ^latest_version
```

```dart
class Post {
final int id;
final String title;

const Post({this.id = 0, required this.title});

Map<String, dynamic> toJson() => {'id': id, 'title': title};
factory Post.fromJson(Map<String, dynamic> json) => Post(id: json['id'], title: json['title']);
}

class PostAdapter extends JsonDBAdapter<Post> {
@override
Post fromMap(Map<String, dynamic> map) => Post.fromJson(map);

@override
int get getUniqueFieldId => 1;

@override
int getId(Post value) => value.id;

@override
Map<String, dynamic> toMap(Post value) => value.toJson();
}
```

```dart

```
