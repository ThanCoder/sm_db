import 'package:sm_db/sm_db.dart';

void main() async {
  final db = SMDB.getInstance();
  await db.open('test.db');
  // SmDbEventsListener.instance.stream.listen((event) {
  //   print('Event: $event: ${event.message}');
  // });

  db.registerAdapterNotExists<Post>(PostAdapter());

  // final ad = db.getAdapter<Post>();
  final box = db.getBox<Post>();

  // await box.add(Post(title: 'post one'));
  // await box.add(Post(title: 'post two'));
  // await box.add(Post(title: 'post three'));

  // await box.deleteById(11);

  // await db.deleteAllJsonRecords();

  // print(await box.getAll());
  await for (var post in box.getAllStream()) {
    print('id: ${post.id} - ${post.title}');
  }

  // await db.addFile('/home/thancoder/projects/plugins/sm_db/README.md');
  // await db.addFile('/home/thancoder/projects/plugins/sm_db/CHANGELOG.md');

  //set cover
  // await db.setCoverFormPath('cover.png');

  print('all record: ${await db.readAll()}');

  print('lastIndex: ${db.lastIndex}');
  print('deletedCount: ${db.deletedCount}');
  print('deletedSize: ${db.deletedSize}');
  print('Type: ${db.header}');

  // if (db.coverRecod != null) {
  //   print('cover record');
  //   print(await db.getCoverData());
  // }
}

class PostAdapter extends JsonDBAdapter<Post> {
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
