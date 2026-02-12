# Notas de Upgrade - Speew v2.0

## 🚨 Importante - Leia Antes de Usar

Este é um **UPDATE MASSIVO** que muda completamente a arquitetura do app.

## ⚡ O Que Mudou

### Estrutura de Pastas
A estrutura foi completamente reorganizada:

**Antes:**
```
lib/
├── core/
├── models/
├── providers/
├── services/
└── ui/
```

**Agora:**
```
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── di/
│   ├── error/
│   ├── router/
│   └── theme/
├── models/
├── providers/
├── services/
└── ui/
    ├── screens/
    └── widgets/
```

### Dependency Injection
Agora usamos GetIt para DI. Inicialize no início:

```dart
await InjectionContainer.init();
```

### Providers
Todos os providers foram refatorados:

```dart
// ChatProvider agora recebe dependências
ChatProvider(
  p2pService: getIt(),
  cryptoService: getIt(),
  storageService: getIt(),
  notificationService: getIt(),
  fileTransferService: getIt(),
)
```

### Routing
Sistema de rotas centralizado:

```dart
// Antes
Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen()))

// Agora
Navigator.pushNamed(context, AppRouter.chat, arguments: {'peer': peer})
```

### Configurações
Configurações centralizadas em AppConfig:

```dart
// Acesse configurações
AppConfig.maxImageSize
AppConfig.appVersion
AppConfig.darkMode
```

## 📦 Como Migrar

### 1. Limpe o Projeto
```bash
flutter clean
flutter pub get
```

### 2. Atualize Imports
Todos os imports mudaram. Use o find/replace do seu IDE.

### 3. Configure DI
No main.dart, adicione:
```dart
await InjectionContainer.init();
```

### 4. Atualize Providers
Use os novos providers com DI:
```dart
ChangeNotifierProvider(
  create: (_) => getIt<ChatProvider>(),
)
```

### 5. Use Novo Router
Substitua navegação manual pelo sistema de rotas.

## 🎯 Benefícios

- ✅ Código mais limpo e organizado
- ✅ Melhor testabilidade
- ✅ Performance otimizada
- ✅ Manutenção mais fácil
- ✅ Escalabilidade melhorada

## ❓ Problemas Comuns

### Build Errors
Se tiver erros de build:
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Import Errors
Atualize todos os imports para a nova estrutura.

### DI Errors
Certifique-se que InjectionContainer.init() foi chamado.

## 📞 Suporte

Se tiver problemas, abra uma issue no GitHub com:
- Versão do Flutter
- Versão do Dart
- Mensagem de erro completa
- Steps para reproduzir

---

**Boa sorte com o upgrade! 🚀**
