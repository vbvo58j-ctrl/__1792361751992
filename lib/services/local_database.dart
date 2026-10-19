import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    _db = await openDatabase(
      p.join(base, 'blosab.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations(
            address TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            last_message TEXT NOT NULL DEFAULT '',
            updated TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peer_address TEXT NOT NULL,
            sender TEXT NOT NULL,
            body TEXT NOT NULL,
            created TEXT NOT NULL,
            is_mine INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<Map<String, Object?>>> conversations() async {
    final db = await database;
    return db.query('conversations', orderBy: 'updated DESC');
  }

  Future<void> saveConversation({
    required String address,
    required String name,
    String lastMessage = '',
  }) async {
    final db = await database;
    await db.insert('conversations', {
      'address': address,
      'name': name,
      'last_message': lastMessage,
      'updated': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLastMessage(String address, String message) async {
    final db = await database;
    await db.update('conversations', {
      'last_message': message,
      'updated': DateTime.now().toIso8601String(),
    }, where: 'address = ?', whereArgs: [address]);
  }

  Future<List<Map<String, Object?>>> messages(String address) async {
    final db = await database;
    return db.query('messages',
      where: 'peer_address = ?', whereArgs: [address], orderBy: 'id ASC');
  }

  Future<void> saveMessage({
    required String address,
    required String sender,
    required String body,
    required bool isMine,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('messages', {
      'peer_address': address,
      'sender': sender,
      'body': body,
      'created': now,
      'is_mine': isMine ? 1 : 0,
    });
    await saveConversation(address: address, name: sender, lastMessage: body);
  }
}