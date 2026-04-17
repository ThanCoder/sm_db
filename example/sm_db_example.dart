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

  for (var post in await box.getAll()) {
    print('id: ${post.id} - title: ${post.title}');
  }

  // final files = await db.readAllFileRecordsInDatabase();
  // await db.mabyCompact();

  // await db.removeRecord(files.first);

  // await db.addFile(
  //   '/home/thancoder/Downloads/blender-5.1.0-linux-x64.tar.xz',
  //   onProgress: (progress) =>
  //       print('Progress: ${(progress * 100).toStringAsFixed(2)}%'),
  // );
  // await db.extractFile(
  //   files.first,
  //   savePath: files.first.name,
  //   onProgress: (progress) =>
  //       print('Progress: ${(progress * 100).toStringAsFixed(2)}%'),
  // );
  // await db.deleteCover();
  // print(files.first.info);
  // await db.removeRecord(files.last);
  // await db.compact(
  //   onProgress: (progress) =>
  //       print('Progress: ${(progress * 100).toStringAsFixed(2)}%'),
  // );

  print('all record: ${await db.readAll()}');

  print('lastIndex: ${db.lastIndex}');
  print('deletedCount: ${db.deletedCount}');
  print('deletedSize: ${db.deletedSize}');
  print('Type: ${db.header}');
}

class PostAdapter extends SMDBJsonAdapter<Post> {
  @override
  Post fromMap(Map<String, dynamic> map) {
    return Post.fromJson(map);
  }

  @override
  int get getUniqueFieldId => 1;

  @override
  int getId(Post value) {
    return value.id;
  }

  @override
  Map<String, dynamic> toMap(Post value) {
    return value.toJson();
  }
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
  int get getUniqueFieldId => 2;

  @override
  Map<String, dynamic> toMap(PostContent value) {
    return value.toJson();
  }

  @override
  int getParentId(PostContent value) {
    return value.parentId;
  }
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
}
