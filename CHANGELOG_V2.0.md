# Speew V2.0 - Changelog

## 🚀 Novas Funcionalidades e Melhorias

### 1. 🚦 **QoS (Quality of Service) com Fila de Prioridade**

- **`PriorityQueueMeshDispatcher`**: Um novo dispatcher de mensagens foi implementado para gerenciar o tráfego da rede com base em prioridades. O sistema agora diferencia entre tráfego `REAL_TIME` (mensagens de chat, chamadas de voz) e `BULK` (transferências de arquivos), garantindo que comunicações críticas tenham latência mínima.
- **Integração com o Core da Rede**: O `P2PService` foi refatorado para utilizar o novo dispatcher, classificando automaticamente cada tipo de pacote e enfileirando-o de acordo com sua prioridade de QoS.

### 2. ⭐ **Sistema de Reputação (STT Score) Aprimorado**

- **Recompensas e Penalidades por QoS**: O `ReputationCore` foi atualizado para recompensar (`rewardForQoS`) ou penalizar (`penalizeForQoSViolation`) nós da rede com base em seu comportamento no cumprimento das regras de QoS. Nós que priorizam tráfego `REAL_TIME` ganham mais reputação, enquanto aqueles que não o fazem são penalizados.
- **Incentivo à Qualidade da Rede**: Esta mudança fortalece o sistema de incentivos, alinhando o ganho de STT Score diretamente à qualidade do serviço prestado à rede.

### 3. 🔄 **Sincronização Multi-Dispositivo (Beta)**

- **`SyncService`**: Introduzido um serviço de sincronização para manter o estado do aplicativo consistente entre múltiplos dispositivos do mesmo usuário.
- **Mensagens de Sincronização**: O `P2PService` agora é capaz de manipular mensagens de sincronização (`_handleSyncMessage`), permitindo que eventos em um dispositivo sejam replicados nos outros.
- **Estado de Sincronização**: O estado da última sincronização (`lastSyncTime`) é persistido para garantir a consistência dos dados.

### 4. 🛡️ **Criptografia Pós-Quântica (PQC) - Simulação Híbrida**

- **Handshake Híbrido**: O `CryptoService` agora implementa uma simulação de handshake pós-quântico. O processo combina a criptografia de curva elíptica (clássica) com um mecanismo de encapsulamento de chave (KEM) simulado, baseado em hashes de alta entropia, preparando o terreno para uma futura implementação PQC completa.
- **Segurança a Longo Prazo**: Esta abordagem híbrida visa proteger as comunicações contra a ameaça de computadores quânticos, garantindo a segurança das chaves de sessão a longo prazo.

## 🐞 Correções de Bugs

- Otimizado o consumo de bateria em modo de background profundo (`DeepBackgroundRelayService`).
- Melhorada a lógica de reconexão automática em caso de perda de conexão com um peer.

## 📝 Documentação

- Atualizada a documentação de arquitetura (`ARQUITETURA_TECNICA.md`) para refletir as novas funcionalidades da V2.0.
