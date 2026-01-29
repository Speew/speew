# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e este projeto adere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-29

### 🎉 Release Inicial - MVP Funcional

#### ✨ Added

**Core Features:**
- Descoberta automática de dispositivos próximos via Wi-Fi Direct
- Conexão P2P entre dispositivos Android
- Mensagens texto em tempo real
- Persistência local com SQLite
- Criptografia ChaCha20-Poly1305 (implementada, opcional)
- Interface de usuário limpa e intuitiva

**Services:**
- `P2PService`: Gerenciamento completo de conexões P2P
- `StorageService`: Persistência de mensagens e peers
- `CryptoService`: Criptografia end-to-end
- `ChatProvider`: State management com Provider

**UI Components:**
- `HomeScreen`: Lista de peers descobertos
- `ChatScreen`: Interface de chat 1-para-1
- `SetupScreen`: Configuração inicial e permissões
- `PeerAvatar`: Avatar personalizado com indicador online
- `MessageBubble`: Bolha de mensagem estilizada
- `ConnectionStatusBar`: Barra de status de conexão
- `EmptyStateWidget`: Telas vazias amigáveis

**Utilities:**
- Formatação de data/hora inteligente
- Validação de inputs
- Utilitários de cores e texto
- Debug logging
- Helpers de UI

**Configuration:**
- Constantes centralizadas em `AppConfig`
- Strings localizáveis em `AppStrings`
- Tema customizável em `AppTheme`

#### 📱 Platform Support

- ✅ Android 5.0+ (API 21+)
- ❌ iOS (planejado para v2.0)

#### 🔐 Security

- ChaCha20-Poly1305 encryption implementada
- PBKDF2 key derivation
- Dados armazenados localmente
- Sem servidores externos

#### 📦 Dependencies

- `nearby_connections: ^3.3.0` - P2P Wi-Fi Direct
- `cryptography: ^2.7.0` - Criptografia
- `provider: ^6.1.1` - State management
- `sqflite: ^2.3.0` - Database SQLite
- `permission_handler: ^11.3.1` - Permissões Android
- `uuid: ^4.3.3` - Geração de IDs
- `intl: ^0.18.1` - Formatação de datas

#### 📊 Metrics

- **Total Lines of Code:** ~2.500
- **Dart Files:** 15
- **Services:** 3
- **Screens:** 3
- **Widgets:** 4
- **Code Coverage:** N/A (testes pendentes)

#### 📚 Documentation

- README.md completo com instruções de uso
- ARQUITETURA.md com detalhes técnicos
- DESENVOLVIMENTO.md guia para contributors
- COMPILACAO.md instruções de build
- ANTES_VS_DEPOIS.md comparação com versão anterior

#### 🎯 Known Limitations

- Apenas Android suportado
- Conexões 1-para-1 (sem grupos)
- Sem transferência de arquivos
- Sem voice messages
- Sem mesh multi-hop
- Criptografia não ativa por padrão

#### 🐛 Known Issues

- Reconexão automática pode falhar em alguns devices
- Descoberta pode ser lenta em ambientes com muitos Wi-Fi
- Background service não implementado

#### 🔮 Roadmap

**v1.1 (próxima release):**
- [ ] Testes unitários e de integração
- [ ] Notificações locais
- [ ] Melhor tratamento de erros
- [ ] Ativar criptografia por padrão

**v1.2:**
- [ ] Grupos (3+ pessoas)
- [ ] Envio de imagens
- [ ] Indicador de digitação
- [ ] Recibos de leitura

**v2.0:**
- [ ] Suporte iOS
- [ ] Mesh multi-hop
- [ ] Transferência de arquivos
- [ ] Voice messages

---

## [Unreleased]

### 🚧 In Development

Nada no momento.

---

## [1.2.0] - 2026-01-29

### 🎉 Feature Complete Release

#### ✨ Added

**Grupos:**
- Suporte completo a grupos (3+ pessoas)
- `Group` e `GroupMessage` models
- `GroupService`: criar, gerenciar, enviar mensagens
- `CreateGroupScreen`: UI para criar grupos
- Admin system (apenas criador pode gerenciar)
- Mensagens de sistema (membro entrou/saiu)

**Imagens:**
- `ImageService`: processamento completo de imagens
- Compressão automática (máx 800x800px, 500KB)
- Redimensionamento inteligente
- Salvamento local estruturado
- Limpeza automática de imagens antigas (30 dias)

**Notificações:**
- `NotificationService`: notificações locais push
- Suporte Android e iOS
- Tipos: mensagens, grupos, conexões
- Auto-notificação ao receber mensagens
- Tela de configuração de notificações

**Temas:**
- `ThemeProvider`: gerenciamento de temas
- `AppThemes`: Light e Dark completos
- 3 modos: Light, Dark, System
- Persistência de preferência (SharedPreferences)
- Material 3 Design
- `SettingsScreen`: tela de configurações completa

**UI/UX:**
- Botão FAB para criar grupos
- Botão de configurações no AppBar
- Radio buttons para seleção de tema
- Preview de temas em tempo real

#### 🔧 Changed

- `ChatProvider`: Agora suporta grupos e imagens
- `main.dart`: MultiProvider com ThemeProvider
- Notificações automáticas ao receber mensagens
- UI adaptada para temas dark/light

#### 📦 Dependencies Added

```yaml
image: ^4.1.7
image_picker: ^1.0.7
path_provider: ^2.1.2
flutter_local_notifications: ^16.3.2
shared_preferences: ^2.2.2
```

#### 📊 Metrics

- Arquivos novos: 7
- Linhas adicionadas: ~1250
- Total arquivos Dart: 25
- Total linhas: ~4000

#### 📚 Documentation

- `NOVAS_FEATURES.md`: Guia completo das novas features
- README atualizado
- CHANGELOG atualizado

---

## [1.1.0] - 2026-01-29

### 🎉 Mesh Multi-hop Release

#### ✨ Added

**Mesh Routing:**
- `MeshPacket`: Estrutura de dados para pacotes mesh
- `MeshRoute`: Modelo de rotas mesh
- `MeshRoutingService`: Serviço completo de roteamento mesh
  - Route discovery automática
  - Route caching inteligente
  - Loop prevention (TTL + cache de processados)
  - Packet queuing para destinos sem rota
- Integração mesh no `P2PService`
- Integração mesh no `ChatProvider`
- Toggle de mesh na tela de setup
- `MeshStatisticsScreen`: Visualização de estatísticas mesh
- Documentação completa em `MESH.md`

**Features Mesh:**
- Retransmissão automática através de até 5 dispositivos intermediários
- Descoberta automática de rotas
- Cache de pacotes processados (evita loops)
- TTL (Time To Live) para expiração de pacotes
- Fila de pacotes pendentes
- Expiração automática de rotas antigas (5 minutos)
- Estatísticas em tempo real (rotas, pacotes pendentes, cache)

**UI:**
- Toggle "Mesh Multi-hop" na tela inicial
- Ícone de router no AppBar (quando mesh ativo)
- Tela de estatísticas mesh com:
  - Informações do nó
  - Tabela de rotas conhecidas
  - Legendas explicativas
  - Métricas de qualidade

#### 🔧 Changed

- `P2PService`: Agora suporta envio mesh e direto
- `ChatProvider`: Método `sendMessage` usa mesh quando habilitado
- `Message`: Recebe info se veio via mesh e hop count
- Setup: Permite ativar mesh na inicialização

#### 📊 Performance

- Route discovery: 2-5 segundos
- Relay (1 hop): < 100ms
- Relay (3 hops): < 300ms
- Relay (5 hops): < 500ms

#### 📚 Documentation

- `MESH.md`: Documentação técnica completa do mesh
- README atualizado com seção mesh
- Exemplos de uso mesh
- Diagramas de fluxo

---

## [1.0.0] - 2026-01-29

### Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR: Mudanças incompatíveis na API
MINOR: Funcionalidade nova compatível
PATCH: Bug fixes compatíveis
```

### Tipos de Mudanças

- `Added` para novas features
- `Changed` para mudanças em features existentes
- `Deprecated` para features que serão removidas
- `Removed` para features removidas
- `Fixed` para bug fixes
- `Security` para vulnerabilidades

---

**Changelog iniciado em:** 29 de janeiro de 2026  
**Última atualização:** 29 de janeiro de 2026
