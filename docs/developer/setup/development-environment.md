# Environnement De Développement

[← Documentation développeur](../README.md)

## Prérequis

- Flutter `>= 3.24.0`.
- Dart `>= 3.5.0 < 4.0.0`.
- Android SDK pour les builds Android.
- Visual Studio avec outils C++ Desktop pour Windows si vous buildez Windows.
- Inno Setup si vous générez l'installateur Windows.

## Installation des dépendances

À exécuter à la racine du projet:

```bash
flutter pub get
```

Résultat attendu: les dépendances Flutter sont installées.

## Première exécution

Windows:

```bash
flutter run -d windows
```

Android:

```bash
flutter run -d android
```

Web:

```bash
flutter run -d chrome
```

## Variables d'environnement

Le projet ne définit pas de fichier `.env` applicatif.

Les secrets de signature Android ne doivent pas être committés. Ils sont lus
depuis:

```text
android/key.properties
```

Ce fichier doit rester local.

## Configuration locale

Le dossier de travail de l'utilisateur est stocké par l'application dans le
dossier support de la plateforme via `path_provider`.

## Environnements development / staging / production

Le projet ne contient pas de configuration staging séparée. Les variantes
réelles sont les modes Flutter habituels:

- debug;
- profile;
- release.
