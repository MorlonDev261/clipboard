# Documentation Développeur

[← Retour à la documentation](../README.md)

Cette documentation explique le fonctionnement réel du projet Influencor pour
les développeurs qui doivent le maintenir, le modifier, le tester, le builder et
préparer des releases.

## Sections

- [Architecture](./architecture/overview.md)
- [Données et état](./architecture/data-and-state.md)
- [Navigation et routing](./architecture/routing.md)
- [Environnement de développement](./setup/development-environment.md)
- [Commandes du projet](./commands/project-commands.md)
- [Fonctionnalités](./features/README.md)
- [Tests](./tests.md)
- [Builds](./build/builds.md)
- [Signature et versioning](./release/signing-and-versioning.md)
- [Publication](./deployment/publishing.md)
- [Dépannage développeur](./troubleshooting/README.md)
- [Checklist de maintenance](./maintenance-checklist.md)

## Technologies réellement utilisées

- Flutter et Dart.
- Riverpod pour l'état.
- GoRouter pour la navigation.
- Fichiers locaux comme source de vérité.
- `share_plus` pour le partage natif.
- `desktop_drop` pour le glisser-déposer desktop.
- `media_kit` pour la prévisualisation vidéo.
- `super_clipboard` et `pasteboard` pour les opérations de copie avancées.

## Dossiers principaux

- [Application](../../lib/app/)
- [Core](../../lib/core/)
- [Features](../../lib/features/)
- [Tests](../../test/)
- [Android](../../android/)
- [Windows](../../windows/)
- [Installateur Windows](../../installer/)
- [Scripts](../../tools/)
