# 📡 Speew Alpha-1: Tactical Mesh Communications

**Speew** é um protocolo de sobrevivência digital projetado para operar em **Blackout Total**. Transforma dispositivos móveis em nós de uma malha P2P criptografada e resiliente, sem necessidade de internet ou GSM.

---

## 🛡️ Pilares de Missão Crítica (Alpha-1)

* **Criptografia**: XChaCha20-Poly1305 + Ed25519. Sigilo absoluto.
* **Rede**: Bluetooth LE + Wi-Fi Direct. Comunicação 100% offline.
* **Resiliência**: Priority Queue + Auto-Reparo de DB.
* **Segurança**: Emergency Wipe + QR Handshake.

---

## ⚡ Quick Start: Build Automático

No **GitHub Codespaces** ou Linux, execute:

```bash
chmod +x automate_all.sh
./automate_all.sh
```

🛠️ Operação do Terminal
 * Setup Wizard: Gera sua identidade criptográfica no primeiro boot.
 * QR Handshake: Troca de chaves públicas visual em Settings > Identity.
 * Mission Control: Monitoramento de rádio e fila de mensagens em tempo real.
👥 Contribuição e Licença
Projeto Open Source sob licença MIT.

---

```bash
#!/bin/bash
set -e
echo "🚀 SPEEW: INICIANDO PROVISIONAMENTO TOTAL..."

# 1. Dependências
sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk wget

# 2. Flutter
if [ ! -d "$HOME/flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
fi
export PATH="$PATH:$HOME/flutter/bin"

# 3. Android SDK (Minimal)
export ANDROID_HOME=$HOME/android-sdk
mkdir -p $ANDROID_HOME/cmdline-tools
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O cmdline.zip
    unzip -q cmdline.zip -d $ANDROID_HOME/cmdline-tools
    mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest
    rm cmdline.zip
fi
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
```

# 4. Licenças e Pub
yes | flutter doctor --android-licenses || true
flutter pub get

# 5. Build
flutter build apk --release --no-tree-shake-icons
echo "✅ APK em: build/app/outputs/flutter-apk/app-release.apk"

