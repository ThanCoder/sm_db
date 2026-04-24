// ignore_for_file: unused_local_variable

import 'package:sm_db/sm_db.dart';

void main() async {
  final db = SMDB.getInstance();
  db.registerAdapterNotExists<Post>(PostAdapter());
  db.registerAdapterNotExists<PostContent>(PostContentAdapter());

  await db.open('test.db');

  final box = db.getBox<Post>();
  // await box.add(Post(title: 'post two'));
  // await box.add(Post(title: 'post three'));

  // await box.deleteById(1);
  // await box.deleteById(2);
  // await box.deleteById(1);

  print(await box.getAll());

  print('lastIndex: ${db.lastIndex}');
  print('deletedCount: ${db.deletedCount}');
  print('deletedSize: ${db.deletedSize}');
  print('Type: ${db.header}');

  await db.close();
}

class PostAdapter extends SMDBJsonAdapter<Post> {
  @override
  Post fromMap(Map<String, dynamic> map) {
    return Post.fromJson(map);
  }

  @override
  int getId(Post value) {
    return value.id;
  }

  @override
  Map<String, dynamic> toMap(Post value) {
    return value.toJson();
  }

  @override
  int get adapterTypeId => 1;
}

class PostContentAdapter extends SMDBJsonAdapter<PostContent> {
  @override
  PostContent fromMap(Map<String, dynamic> map) {
    return PostContent.fromJson(map);
  }

  @override
  int getId(PostContent value) {
    return value.id;
  }

  @override
  Map<String, dynamic> toMap(PostContent value) {
    return value.toJson();
  }

  @override
  int getParentId(PostContent value) {
    return value.parentId;
  }

  @override
  int get adapterTypeId => 2;
}

class Post {
  final int id;
  final String title;

  const Post({this.id = 0, required this.title});

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title};
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(id: json['id'], title: json['title']);
  }
  @override
  String toString() {
    return 'ID: $id - Title: $title';
  }
}

class PostContent {
  final int id;
  final int parentId;
  final String content;

  const PostContent({
    this.id = 0,
    required this.parentId,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'parentId': parentId, 'content': content};
  }

  factory PostContent.fromJson(Map<String, dynamic> json) {
    return PostContent(
      id: json['id'],
      parentId: json['parentId'],
      content: json['content'],
    );
  }
  @override
  String toString() {
    return 'ID: $id - parentId: $parentId';
  }
}
