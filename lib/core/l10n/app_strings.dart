import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight, dependency-free localisation for the MVP.
///
/// This keeps user-facing text out of the widgets and behind a typed API,
/// while remaining trivially replaceable by `flutter_localizations` / ARB
/// files later. French is the default; English is provided as a fallback.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get _isEn => locale.languageCode == 'en';
  String _t(String fr, String en) => _isEn ? en : fr;

  String get appName => 'Clipboard';

  // Navigation
  String get home => _t('Accueil', 'Home');
  String get search => _t('Recherche', 'Search');
  String get trash => _t('Corbeille', 'Trash');
  String get settings => _t('Réglages', 'Settings');
  String get favorites => _t('Favoris', 'Favorites');

  // Actions
  String get add => _t('Ajouter', 'Add');
  String get newFolder => _t('Nouveau dossier', 'New folder');
  String get import => _t('Importer', 'Import');
  String get createText => _t('Créer un texte', 'Create text');
  String get createPost => _t('Créer une publication', 'Create post');
  String get copy => _t('Copier', 'Copy');
  String get share => _t('Partager', 'Share');
  String get delete => _t('Supprimer', 'Delete');
  String get restore => _t('Restaurer', 'Restore');
  String get rename => _t('Renommer', 'Rename');
  String get cancel => _t('Annuler', 'Cancel');
  String get create => _t('Créer', 'Create');
  String get save => _t('Enregistrer', 'Save');
  String get open => _t('Ouvrir', 'Open');
  String get edit => _t('Modifier', 'Edit');

  // Text asset / create
  String get createTextTitle => _t('Nouveau texte', 'New text');
  String get editTextTitle => _t('Modifier le texte', 'Edit text');
  String get titleOptionalLabel => _t('Titre (optionnel)', 'Title (optional)');
  String get textLabel => _t('Texte', 'Text');
  String get statusLabel => _t('Statut', 'Status');
  String get statusDraft => _t('Brouillon', 'Draft');
  String get statusReady => _t('Prêt', 'Ready');
  String get textEmptyError =>
      _t('Le texte ne peut pas être vide.', 'The text cannot be empty.');
  String get copyText => _t('Copier le texte', 'Copy text');
  String get copyTitleAndText =>
      _t('Copier le titre et le texte', 'Copy title and text');
  String get copiedToClipboard =>
      _t('Copié dans le presse-papiers', 'Copied to clipboard');
  String get addToFavorites => _t('Ajouter aux favoris', 'Add to favorites');
  String get removeFromFavorites =>
      _t('Retirer des favoris', 'Remove from favorites');
  String get deleteAssetTitle => _t('Supprimer ce contenu ?', 'Delete this content?');
  String get deleteAssetMessage => _t(
        'Ce contenu sera déplacé vers la corbeille.',
        'This content will be moved to the trash.',
      );
  String get contentDeleted => _t('Contenu supprimé.', 'Content deleted.');
  String get textSaved => _t('Texte enregistré.', 'Text saved.');
  String get mediaComingSoon => _t(
        'L\'import de médias arrive bientôt.',
        'Media import is coming soon.',
      );
  String get importImages => _t('Importer des images', 'Import images');
  String get importVideos => _t('Importer des vidéos', 'Import videos');

  // Content categories
  String get images => _t('Images', 'Images');
  String get videos => _t('Vidéos', 'Videos');
  String get texts => _t('Textes', 'Texts');
  String get posts => _t('Publications', 'Posts');
  String get subfolders => _t('Sous-dossiers', 'Subfolders');
  String get contents => _t('Contenus', 'Contents');
  String get readyToPublish => _t('Prêt à publier', 'Ready to publish');

  // Home
  String get quickStats => _t('Statistiques rapides', 'Quick stats');
  String get recentFolders => _t('Dossiers récents', 'Recent folders');
  String get openMain => _t('Ouvrir Main', 'Open Main');
  String get searchHint =>
      _t('Rechercher un contenu…', 'Search your content…');

  // Empty states
  String get emptyFolderTitle => _t('Dossier vide', 'Empty folder');
  String get emptyFolderMessage => _t(
        'Créez un sous-dossier ou importez du contenu pour commencer.',
        'Create a sub-folder or import content to get started.',
      );
  String get noSubfolders => _t('Aucun sous-dossier', 'No sub-folders');
  String get noContents => _t('Aucun contenu', 'No content yet');

  // Dialogs
  String get newFolderTitle => _t('Nouveau dossier', 'New folder');
  String get folderNameLabel => _t('Nom du dossier', 'Folder name');
  String get renameFolderTitle => _t('Renommer le dossier', 'Rename folder');
  String get deleteFolderTitle =>
      _t('Supprimer le dossier ?', 'Delete folder?');
  String get deleteFolderMessage => _t(
        'Ce dossier sera déplacé vers la corbeille.',
        'This folder will be moved to the trash.',
      );

  // Errors / feedback
  String get mainCannotBeDeleted =>
      _t('Le dossier Main ne peut pas être supprimé.',
          'The Main folder cannot be deleted.');
  String get genericError =>
      _t('Une erreur est survenue.', 'Something went wrong.');
  String get comingSoon =>
      _t('Bientôt disponible.', 'Coming soon.');
  String folderCreated(String name) =>
      _t('Dossier « $name » créé.', 'Folder "$name" created.');
  String folderDeleted(String name) =>
      _t('Dossier « $name » supprimé.', 'Folder "$name" deleted.');
}

/// Current app strings. Defaults to French for the MVP.
final appStringsProvider = Provider<AppStrings>((ref) {
  return const AppStrings(Locale('fr'));
});
