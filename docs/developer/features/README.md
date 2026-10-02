# Fonctionnalités Côté Développeur

[← Documentation développeur](../README.md)

## Où modifier quoi ?

| Besoin | Emplacement |
| --- | --- |
| Ajouter une route | [lib/app/router.dart](../../../lib/app/router.dart) et [lib/app/nav.dart](../../../lib/app/nav.dart) |
| Modifier le thème | [lib/app/theme](../../../lib/app/theme/) |
| Modifier les textes | [lib/core/l10n/app_strings.dart](../../../lib/core/l10n/app_strings.dart) |
| Modifier les réglages | [settings_service.dart](../../../lib/core/services/settings_service.dart), [settings_providers.dart](../../../lib/core/providers/settings_providers.dart), [settings_screen.dart](../../../lib/features/settings/presentation/settings_screen.dart) |
| Modifier la bibliothèque | [lib/features/library](../../../lib/features/library/) |
| Modifier les notes | [note_screen.dart](../../../lib/features/library/presentation/note_screen.dart) |
| Modifier les tableaux | [table_screen.dart](../../../lib/features/library/presentation/table_screen.dart), [table_document.dart](../../../lib/features/library/domain/table_document.dart) |
| Modifier le partage | [image_share_service.dart](../../../lib/core/services/image_share_service.dart) |
| Modifier le picker | [lib/core/picker](../../../lib/core/picker/) |
| Ajouter des tests | [test](../../../test/) |
| Modifier Android natif | [android](../../../android/) |
| Modifier Windows natif | [windows](../../../windows/) |
| Modifier les assets | [assets](../../../assets/) |

## Flux importants

- [Bibliothèque](./library-flow.md)
- [Notes](./notes-flow.md)
- [Partage](./sharing-flow.md)
- [Tableaux](./tables-flow.md)
