import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final instance = LocalDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'blosab.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE conversations(address TEXT PRIMARY KEY, name TEXT NOT NULL, last_message TEXT NOT NULL DEFAULT \'\', updated TEXT NOT NULL)');
        await db.execute('CREATE TABLE messages(id INTEGER PRIMARY KEY AUTOINCREMENT, peer_address TEXT NOT NULL, sender TEXT NOT NULL, body TEXT NOT NULL, created TEXT NOT NULL, is_mine INTEGER NOT NULL DEFAULT 0)');
      },
    );
    return _db!;
  }

  Future<List<Map<String, Object?>>> conversations() async =>
      (await database).query('conversations', orderBy: 'updated DESC');

  Future<void> saveConversation({required String address, required String name, String lastMessage = ''}) async {
    await (await database).insert('conversations', {
      'address': address, 'name': name, 'last_message': lastMessage,
      'updated': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> messages(String address) async =>
      (await database).query('messages', where: 'peer_address = ?', whereArgs: [address], orderBy: 'id ASC');

  Future<void> saveMessage({required String address, required String sender, required String body, required bool isMine}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('messages', {'peer_address': address, 'sender': sender, 'body': body, 'created': now, 'is_mine': isMine ? 1 : 0});
      final found = await txn.query('conversations', columns: ['name'], where: 'address = ?', whereArgs: [address], limit: 1);
      final name = found.isNotEmpty ? found.first['name']?.toString() ?? sender : sender;
      await txn.insert('conversations', {'address': address, 'name': name, 'last_message': body, 'updated': now}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}