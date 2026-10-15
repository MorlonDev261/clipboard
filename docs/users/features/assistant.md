# Degany, l'assistant IA

[← Fonctionnalités](./README.md)

L'assistant agit dans l'application à votre place : il cherche, range, écrit,
nettoie vos photos avec Deganeo, gère vos tâches et votre comptabilité.

## Connecter votre IA

1. Menu → Réglages → **Assistant IA** (ou l'icône de réglages dans l'onglet
   Assistant).
2. Choisissez un fournisseur : ChatGPT (OpenAI), Claude (Anthropic), Gemini
   (Google), DeepSeek, Mistral, Grok, Groq, OpenRouter, Qwen, Ollama (local)
   ou « Autre » (tout service compatible OpenAI).
3. Collez votre clé API (bouton « Obtenir une clé »), choisissez un modèle
   (bouton nuage : liste les modèles de votre compte).
4. **Tester la connexion**.

La clé reste sur votre appareil, dans le coffre sécurisé du système. Vos messages et les données que l'assistant
lit pour répondre sont envoyés au fournisseur choisi.

## Exemples de demandes

- « Qu'y a-t-il dans ma bibliothèque ? »
- « Trouve mes notes qui parlent des prix et ajoute le tag tarifs »
- « Crée une note Légende Instagram dans Clients/Ana avec 3 propositions »
- « Nettoie les métadonnées de toutes les photos du dossier Shooting »
- « Ajoute une vente de 25 000 Ar sur MVola » / « Bilan de ce mois »
- « Combien de frais pour retirer 120 000 Ar ? Quelle est la meilleure découpe ? »
- « Crée une tâche Shooting avec : lumière, robe, maquillage »

La réponse s'écrit mot à mot. Pendant le travail, vous voyez :

- **✻ Réflexion** : le raisonnement du modèle, en direct, puis replié (touchez
  pour le relire). Disponible avec Claude, Gemini, DeepSeek, Qwen, et les
  modèles qui la publient.
- **● Action(…)** : chaque action réalisée (point vert = réussie, rouge =
  échec), avec son résultat en dessous. Touchez une action pour voir le
  détail exact.

Les fichiers cités apparaissent comme des boutons : appui = ouvrir, appui long =
copier le chemin. Touchez une ligne d'outil pour voir ce qui a été fait.

## Nettoyer des photos avec l'assistant

1. Touchez le trombone dans la zone de saisie : **Photos et vidéos** ou
   **Fichiers** (sur ordinateur, vous pouvez aussi glisser les fichiers sur le
   chat).
2. Envoyez, avec ou sans message (« nettoie pour Instagram »…).
3. L'assistant analyse les métadonnées avec Deganeo, puis vous demande où
   enregistrer : **Copie à côté de l'original**, **Remplacer l'original** ou
   **Ranger dans la bibliothèque** (et dans quel dossier). Touchez un choix
   ou écrivez votre réponse.

Quand le sélecteur de photos a fourni une copie temporaire du fichier
(fréquent sur Android), seul le rangement dans la bibliothèque est proposé.

## Sécurité

Avant de mettre à la corbeille, supprimer définitivement ou remplacer un
original, l'assistant vous demande d'**Autoriser** ou **Refuser**. Quand il
réécrit une note, l'ancienne version est gardée dans la corbeille.
Le bouton ■ arrête l'assistant à tout moment.

La conversation est conservée quand vous fermez l'app ; « Nouvelle
conversation » l'efface.
