# Builds

[← Documentation développeur](../README.md)

## Android APK release

À la racine:

```bash
flutter build apk --release
```

Commande Windows recommandée pour éviter le warning Java du launcher Gradle:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_android_release.ps1
```

Cette commande collecte aussi les artefacts dans `dist/`.

Sortie attendue:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android APK par ABI

À la racine:

```bash
flutter build apk --release --split-per-abi
```

Commande Windows recommandée pour éviter le warning Java du launcher Gradle:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_android_split_release.ps1
```

Cette commande collecte aussi les artefacts dans `dist/`.

Sorties attendues:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

## Android AAB

À la racine:

```bash
flutter build appbundle --release
```

Sortie attendue si le build réussit:

```text
build/app/outputs/bundle/release/app-release.aab
```

Problème connu: sur l'environnement Windows utilisé pendant le développement,
ce build a déjà échoué sur le stripping des symboles natifs. Vérifier et corriger
ce point avant publication Google Play.

## Windows release

À la racine:

```bash
flutter build windows --release
```

Sortie attendue:

```text
build/windows/x64/runner/Release/
```

Exécutable principal:

```text
build/windows/x64/runner/Release/clipboard.exe
```

## Installateur Windows

Prérequis:

- build Windows release généré;
- Inno Setup installé;
- commande `iscc` disponible.

Commande:

```bash
iscc installer/influencor.iss
```

Sortie attendue:

```text
build/installer/InfluencorSetup.exe
```

## Web

Le projet contient un dossier `web/`. Build Flutter standard:

```bash
flutter build web --release
```

Commande Windows recommandée pour éviter le message informatif du dry-run Wasm:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_web_release.ps1
```

Cette commande collecte aussi les artefacts dans `dist/`.

Sortie attendue:

```text
build/web/
```

Vérifier manuellement les limites navigateur liées à l'accès aux fichiers locaux.

## Dossier de distribution officiel

Tous les artefacts prêts à partager doivent être collectés dans:

```text
dist/latest/
dist/releases/<version-date>/
```

Commande de collecte:

```powershell
powershell -ExecutionPolicy Bypass -File tools/collect_release_artifacts.ps1
```

Commande complète recommandée:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_full_release.ps1
```
