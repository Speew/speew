# 👨‍💻 Guia de Desenvolvimento - Speew MVP

## 🎯 Bem-vindo!

Este guia vai te ajudar a contribuir com o projeto Speew MVP.

---

## 🛠️ Setup do Ambiente

### 1. Pré-requisitos

```bash
# Flutter SDK (3.0+)
flutter --version

# Android Studio ou VS Code
# Android SDK (API 21+)
# Git
```

### 2. Clonar e Configurar

```bash
# Clone
git clone <seu-repo>
cd speew_mvp

# Instalar dependências
flutter pub get

# Verificar setup
flutter doctor
```

### 3. Rodar em Device

```bash
# Listar devices
flutter devices

# Rodar
flutter run -d <device-id>

# Modo debug com hot reload
flutter run --debug

# Modo release
flutter run --release
```

---

## 📂 Estrutura do Código

### Convenções de Nomenclatura

```dart
// Classes: PascalCase
class ChatProvider extends ChangeNotifier {}

// Arquivos: snake_case
chat_provider.dart

// Variáveis e funções: camelCase
String userName;
void sendMessage() {}

// Constantes: UPPER_SNAKE_CASE (em classes)
static const String APP_NAME = 'Speew';

// Constantes: lowerCamelCase (globais)
const int maxRetries = 3;

// Private: prefixo _
String _privateVar;
void _privateMethod() {}
```

### Organização de Imports

```dart
// 1. Dart core
import 'dart:async';
import 'dart:convert';

// 2. Flutter
import 'package:flutter/material.dart';

// 3. Packages externos
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

// 4. Imports locais (relativos)
import '../models/message.dart';
import '../services/p2p_service.dart';
```

---

## 🎨 Estilo de Código

### Formatação

```bash
# Formatar tudo
flutter format .

# Formatar arquivo específico
flutter format lib/main.dart

# Verificar formatação
flutter format --set-exit-if-changed .
```

### Análise Estática

```bash
# Rodar analyzer
flutter analyze

# Deve retornar: No issues found!
```

### Regras de Linting

Configurado em `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_final_fields
    - avoid_print
    - always_declare_return_types
```

---

## 🧩 Como Adicionar Features

### 1. Criar Issue

Antes de começar, crie uma issue descrevendo:
- O que será implementado
- Por que é necessário
- Como será implementado

### 2. Branch Nova

```bash
git checkout -b feature/nome-da-feature
```

### 3. Desenvolvimento

#### Exemplo: Adicionar Indicador de Digitação

**a) Atualizar Model**

```dart
// lib/models/peer.dart
class Peer {
  final bool isTyping;
  
  Peer copyWith({bool? isTyping}) {
    return Peer(
      // ... outros campos
      isTyping: isTyping ?? this.isTyping,
    );
  }
}
```

**b) Atualizar Service**

```dart
// lib/services/p2p_service.dart
Future<void> sendTypingIndicator(String peerId, bool isTyping) async {
  final payload = jsonEncode({
    'type': 'typing',
    'isTyping': isTyping,
  });
  
  await _nearby.sendBytesPayload(peerId, utf8.encode(payload));
}
```

**c) Atualizar Provider**

```dart
// lib/providers/chat_provider.dart
void setTyping(String peerId, bool isTyping) {
  final index = _peers.indexWhere((p) => p.id == peerId);
  if (index >= 0) {
    _peers[index] = _peers[index].copyWith(isTyping: isTyping);
    notifyListeners();
  }
}
```

**d) Atualizar UI**

```dart
// lib/ui/screens/chat_screen.dart
if (peer.isTyping)
  Padding(
    padding: const EdgeInsets.all(8),
    child: Text('${peer.name} está digitando...'),
  ),
```

### 4. Testar

```bash
# Testar manualmente em 2 devices
flutter run -d device1
flutter run -d device2

# Testar casos:
# 1. Feature funciona?
# 2. Não quebrou nada?
# 3. Performance ok?
```

### 5. Commit & Push

```bash
# Add arquivos
git add .

# Commit com mensagem descritiva
git commit -m "feat: adiciona indicador de digitação"

# Push
git push origin feature/nome-da-feature
```

### 6. Pull Request

Crie PR com:
- Descrição clara
- Screenshots/GIFs se UI mudou
- Checklist de testes

---

## 🧪 Testes

### Testes Unitários

```dart
// test/services/crypto_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:speew_mvp/services/crypto_service.dart';

void main() {
  group('CryptoService', () {
    late CryptoService cryptoService;

    setUp(() {
      cryptoService = CryptoService();
    });

    test('deve encriptar e decriptar corretamente', () async {
      final key = await cryptoService.generateKey();
      final plaintext = 'Hello, World!';
      
      final encrypted = await cryptoService.encrypt(plaintext, key);
      final decrypted = await cryptoService.decrypt(encrypted, key);
      
      expect(decrypted, plaintext);
    });
  });
}
```

**Rodar testes:**

```bash
flutter test
```

### Testes de Widget

```dart
// test/widgets/message_bubble_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:speew_mvp/ui/widgets/message_bubble.dart';

void main() {
  testWidgets('MessageBubble mostra conteúdo', (tester) async {
    final message = Message(
      id: '1',
      senderId: 'me',
      receiverId: 'you',
      content: 'Test message',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message, isMe: true),
        ),
      ),
    );

    expect(find.text('Test message'), findsOneWidget);
  });
}
```

### Testes de Integração

```bash
# Em device real
flutter test integration_test/app_test.dart
```

---

## 🐛 Debugging

### Print Debugging

```dart
import 'package:speew_mvp/core/utils.dart';

DebugUtils.log('Mensagem de debug', tag: 'ChatProvider');
DebugUtils.logError('Erro!', error: e, stackTrace: st);
```

### DevTools

```bash
# Abrir DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Rodar app e conectar
flutter run --observatory-port=9200
# Abrir http://localhost:9200 no DevTools
```

### Breakpoints

No VS Code:
1. Clique na margem esquerda do editor
2. Rode em modo debug (F5)
3. Inspecione variáveis

---

## 📦 Dependências

### Adicionar Nova Dependência

```bash
# Adicionar package
flutter pub add nome_do_package

# Atualizar
flutter pub upgrade

# Remover
flutter pub remove nome_do_package
```

### Quando Adicionar

✅ **Adicione** se:
- Resolve problema complexo
- É bem mantido (updates recentes)
- Tem bom rating no pub.dev
- Não há alternativa mais simples

❌ **Não adicione** se:
- Pode ser implementado facilmente
- Não é mantido há > 1 ano
- Tem issues abertas críticas
- Adiciona muito peso ao app

---

## 🎯 Boas Práticas

### 1. Single Responsibility

```dart
// ❌ Ruim: Classe faz muita coisa
class SuperService {
  void sendMessage() {}
  void encryptData() {}
  void saveToDatabase() {}
  void connectP2P() {}
}

// ✅ Bom: Cada classe tem 1 responsabilidade
class P2PService {
  void connect() {}
  void send() {}
}

class CryptoService {
  void encrypt() {}
  void decrypt() {}
}
```

### 2. Evitar setState em Stateless

```dart
// ❌ Ruim
class MyWidget extends StatelessWidget {
  int counter = 0; // Não funciona!
  
  void increment() {
    counter++; // Não vai atualizar UI
  }
}

// ✅ Bom: Use Provider
class MyWidget extends StatelessWidget {
  Widget build(context) {
    return Consumer<MyProvider>(
      builder: (context, provider, child) {
        return Text('${provider.counter}');
      },
    );
  }
}
```

### 3. Usar const Constructors

```dart
// ❌ Ruim
return Container(
  child: Text('Hello'),
);

// ✅ Bom
return const Text('Hello');
```

### 4. Null Safety

```dart
// ❌ Ruim
String? name;
print(name.length); // Pode dar erro!

// ✅ Bom
String? name;
print(name?.length ?? 0);
```

### 5. Async/Await

```dart
// ❌ Ruim
Future<void> loadData() {
  database.query().then((data) {
    return processData(data);
  }).then((processed) {
    updateUI(processed);
  });
}

// ✅ Bom
Future<void> loadData() async {
  final data = await database.query();
  final processed = await processData(data);
  updateUI(processed);
}
```

---

## 🔒 Segurança

### Checklist

- [ ] Nunca commite senhas/chaves
- [ ] Use .gitignore para key.properties
- [ ] Valide todos os inputs do usuário
- [ ] Sanitize dados antes de salvar
- [ ] Use HTTPS para comunicação externa
- [ ] Mantenha dependências atualizadas

### Exemplo: Validação de Input

```dart
String? validateMessage(String? value) {
  if (value == null || value.isEmpty) {
    return 'Mensagem vazia';
  }
  
  if (value.length > AppConfig.maxMessageLength) {
    return 'Mensagem muito longa';
  }
  
  // Remover caracteres perigosos
  final sanitized = value
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  
  return null;
}
```

---

## 📝 Documentação

### Docstrings

```dart
/// Envia uma mensagem para um peer específico.
///
/// Retorna `true` se a mensagem foi enviada com sucesso,
/// `false` caso contrário.
///
/// Throws [ConnectionException] se não houver conexão.
///
/// Exemplo:
/// ```dart
/// final sent = await sendMessage('peer-123', 'Olá!');
/// if (sent) print('Enviado!');
/// ```
Future<bool> sendMessage(String peerId, String content) async {
  // implementação
}
```

### README Updates

Ao adicionar feature:
1. Atualizar lista de features
2. Adicionar screenshots se necessário
3. Atualizar instruções de uso

---

## 🚀 Release Process

### 1. Preparação

```bash
# 1. Atualizar versão
# pubspec.yaml: version: 1.1.0+2

# 2. Atualizar CHANGELOG.md
## [1.1.0] - 2026-02-01
### Added
- Indicador de digitação
### Fixed
- Bug na conexão

# 3. Testes finais
flutter test
flutter analyze
```

### 2. Build

```bash
# Build APK
flutter build apk --release --split-per-abi

# Testar APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### 3. Tag & Release

```bash
# Commit
git add .
git commit -m "chore: bump version to 1.1.0"

# Tag
git tag v1.1.0
git push origin v1.1.0

# GitHub Release
# Anexar APKs
# Escrever changelog
```

---

## 💡 Dicas Úteis

### Hot Reload vs Hot Restart

```
Hot Reload (r):
- Preserva estado
- Rápido (~1s)
- Use para mudanças de UI

Hot Restart (R):
- Reseta estado
- Mais lento (~5s)
- Use para mudanças de lógica
```

### Debug no VS Code

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter",
      "request": "launch",
      "type": "dart",
      "flutterMode": "debug"
    },
    {
      "name": "Flutter (Profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile"
    }
  ]
}
```

### Atalhos Úteis

| Atalho | Ação |
|--------|------|
| `r` | Hot reload |
| `R` | Hot restart |
| `p` | Toggle grid overlay |
| `o` | Toggle platform (iOS/Android) |
| `q` | Quit |

---

## 📚 Recursos

### Aprender

- [Flutter Docs](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Provider Package](https://pub.dev/packages/provider)

### Comunidade

- [Flutter Discord](https://discord.gg/flutter)
- [r/FlutterDev](https://reddit.com/r/FlutterDev)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

---

## ❓ FAQ

**Q: Como resolver "Gradle build failed"?**

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

**Q: Como resolver conflitos de merge?**

```bash
# Ver arquivos com conflito
git status

# Resolver manualmente
# Depois:
git add .
git commit -m "resolve: merge conflict"
```

**Q: App muito lento?**

1. Rode em modo release: `flutter run --release`
2. Use DevTools para profile
3. Verifique widgets desnecessários rebuilding

---

## 🎉 Contribuindo

1. Fork o projeto
2. Crie sua branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'feat: Add AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

**Obrigado por contribuir! 🙏**

---

**Guia de Desenvolvimento v1.0**  
*Happy coding! 🚀*
