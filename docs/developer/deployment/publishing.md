# Publication

[← Documentation développeur](../README.md)

## Android / Google Play

Le projet contient une configuration Android et peut générer APK/AAB via Flutter.
La publication Google Play nécessite un AAB signé.

## Préparation

1. Mettre à jour la version dans [pubspec.yaml](../../../pubspec.yaml).
2. Vérifier la signature Android locale.
3. Lancer les tests et l'analyse.
4. Générer l'AAB.

Commande:

```bash
flutter build appbundle --release
```

## Attention AAB

Un problème de génération AAB a déjà été observé sur l'environnement Windows de
développement: échec du stripping de symboles natifs. Avant publication, il faut
obtenir un AAB valide.

## Google Play Console

Étapes générales:

1. Créer ou ouvrir l'application dans Google Play Console.
2. Configurer le nom de l'application.
3. Ajouter l'icône.
4. Ajouter captures d'écran et visuels.
5. Rédiger la description courte et complète.
6. Choisir la catégorie.
7. Remplir la classification du contenu.
8. Ajouter une politique de confidentialité si nécessaire.
9. Configurer les pays/régions.
10. Créer une piste de test interne ou fermé.
11. Uploader l'AAB signé.
12. Vérifier les alertes Play Console.
13. Publier en test puis en production.

## Rollback / correction

Google Play ne permet pas toujours un rollback direct vers un ancien artefact.
La procédure habituelle est:

1. corriger le problème;
2. augmenter le build number;
3. générer un nouvel AAB;
4. publier une nouvelle release.

## Windows

Le projet produit:

- un build Windows release;
- un installateur Inno Setup.

Artefact attendu:

```text
build/installer/InfluencorSetup.exe
```

La distribution Windows peut se faire par partage direct de l'installateur.
