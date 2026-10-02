# Navigation Et Routing

[← Documentation développeur](../README.md)

Le routing est défini dans [lib/app/router.dart](../../../lib/app/router.dart)
avec GoRouter.

## Routes existantes

| Route | Écran |
| --- | --- |
| `/` | HomeScreen |
| `/browse?path=<path>` | BrowseScreen |
| `/note?path=<path>` | NoteScreen en édition d'une note existante |
| `/note?dir=<dir>` | NoteScreen pour nouvelle note |
| `/preview?path=<path>` | PreviewScreen |
| `/table?path=<path>` | TableScreen |
| `/search` | SearchScreen |
| `/favorites` | FavoritesScreen |
| `/assistant` | AssistantScreen |
| `/trash` | TrashScreen |
| `/settings` | SettingsScreen |

## Helpers de navigation

Les helpers sont dans [lib/app/nav.dart](../../../lib/app/nav.dart).

## Shell applicatif

Le shell est dans [lib/app/widgets/app_shell.dart](../../../lib/app/widgets/app_shell.dart).

Il choisit:

- une barre inférieure sur mobile;
- une NavigationRail sur desktop/tablette.
