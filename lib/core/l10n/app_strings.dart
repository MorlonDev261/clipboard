import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';

/// Lightweight, dependency-free localisation for the MVP (French default,
/// English fallback). Easily replaceable by flutter_localizations / ARB later.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get _isEn => locale.languageCode == 'en';
  String _t(String fr, String en) => _isEn ? en : fr;

  String get appName => 'Influencor.mg';

  // Navigation
  String get home => _t('Accueil', 'Home');
  String get search => _t('Recherche', 'Search');
  String get trash => _t('Corbeille', 'Trash');
  String get settings => _t('Réglages', 'Settings');
  String get favorites => _t('Favoris', 'Favorites');
  String get library => _t('Bibliothèque', 'Library');

  // Generic actions
  String get add => _t('Ajouter', 'Add');
  String get open => _t('Ouvrir', 'Open');
  String get copy => _t('Copier', 'Copy');
  String get share => _t('Partager', 'Share');
  String get delete => _t('Supprimer', 'Delete');
  String get restore => _t('Restaurer', 'Restore');
  String get rename => _t('Renommer', 'Rename');
  String get cancel => _t('Annuler', 'Cancel');
  String get create => _t('Créer', 'Create');
  String get save => _t('Enregistrer', 'Save');
  String get edit => _t('Modifier', 'Edit');
  String get refresh => _t('Actualiser', 'Refresh');

  // Workspace
  String get chooseWorkspace =>
      _t('Choisir le dossier de travail', 'Choose the working folder');
  String get workspaceIntro => _t(
        'Influencor travaille directement dans un dossier de votre disque. '
            'Choisissez-le pour commencer.',
        'Influencor works directly inside a folder on your disk. '
            'Choose one to get started.',
      );
  String get changeWorkspace =>
      _t('Changer de dossier de travail', 'Change working folder');
  String get workspaceFolder => _t('Dossier de travail', 'Working folder');
  String get openLibrary => _t('Ouvrir la bibliothèque', 'Open library');

  // Add menu
  String get newFolder => _t('Nouveau dossier', 'New folder');
  String get newNote => _t('Nouvelle note', 'New note');
  String get importFiles => _t('Importer des fichiers', 'Import files');

  // Content categories
  String get folders => _t('Dossiers', 'Folders');
  String get images => _t('Images', 'Images');
  String get videos => _t('Vidéos', 'Videos');
  String get notes => _t('Notes', 'Notes');
  String get files => _t('Fichiers', 'Files');
  String get contents => _t('Contenus', 'Contents');

  // Notes
  String get noteTitle => _t('Titre', 'Title');
  String get noteTitleHint =>
      _t('Titre de la note (nom du fichier .md)', 'Note title (.md file name)');
  String get noteContent => _t('Contenu (Markdown)', 'Content (Markdown)');
  String get newNoteTitle => _t('Nouvelle note', 'New note');
  String get editNoteTitle => _t('Modifier la note', 'Edit note');
  String get copyContent => _t('Copier le contenu', 'Copy content');
  String get emptyNoteError =>
      _t('La note ne peut pas être vide.', 'The note cannot be empty.');
  String get attachPhoto => _t('Joindre une photo', 'Attach a photo');
  String get attachments => _t('Pièces jointes', 'Attachments');
  String photosAttached(int n) =>
      _t('$n photo(s) jointe(s).', '$n photo(s) attached.');

  // Rich-text formatting toolbar
  String get bold => _t('Gras', 'Bold');
  String get italic => _t('Italique', 'Italic');
  String get underline => _t('Souligné', 'Underline');
  String get strikethrough => _t('Barré', 'Strikethrough');
  String get monospace => _t('Code / chasse fixe', 'Code / monospace');
  String get bulletList => _t('Liste à puces', 'Bullet list');
  String get numberedList => _t('Liste numérotée', 'Numbered list');
  String get clearFormatting => _t('Effacer la mise en forme', 'Clear formatting');
  String get selectTextFirst =>
      _t('Sélectionnez d\'abord du texte.', 'Select some text first.');
  String get preview => _t('Aperçu', 'Preview');
  String get sent => _t('Envoyé', 'Sent');

  // Copy modes
  String get copyForSocial =>
      _t('Copier pour les réseaux sociaux', 'Copy for social media');
  String get copyPlainText => _t('Copier en texte simple', 'Copy as plain text');
  String get copyMarkdown => _t('Copier en Markdown', 'Copy as Markdown');
  String get socialPreviewTitle =>
      _t('Aperçu réseaux sociaux', 'Social media preview');
  String get copyFailed =>
      _t('Échec de la copie dans le presse-papiers.', 'Failed to copy to clipboard.');

  // Dialogs
  String get nameLabel => _t('Nom', 'Name');
  String get folderNameLabel => _t('Nom du dossier', 'Folder name');
  String get newFolderTitle => _t('Nouveau dossier', 'New folder');
  String get renameTitle => _t('Renommer', 'Rename');
  String get deleteTitle => _t('Supprimer cet élément ?', 'Delete this item?');
  String get deleteMessage => _t(
        'Il sera déplacé vers la corbeille.',
        'It will be moved to the trash.',
      );
  String get emptyTrashTitle =>
      _t('Vider la corbeille ?', 'Empty the trash?');
  String get emptyTrashMessage => _t(
        'Tous les éléments seront supprimés définitivement.',
        'All items will be permanently deleted.',
      );
  String get emptyTrash => _t('Vider la corbeille', 'Empty trash');
  String get deletePermanently =>
      _t('Supprimer définitivement', 'Delete permanently');

  // Drag & drop
  String get dropHint =>
      _t('Déposez des fichiers ou dossiers ici', 'Drop files or folders here');
  String get dropToImport =>
      _t('Relâchez pour importer', 'Release to import');

  // Empty states
  String get emptyFolderTitle => _t('Dossier vide', 'Empty folder');
  String get emptyFolderMessage => _t(
        'Créez un dossier, une note, ou glissez-déposez des fichiers ici.',
        'Create a folder, a note, or drag & drop files here.',
      );
  String get noContents => _t('Aucun contenu', 'No content yet');
  String get trashEmpty => _t('La corbeille est vide', 'The trash is empty');

  // Favorites
  String get addToFavorites => _t('Ajouter aux favoris', 'Add to favorites');
  String get removeFromFavorites =>
      _t('Retirer des favoris', 'Remove from favorites');

  // Feedback / errors
  String get genericError => _t('Une erreur est survenue.', 'Something went wrong.');
  String get comingSoon => _t('Bientôt disponible.', 'Coming soon.');
  String get copiedToClipboard =>
      _t('Copié dans le presse-papiers', 'Copied to clipboard');
  String copiedWithFiles(int n) => _t(
        'Texte et $n fichier(s) copiés',
        'Text and $n file(s) copied',
      );
  String get noteSaved => _t('Note enregistrée.', 'Note saved.');
  String get itemDeleted => _t('Élément supprimé.', 'Item deleted.');
  String get videoPreviewHint => _t(
        'Aperçu vidéo bientôt disponible. Le fichier est bien enregistré.',
        'Video preview coming soon. The file is safely stored.',
      );
  String folderCreated(String name) =>
      _t('Dossier « $name » créé.', 'Folder "$name" created.');
  String importReport(int ok, int failed) => failed == 0
      ? _t('$ok élément(s) importé(s).', '$ok item(s) imported.')
      : _t('$ok importé(s), $failed échec(s).', '$ok imported, $failed failed.');

  // Search
  String get searchHint =>
      _t('Rechercher dans la bibliothèque…', 'Search the library…');
  String get searchPrompt => _t(
        'Tapez pour rechercher par nom ou tag.',
        'Type to search by name or tag.',
      );
  String get noResults => _t('Aucun résultat', 'No results');
  String get all => _t('Tous', 'All');

  // Sort
  String get sortBy => _t('Trier par', 'Sort by');
  String get sortNameAsc => _t('Nom (A→Z)', 'Name (A→Z)');
  String get sortNameDesc => _t('Nom (Z→A)', 'Name (Z→A)');
  String get sortNewest => _t('Plus récent', 'Newest');
  String get sortOldest => _t('Plus ancien', 'Oldest');
  String get sortSizeAsc => _t('Taille croissante', 'Size ascending');
  String get sortSizeDesc => _t('Taille décroissante', 'Size descending');

  // Tags
  String get tags => _t('Tags', 'Tags');
  String get editTags => _t('Modifier les tags', 'Edit tags');
  String get tagsHint =>
      _t('Tags séparés par des virgules', 'Comma-separated tags');

  // Move / duplicate
  String get move => _t('Déplacer', 'Move');
  String get duplicate => _t('Dupliquer', 'Duplicate');
  String get moved => _t('Déplacé.', 'Moved.');
  String get duplicated => _t('Dupliqué.', 'Duplicated.');
  String get chooseDestination =>
      _t('Choisir le dossier de destination', 'Choose destination folder');

  // Favorites
  String get favoritesEmpty => _t('Aucun favori', 'No favorites yet');
  String get inFolder => _t('dans', 'in');

  // Settings
  String get appearance => _t('Apparence', 'Appearance');
  String get theme => _t('Thème', 'Theme');
  String get themeSystem => _t('Système', 'System');
  String get themeLight => _t('Clair', 'Light');
  String get themeDark => _t('Sombre', 'Dark');
  String get language => _t('Langue', 'Language');
  String get french => _t('Français', 'French');
  String get english => _t('Anglais', 'English');
  String get defaultView => _t('Vue par défaut', 'Default view');
  String get viewGrid => _t('Grille', 'Grid');
  String get viewList => _t('Liste', 'List');

  // In-app file picker
  String get selectFilesTitle =>
      _t('Sélectionner des fichiers', 'Select files');
  String get selectImagesTitle =>
      _t('Sélectionner des photos', 'Select photos');
  String get multipleSelection => _t('Sélection multiple', 'Multiple selection');
  String get chooseThisFolder => _t('Choisir ce dossier', 'Choose this folder');
  String get parentFolder => _t('Dossier parent', 'Parent folder');
  String get importAction => _t('Importer', 'Import');
  String get selectAction => _t('Sélectionner', 'Select');
  String get folderAccessError => _t(
        'Impossible d\'accéder à ce dossier.',
        'Cannot access this folder.',
      );
  String get locationHome => _t('Dossier personnel', 'Home');
  String get locationDesktop => _t('Bureau', 'Desktop');
  String get locationDocuments => _t('Documents', 'Documents');
  String get locationDownloads => _t('Téléchargements', 'Downloads');
  String nSelected(int n) => _t('$n sélectionné(s)', '$n selected');
}

/// Current app strings, following the language chosen in settings (French by
/// default).
final appStringsProvider = Provider<AppStrings>((ref) {
  final code = ref.watch(settingsProvider).languageCode;
  return AppStrings(Locale(code));
});
