# Dépannage Développeur

[← Documentation développeur](../README.md)

## `flutter analyze` échoue

1. Lire la première erreur.
2. Corriger le fichier indiqué.
3. Relancer:

```bash
flutter analyze
```

## Problème de dépendances

À la racine:

```bash
flutter clean
flutter pub get
```

## Build Windows échoue

Vérifier:

- Visual Studio avec workload Desktop C++;
- Windows SDK;
- dépendances Flutter installées.

Puis relancer:

```bash
flutter build windows --release
```

## Build Android échoue

Vérifier:

- Android SDK;
- Java 17 compatible;
- configuration Gradle;
- fichier `android/key.properties` si signature release souhaitée.

## Warning Java `restricted method`

Si Gradle affiche un warning sur `java.lang.System::load`, le launcher Gradle
utilise probablement Java 25 depuis le `PATH`.

Utiliser les scripts Android du dossier [tools](../../../tools/), qui placent
`JAVA_HOME` sur JBR 21 si ce JBR est disponible localement:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_android_release.ps1
```

ou:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_android_split_release.ps1
```

Ne pas committer de chemin Java propre à une autre machine.

## Message Web sur Wasm dry run

Flutter peut afficher une suggestion `--wasm` pendant `flutter build web`.
Ce n'est pas une erreur. Pour un log plus propre, utiliser:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_web_release.ps1
```

## Erreurs stockage Android

Le projet utilise un MethodChannel:

```text
com.influencor.app/storage_permissions
```

Fichiers:

- [storage_permission_service.dart](../../../lib/core/services/storage_permission_service.dart)
- [MainActivity.kt](../../../android/app/src/main/kotlin/com/influencor/app/MainActivity.kt)

## AAB échoue sur symboles natifs

Le fichier [android/app/build.gradle.kts](../../../android/app/build.gradle.kts)
contient déjà `keepDebugSymbols += listOf("**/*.so")`, mais l'environnement
Windows peut encore échouer. Tester sur un environnement Android/Flutter propre
avant publication Play Store.
