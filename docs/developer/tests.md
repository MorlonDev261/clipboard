# Tests

[← Documentation développeur](./README.md)

## Framework

Les tests utilisent `flutter_test`.

## Emplacement

Les tests sont dans [test](../../test/).

Tests existants:

- [browse_filter_test.dart](../../test/browse_filter_test.dart)
- [dir_stats_test.dart](../../test/dir_stats_test.dart)
- [formatting_test.dart](../../test/formatting_test.dart)
- [import_test.dart](../../test/import_test.dart)
- [note_creation_smoke_test.dart](../../test/note_creation_smoke_test.dart)
- [widget_test.dart](../../test/widget_test.dart)

## Lancer les tests

À la racine:

```bash
flutter test
```

## Ajouter un test

1. Créer un fichier dans `test/`.
2. Utiliser `package:flutter_test/flutter_test.dart`.
3. Tester le comportement public ou un flux important.
4. Lancer `flutter test`.

## Avant release

Checklist minimale:

- `flutter analyze`;
- `flutter test`;
- build de la ou des plateformes ciblées;
- vérification manuelle de création note, import, partage, corbeille et réglages.

## Couverture

Le projet ne contient pas actuellement de configuration de couverture dédiée.
Flutter peut générer une couverture avec:

```bash
flutter test --coverage
```

Le rapport brut est généré dans `coverage/`.
