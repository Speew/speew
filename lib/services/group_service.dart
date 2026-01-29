import 'dart:async';
import '../models/group.dart';
import '../models/peer.dart';
import '../core/utils.dart';

class GroupService {
  final Map<String, Group> _groups = {};
  final Map<String, List<GroupMessage>> _groupMessages = {};
  
  final StreamController<Group> _groupsController = 
      StreamController<Group>.broadcast();
  final StreamController<GroupMessage> _messagesController =
      StreamController<GroupMessage>.broadcast();

  Stream<Group> get groupsStream => _groupsController.stream;
  Stream<GroupMessage> get messagesStream => _messagesController.stream;
  
  List<Group> get groups => _groups.values.toList();

  // Criar grupo
  Group createGroup({
    required String id,
    required String name,
    required String creatorId,
    required List<String> memberIds,
  }) {
    // Garantir que criador está nos membros
    if (!memberIds.contains(creatorId)) {
      memberIds = [creatorId, ...memberIds];
    }

    final group = Group(
      id: id,
      name: name,
      creatorId: creatorId,
      memberIds: memberIds,
      createdAt: DateTime.now(),
    );

    _groups[id] = group;
    _groupMessages[id] = [];
    
    DebugUtils.log('Group created: $name (${memberIds.length} members)', tag: 'GROUP');
    _groupsController.add(group);

    return group;
  }

  // Adicionar membro ao grupo
  bool addMember(String groupId, String memberId) {
    final group = _groups[groupId];
    if (group == null) return false;

    if (group.isMember(memberId)) {
      DebugUtils.log('Member already in group', tag: 'GROUP');
      return false;
    }

    final updatedGroup = group.copyWith(
      memberIds: [...group.memberIds, memberId],
    );

    _groups[groupId] = updatedGroup;
    _groupsController.add(updatedGroup);

    // Criar mensagem de sistema
    final systemMsg = GroupMessage(
      id: _generateMessageId(),
      groupId: groupId,
      senderId: 'system',
      content: 'Membro adicionado ao grupo',
      timestamp: DateTime.now(),
      type: MessageType.system,
    );
    
    addMessage(systemMsg);
    
    DebugUtils.log('Member added to group: $memberId', tag: 'GROUP');
    return true;
  }

  // Remover membro do grupo
  bool removeMember(String groupId, String memberId, String requesterId) {
    final group = _groups[groupId];
    if (group == null) return false;

    // Apenas admin pode remover
    if (!group.isAdmin(requesterId)) {
      DebugUtils.log('Only admin can remove members', tag: 'GROUP');
      return false;
    }

    // Não pode remover criador
    if (memberId == group.creatorId) {
      DebugUtils.log('Cannot remove group creator', tag: 'GROUP');
      return false;
    }

    final updatedMembers = group.memberIds.where((id) => id != memberId).toList();
    final updatedGroup = group.copyWith(memberIds: updatedMembers);

    _groups[groupId] = updatedGroup;
    _groupsController.add(updatedGroup);

    // Mensagem de sistema
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

  // Adicionar mensagem ao grupo
  void addMessage(GroupMessage message) {
    if (!_groupMessages.containsKey(message.groupId)) {
      _groupMessages[message.groupId] = [];
    }

    _groupMessages[message.groupId]!.add(message);
    _messagesController.add(message);
  }

  // Obter mensagens de um grupo
  List<GroupMessage> getMessages(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  // Obter grupo por ID
  Group? getGroup(String groupId) {
    return _groups[groupId];
  }

  // Verificar se usuário é membro
  bool isMember(String groupId, String userId) {
    final group = _groups[groupId];
    return group?.isMember(userId) ?? false;
  }

  // Obter grupos do usuário
  List<Group> getUserGroups(String userId) {
    return _groups.values
        .where((group) => group.isMember(userId))
        .toList();
  }

  // Atualizar nome do grupo
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

  // Sair do grupo
  bool leaveGroup(String groupId, String userId) {
    final group = _groups[groupId];
    if (group == null) return false;

    // Criador não pode sair
    if (group.creatorId == userId) {
      DebugUtils.log('Creator cannot leave group', tag: 'GROUP');
      return false;
    }

    return removeMember(groupId, userId, group.creatorId);
  }

  // Deletar grupo (apenas criador)
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
