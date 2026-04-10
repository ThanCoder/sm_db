# SMDB

A lightweight, reactive, and efficient NoSQL database for Flutter and Dart. It supports object storage via adapters, file management, and real-time data streaming.

## SMDB (Simple Mobile Database)

SMDB is a high-performance, indexed binary database designed for Flutter/Dart. It supports multiple record types including JSON, Binary Files, and Cover Images, utilizing an append-only architecture with an automated Compaction mechanism to keep the database clean and efficient.

## 🚀 Key Features

- **Hybrid Storage**: Store structured JSON data and large binary files in a single database file.

- **Indexed Access**: Maintains an in-memory index for fast lookups and efficient record management.

- **Smart Compaction**: Automatically removes "deleted" marks and reorganizes the file to save disk space.

- **Progress Tracking**: Built-in support for progress callbacks and cancellation during large file operations or compaction.

- **Event Driven**: Integrated EventBus for monitoring database changes.

- **Singleton Pattern**: Easy access from anywhere in your app via SMDB.getInstance().

## 🛠 Core Concepts

### 1. Record Types

### The database handles three primary record types:

- **CoverRecord**: Used for a single database "cover" or preview image.

- **JsonRecord**: For structured data (Maps/Lists). Requires a JsonDBAdapter.

- **FileRecord**: For storing large binary blobs (Images, Videos, PDFs) without loading them into memory.

### 2. Append-Only Logic

When you add or delete data, SMDB appends a "Mark" or new data to the end of the file. This ensures fast write operations. 3. Compaction

Deleted records are not immediately removed from the physical disk to prevent slow file-reconstruction. The compact() method creates a new, clean version of the database containing only Active records.

## Installation

Add `sm_db` to your `pubspec.yaml`:

```yaml
dependencies:
  sm_db: ^latest_version
```

## Example

```dart
final db = SMDB.getInstance();
  await db.open('test.db');

  db.registerAdapterNotExists<Post>(PostAdapter());
  db.registerAdapterNotExists<PostContent>(PostContentAdapter());

  final box = db.getBox<Post>();
  final contentBox = db.getBox<PostContent>();

  //Return (addedValue,record, isAdded)
  final (value, _, _) = await box.add(Post(title: 'post two'));

   await contentBox.add(
     PostContent(parentId: value.id, content: '${value.title} content one'),
   );
    await contentBox.add(
     PostContent(parentId: value.id, content: '${value.title} content two'),
   );
   await contentBox.deleteById(28, willDeleteByParentRecord: true);


  await contentBox.deleteAll();
  await box.deleteAll();

  for (var post in await box.getAll()) {
    print('id: ${post.id} - title: ${post.title}');
  }


  for (var content in await contentBox.getAll()) {
    print(
      'id: ${content.id} - parentId: ${content.parentId} - Data: ${content.content}',
    );
  }

  print('all record: ${await db.readAll()}');

  print('lastIndex: ${db.lastIndex}');
  print('deletedCount: ${db.deletedCount}');
  print('deletedSize: ${db.deletedSize}');
  print('Type: ${db.header}');

```

### Opening a Database

```dart
final db = SMDB.getInstance();
await db.open('path/to/my_database.db');
```

## Registering Adapters

Before saving custom objects as JSON, you must register an adapter:
Dart

```dart
db.registerAdapterNotExists<User>(UserAdapter());
```

## Working with Files

You can add a file to the database and track the progress:
Dart

```dart
final record = FileRecord.fromPath('local_file.jpg');
await db.addRecord(
  record,
  onProgressFile: (p) => print('Saving: $p'),
);
```

### Deleting Records

Records are marked as deleted first. mabyCompact() is called internally to decide if a full cleanup is needed based on the deletedCount.
Dart

```dart
await db.removeRecord(myRecord);
```

## Manual Compaction

To manually trigger a file cleanup and show progress to the user:
Dart

```dart
await db.compact(
  onProgress: (p) => print('Compacting Database: $p'),
);
```

## 🏗 Architecture Detail (Code Overview)

### Database Header

Every SMDB file starts with a header containing the DB Type and Version. Use readHeaderFromPath to inspect a file without loading the entire database.
IndexedDB Layer

### This is the "Brain" of the system. It:

- **Loads Indexes**: Reads the file and builds a list of allActiveRecordList in RAM.

- **Manages Offsets**: Keeps track of exactly where each record starts in the physical file.

- **Monitors Health**: Tracks deletedSize and deletedCount to determine when compaction is necessary.

### transferRecord Mechanism

The compaction process uses a RandomAccessFile to RandomAccessFile transfer. It uses a 1MB Buffer to move data, ensuring the app doesn't crash even if you are moving gigabytes of data.

## Json DB Adapter

```dart
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

class PostContentAdapter extends JsonDBAdapter<PostContent> {
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
```

## Cover

```dart
  await db.setCoverFormPath('/home/thancoder/Pictures/images.jpeg');
  await db.setCoverFormPath('/home/thancoder/Pictures/green_way_logo.png');

  final exported = await db.exportCoverFile('test.jpeg');
  if (exported) {
    print('exported Cover');
  }
```

## Files

```dart
  await db.addFiles([
    '/home/thancoder/projects/plugins/sm_db/CHANGELOG.md',
    '/home/thancoder/projects/plugins/sm_db/test.jpeg',
  ]);
  await db.addFile(
    '/home/thancoder/Videos/Supernatural S1/11.mp4',
    onProgressFile: (progress) =>
        print('Progress: ${(progress * 100).toStringAsFixed(2)}%'),
  );

  final files = await db.readAllFiles();
  print(files.last.info);

  // Remove
  await db.removeRecord(files.last);

  // await files.last.extract(raf, outDir: outDir)
  await db.extractFile(
    files.last,
    savePath: 'test.mp4',
    onProgress: (progress) =>
        print('Progress: ${(progress * 100).toStringAsFixed(2)}%'),
  );
```

```

```
