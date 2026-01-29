import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/peer.dart';

class StorageService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'speew_mvp.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de mensagens
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_sent INTEGER DEFAULT 0
      )
    ''');

    // Tabela de peers
    await db.execute('''
      CREATE TABLE peers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        last_seen INTEGER NOT NULL,
        is_connected INTEGER DEFAULT 0
      )
    ''');

    // Índices para performance
    await db.execute('CREATE INDEX idx_messages_sender ON messages(sender_id)');
    await db.execute('CREATE INDEX idx_messages_receiver ON messages(receiver_id)');
    await db.execute('CREATE INDEX idx_messages_timestamp ON messages(timestamp)');
  }

  // ==================== MESSAGES ====================

  Future<void> saveMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String peerId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [peerId, peerId],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Message>> getAllMessages() async {
    final db = await database;
    final maps = await db.query(
      'messages',
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<void> updateMessageStatus(String messageId, bool isSent) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_sent': isSent ? 1 : 0},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ==================== PEERS ====================

  Future<void> savePeer(Peer peer) async {
    final db = await database;
    await db.insert(
      'peers',
      peer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Peer>> getAllPeers() async {
    final db = await database;
    final maps = await db.query(
      'peers',
      orderBy: 'last_seen DESC',
    );

    return maps.map((map) => Peer.fromMap(map)).toList();
  }

  Future<Peer?> getPeer(String peerId) async {
    final db = await database;
    final maps = await db.query(
      'peers',
      where: 'id = ?',
      whereArgs: [peerId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Peer.fromMap(maps.first);
  }

  Future<void> updatePeerConnection(String peerId, bool isConnected) async {
    final db = await database;
    await db.update(
      'peers',
      {
        'is_connected': isConnected ? 1 : 0,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [peerId],
    );
  }

  Future<void> deletePeer(String peerId) async {
    final db = await database;
    await db.delete(
      'peers',
      where: 'id = ?',
      whereArgs: [peerId],
    );
  }

  // ==================== UTILITY ====================

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('peers');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
