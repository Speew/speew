# CHECKLIST DE CONSTRUÇÃO - SPEEW ALPHA-1 (SDA)

## 📋 Visão Geral

Este checklist segue rigorosamente as instruções do **Dossiê SPEEW ALPHA-1 - Projeto de Engenharia Integral (SDA)**. O dossiê é a **ÚNICA FONTE DE VERDADE** para o build.

---

## ✅ Checklist de Implementação

### 1. Estrutura Nativa: Android

- [x] **AndroidManifest.xml atualizado** com todas as permissões necessárias:
  - [x] `android.permission.BLUETOOTH`
  - [x] `android.permission.BLUETOOTH_ADMIN`
  - [x] `android.permission.BLUETOOTH_SCAN`
  - [x] `android.permission.BLUETOOTH_ADVERTISE`
  - [x] `android.permission.BLUETOOTH_CONNECT`
  - [x] `android.permission.ACCESS_FINE_LOCATION`
  - [x] `android.permission.NEARBY_WIFI_DEVICES`
  - [x] `android.permission.FOREGROUND_SERVICE`
  - [x] `android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE`

- [x] **Serviço Nearby Connections declarado:**
  ```xml
  <service 
      android:name="com.google.android.gms.nearby.connection.service.NearbyConnectionsService"
      android:foregroundServiceType="connectedDevice"
      android:exported="false" />
  ```

### 2. Estrutura Nativa: iOS

- [x] **Info.plist atualizado** com chaves necessárias:
  - [x] `NSBluetoothAlwaysUsageDescription`
  - [x] `NSLocalNetworkUsageDescription`
  - [x] `UIBackgroundModes` com:
    - [x] `bluetooth-central`
    - [x] `bluetooth-peripheral`
    - [x] `fetch`

### 3. Código Fonte Consolidado

- [x] **lib/main.dart substituído** pelo código monolito do dossiê SDA:
  - [x] Classe `SpeewSecurity` implementada
  - [x] Classe `MeshEngine` implementada
  - [x] Classe `RadarApp` implementada
  - [x] Método `getDeviceId()` implementado
  - [x] Roteamento multi-hop com TTL implementado
  - [x] ServiceId definido como `"com.speew.alpha1.mesh"`

### 4. Dependências

- [x] **pubspec.yaml simplificado** com apenas as dependências necessárias:
  - [x] `provider: ^6.1.1`
  - [x] `nearby_connections: ^3.1.0`
  - [x] `cryptography: ^2.5.0`
  - [x] `flutter_secure_storage: ^9.0.0`

---

## 🔧 Tarefas Pendentes (Para o Desenvolvedor)

### 1. ⬜ Garantir ServiceId Idêntico

**Ação:** Verificar que o `serviceId` é rigorosamente igual no Android e iOS.

**Código atual:**
```dart
const String serviceId = "com.speew.alpha1.mesh";
```

**Status:** ✅ Implementado no código

**Verificação necessária:** Testar em dispositivos Android e iOS para confirmar interoperabilidade.

---

### 2. ✅ Substituir "MEU_ID_LOCAL" pelo ID do Dispositivo

**Ação:** O código já foi atualizado para usar `_myDeviceId` obtido via `SpeewSecurity.getDeviceId()`.

**Código implementado:**
```dart
if (data['targetId'] != _myDeviceId) {
  data['ttl'] = ttl - 1;
  _relay(data, senderId);
} else {
  print("Mensagem destinada a este dispositivo: ${data['content']}");
}
```

**Status:** ✅ Concluído

---

### 3. ⬜ Implementar Fragmentação de Arquivos de Áudio

**Ação:** Implementar fragmentação de arquivos no envio de áudio (Chunks de 32KB).

**Código sugerido:**
```dart
class AudioFragmenter {
  static const int CHUNK_SIZE = 32 * 1024; // 32KB
  
  static List<Uint8List> fragmentAudio(Uint8List audioData) {
    final chunks = <Uint8List>[];
    for (int i = 0; i < audioData.length; i += CHUNK_SIZE) {
      final end = (i + CHUNK_SIZE < audioData.length) 
          ? i + CHUNK_SIZE 
          : audioData.length;
      chunks.add(audioData.sublist(i, end));
    }
    return chunks;
  }
  
  static Future<void> sendAudioFragmented(
    String peerId, 
    Uint8List audioData,
  ) async {
    final chunks = fragmentAudio(audioData);
    
    for (int i = 0; i < chunks.length; i++) {
      final metadata = {
        'type': 'AUDIO_CHUNK',
        'index': i,
        'total': chunks.length,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Enviar chunk com metadata
      await Nearby().sendBytesPayload(peerId, chunks[i]);
      
      // Pequeno delay para evitar congestionamento
      await Future.delayed(Duration(milliseconds: 50));
    }
  }
}
```

**Status:** ⬜ Pendente

**Prioridade:** Média (necessário para transferência de áudio)

---

### 4. ⬜ Configurar Proguard para Android

**Ação:** No Android, configurar o Proguard para não ofuscar as classes do GMS Nearby.

**Arquivo:** `android/app/proguard-rules.pro`

**Conteúdo necessário:**
```proguard
# Manter classes do Google Play Services Nearby Connections
-keep class com.google.android.gms.nearby.** { *; }
-dontwarn com.google.android.gms.nearby.**

# Manter classes do Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Manter classes de reflexão
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
```

**Arquivo:** `android/app/build.gradle`

**Adicionar:**
```gradle
buildTypes {
    release {
        signingConfig signingConfigs.debug
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

**Status:** ⬜ Pendente

**Prioridade:** Alta (necessário para build de release)

---

## 🧪 Testes Necessários

### Teste 1: Conexão P2P Básica
- [ ] Ativar radar em dois dispositivos
- [ ] Verificar se os dispositivos se descobrem mutuamente
- [ ] Confirmar que a conexão é estabelecida
- [ ] Verificar que os peers aparecem na lista

### Teste 2: Persistência de ID
- [ ] Ativar radar e anotar o Device ID
- [ ] Fechar e reabrir o app
- [ ] Verificar que o Device ID permanece o mesmo

### Teste 3: Roteamento Multi-hop
- [ ] Conectar 3 dispositivos (A -> B -> C)
- [ ] Enviar mensagem de A para C
- [ ] Verificar que B faz relay da mensagem
- [ ] Confirmar que TTL é decrementado corretamente

### Teste 4: TTL Expirado
- [ ] Enviar mensagem com TTL = 1
- [ ] Verificar que a mensagem não é retransmitida após 1 hop

### Teste 5: Prevenção de Loops
- [ ] Criar topologia circular (A -> B -> C -> A)
- [ ] Enviar mensagem broadcast
- [ ] Verificar que mensagens duplicadas são descartadas

---

## 📦 Arquivos Modificados

### Arquivos Substituídos (Backups Criados)
1. `lib/main.dart` → `lib/main.dart.backup`
2. `android/app/src/main/AndroidManifest.xml` → `AndroidManifest.xml.backup`
3. `pubspec.yaml` → `pubspec.yaml.backup`

### Arquivos Mantidos
1. `ios/Runner/Info.plist` (já estava conforme especificação)

### Arquivos Novos
1. `CHECKLIST_CONSTRUCAO_SDA.md` (este arquivo)

---

## 🚀 Próximos Passos

### Passo 1: Instalar Dependências
```bash
cd /caminho/para/speew_alpha1_sda
flutter pub get
```

### Passo 2: Compilar para Android
```bash
flutter build apk --release
```

### Passo 3: Compilar para iOS
```bash
flutter build ios --release
```

### Passo 4: Testar em Dispositivos Reais
- Instalar em pelo menos 2 dispositivos
- Executar testes de conexão P2P
- Validar roteamento multi-hop

---

## 📝 Notas Importantes

### ServiceId
O `serviceId` **DEVE** ser idêntico em todos os dispositivos para que a descoberta funcione. O valor atual é:
```dart
const String serviceId = "com.speew.alpha1.mesh";
```

### Device ID
O Device ID é gerado automaticamente na primeira execução e armazenado de forma persistente usando `FlutterSecureStorage`. Ele não muda entre execuções do app.

### TTL (Time To Live)
O TTL padrão é 3, conforme especificação. Cada hop decrementa o TTL em 1. Mensagens com TTL <= 0 são descartadas.

### Prevenção de Loops
O `processedMsgIds` mantém um Set de IDs de mensagens já processadas para evitar loops infinitos na malha mesh.

---

## 🔐 Segurança

### Criptografia
A classe `SpeewSecurity` implementa AES-256-GCM para criptografia de mensagens. Atualmente, os métodos `encrypt()` e `decrypt()` estão implementados mas não são usados automaticamente no envio de mensagens.

**TODO:** Integrar criptografia automática no envio/recebimento de mensagens.

### Armazenamento Seguro
O Device ID é armazenado usando `FlutterSecureStorage`, que usa:
- **Android:** Keystore do Android
- **iOS:** Keychain do iOS

---

## 📊 Status Final

| Componente | Status | Observações |
|-----------|--------|-------------|
| AndroidManifest.xml | ✅ Completo | Todas as permissões adicionadas |
| Info.plist | ✅ Completo | Já estava conforme especificação |
| main.dart | ✅ Completo | Código monolito implementado |
| pubspec.yaml | ✅ Completo | Dependências simplificadas |
| ServiceId | ✅ Completo | Definido como constante |
| Device ID | ✅ Completo | Usando getDeviceId() |
| Fragmentação de Áudio | ⬜ Pendente | Código sugerido fornecido |
| Proguard | ⬜ Pendente | Regras fornecidas |

---

**Data:** 21 de dezembro de 2025  
**Versão:** 1.0.0+1  
**Arquitetura:** SDA (Single Document Architecture)  
**Status:** ✅ Build base concluído - Pronto para testes
