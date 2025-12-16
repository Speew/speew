import '../../models/message.dart';
import '../../services/crypto/crypto_service.dart';
import '../../services/network/file_transfer_service.dart';
import '../../services/network/p2p_service.dart';
import '../../services/storage/database_service.dart';
import '../../services/wallet/wallet_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';

/// Tela de chat para conversa com um peer
/// Permite enviar texto, arquivos e moeda simbólica
class ChatScreen extends StatefulWidget {
  final String userId;
  final String peerId;
  final String peerName;

  const ChatScreen({
    Key? key,
    required this.userId,
    required this.peerId,
    required this.peerName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();
  final P2PService _p2p = P2PService();
  final FileTransferService _fileTransfer = FileTransferService();
  final WalletService _wallet = WalletService();

  List<Message> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenToIncomingMessages();
  }

  /// Carrega mensagens do banco de dados
  Future<void> _loadMessages() async {
    try {
      final messages = await _db.getMessagesBetweenUsers(widget.userId, widget.peerId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      _showError('Erro ao carregar mensagens: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Escuta mensagens recebidas em tempo real
  void _listenToIncomingMessages() {
    _p2p.messageStream.listen((p2pMessage) {
      if (p2pMessage.senderId == widget.peerId && p2pMessage.receiverId == widget.userId) {
        _loadMessages(); // Recarrega mensagens quando recebe nova
      }
    });
  }

  /// Envia mensagem de texto
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Gerar chave simétrica para criptografar a mensagem
      final symmetricKey = await _crypto.generateSymmetricKey();
      
      // Criptografar o conteúdo
      final encrypted = await _crypto.encryptData(text, symmetricKey);
      final encryptedContent = '${encrypted['ciphertext']}|${encrypted['nonce']}|${encrypted['mac']}';

      // Criar mensagem
      final message = Message(
        messageId: _crypto.generateUniqueId(),
        senderId: widget.userId,
        receiverId: widget.peerId,
        contentEncrypted: encryptedContent,
        timestamp: DateTime.now(),
        status: 'pending',
        type: 'text',
      );

      // Salvar no banco de dados
      await _db.insertMessage(message);

      // Enviar via P2P
      final p2pMessage = P2PMessage(
        messageId: message.messageId,
        senderId: widget.userId,
        receiverId: widget.peerId,
        type: 'text',
        payload: message.toMap(),
      );
      
      await _p2p.sendMessage(widget.peerId, p2pMessage);

      // Limpar campo de texto
      _messageController.clear();

      // Recarregar mensagens
      await _loadMessages();
    } catch (e) {
      _showError('Erro ao enviar mensagem: $e');
    }
  }

  /// Envia arquivo
  Future<void> _sendFile() async {
    try {
      // Em produção, usar file_picker para selecionar arquivo
      _showInfo('Seleção de arquivo não implementada nesta versão de demonstração');
      
      // Exemplo de uso:
      // final result = await FilePicker.platform.pickFiles();
      // if (result != null) {
      //   final file = File(result.files.single.path!);
      //   await _fileTransfer.fragmentFile(file, widget.userId);
      //   // Enviar blocos via P2P
      // }
    } catch (e) {
      _showError('Erro ao enviar arquivo: $e');
    }
  }

  /// Envia moeda simbólica
  Future<void> _sendCoins() async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar Moeda'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade',
            hintText: 'Digite a quantidade',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                await _processCoinTransfer(amount);
              } else {
                _showError('Quantidade inválida');
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  /// Processa transferência de moeda
  Future<void> _processCoinTransfer(double amount) async {
    try {
      // Em produção, obter chave privada do armazenamento seguro
      final privateKey = 'user-private-key'; // Placeholder
      
      final transaction = await _wallet.sendCoins(
        senderId: widget.userId,
        receiverId: widget.peerId,
        amount: amount,
        senderPrivateKey: privateKey,
      );

      if (transaction != null) {
        _showSuccess('Moeda enviada: $amount');
      } else {
        _showError('Falha ao enviar moeda');
      }
    } catch (e) {
      _showError('Erro ao enviar moeda: $e');
    }
  }

  /// Rola para o final da lista de mensagens
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Mostra mensagem de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Mostra mensagem de sucesso
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Mostra mensagem de informação
  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _sendFile,
          ),
          IconButton(
            icon: const Icon(Icons.monetization_on),
            onPressed: _sendCoins,
          ),
        ],
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),
          
          // Campo de entrada de mensagem
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Constrói a lista de mensagens
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Nenhuma mensagem ainda\nEnvie a primeira mensagem!'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == widget.userId;
        
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  /// Constrói um balão de mensagem
  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conteúdo da mensagem (criptografado - em produção, descriptografar)
            Text(
              message.type == 'text' 
                ? '[Mensagem criptografada]' 
                : '[${message.type.toUpperCase()}]',
              style: const TextStyle(fontSize: 16),
            ),
            
            const SizedBox(height: 4),
            
            // Timestamp e status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == 'delivered' 
                      ? Icons.done_all 
                      : Icons.done,
                    size: 16,
                    color: message.status == 'read' 
                      ? Colors.blue 
                      : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o campo de entrada de mensagem
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Digite uma mensagem...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(),
            ),
          ),
          
          const SizedBox(width: 8),
          
          IconButton(
            icon: const Icon(Icons.send),
            color: Colors.blue,
            onPressed: _sendTextMessage,
          ),
        ],
      ),
    );
  }

  /// Formata timestamp para exibição
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
