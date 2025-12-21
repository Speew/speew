# 🏅 **Certificação V2.0 - Código Auditado (Auto-Revisão)**

# 👻 Speew V2.0: A Evolução da Comunicação Descentralizada

**Speew** é um aplicativo mobile (Android/iOS) desenvolvido em Flutter que implementa uma rede P2P descentralizada e 100% offline, projetada para **comunicação anônima, efêmera e resistente à censura**. A versão 2.0 solidifica a fundação do projeto, introduzindo mecanismos avançados de QoS, um sistema de reputação aprimorado e preparando o terreno para a computação pós-quântica.

## ✨ Missão Principal

Ser a principal ferramenta de comunicação na era da vigilância, garantindo que o usuário mantenha sua privacidade e liberdade de comunicação, operando mesmo sem infraestrutura de internet.

| Característica V2.0 | Tecnologia Habilitadora |
| :--- | :--- |
| **Qualidade de Serviço (QoS)** | **PriorityQueueMeshDispatcher** (Fila de Prioridade) |
| **Reputação Dinâmica** | **Recompensas e Penalidades por QoS** no STT Score |
| **Sincronização Multi-Dispositivo** | **Serviço de Sincronização de Estado (Beta)** |
| **Segurança Pós-Quântica** | **Simulação de Handshake Híbrido (PQC)** |

---

## 🛠️ Pilares da Versão 2.0

A V2.0 foi desenhada para ser mais inteligente, robusta e segura, com foco na otimização da experiência do usuário em redes congestionadas e na preparação para o futuro da criptografia.

### 1. 🚦 **QoS com Fila de Prioridade (`PriorityQueueMeshDispatcher`)**

O tráfego na rede Speew agora é classificado e priorizado. O `PriorityQueueMeshDispatcher` diferencia entre pacotes de **`REAL_TIME`** (mensagens de chat, voz) e **`BULK`** (arquivos), garantindo que comunicações urgentes não sejam atrasadas por transferências de dados pesados. Esta arquitetura de QoS é fundamental para uma experiência de comunicação fluida e responsiva.

### 2. ⭐ **Sistema de Reputação (STT Score) com Incentivo à QoS**

O sistema de **Speew Trust Tokens (STT)** foi aprimorado para recompensar o bom comportamento na rede. Nós que processam tráfego `REAL_TIME` de forma prioritária são recompensados com um aumento no seu STT Score, enquanto falhas em cumprir as regras de QoS resultam em penalidades. Isso cria um ecossistema onde a colaboração e a qualidade do serviço são diretamente incentivadas.

### 3. 🔄 **Sincronização Multi-Dispositivo (Beta)**

Para usuários com múltiplos aparelhos, a V2.0 introduz um serviço de sincronização de estado. Eventos e mensagens recebidos em um dispositivo são replicados nos demais, garantindo uma experiência de usuário consistente e contínua, independentemente do ponto de acesso à rede Speew.

### 4. 🛡️ **Preparação para a Criptografia Pós-Quântica (PQC)**

Antecipando-se às ameaças futuras, o `CryptoService` agora simula um **handshake híbrido pós-quântico**. Este mecanismo combina a segurança da criptografia de curva elíptica tradicional com um esquema de encapsulamento de chave (KEM) simulado, projetado para resistir a ataques de computadores quânticos. É um passo crucial para garantir a longevidade e a segurança da rede.

---

## 🏗️ Resumo da Arquitetura

* **Rede P2P**: Wi-Fi Direct + Bluetooth Mesh (modelo Store-and-forward)
* **Criptografia**: XChaCha20-Poly1305 (mensagens), Ed25519 (assinaturas) e Simulação PQC (handshake)
* **Reputação**: STT Score dinâmico baseado em performance de QoS.
* **QoS**: Fila de prioridade para tráfego `REAL_TIME` e `BULK`.

---

## 🚀 Como Auditar e Compilar

Este é um projeto de código aberto sob licença MIT. Incentivamos a auditoria e as contribuições da comunidade.

1.  **Instalar Flutter:** `flutter doctor`
2.  **Instalar dependências:** `flutter pub get`
3.  **Compilar (Android):** `flutter build apk --release`
4.  **Compilar (iOS):** `flutter build ios --release`
5.  **Executar em modo debug:** `flutter run`

Consulte o guia completo de compilação em: [docs/COMO_COMPILAR.md](docs/COMO_COMPILAR.md)

---

## 👥 Autores e Licença

Desenvolvido pelo **Manus Ai** como parte do projeto **Speew**.

Este projeto está sob a [Licença MIT](LICENSE).

Para dúvidas ou sugestões, abra uma **Issue** no repositório.
