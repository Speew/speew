import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/peer.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Database? _database;

  Future<void> initialize() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'speew.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sender_id TEXT NOT NULL,
            receiver_id TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            type INTEGER NOT NULL,
            status INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE peers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            last_seen INTEGER NOT NULL,
            is_connected INTEGER NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_messages_receiver ON messages(receiver_id)');
        await db.execute('CREATE INDEX idx_messages_timestamp ON messages(timestamp)');
      },
    );
  }

  Database get database {
    if (_database == null) {
      throw Exception('StorageService not initialized');
    }
    return _database!;
  }

  Future<void> saveMessage(Message message) async {
    await database.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String peerId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'messages',
      where: 'receiver_id = ? OR sender_id = ?',
      whereArgs: [peerId, peerId],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<void> deleteMessage(String messageId) async {
    await database.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> savePeer(Peer peer) async {
    await database.insert(
      'peers',
      peer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Peer>> getPeers() async {
    final List<Map<String, dynamic>> maps = await database.query(
      'peers',
      orderBy: 'last_seen DESC',
    );

    return maps.map((map) => Peer.fromMap(map)).toList();
  }

  Future<void> updatePeerConnection(String peerId, bool isConnected) async {
    await database.update(
      'peers',
      {'is_connected': isConnected ? 1 : 0, 'last_seen': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [peerId],
    );
  }

  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}
