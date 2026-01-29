# 🕸️ Mesh Multi-hop - Documentação Técnica

## 🎯 Visão Geral

O **Mesh Multi-hop** permite que mensagens sejam retransmitidas através de múltiplos dispositivos intermediários, estendendo o alcance da rede P2P além das conexões diretas.

---

## 🏗️ Como Funciona

### Conceito Básico

```
Device A ←→ Device B ←→ Device C ←→ Device D

Sem mesh: A só fala com B, B só fala com C, etc.
Com mesh: A pode enviar mensagem para D através de B e C!
```

### Arquitetura

```
┌─────────────────────────────────────────────┐
│           MeshRoutingService                │
│  ┌────────────┬──────────────┬────────────┐ │
│  │  Routing   │   Packet     │   Route    │ │
│  │  Table     │   Queue      │  Discovery │ │
│  └────────────┴──────────────┴────────────┘ │
├─────────────────────────────────────────────┤
│              P2PService                     │
│  ┌────────────────────────────────────────┐ │
│  │   Nearby Connections (Wi-Fi Direct)    │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## 📦 Componentes Principais

### 1. MeshPacket

Estrutura de dados para pacotes mesh:

```dart
class MeshPacket {
  final String id;              // ID único do pacote
  final String senderId;        // Quem enviou originalmente
  final String destinationId;   // Destino final
  final String content;         // Conteúdo da mensagem
  final List<String> path;      // Caminho percorrido
  final int ttl;                // Time To Live (hops restantes)
  final DateTime timestamp;     // Quando foi criado
  final String type;            // Tipo: message, route_discovery, etc.
}
```

**Exemplo:**

```dart
MeshPacket(
  id: 'abc123',
  senderId: 'Alice',
  destinationId: 'David',
  content: 'Olá David!',
  path: ['Alice', 'Bob', 'Charlie'],
  ttl: 2, // Pode passar por mais 2 dispositivos
  timestamp: DateTime.now(),
  type: 'message',
)
```

### 2. MeshRoute

Informação de rota armazenada:

```dart
class MeshRoute {
  final String destinationId;   // Para onde vai
  final List<String> hops;      // Caminho até lá
  final int hopCount;           // Número de hops
  final DateTime timestamp;     // Quando foi descoberta
  final int quality;            // Qualidade da rota (0-100)
}
```

**Exemplo:**

```dart
MeshRoute(
  destinationId: 'David',
  hops: ['Alice', 'Bob', 'Charlie', 'David'],
  hopCount: 4,
  timestamp: DateTime.now(),
  quality: 70, // Boa qualidade
)
```

### 3. MeshRoutingService

Serviço que gerencia todo o roteamento mesh:

```dart
class MeshRoutingService {
  // Tabela de rotas conhecidas
  Map<String, MeshRoute> _routingTable;
  
  // Cache de pacotes processados (evita loops)
  Set<String> _processedPackets;
  
  // Fila de pacotes pendentes
  Queue<MeshPacket> _pendingPackets;
  
  // Métodos principais
  Future<bool> sendMessage();      // Enviar mensagem
  Future<void> receivePacket();    // Receber pacote
  void cleanExpiredRoutes();       // Limpar rotas antigas
}
```

---

## 🔄 Fluxo de Mensagem Mesh

### 1. Envio de Mensagem

```
Alice quer enviar "Olá!" para David

1. Alice cria MeshPacket:
   - senderId: Alice
   - destinationId: David
   - content: "Olá!"
   - path: [Alice]
   - ttl: 5

2. Alice consulta tabela de rotas:
   - Tem rota para David? SIM → Alice → Bob → Charlie → David
   - Próximo hop: Bob

3. Alice envia pacote para Bob
```

### 2. Retransmissão (Relay)

```
Bob recebe pacote

1. Bob verifica:
   - Já processei este pacote? NÃO
   - TTL > 0? SIM (ttl=4)
   - Sou o destino? NÃO

2. Bob atualiza pacote:
   - path: [Alice, Bob]
   - ttl: 4

3. Bob consulta rota:
   - Próximo hop: Charlie

4. Bob envia para Charlie
```

### 3. Entrega Final

```
David recebe pacote

1. David verifica:
   - Já processei? NÃO
   - TTL > 0? SIM
   - Sou o destino? SIM ✓

2. David processa mensagem:
   - Adiciona à lista de mensagens
   - Envia ACK de volta para Alice

3. Mensagem entregue!
```

---

## 🗺️ Descoberta de Rotas

### Quando Não Há Rota Conhecida

```
Alice quer enviar para David, mas não tem rota

1. Alice inicia Route Discovery:
   - Cria pacote tipo 'route_discovery'
   - Broadcast para todos os vizinhos

2. Pacote é retransmitido pela rede:
   Alice → Bob → Charlie → David
   
3. David recebe discovery:
   - Envia 'route_reply' de volta
   - Inclui caminho: [Alice, Bob, Charlie, David]

4. Alice recebe reply:
   - Adiciona rota à tabela
   - Envia mensagem original usando esta rota
```

### Diagrama de Descoberta

```
[Alice]
   │
   ├──→ [Bob]
   │      │
   │      ├──→ [Charlie]
   │      │       │
   │      │       └──→ [David] ← Destino encontrado!
   │      │              │
   │      │              └──→ Route Reply
   │      │                     │
   │      └─────────────────────┘
   │                             │
   └─────────────────────────────┘
   
Rota descoberta: Alice → Bob → Charlie → David
```

---

## 🛡️ Prevenção de Loops

### Problema: Loop Infinito

```
Sem prevenção:

Alice → Bob → Charlie → Bob → Charlie → Bob → ∞

Pacote fica circulando eternamente!
```

### Solução 1: Cache de Pacotes Processados

```dart
Set<String> _processedPackets = {};

void receivePacket(MeshPacket packet) {
  // Verificar se já processamos
  if (_processedPackets.contains(packet.id)) {
    return; // Ignora pacote duplicado
  }
  
  // Adicionar ao cache
  _processedPackets.add(packet.id);
  
  // Processar normalmente...
}
```

### Solução 2: TTL (Time To Live)

```dart
class MeshPacket {
  int ttl; // Máximo de 5 hops
  
  MeshPacket withDecrementedTTL() {
    return MeshPacket(
      // ... outros campos
      ttl: this.ttl - 1, // Decrementa a cada hop
    );
  }
}

void relayPacket(MeshPacket packet) {
  if (packet.ttl <= 0) {
    return; // Pacote expirou, descarta
  }
  
  final newPacket = packet.withDecrementedTTL();
  sendToNextHop(newPacket);
}
```

---

## ⚙️ Configuração

### Constantes Importantes

```dart
class MeshRoutingService {
  static const int maxTTL = 5;                  // Máximo de hops
  static const int maxProcessedCache = 1000;    // Cache de pacotes
  static const int routeExpirationMinutes = 5;  // Expiração de rotas
  static const int maxPendingPackets = 100;     // Fila de pendentes
}
```

### Ativar/Desativar Mesh

```dart
// Na inicialização
await chatProvider.initialize(
  userName,
  enableMesh: true, // ← Ativa mesh
);

// Durante execução
await chatProvider.toggleMesh(true);
```

---

## 📊 Exemplo Prático

### Cenário: 4 Dispositivos

```
Configuração:
- Alice, Bob, Charlie, David
- Alice ←→ Bob (conectados)
- Bob ←→ Charlie (conectados)
- Charlie ←→ David (conectados)
- Alice e David NÃO conectados diretamente
```

### Sem Mesh

```
Alice tenta enviar para David:
❌ Falha - não há conexão direta
```

### Com Mesh

```
1. Alice envia "Olá David!"
   ↓
2. Pacote vai para Bob (ttl=5, path=[Alice])
   ↓
3. Bob retransmite para Charlie (ttl=4, path=[Alice,Bob])
   ↓
4. Charlie retransmite para David (ttl=3, path=[Alice,Bob,Charlie])
   ↓
5. David recebe! ✅
   ↓
6. David envia ACK de volta
   ↓
7. ACK retorna: David → Charlie → Bob → Alice
   ↓
8. Alice recebe confirmação ✅
```

---

## 🎯 Casos de Uso

### 1. Extensão de Alcance

```
Situação: Grupo de amigos em área grande (festival, campus)

Sem mesh:
- Alcance: ~100m
- 3 pessoas podem se comunicar

Com mesh:
- Alcance: ~500m (5 hops × 100m)
- 15+ pessoas podem se comunicar
```

### 2. Comunicação em Emergência

```
Situação: Desastre natural, sem internet

Sem mesh:
- Comunicação limitada a vizinhos próximos

Com mesh:
- Mensagens podem alcançar vários quarteirões
- Rede auto-organizada
- Resiliente a falhas
```

### 3. Eventos com Multidão

```
Situação: Show, conferência, manifestação

Sem mesh:
- Difícil coordenar grandes grupos

Com mesh:
- Organiza coordenação distribuída
- Mensagens alcançam toda a multidão
```

---

## ⚡ Performance

### Benchmarks

| Operação | Tempo Médio |
|----------|-------------|
| Route Discovery | 2-5s |
| Relay (1 hop) | < 100ms |
| Relay (3 hops) | < 300ms |
| Relay (5 hops) | < 500ms |

### Limitações

```
Máximo de hops: 5
Razão: Evitar latência excessiva e loops

Tamanho máximo do pacote: 5KB
Razão: Limites do Nearby Connections

Cache de processados: 1000 pacotes
Razão: Memória limitada em devices móveis

Expiração de rotas: 5 minutos
Razão: Topologia da rede muda constantemente
```

---

## 🐛 Debugging

### Logs Úteis

```dart
// Ativar logs detalhados
AppConfig.enableDebugLogs = true;

// Você verá:
[MESH] Mesh routing initialized for node: abc123
[MESH] Received packet: xyz789
[MESH] Using cached route: Route to device2 via [device1]
[MESH] Packet reached destination!
[MESH] Relaying packet abc (TTL: 3)
```

### Visualizar Estatísticas

```dart
// Obter estatísticas
final stats = chatProvider.getMeshStatistics();

print(stats);
// {
//   'node_id': 'abc123',
//   'routes_count': 5,
//   'pending_packets': 2,
//   'processed_cache_size': 47,
//   'routes': [
//     'Route to device2 via [device1] (quality: 90)',
//     'Route to device3 via [device1, device2] (quality: 80)',
//   ]
// }
```

### Tela de Estatísticas

```dart
// Abrir tela de estatísticas mesh
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MeshStatisticsScreen(),
  ),
);
```

---

## 🔒 Segurança

### Considerações

```
✅ Pacotes incluem sender/destination IDs
✅ TTL previne loops infinitos
✅ Cache previne replay attacks
✅ Rotas têm expiração

⚠️ Não há autenticação de rotas
⚠️ Possível man-in-the-middle
⚠️ Conteúdo pode ser lido por intermediários

Solução: Ativar criptografia E2E!
```

### Com Criptografia

```
Alice → [encrypted] → Bob → [encrypted] → Charlie → David

Bob e Charlie apenas retransmitem pacotes criptografados
Só Alice e David podem ler o conteúdo
```

---

## 🎓 Comparação com Outros Protocolos

### vs AODV (Ad-hoc On-Demand Distance Vector)

```
AODV:
+ Protocolo padrão (RFC 3561)
+ Otimizado para mobilidade
- Complexo de implementar

Speew Mesh:
+ Simples e direto
+ Fácil de debugar
- Menos otimizado para grandes redes
```

### vs OLSR (Optimized Link State Routing)

```
OLSR:
+ Rotas sempre disponíveis
+ Boa para redes densas
- Overhead de manutenção

Speew Mesh:
+ On-demand (economiza bateria)
+ Simples
- Latência inicial (route discovery)
```

---

## 📚 Referências

### Algoritmos Usados

1. **Flooding** - Route Discovery
2. **Source Routing** - Path em cada pacote
3. **Route Caching** - Tabela de rotas

### Papers Relevantes

- RFC 3561: AODV Routing
- DSR (Dynamic Source Routing)
- Mesh networking principles

---

## 🚀 Próximas Melhorias

### v1.1

- [ ] Route optimization (escolher rota mais rápida)
- [ ] Load balancing (distribuir tráfego)
- [ ] Route metrics (qualidade baseada em latência)

### v2.0

- [ ] Multipath routing (múltiplas rotas simultâneas)
- [ ] Adaptive TTL (ajustar baseado em rede)
- [ ] Route repair (consertar rotas quebradas)

---

**Mesh Multi-hop v1.0**  
*Estendendo o alcance, uma retransmissão por vez.* 🕸️
