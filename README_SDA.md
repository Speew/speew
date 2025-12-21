# SPEEW ALPHA-1 - Single Document Architecture (SDA)

## 🎯 Sobre Este Build

Este é o **SPEEW ALPHA-1**, uma implementação **monolítica simplificada** baseada no **Dossiê de Engenharia Integral (SDA)**. 

### Diferenças em Relação ao Projeto Original

| Aspecto | Projeto Original | SPEEW ALPHA-1 (SDA) |
|---------|------------------|---------------------|
| **Arquitetura** | Modular com múltiplos serviços | Monolítica em um único arquivo |
| **Complexidade** | Alta (10+ serviços) | Baixa (2 classes principais) |
| **Dependências** | 15+ pacotes | 4 pacotes essenciais |
| **Funcionalidades** | Sistema de tokens, reputação, economia | Apenas mesh P2P básico |
| **Linhas de código** | ~5000+ | ~400 |
| **Objetivo** | Produção completa | Prova de conceito / Alpha |

---

## 🚀 Quick Start

### 1. Instalar Dependências

```bash
flutter pub get
```

### 2. Compilar e Executar

**Android:**
```bash
flutter run
```

**iOS:**
```bash
flutter run
```

### 3. Usar o App

1. Abra o app em dois ou mais dispositivos
2. Toque em "DISPARAR RADAR MESH"
3. Aguarde a descoberta de peers
4. Os dispositivos conectados aparecerão na lista

---

## 📱 Funcionalidades

### ✅ Implementadas

- **Descoberta P2P:** Usando Google Nearby Connections
- **Conexão Automática:** Aceita conexões automaticamente
- **Visualização de Peers:** Lista de nós conectados em tempo real
- **Roteamento Multi-hop:** TTL de 3 saltos
- **Prevenção de Loops:** Cache de mensagens processadas
- **Persistência de ID:** Device ID armazenado de forma segura
- **Interface Radar:** UI dark theme conforme especificação

### ⬜ Pendentes

- **Criptografia E2EE:** Métodos implementados, não integrados
- **Transferência de Áudio:** Fragmentação de 32KB
- **Handshake ECDH:** Troca de chaves públicas
- **Serviço em Background:** Notificação persistente

---

## 🏗️ Arquitetura

### Estrutura de Código

```
lib/
└── main.dart (ÚNICO ARQUIVO)
    ├── SpeewSecurity (Segurança e Identidade)
    ├── MeshEngine (Motor Mesh P2P)
    └── RadarApp (Interface do Usuário)
```

### Fluxo de Dados

```
[Dispositivo A] → Nearby Connections → [Dispositivo B]
       ↓                                      ↓
   MeshEngine                            MeshEngine
       ↓                                      ↓
   _routePayload                         _routePayload
       ↓                                      ↓
   TTL Check                             TTL Check
       ↓                                      ↓
   _relay (se TTL > 0)                   _relay (se TTL > 0)
       ↓                                      ↓
[Dispositivo C]                         [Dispositivo D]
```

---

## 🔧 Configuração

### ServiceId

O `serviceId` é **crítico** para a descoberta de peers. Ele deve ser idêntico em todos os dispositivos:

```dart
const String serviceId = "com.speew.alpha1.mesh";
```

**⚠️ IMPORTANTE:** Não altere este valor sem motivo. Se alterado, todos os dispositivos devem usar o mesmo valor.

### Permissões

#### Android (AndroidManifest.xml)

Todas as permissões necessárias já estão configuradas:
- Bluetooth (SCAN, ADVERTISE, CONNECT)
- Localização (ACCESS_FINE_LOCATION)
- Nearby WiFi Devices
- Foreground Service

#### iOS (Info.plist)

Todas as chaves necessárias já estão configuradas:
- NSBluetoothAlwaysUsageDescription
- NSLocalNetworkUsageDescription
- UIBackgroundModes

---

## 📊 Roteamento Multi-hop

### Como Funciona

1. **Mensagem Enviada:** TTL = 3
2. **Hop 1:** Dispositivo B recebe, TTL = 2, retransmite
3. **Hop 2:** Dispositivo C recebe, TTL = 1, retransmite
4. **Hop 3:** Dispositivo D recebe, TTL = 0, NÃO retransmite

### Prevenção de Loops

Cada mensagem tem um ID único (`msgId`). O `MeshEngine` mantém um `Set<String>` de IDs processados:

```dart
Set<String> processedMsgIds = {};
```

Se uma mensagem com o mesmo ID chegar novamente, ela é descartada.

---

## 🔐 Segurança

### Device ID

Cada dispositivo tem um ID único persistente:

```dart
String deviceId = "Node_${timestamp}";
```

Armazenado em `FlutterSecureStorage`:
- **Android:** Keystore
- **iOS:** Keychain

### Criptografia (Implementada, Não Integrada)

A classe `SpeewSecurity` possui métodos para criptografia AES-256-GCM:

```dart
// Criptografar
final encrypted = await security.encrypt(data, key);

// Descriptografar
final decrypted = await security.decrypt(encrypted, key);
```

**TODO:** Integrar automaticamente no envio/recebimento de mensagens.

---

## 🧪 Testes

### Teste Básico (2 Dispositivos)

1. Instalar o app em 2 dispositivos
2. Ativar radar em ambos
3. Verificar que se descobrem mutuamente
4. Confirmar que aparecem na lista de peers

### Teste Multi-hop (3+ Dispositivos)

1. Instalar o app em 3 dispositivos (A, B, C)
2. Posicionar de forma que:
   - A alcança apenas B
   - B alcança A e C
   - C alcança apenas B
3. Enviar mensagem de A
4. Verificar que C recebe (via relay de B)

### Teste de TTL

1. Modificar TTL para 1:
   ```dart
   'ttl': 1,
   ```
2. Conectar 3 dispositivos em cadeia
3. Enviar mensagem do primeiro
4. Verificar que o terceiro NÃO recebe

---

## 📝 Logs e Debug

### Ativar Logs Detalhados

O código já possui `print()` statements para debug:

```dart
print("Conectado ao peer: $id");
print("Mensagem recebida: $msgId (TTL: $ttl)");
print("Mensagem retransmitida para: ${peer['id']}");
```

### Ver Logs

**Android:**
```bash
flutter logs
```

**iOS:**
```bash
flutter logs
```

---

## 🐛 Troubleshooting

### Erro: "Permissão de localização negada"

**Solução:** Conceder permissão de localização manualmente nas configurações do dispositivo.

### Erro: "Nenhum peer descoberto"

**Possíveis causas:**
1. Bluetooth desativado
2. Localização desativada
3. ServiceId diferente entre dispositivos
4. Dispositivos muito distantes

**Solução:**
1. Verificar que Bluetooth e Localização estão ativos
2. Verificar que o `serviceId` é idêntico
3. Aproximar os dispositivos

### Erro: "Conexão falhou"

**Possíveis causas:**
1. Muitas conexões simultâneas (Erro 8003)
2. Interferência de outros dispositivos Bluetooth

**Solução:**
1. Reiniciar Bluetooth
2. Reduzir número de dispositivos conectados
3. Afastar de outros dispositivos Bluetooth

---

## 📦 Build de Release

### Android

```bash
flutter build apk --release
```

**⚠️ IMPORTANTE:** Configurar Proguard antes do build de release (ver `CHECKLIST_CONSTRUCAO_SDA.md`).

### iOS

```bash
flutter build ios --release
```

**⚠️ IMPORTANTE:** Configurar certificados de desenvolvedor Apple.

---

## 🔄 Migração do Projeto Original

Se você tem o projeto original e quer voltar para ele:

1. Os backups estão em:
   - `lib/main.dart.backup`
   - `android/app/src/main/AndroidManifest.xml.backup`
   - `pubspec.yaml.backup`

2. Restaurar:
   ```bash
   mv lib/main.dart.backup lib/main.dart
   mv android/app/src/main/AndroidManifest.xml.backup android/app/src/main/AndroidManifest.xml
   mv pubspec.yaml.backup pubspec.yaml
   flutter pub get
   ```

---

## 📚 Documentação Adicional

- **CHECKLIST_CONSTRUCAO_SDA.md:** Checklist completo de implementação
- **Dossiê SDA Original:** Fonte de verdade para a arquitetura

---

## 🤝 Contribuindo

Este é um projeto **alpha** focado em simplicidade. Contribuições devem manter a filosofia SDA:

- **Um único arquivo:** `lib/main.dart`
- **Dependências mínimas:** Apenas o essencial
- **Código simples:** Fácil de entender e modificar

---

## 📄 Licença

Este projeto segue a mesma licença do projeto original SPEEW.

---

## 🎓 Aprendizado

Este build SDA é ideal para:
- **Aprender** como funciona o Google Nearby Connections
- **Entender** roteamento mesh básico
- **Prototipar** rapidamente novas ideias
- **Ensinar** conceitos de redes P2P

---

## 🚧 Roadmap

### v1.1.0 (Próxima)
- [ ] Integrar criptografia E2EE automaticamente
- [ ] Implementar fragmentação de áudio
- [ ] Adicionar handshake ECDH

### v1.2.0
- [ ] Serviço em background
- [ ] Notificação persistente
- [ ] Estatísticas de rede

### v2.0.0
- [ ] Migrar para arquitetura modular
- [ ] Adicionar sistema de reputação
- [ ] Implementar economia de tokens

---

**Versão:** 1.0.0+1  
**Data:** 21 de dezembro de 2025  
**Arquitetura:** SDA (Single Document Architecture)  
**Status:** ✅ Alpha Release
