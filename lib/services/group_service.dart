import 'dart:async';
import 'package:cryptography/cryptography.dart';
import '../models/group.dart';
import 'p2p_service.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

class GroupService {
  final P2PService _p2pService;
  final CryptoService _cryptoService;
  final StorageService _storageService;

  GroupService({
    required P2PService p2pService,
    required CryptoService cryptoService,
    required StorageService storageService,
  })  : _p2pService = p2pService,
        _cryptoService = cryptoService,
        _storageService = storageService;

  final Map<String, Group> _groups = {};
  final Map<String, SecretKey> _groupKeys = {};
  final Map<String, List<GroupMessage>> _groupMessages = {};

  final StreamController<Group> _groupsController = StreamController<Group>.broadcast();
  final StreamController<GroupMessage> _messagesController = StreamController<GroupMessage>.broadcast();

  Stream<Group> get groupsStream => _groupsController.stream;
  Stream<GroupMessage> get messagesStream => _messagesController.stream;
  List<Group> get groups => _groups.values.toList();

  Future<void> loadGroups() async {
    final groups = await _storageService.getGroups();
    for (final group in groups) {
      _groups[group.id] = group;
    }
  }

  Future<Group> createGroup({
    required String name,
    required String creatorId,
    required List<String> memberIds,
    String? description,
  }) async {
    if (!memberIds.contains(creatorId)) {
      memberIds.insert(0, creatorId);
    }

    final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final groupKey = await _cryptoService.generateSecretKey();

    final group = Group(
      id: groupId,
      name: name,
      description: description,
      creatorId: creatorId,
      memberIds: memberIds,
      createdAt: DateTime.now(),
      groupKey: await _encodeKey(groupKey),
    );

    _groups[groupId] = group;
    _groupKeys[groupId] = groupKey;

    await _storageService.saveGroup(group);
    await _distributeGroupKey(group, groupKey);

    _groupsController.add(group);

    return group;
  }

  Future<bool> addMember(String groupId, String memberId, String requesterId) async {
    final group = _groups[groupId];
    if (group == null || !group.isAdmin(requesterId) || group.isMember(memberId)) {
      return false;
    }

    final updatedGroup = group.copyWith(memberIds: [...group.memberIds, memberId]);
    _groups[groupId] = updatedGroup;
    await _storageService.updateGroup(updatedGroup);

    final groupKey = _groupKeys[groupId];
    if (groupKey != null) {
      await _sendGroupKeyTo(memberId, groupId, groupKey);
    }

    _groupsController.add(updatedGroup);

    return true;
  }

  Future<bool> removeMember(String groupId, String memberId, String requesterId) async {
    final group = _groups[groupId];
    if (group == null || !group.isAdmin(requesterId) || memberId == group.creatorId) {
      return false;
    }

    final updatedMembers = group.memberIds.where((id) => id != memberId).toList();
    final updatedGroup = group.copyWith(memberIds: updatedMembers);

    _groups[groupId] = updatedGroup;
    await _storageService.updateGroup(updatedGroup);

    _groupsController.add(updatedGroup);

    return true;
  }

  Future<bool> leaveGroup(String groupId, String memberId) async {
    final group = _groups[groupId];
    if (group == null) return false;

    if (group.creatorId == memberId) {
      return deleteGroup(groupId, memberId);
    }

    return removeMember(groupId, memberId, group.creatorId);
  }

  Future<bool> deleteGroup(String groupId, String requesterId) async {
    final group = _groups[groupId];
    if (group == null || !group.isAdmin(requesterId)) return false;

    _groups.remove(groupId);
    _groupKeys.remove(groupId);
    await _storageService.deleteGroup(groupId);

    return true;
  }

  Future<bool> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? requesterId,
  }) async {
    final group = _groups[groupId];
    if (group == null || (requesterId != null && !group.isAdmin(requesterId))) {
      return false;
    }

    final updatedGroup = group.copyWith(name: name, description: description);

    _groups[groupId] = updatedGroup;
    await _storageService.updateGroup(updatedGroup);

    _groupsController.add(updatedGroup);

    return true;
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String content,
  }) async {
    final group = _groups[groupId];
    if (group == null) return;

    final groupKey = _groupKeys[groupId];
    if (groupKey == null) return;

    final encrypted = await _cryptoService.encryptString(content, groupKey);

    final message = 'GROUP_MSG:$groupId:$encrypted';

    for (final memberId in group.memberIds) {
      if (memberId != senderId) {
        await _p2pService.sendMessage(memberId, message, isGroup: true);
      }
    }
  }

  Future<void> _distributeGroupKey(Group group, SecretKey key) async {
    for (final memberId in group.memberIds) {
      await _sendGroupKeyTo(memberId, group.id, key);
    }
  }

  Future<void> _sendGroupKeyTo(String memberId, String groupId, SecretKey key) async {
    final encoded = await _encodeKey(key);
    final message = 'GROUP_KEY:$groupId:$encoded';
    await _p2pService.sendMessage(memberId, message);
  }

  Future<String> _encodeKey(SecretKey key) async {
    final bytes = await key.extractBytes();
    return bytes.toString();
  }

  Group? getGroup(String groupId) {
    return _groups[groupId];
  }

  List<Group> getUserGroups(String userId) {
    return _groups.values.where((g) => g.isMember(userId)).toList();
  }

  bool isGroupAdmin(String groupId, String userId) {
    final group = _groups[groupId];
    return group?.isAdmin(userId) ?? false;
  }

  void addMessage(GroupMessage message) {
    if (!_groupMessages.containsKey(message.groupId)) {
      _groupMessages[message.groupId] = [];
    }
    _groupMessages[message.groupId]!.add(message);
    _messagesController.add(message);
  }

  List<GroupMessage> getMessages(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  void dispose() {
    _groups.clear();
    _groupKeys.clear();
    _groupsController.close();
    _messagesController.close();
  }
}
