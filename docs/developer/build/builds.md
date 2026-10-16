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

Les symboles de débogage du moteur Flutter et du code de l'app sont retirés
des bibliothèques et rangés dans `BUNDLE-METADATA` de l'AAB. Seules les deux
bibliothèques compilées par cargokit (`libsuper_native_extensions.so`,
`libirondash_engine_context_native.so`) gardent leurs symboles (voir
`packaging.jniLibs.keepDebugSymbols` dans `android/app/build.gradle.kts`).

Flutter vérifie ce point avec `apkanalyzer`, fourni par le composant
**Android SDK Command-line Tools**. Sans lui, `flutter build appbundle`
affiche « failed to strip debug symbols » même quand l'AAB est correct :
installer ce composant (Android Studio → SDK Manager → SDK Tools), puis
`flutter doctor --android-licenses`.

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
build/windows/x64/runner/Release/influencor.exe
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

Commande complète recommandée (Windows, APK par ABI, APK universel, AAB, web):

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_full_release.ps1
```

Android et Windows seulement:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_full_release.ps1 -SkipWeb
```
