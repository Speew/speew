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

  final StreamController<Group> _groupsController = StreamController<Group>.broadcast();

  Stream<Group> get groupsStream => _groupsController.stream;
  List<Group> get groups => _groups.values.toList();

  Future<void> loadGroups() async {
    final groups = await _storageService.getAllGroups();
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
      memberIds = [creatorId, ...memberIds];
    }

    final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final groupKey = await _cryptoService.generateKey();

    final group = Group(
      id: groupId,
      name: name,
      description: description,
      adminId: creatorId,
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
    if (group == null) return false;

    if (group.adminId != requesterId) return false;

    if (group.memberIds.contains(memberId)) return false;

    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      description: group.description,
      adminId: group.adminId,
      memberIds: [...group.memberIds, memberId],
      createdAt: group.createdAt,
      groupKey: group.groupKey,
    );

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
    if (group == null) return false;

    if (group.adminId != requesterId) return false;

    if (memberId == group.adminId) return false;

    final updatedMembers = group.memberIds.where((id) => id != memberId).toList();

    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      description: group.description,
      adminId: group.adminId,
      memberIds: updatedMembers,
      createdAt: group.createdAt,
      groupKey: group.groupKey,
    );

    _groups[groupId] = updatedGroup;
    await _storageService.updateGroup(updatedGroup);

    _groupsController.add(updatedGroup);

    return true;
  }

  Future<bool> leaveGroup(String groupId, String memberId) async {
    final group = _groups[groupId];
    if (group == null) return false;

    if (group.adminId == memberId) {
      return await deleteGroup(groupId, memberId);
    }

    return await removeMember(groupId, memberId, group.adminId);
  }

  Future<bool> deleteGroup(String groupId, String requesterId) async {
    final group = _groups[groupId];
    if (group == null) return false;

    if (group.adminId != requesterId) return false;

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
    if (group == null) return false;

    if (requesterId != null && group.adminId != requesterId) return false;

    final updatedGroup = Group(
      id: group.id,
      name: name ?? group.name,
      description: description ?? group.description,
      adminId: group.adminId,
      memberIds: group.memberIds,
      createdAt: group.createdAt,
      groupKey: group.groupKey,
    );

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

    final encrypted = await _cryptoService.encrypt(content, groupKey);

    for (final memberId in group.memberIds) {
      if (memberId != senderId) {
        await _p2pService.sendMessage(
          peerId: memberId,
          message: encrypted,
          isGroup: true,
        );
      }
    }
  }

  Future<void> _distributeGroupKey(Group group, SecretKey key) async {
    for (final memberId in group.memberIds) {
      await _sendGroupKeyTo(memberId, group.id, key);
    }
  }

  Future<void> _sendGroupKeyTo(String memberId, String groupId, SecretKey key) async {
    final keyBytes = await key.extractBytes();
    final encoded = await _encodeKey(key);

    await _p2pService.sendMessage(
      peerId: memberId,
      message: 'GROUP_KEY:$groupId:$encoded',
    );
  }

  Future<String> _encodeKey(SecretKey key) async {
    final bytes = await key.extractBytes();
    return bytes.join(',');
  }

  Group? getGroup(String groupId) {
    return _groups[groupId];
  }

  List<Group> getUserGroups(String userId) {
    return _groups.values.where((g) => g.memberIds.contains(userId)).toList();
  }

  bool isGroupAdmin(String groupId, String userId) {
    final group = _groups[groupId];
    return group?.adminId == userId;
  }

  bool isGroupMember(String groupId, String userId) {
    final group = _groups[groupId];
    return group?.memberIds.contains(userId) ?? false;
  }

  void dispose() {
    _groups.clear();
    _groupKeys.clear();
    _groupsController.close();
  }
}
    if (group == null) return false;

    if (!group.isAdmin(requesterId)) {
      DebugUtils.log('Only admin can remove members', tag: 'GROUP');
      return false;
    }

    if (memberId == group.creatorId) {
      DebugUtils.log('Cannot remove group creator', tag: 'GROUP');
      return false;
    }

    final updatedMembers = group.memberIds.where((id) => id != memberId).toList();
    final updatedGroup = group.copyWith(memberIds: updatedMembers);

    _groups[groupId] = updatedGroup;
    _groupsController.add(updatedGroup);

    final systemMsg = GroupMessage(
      id: _generateMessageId(),
      groupId: groupId,
      senderId: 'system',
      content: 'Membro removido do grupo',
      timestamp: DateTime.now(),
      type: MessageType.system,
    );
    
    addMessage(systemMsg);
    
    DebugUtils.log('Member removed from group: $memberId', tag: 'GROUP');
    return true;
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

  Group? getGroup(String groupId) {
    return _groups[groupId];
  }

  bool isMember(String groupId, String userId) {
    final group = _groups[groupId];
    return group?.isMember(userId) ?? false;
  }

  List<Group> getUserGroups(String userId) {
    return _groups.values
        .where((group) => group.isMember(userId))
        .toList();
  }

  bool updateGroupName(String groupId, String newName, String requesterId) {
    final group = _groups[groupId];
    if (group == null) return false;

    if (!group.isAdmin(requesterId)) {
      DebugUtils.log('Only admin can update group name', tag: 'GROUP');
      return false;
    }

    final updatedGroup = group.copyWith(name: newName);
    _groups[groupId] = updatedGroup;
    _groupsController.add(updatedGroup);

    return true;
  }

  bool leaveGroup(String groupId, String userId) {
    final group = _groups[groupId];
    if (group == null) return false;

    if (group.creatorId == userId) {
      DebugUtils.log('Creator cannot leave group', tag: 'GROUP');
      return false;
    }

    return removeMember(groupId, userId, group.creatorId);
  }

  bool deleteGroup(String groupId, String requesterId) {
    final group = _groups[groupId];
    if (group == null) return false;

    if (!group.isAdmin(requesterId)) {
      DebugUtils.log('Only admin can delete group', tag: 'GROUP');
      return false;
    }

    _groups.remove(groupId);
    _groupMessages.remove(groupId);
    
    DebugUtils.log('Group deleted: $groupId', tag: 'GROUP');
    return true;
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  void dispose() {
    _groupsController.close();
    _messagesController.close();
  }
}