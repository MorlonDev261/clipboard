# Permission Android « accès à tous les fichiers » (`MANAGE_EXTERNAL_STORAGE`)

## Ce que fait l'app

Influencor travaille dans **un dossier choisi par l'utilisateur** (le *workspace*),
n'importe où sur le stockage : ses notes, images, vidéos et tableaux sont de
simples fichiers qu'il retrouve aussi avec son gestionnaire de fichiers. L'import
et le déplacement lisent et déplacent des fichiers situés ailleurs.

Sur Android 11+, écrire dans un dossier arbitraire du stockage partagé exige
`MANAGE_EXTERNAL_STORAGE`. L'app la déclare dans le manifeste, mais **ne la
demande que si c'est nécessaire** :

1. Le dossier choisi est testé par une écriture réelle (`_canUseAsWorkspace`).
2. S'il est déjà accessible (par exemple un dossier propre à l'app), **aucune
   permission n'est demandée**.
3. Sinon seulement, l'écran système « Accès à tous les fichiers » est ouvert.
4. Si l'utilisateur refuse, l'app l'affiche et propose le **dossier de l'app**
   (`Android/data/com.influencor.app/files/Influencor`), qui marche sans aucune
   permission. L'ancien workspace n'est jamais écrasé par un échec.

Tests : `test/workspace_permission_test.dart`.

## Ce que l'app ne fait pas

- Elle ne parcourt pas le stockage : elle ne lit que le workspace et les fichiers
  que l'utilisateur désigne (sélecteur ou glisser-déposer).
- Elle n'envoie aucun fichier sur un serveur (le nettoyage de métadonnées est
  entièrement local).

## Déclaration Google Play

Google Play n'accepte `MANAGE_EXTERNAL_STORAGE` que pour une *fonctionnalité
principale*. Texte proposé pour le formulaire « Accès à tous les fichiers » :

> Influencor is a personal content library whose core function is organising
> the user's own notes, images and videos in a folder of their choice on shared
> storage, and importing/moving existing files into it. This requires reading
> and writing arbitrary folders that the system file picker (SAF) cannot grant
> persistently as a regular file tree. The permission is requested only when the
> chosen folder is not otherwise writable; declining it falls back to an
> app-private folder. No files are uploaded or scanned.

Catégorie à choisir : *document management / file organisation*. Préparer une
courte vidéo montrant : choix du dossier → demande de permission → import.

## Alternative sans cette permission (projet à part)

Remplacer le moteur de fichiers par le **Storage Access Framework** (arbre de
documents persistant, `ContentResolver`). Le workspace deviendrait une URI et non
un chemin : toutes les opérations (`dart:io`, `path`, nettoyeur de métadonnées,
partage, aperçus) devraient passer par un plugin SAF. C'est une réécriture de la
couche fichiers, pas un correctif ; tant qu'elle n'est pas faite, la combinaison
« demande paresseuse + repli dossier de l'app » est le meilleur compromis.
