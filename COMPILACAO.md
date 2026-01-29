# 📦 Guia de Compilação - Speew MVP

Este documento explica como compilar o Speew MVP para produção.

## 🔧 Pré-requisitos

### 1. Flutter SDK

```bash
# Verificar instalação
flutter doctor

# Deve mostrar:
# ✓ Flutter (Channel stable, 3.x.x)
# ✓ Android toolchain
# ✓ Android Studio
```

### 2. Android SDK

- Android SDK 21+ (Lollipop)
- Build Tools 33.0.0+
- Android NDK (opcional, mas recomendado)

### 3. Keystore (para release)

Se não tiver, crie um:

```bash
keytool -genkey -v -keystore ~/speew-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias speew
```

**IMPORTANTE:** Guarde a senha em local seguro!

## 🏗️ Compilação

### Debug Build (para testes)

```bash
# APK Debug
flutter build apk --debug

# Localização: build/app/outputs/flutter-apk/app-debug.apk
```

### Profile Build (para performance testing)

```bash
# APK Profile
flutter build apk --profile

# Localização: build/app/outputs/flutter-apk/app-profile.apk
```

### Release Build (para produção)

#### 1. Configurar Keystore

Crie `android/key.properties`:

```properties
storePassword=<sua-senha>
keyPassword=<sua-senha>
keyAlias=speew
storeFile=<caminho-para-seu-keystore.jks>
```

**NUNCA** commite este arquivo no Git!

Adicione ao `.gitignore`:

```bash
echo "android/key.properties" >> .gitignore
```

#### 2. Atualizar build.gradle

Edite `android/app/build.gradle`:

```gradle
// Adicione antes de 'android {'
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... configurações existentes

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

#### 3. Compilar Release APK

```bash
flutter build apk --release

# Localização: build/app/outputs/flutter-apk/app-release.apk
```

#### 4. Compilar App Bundle (para Play Store)

```bash
flutter build appbundle --release

# Localização: build/app/outputs/bundle/release/app-release.aab
```

## 📲 Instalação

### Via ADB (Debug/Profile)

```bash
# Instalar APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Desinstalar
adb uninstall com.speew.speew_mvp
```

### Via File Manager

1. Copie o APK para o celular
2. Abra o arquivo
3. Permita instalação de fontes desconhecidas
4. Instale

## ✅ Checklist Pré-Release

Antes de fazer release, verifique:

- [ ] Versão atualizada em `pubspec.yaml`
- [ ] Changelog atualizado
- [ ] Testes básicos funcionando
- [ ] Permissões corretas no AndroidManifest
- [ ] Ícone do app configurado
- [ ] Nome do app correto
- [ ] Keystore configurado
- [ ] Build release sem warnings
- [ ] APK testado em device físico

## 🐛 Troubleshooting

### Erro: "Keystore not found"

```bash
# Verificar se o arquivo existe
ls -la ~/speew-release-key.jks

# Verificar path no key.properties
cat android/key.properties
```

### Erro: "Unsupported class file version"

```bash
# Atualizar Java para versão 11+
java -version

# Se necessário, instalar JDK 11
```

### Erro: "SDK location not found"

```bash
# Criar local.properties
echo "sdk.dir=/home/seu-usuario/Android/Sdk" > android/local.properties
```

### Erro: "Flutter SDK not found"

```bash
# Verificar variável de ambiente
echo $FLUTTER_ROOT

# Se vazio, adicionar ao .bashrc ou .zshrc
export FLUTTER_ROOT=/path/to/flutter
export PATH=$PATH:$FLUTTER_ROOT/bin
```

## 📊 Otimizações

### Reduzir Tamanho do APK

#### 1. Split APKs por ABI

```bash
flutter build apk --split-per-abi

# Gera APKs separados:
# - app-armeabi-v7a-release.apk (~15MB)
# - app-arm64-v8a-release.apk (~17MB)
# - app-x86_64-release.apk (~18MB)
```

#### 2. Usar App Bundle

```bash
flutter build appbundle --release

# Play Store gera APKs otimizados automaticamente
```

#### 3. Remover recursos não usados

Edite `android/app/build.gradle`:

```gradle
android {
    buildTypes {
        release {
            shrinkResources true
            minifyEnabled true
        }
    }
}
```

### Melhorar Performance

#### 1. Usar mode release

```bash
flutter run --release
```

#### 2. Profile build para debugging de performance

```bash
flutter run --profile
flutter attach --profile
```

#### 3. Analisar tamanho do app

```bash
flutter build apk --analyze-size
```

## 🚀 CI/CD (Opcional)

### GitHub Actions

Crie `.github/workflows/build.yml`:

```yaml
name: Build APK

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - uses: actions/setup-java@v2
        with:
          distribution: 'zulu'
          java-version: '11'
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - run: flutter pub get
      - run: flutter build apk --release
      
      - uses: actions/upload-artifact@v2
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

## 📝 Versionamento

### Formato de Versão

```
MAJOR.MINOR.PATCH+BUILD

Exemplo: 1.2.3+45
```

### Atualizar Versão

Edite `pubspec.yaml`:

```yaml
version: 1.0.0+1
#        ^     ^
#        |     |
#        |     +-- Build number (inteiro, sempre crescente)
#        +-------- Version name (semver)
```

### Script de Bump

```bash
#!/bin/bash
# bump-version.sh

VERSION=$1
BUILD=$2

sed -i "s/version: .*/version: $VERSION+$BUILD/" pubspec.yaml

echo "Versão atualizada para $VERSION+$BUILD"
```

Uso:

```bash
./bump-version.sh 1.0.1 2
```

## 🏪 Publicação

### Google Play Store

1. Criar conta de desenvolvedor ($25 one-time)
2. Criar novo app
3. Upload do App Bundle
4. Preencher metadados
5. Publicar

### F-Droid (open source)

1. Fork do fdroiddata
2. Adicionar metadata
3. Pull request

### Distribuição Direta

1. Host do APK (GitHub Releases, website próprio)
2. Instruções de instalação
3. Aviso sobre fontes desconhecidas

## 📦 Empacotamento

### Criar Release ZIP

```bash
#!/bin/bash
# create-release.sh

VERSION=$(grep 'version:' pubspec.yaml | cut -d ' ' -f 2 | cut -d '+' -f 1)

zip -r speew-mvp-v$VERSION.zip \
  build/app/outputs/flutter-apk/app-release.apk \
  README.md \
  LICENSE

echo "Release criado: speew-mvp-v$VERSION.zip"
```

## 🔍 Verificação

### Verificar Assinatura

```bash
jarsigner -verify -verbose -certs app-release.apk
```

### Informações do APK

```bash
aapt dump badging app-release.apk | grep package
```

### Tamanho do APK

```bash
ls -lh build/app/outputs/flutter-apk/*.apk
```

---

**Dúvidas?** Consulte a documentação oficial do Flutter: https://flutter.dev/docs/deployment/android
