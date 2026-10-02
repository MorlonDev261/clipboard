# Flux Partage

[← Fonctionnalités développeur](./README.md)

## Service principal

Le partage image est centralisé dans:

- [image_share_service.dart](../../../lib/core/services/image_share_service.dart)

## Cas supportés

- image seule depuis `PreviewScreen`;
- plusieurs images depuis la sélection de `BrowseScreen`;
- note texte seul ou texte + images depuis `NoteScreen`.

## Flux

```mermaid
sequenceDiagram
    participant UI as Écran
    participant S as image_share_service
    participant OS as Feuille de partage native
    participant App as Application receptrice

    UI->>S: shareImages/shareImageFiles
    S->>OS: ShareParams fichiers/texte
    OS->>App: utilisateur choisit une destination
    App-->>OS: résultat dépend de l'app
    OS-->>UI: retour système
```

## Points importants

- Les images sont partagées avec MIME explicite selon extension.
- Les noms de fichiers sont conservés.
- Le service ne force pas l'application receptrice à ouvrir un mode particulier.
