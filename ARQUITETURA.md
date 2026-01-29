# 📐 Arquitetura Técnica - Speew MVP

## 🎯 Visão Geral

O Speew MVP é um aplicativo de mensagens P2P offline construído com **Flutter/Dart**, focado em **simplicidade, funcionalidade e manutenibilidade**.

---

## 🏗️ Arquitetura Clean & Pragmática

```
┌─────────────────────────────────────────────────────┐
│                   UI Layer (Flutter)                 │
│  ┌───────────┬───────────┬──────────────────────┐  │
│  │  Screens  │  Widgets  │   Theme & Styles     │  │
│  └───────────┴───────────┴──────────────────────┘  │
├─────────────────────────────────────────────────────┤
│              Provider Layer (State)                  │
│  ┌─────────────────────────────────────────────┐   │
│  │        ChatProvider (Business Logic)         │   │
│  └─────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│             Service Layer (Core Logic)              │
│  ┌──────────┬───────────┬─────────────────────┐   │
│  │   P2P    │  Crypto   │      Storage        │   │
│  │ Service  │  Service  │      Service        │   │
│  └──────────┴───────────┴─────────────────────┘   │
├─────────────────────────────────────────────────────┤
│              Model Layer (Data)                     │
│  ┌──────────┬───────────┬─────────────────────┐   │
│  │ Message  │   Peer    │   Configuration     │   │
│  └──────────┴───────────┴─────────────────────┘   │
├─────────────────────────────────────────────────────┤
│         Platform Layer (Android/iOS)                │
│  ┌──────────────────────────────────────────────┐  │
│  │  Nearby Connections / Multipeer Connectivity  │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 📁 Estrutura de Arquivos

```
speew_mvp/
├── lib/
│   ├── main.dart (150 linhas)
│   │   └── Entry point + Setup inicial
│   │
│   ├── core/
│   │   ├── app_config.dart (200 linhas)
│   │   │   └── Constantes e configurações
│   │   └── utils.dart (350 linhas)
│   │       └── Utilitários reutilizáveis
│   │
│   ├── models/
│   │   ├── message.dart (60 linhas)
│   │   │   └── Modelo de mensagem
│   │   └── peer.dart (50 linhas)
│   │       └── Modelo de peer/dispositivo
│   │
│   ├── services/
│   │   ├── crypto_service.dart (120 linhas)
│   │   │   └── Criptografia E2E
│   │   ├── p2p_service.dart (250 linhas)
│   │   │   └── Wi-Fi Direct & Nearby
│   │   └── storage_service.dart (180 linhas)
│   │       └── SQLite & Persistência
│   │
│   ├── providers/
│   │   └── chat_provider.dart (300 linhas)
│   │       └── State management
│   │
│   └── ui/
│       ├── screens/
│       │   ├── home_screen.dart (250 linhas)
│       │   │   └── Lista de peers
│       │   └── chat_screen.dart (300 linhas)
│       │       └── Conversa 1-1
│       └── widgets/
│           ├── peer_avatar.dart (50 linhas)
│           ├── message_bubble.dart (100 linhas)
│           ├── connection_status.dart (80 linhas)
│           └── empty_state.dart (50 linhas)
│
├── android/
│   └── app/
│       ├── src/main/AndroidManifest.xml
│       └── build.gradle
│
└── pubspec.yaml

Total: ~2.500 linhas de código
```

---

## 🔄 Fluxo de Dados

### 1. Inicialização do App

```
main.dart
  │
  ├─> MaterialApp
  │     │
  │     └─> ChangeNotifierProvider
  │           │
  │           └─> ChatProvider
  │                 │
  │                 └─> SetupScreen
  │                       │
  │                       ├─> Solicitar permissões
  │                       ├─> Input do nome
  │                       └─> initialize()
  │                             │
  │                             ├─> P2PService.startAdvertising()
  │                             ├─> P2PService.startDiscovery()
  │                             ├─> StorageService.loadData()
  │                             └─> HomeScreen
```

### 2. Descoberta de Peers

```
P2PService
  │
  ├─> startDiscovery()
  │     │
  │     └─> Nearby.startDiscovery()
  │           │
  │           └─> onEndpointFound()
  │                 │
  │                 └─> discoveredPeersStream
  │                       │
  │                       └─> ChatProvider.listen()
  │                             │
  │                             └─> _addOrUpdatePeer()
  │                                   │
  │                                   ├─> StorageService.savePeer()
  │                                   └─> notifyListeners()
  │                                         │
  │                                         └─> UI atualizada
```

### 3. Conexão P2P

```
HomeScreen (usuário toca em peer)
  │
  └─> ChatProvider.connectToPeer()
        │
        └─> P2PService.connectToPeer()
              │
              ├─> Nearby.requestConnection()
              │     │
              │     └─> onConnectionInitiated()
              │           │
              │           └─> Nearby.acceptConnection()
              │
              └─> onConnectionResult()
                    │
                    └─> Status.CONNECTED
                          │
                          ├─> connectionStatusStream
                          │     │
                          │     └─> ChatProvider.listen()
                          │           │
                          │           └─> Update peer.isConnected
                          │
                          └─> UI mostra "Conectado"
```

### 4. Envio de Mensagem

```
ChatScreen (usuário digita e envia)
  │
  └─> ChatProvider.sendMessage()
        │
        ├─> 1. Criar Message object
        │
        ├─> 2. StorageService.saveMessage()
        │     │
        │     └─> SQLite INSERT
        │
        ├─> 3. Atualizar UI local (otimistic update)
        │     │
        │     └─> notifyListeners()
        │
        └─> 4. P2PService.sendMessage()
              │
              ├─> Montar payload JSON
              │     {
              │       type: 'message',
              │       content: 'texto',
              │       timestamp: 1234567890
              │     }
              │
              ├─> utf8.encode(JSON)
              │
              └─> Nearby.sendBytesPayload()
                    │
                    └─> [NETWORK] → Peer
```

### 5. Recepção de Mensagem

```
[NETWORK] ← Peer
  │
  └─> Nearby.onPayloadReceived()
        │
        ├─> Payload.bytes
        │
        ├─> utf8.decode()
        │
        ├─> JSON.decode()
        │
        └─> messagesStream.add()
              │
              └─> ChatProvider.listen()
                    │
                    └─> _handleIncomingMessage()
                          │
                          ├─> Criar Message object
                          │
                          ├─> StorageService.saveMessage()
                          │     │
                          │     └─> SQLite INSERT
                          │
                          └─> notifyListeners()
                                │
                                └─> UI atualizada com nova mensagem
```

---

## 🔐 Criptografia (Opcional no MVP)

### Algoritmo: ChaCha20-Poly1305

```
Envio:
  plaintext → ChaCha20-Poly1305 → {ciphertext, nonce, mac} → base64 → JSON → P2P

Recepção:
  P2P → JSON → base64.decode → {ciphertext, nonce, mac} → ChaCha20-Poly1305 → plaintext
```

### Troca de Chaves (Simplificada)

```
Peer A                          Peer B
  │                               │
  ├─> Gera senha compartilhada    │
  │   (QR code ou input manual)   │
  │                               │
  ├────── Senha compartilhada ────┤
  │                               │
  ├─> PBKDF2(senha) → key         │
  │                               │
  │                          PBKDF2(senha) → key
  │                               │
  └────────── Comunicação encriptada ──────┘
```

**Nota:** No MVP atual, criptografia está implementada mas não ativada por padrão para facilitar debugging.

---

## 💾 Persistência de Dados

### Banco de Dados SQLite

```sql
-- Tabela: messages
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  sender_id TEXT NOT NULL,
  receiver_id TEXT NOT NULL,
  content TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  is_sent INTEGER DEFAULT 0
);

-- Índices
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_timestamp ON messages(timestamp);

-- Tabela: peers
CREATE TABLE peers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  last_seen INTEGER NOT NULL,
  is_connected INTEGER DEFAULT 0
);
```

### Queries Principais

```dart
// Salvar mensagem
INSERT INTO messages VALUES (?, ?, ?, ?, ?, ?);

// Buscar mensagens de conversa
SELECT * FROM messages
WHERE sender_id = ? OR receiver_id = ?
ORDER BY timestamp ASC;

// Atualizar status de mensagem
UPDATE messages
SET is_sent = 1
WHERE id = ?;

// Salvar/atualizar peer
INSERT OR REPLACE INTO peers VALUES (?, ?, ?, ?);
```

---

## 📡 Rede P2P

### Protocolo: Wi-Fi Direct (Android)

```
┌─────────────┐                    ┌─────────────┐
│  Device A   │                    │  Device B   │
│             │                    │             │
│ Advertising │◄──────────────────►│ Discovery   │
│             │   Service ID       │             │
└─────────────┘   "com.speew.p2p"  └─────────────┘
       │                                  │
       │                                  │
       │    Connection Request            │
       │─────────────────────────────────►│
       │                                  │
       │    Connection Accepted           │
       │◄─────────────────────────────────│
       │                                  │
       │                                  │
       │    Payload (Mensagens)           │
       │◄────────────────────────────────►│
       │                                  │
```

### Tipos de Mensagens

```json
{
  "type": "message",
  "content": "Olá!",
  "timestamp": 1706543210000
}

{
  "type": "typing",
  "isTyping": true
}

{
  "type": "receipt",
  "messageId": "uuid-123",
  "status": "delivered"
}
```

---

## 🎨 UI/UX Design

### Cores Principais

```dart
Primary:    #2196F3 (Blue)
Accent:     #00BCD4 (Cyan)
Success:    #4CAF50 (Green)
Error:      #F44336 (Red)
Warning:    #FFC107 (Amber)

Message (Me):    #2196F3
Message (Peer):  #E0E0E0
```

### Componentes Reutilizáveis

1. **PeerAvatar**
   - Avatar circular colorido
   - Iniciais do nome
   - Indicador online/offline

2. **MessageBubble**
   - Bolha de mensagem
   - Timestamp
   - Status de envio
   - Long-press para ações

3. **ConnectionStatusBar**
   - Barra de status superior
   - Loading indicator
   - Mensagens informativas

4. **EmptyStateWidget**
   - Telas vazias
   - Ícone + Texto
   - Call-to-action opcional

---

## ⚡ Performance

### Otimizações Implementadas

1. **ListView.builder**
   - Renderização lazy de mensagens
   - Apenas widgets visíveis são criados

2. **Provider com ChangeNotifier**
   - Rebuilds seletivos
   - Apenas widgets que escutam são reconstruídos

3. **SQLite Indexing**
   - Índices em colunas frequentemente consultadas
   - Queries rápidas mesmo com milhares de mensagens

4. **Stream Controllers**
   - Comunicação reativa entre camadas
   - Sem polling desnecessário

### Benchmarks Esperados

| Operação | Tempo |
|----------|-------|
| Descoberta de peer | 2-5s |
| Estabelecer conexão | 3-7s |
| Enviar mensagem | <1s |
| Buscar 100 mensagens | <50ms |
| Inserir mensagem no DB | <10ms |

---

## 🔧 Configuração

### Arquivo: app_config.dart

```dart
class AppConfig {
  // P2P
  static const int maxPeers = 8;
  static const int connectionTimeout = 30;
  
  // Storage
  static const int maxMessagesPerPeer = 1000;
  
  // UI
  static const int maxMessageLength = 5000;
  
  // Network
  static const int maxRetries = 3;
  static const int pingInterval = 30;
}
```

Todas as constantes estão centralizadas, facilitando ajustes.

---

## 🧪 Testes

### Estrutura de Testes (Proposta)

```
test/
├── unit/
│   ├── models/
│   │   ├── message_test.dart
│   │   └── peer_test.dart
│   ├── services/
│   │   ├── crypto_service_test.dart
│   │   └── storage_service_test.dart
│   └── utils/
│       └── utils_test.dart
│
├── widget/
│   ├── message_bubble_test.dart
│   └── peer_avatar_test.dart
│
└── integration/
    ├── messaging_flow_test.dart
    └── connection_flow_test.dart
```

### Exemplo de Teste Unitário

```dart
test('Message deve ser criado corretamente', () {
  final message = Message(
    id: '123',
    senderId: 'user1',
    receiverId: 'user2',
    content: 'Olá',
    timestamp: DateTime.now(),
  );

  expect(message.id, '123');
  expect(message.content, 'Olá');
  expect(message.isSent, false);
});
```

---

## 🚀 Build & Deploy

### Build de Produção

```bash
# APK Release
flutter build apk --release --split-per-abi

# Saída:
# - app-armeabi-v7a-release.apk  (~12MB)
# - app-arm64-v8a-release.apk    (~14MB)
# - app-x86_64-release.apk       (~15MB)
```

### Assinatura do APK

```bash
# Criar keystore
keytool -genkey -v -keystore release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias speew

# Configurar em android/key.properties
storePassword=<senha>
keyPassword=<senha>
keyAlias=speew
storeFile=/path/to/release.jks
```

---

## 📊 Métricas de Qualidade

### Complexidade Ciclomática

| Arquivo | Complexidade | Avaliação |
|---------|--------------|-----------|
| crypto_service.dart | 6 | ✅ Baixa |
| p2p_service.dart | 12 | ✅ Média |
| chat_provider.dart | 15 | ✅ Média |
| storage_service.dart | 8 | ✅ Baixa |

**Meta:** Manter complexidade < 20 por arquivo

### Code Coverage (Alvo)

| Camada | Coverage |
|--------|----------|
| Models | 100% |
| Services | 80% |
| Providers | 70% |
| UI | 50% |

---

## 🔮 Roadmap Técnico

### v1.1 - Melhorias Básicas

- [ ] Testes unitários completos
- [ ] Testes de integração
- [ ] Notificações push locais
- [ ] Melhor tratamento de erros

### v1.2 - Features Intermediárias

- [ ] Grupos (3+ pessoas)
- [ ] Envio de imagens (comprimidas)
- [ ] Indicador de digitação
- [ ] Recibos de leitura

### v2.0 - Features Avançadas

- [ ] Mesh multi-hop
- [ ] Suporte iOS (Multipeer)
- [ ] Transferência de arquivos grandes
- [ ] Voice messages
- [ ] End-to-end encryption ativo por padrão

---

## 📚 Referências

### Bibliotecas Usadas

- **nearby_connections**: P2P Wi-Fi Direct
- **cryptography**: ChaCha20-Poly1305
- **provider**: State management
- **sqflite**: SQLite database
- **uuid**: Geração de IDs únicos
- **intl**: Formatação de datas

### Documentação Externa

- [Flutter Docs](https://flutter.dev/docs)
- [Nearby Connections API](https://developers.google.com/nearby/connections/overview)
- [SQLite](https://www.sqlite.org/docs.html)
- [ChaCha20-Poly1305](https://tools.ietf.org/html/rfc8439)

---

**Arquitetura v1.0 - Speew MVP**  
*Simples. Funcional. Manutenível.*
