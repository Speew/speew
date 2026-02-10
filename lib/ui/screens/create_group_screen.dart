import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/peer.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedPeerIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Grupo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final connectedPeers = chatProvider.connectedPeers;

          return Column(
            children: [
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Grupo',
                    hintText: 'Ex: Família, Amigos...',
                    prefixIcon: const Icon(Icons.group),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),

              if (_selectedPeerIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: _selectedPeerIds.map((peerId) {
                      final peer = connectedPeers.firstWhere(
                        (p) => p.id == peerId,
                      );
                      return Chip(
                        label: const Text(peer.name),
                        onDeleted: () {
                          setState(() {
                            _selectedPeerIds.remove(peerId);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),

              const Divider(),

              Expanded(
                child: connectedPeers.isEmpty
                    ? const Center(
                        child: const Text('Nenhum contato conectado'),
                      )
                    : ListView.builder(
                        itemCount: connectedPeers.length,
                        itemBuilder: (context, index) {
                          final peer = connectedPeers[index];
                          final isSelected = _selectedPeerIds.contains(peer.id);

                          return CheckboxListTile(
                            title: const Text(peer.name),
                            subtitle: const Text('Conectado'),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedPeerIds.add(peer.id);
                                } else {
                                  _selectedPeerIds.remove(peer.id);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              child: const Text(peer.name[0].toUpperCase()),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _createGroup() {
    final groupName = _nameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: const Text('Digite um nome para o grupo')),
      );
      return;
    }

    if (_selectedPeerIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text('Selecione pelo menos 2 pessoas'),
        ),
      );
      return;
    }

    final chatProvider = context.read<ChatProvider>();
    chatProvider.createGroup(
      name: groupName,
      memberIds: _selectedPeerIds.toList(),
    );

    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Grupo "$groupName" criado!')),
    );
  }
}