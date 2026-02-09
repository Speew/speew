import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../models/group.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Database? _database;
  Box? _settingsBox;
  Box? _cacheBox;

  Future<void> initialize() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox('settings');
    _cacheBox = await Hive.openBox('cache');
    _database = await _initDatabase();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'speew.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE peers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        public_key TEXT,
        avatar TEXT,
        status TEXT,
        is_connected INTEGER DEFAULT 0,
        last_seen INTEGER,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        type TEXT DEFAULT 'text',
        status TEXT DEFAULT 'pending',
        is_read INTEGER DEFAULT 0,
        reply_to TEXT,
        file_path TEXT,
        file_name TEXT,
        file_size INTEGER,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        admin_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        member_ids TEXT NOT NULL,
        avatar TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        last_message TEXT,
        last_message_time INTEGER,
        unread_count INTEGER DEFAULT 0,
        is_pinned INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_messages_receiver ON messages(receiver_id, timestamp DESC)');
    await db.execute('CREATE INDEX idx_messages_sender ON messages(sender_id, timestamp DESC)');
    await db.execute('CREATE INDEX idx_chats_time ON chats(last_message_time DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE peers ADD COLUMN public_key TEXT');
      await db.execute('ALTER TABLE peers ADD COLUMN avatar TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN is_read INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE messages ADD COLUMN reply_to TEXT');
    }
  }

  // Peers
  Future<int> savePeer(Peer peer) async {
    final db = await database;
    return await db.insert('peers', peer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Peer>> getAllPeers() async {
    final db = await database;
    final maps = await db.query('peers', orderBy: 'last_seen DESC');
    return maps.map((m) => Peer.fromMap(m)).toList();
  }

  Future<Peer?> getPeer(String id) async {
    final db = await database;
    final maps = await db.query('peers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Peer.fromMap(maps.first);
  }

  Future<int> updatePeerStatus(String id, bool isConnected) async {
    final db = await database;
    return await db.update(
      'peers',
      {'is_connected': isConnected ? 1 : 0, 'last_seen': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePeer(String id) async {
    final db = await database;
    return await db.delete('peers', where: 'id = ?', whereArgs: [id]);
  }

  // Messages
  Future<int> saveMessage(Message message) async {
    final db = await database;
    return await db.insert('messages', message.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages(String chatId, {int limit = 100, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [chatId, chatId],
      orderBy: 'timestamp ASC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  Future<Message?> getLastMessage(String chatId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [chatId, chatId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Message.fromMap(maps.first);
  }

  Future<int> getUnreadCount(String chatId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE receiver_id = ? AND is_read = 0',
      [chatId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> updateMessage(Message message) async {
    final db = await database;
    return await db.update('messages', message.toMap(), where: 'id = ?', whereArgs: [message.id]);
  }

  Future<int> deleteMessage(String id) async {
    final db = await database;
    return await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllMessages(String chatId) async {
    final db = await database;
    return await db.delete('messages', where: 'sender_id = ? OR receiver_id = ?', whereArgs: [chatId, chatId]);
  }

  // Groups
  Future<int> saveGroup(Group group) async {
    final db = await database;
    return await db.insert('groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Group>> getAllGroups() async {
    final db = await database;
    final maps = await db.query('groups', orderBy: 'created_at DESC');
    return maps.map((m) => Group.fromMap(m)).toList();
  }

  Future<Group?> getGroup(String id) async {
    final db = await database;
    final maps = await db.query('groups', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Group.fromMap(maps.first);
  }

  Future<int> updateGroup(Group group) async {
    final db = await database;
    return await db.update('groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<int> deleteGroup(String id) async {
    final db = await database;
    return await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // Chats
  Future<List<dynamic>> getAllChats() async {
    final db = await database;
    final maps = await db.query('chats', orderBy: 'last_message_time DESC');
    return maps.map((m) => m).toList();
  }

  // Settings (Hive)
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox?.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue);
  }

  // Cache (Hive)
  Future<void> cache(String key, dynamic value) async {
    await _cacheBox?.put(key, value);
  }

  dynamic getCached(String key) {
    return _cacheBox?.get(key);
  }

  Future<void> clearCache() async {
    await _cacheBox?.clear();
  }

  // Cleanup
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('peers');
    await db.delete('groups');
    await db.delete('chats');
    await _settingsBox?.clear();
    await _cacheBox?.clear();
  }

  Future<void> close() async {
    await _database?.close();
    await _settingsBox?.close();
    await _cacheBox?.close();
  }
}