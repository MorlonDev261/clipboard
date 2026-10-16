# Menu, comptabilité et tâches

[← Fonctionnalités](./README.md)

## Le menu

Le dernier onglet de la barre de navigation (icône à trois barres) ouvre le **Menu**
(`/menu`). Il donne accès à:

- **Comptabilité**;
- **Tâches**;
- **Réglages**.

« Powered by Morlon Rnd » s'affiche en bas de la page.

## Comptabilité

Suivez vos entrées et sorties d'argent.

- **Solde disponible** en haut de la page, avec le solde de chaque compte.
- **Comptes**: Orange Money, MVola, Airtel Money, Cash. Les puces permettent de filtrer la liste par compte.
- Chaque opération a une **date**, une **note**, un **compte**, un **montant** (en Ar), un **sens**
  (crédit ou débit) et un **type** (achat, vente, dépense).
- Une vente est proposée en crédit, un achat ou une dépense en débit; vous pouvez changer le sens.
- Touchez une opération pour la modifier ou la supprimer.

Les données sont enregistrées dans le dossier de travail: `.clipboard/accounting.json`.

## Tâches

Créez autant de tâches que nécessaire (page `/task`).

- Une tâche a un titre et des **blocs**: **bloc de texte** libre ou **checklist** (titre + éléments à cocher).
- La liste affiche la progression de chaque tâche (éléments cochés / total).
- L'enregistrement est automatique.

Chaque tâche est un fichier JSON dans le dossier de travail: `.clipboard/tasks/<id>.json`.

## Où sont les données ?

Dans votre **dossier de travail**, jamais dans l'application. Sauvegarder ou déplacer ce
dossier sauvegarde ou déplace aussi la comptabilité et les tâches. Sans dossier de travail choisi,
ces pages demandent d'en choisir un depuis l'Accueil.
