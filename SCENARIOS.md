# Speew v2.0 - Tratamento de Cenários

## 🎯 Visão Geral

O Speew v2.0 foi preparado para lidar com **todos os cenários possíveis** de uso em condições adversas, garantindo que o app nunca trave e sempre degrade graciosamente.

## 📊 Cenários Tratados

### 1️⃣ Cenários de Rede

#### ✅ Sem Conexão (Offline)
- **Detecção**: Automática via `ConnectivityPlus`
- **Comportamento**:
  - Mensagens ficam em fila local
  - UI mostra status offline claramente
  - Auto-reconexão quando rede volta
  - Sincronização automática de mensagens pendentes
- **Limites**: 0 conexões ativas, fila de 1000 mensagens

#### 📱 Dados Móveis (Data Saving)
- **Detecção**: `ConnectivityResult.mobile`
- **Comportamento**:
  - Reduz tamanho de chunks (32KB vs 64KB)
  - Desabilita auto-download de mídia
  - Limita transferências simultâneas (5 max)
  - Compressão agressiva de imagens
- **Limites**: 5 conexões, 25MB por arquivo

#### 📶 Wi-Fi Fraco
- **Detecção**: Timeouts frequentes, packet loss
- **Comportamento**:
  - Aumenta timeout de operações
  - Retry com backoff exponencial
  - Chunks menores para maior sucesso
  - Circuit breaker para evitar floods

#### 🌐 Ethernet/Wi-Fi Forte
- **Comportamento**: Recursos completos habilitados
- **Limites**: 8 conexões, 100MB por arquivo

### 2️⃣ Cenários de Bateria

#### 🔋 Bateria Baixa (< 20%)
- **Detecção**: `Battery.batteryLevel`
- **Comportamento**:
  - Reduz conexões para 3
  - Desabilita recursos pesados (video, mesh avançado)
  - Aumenta intervalo de heartbeat
  - Limita fila de mensagens (500)
- **Limites**: 3 conexões, 50MB por arquivo

#### ⚡ Bateria Crítica (< 10%)
- **Comportamento**:
  - Apenas 1 conexão ativa
  - Desabilita descoberta de peers
  - Somente mensagens de texto
  - Fila mínima (100 mensagens)
- **Limites**: 1 conexão, 10MB por arquivo

#### 🔌 Carregando
- **Comportamento**: Habilita recursos completos progressivamente

### 3️⃣ Cenários de Hardware

#### 📱 Dispositivo Low-End
- **Detecção**: RAM < 2GB, Android SDK < 24
- **Comportamento**:
  - 4 conexões máximas
  - Fila reduzida (500)
  - Desabilita recursos pesados
  - Cache agressivo para reduzir processamento

#### 💾 Memória Baixa
- **Detecção**: Heurísticas + monitoramento contínuo
- **Comportamento**:
  - Limpa caches automaticamente
  - Reduz fila em 30%
  - Força garbage collection
  - Limita objetos em memória

#### 💿 Disco Cheio
- **Detecção**: Verificação periódica
- **Comportamento**:
  - Bloqueia novos downloads
  - Limita arquivos a 5MB
  - Auto-limpeza de arquivos antigos
  - Notifica usuário

### 4️⃣ Cenários de Falha

#### ❌ Crash de Serviço
- **Proteção**: Try-catch em todas operações críticas
- **Recovery**: Auto-restart de serviços
- **Fallback**: Modo degradado se restart falha

#### 🔄 Falha de Conexão
- **Retry**: Até 3 tentativas com backoff exponencial
- **Timeout**: 30s padrão, ajustável por cenário
- **Circuit Breaker**: Abre após 5 falhas consecutivas

#### 🗃️ Corrupção de Dados
- **Detecção**: Checksums SHA-256
- **Proteção**: Validação defensiva em todas entradas
- **Recovery**: Rejeita dados corrompidos, solicita reenvio

#### 🔐 Falha de Criptografia
- **Detecção**: MAC verification
- **Comportamento**: Bloqueia mensagem, notifica usuário
- **Fallback**: Reinicia handshake de chaves

### 5️⃣ Cenários de Segurança

#### 🚨 Tentativa de Ataque
- **Proteção**: Rate limiting, validação de inputs
- **Detecção**: Padrões suspeitos (flood, malformed data)
- **Resposta**: Bloqueia peer temporariamente

#### 🔓 Sem Chaves Criptográficas
- **Detecção**: Sessão sem chaves estabelecidas
- **Comportamento**: Força novo handshake
- **Fallback**: Bloqueia comunicação até resolver

#### 📸 Screenshot/Gravação
- **Detecção**: Platform channels (quando disponível)
- **Comportamento**: Notifica sender se mensagem auto-destrutiva

### 6️⃣ Cenários de Usuário

#### 👤 Múltiplos Peers Simultâneos
- **Suporte**: Até 8 peers (ajustável por cenário)
- **Priorização**: FIFO com priority queue
- **Throttling**: Limite de mensagens/segundo

#### 💬 Flood de Mensagens
- **Proteção**: Message queue com limite
- **Comportamento**: Descarta mensagens antigas se fila cheia
- **Rate Limit**: Máx 100 msgs/min por peer

#### 📁 Arquivo Gigante
- **Validação**: Limite de 100MB (ajustável)
- **Rejeição**: Erro claro antes de iniciar
- **Sugestão**: Compressão se possível

#### 🌐 Muitos Grupos
- **Suporte**: Sem limite hard, mas UI pagina
- **Performance**: Lazy loading de mensagens
- **Cache**: LRU para grupos recentes

### 7️⃣ Cenários de Mesh

#### 🔀 Rota Inexistente
- **Detecção**: Timeout de descoberta (60s)
- **Comportamento**: Broadcast para descobrir rota
- **Fallback**: Enfileira mensagem para retry

#### ♻️ Loop de Roteamento
- **Proteção**: TTL (max 5 hops)
- **Detecção**: Packet ID tracking
- **Prevenção**: Descarta pacotes duplicados

#### 📡 Peer Intermediário Cai
- **Detecção**: Heartbeat timeout
- **Comportamento**: Redescobre rota
- **Recovery**: Tenta rotas alternativas

### 8️⃣ Cenários de UI

#### 🖼️ Imagem Corrompida
- **Detecção**: Decode failure
- **Fallback**: Placeholder genérico
- **Erro**: Mensagem clara ao usuário

#### 🎥 Video Não Suportado
- **Detecção**: Codec check
- **Fallback**: Mostra nome do arquivo apenas
- **Ação**: Opção de download

#### ⌨️ Input Malicioso
- **Sanitização**: Remove caracteres perigosos
- **Validação**: Max length, caracteres permitidos
- **Proteção**: XSS, injection prevention

## 🛡️ Sistema de Proteção em Camadas

### Camada 1: Validação de Input
```dart
Defensive.requireNonEmpty(message);
Defensive.limitLength(message, 5000);
Defensive.requireValidPeerId(peerId);
```

### Camada 2: State Validation
```dart
Defensive.requireInitialized(isInitialized, 'P2PService');
Defensive.requireState(hasConnection, 'Must be connected');
```

### Camada 3: Error Handling
```dart
try {
  await operation();
} catch (e) {
  ErrorHandler.handleError(e, stackTrace);
  return fallbackValue;
}
```

### Camada 4: Circuit Breaker
```dart
await Defensive.withCircuitBreaker(
  'send_message',
  () => p2pService.sendMessage(...),
  failureThreshold: 5,
  resetTimeout: Duration(minutes: 1),
);
```

### Camada 5: Retry Logic
```dart
await Defensive.retry(
  () => connectToPeer(peerId),
  maxAttempts: 3,
  delay: Duration(seconds: 2),
);
```

## 🎨 Degradação Graciosa

O app **nunca trava**. Em vez disso:

1. **Detecta** o problema
2. **Ajusta** comportamento automaticamente
3. **Notifica** usuário se necessário
4. **Continua funcionando** com recursos reduzidos

### Exemplo: Sem Bateria
```
Normal → Low Power → Critical Power → Offline Mode
(100%) → (20%)      → (10%)          → (0%)

8 peers  3 peers     1 peer           0 peers
100MB    50MB        10MB             Queue only
Video    No video    Text only        Queue only
```

## 📱 Compatibilidade

### Android
- ✅ SDK 21+ (Android 5.0+)
- ✅ Otimizado para SDK 24+ (Android 7.0+)
- ✅ Suporte a dispositivos com 1GB+ RAM
- ✅ Funciona em 512MB RAM (modo ultra-conservativo)

### iOS
- ✅ iOS 12+
- ✅ Otimizado para iOS 14+
- ✅ Suporta iPhone 6 e superiores

## 🔧 Configuração Adaptativa

O app se auto-configura baseado em:

```dart
final scenario = ScenarioHandler();

if (scenario.isLowPowerMode) {
  // Reduz recursos
}

if (scenario.isNetworkConstrained) {
  // Economia de dados
}

if (!scenario.canUseHeavyFeatures) {
  // Desabilita video, mesh avançado, etc
}
```

## 📊 Monitoramento

### Diagnósticos em Tempo Real
```dart
final diagnostics = ScenarioHandler().getDiagnostics();
// {
//   'scenario': 'DeviceScenario.lowPower',
//   'battery_level': 15,
//   'network': 'NetworkState.mobile',
//   'max_connections': 3,
//   ...
// }
```

### Logs Estruturados
```dart
DebugUtils.log('Message sent', tag: 'P2P');
DebugUtils.logError('Connection failed', error: e);
```

## 🚀 Performance

### Otimizações
- **Batch Processing**: Agrupa operações
- **Lazy Loading**: Carrega sob demanda
- **Connection Pooling**: Reutiliza conexões
- **Message Queuing**: Prioriza mensagens
- **LRU Caching**: Mantém dados frequentes

### Limites Auto-Ajustáveis
- Max connections: 1-8 (baseado em cenário)
- Message queue: 100-1000 (baseado em memória)
- File size: 5MB-100MB (baseado em disco/rede)
- Chunk size: 16KB-64KB (baseado em rede)

## 🎯 Testes de Cenários

Para testar cada cenário:

```dart
// Simula low battery
ScenarioHandler()._batteryLevel = 15;

// Simula sem rede
ScenarioHandler()._networkState = NetworkState.none;

// Simula memória baixa
ScenarioHandler()._isLowMemory = true;
```

## 📖 Documentação Adicional

- `ARCHITECTURE.md` - Arquitetura completa
- `API.md` - Referência de APIs
- `SECURITY.md` - Detalhes de segurança
- `TROUBLESHOOTING.md` - Resolução de problemas

---

**Resultado**: Um app que **sempre funciona**, mesmo nas piores condições! 🎉
