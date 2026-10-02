# Plan de durcissement (audit sécurité / bugs)

Source : audit du code Influencor. Les 9 premiers points ont déjà été corrigés et
couverts par des tests (`test/security_test.dart`) ; ce plan traite le **reste**,
une tâche à la fois, chacune avec sa vérification.

## Déjà fait (rappel)

- [x] Perte de données : déplacer/importer un dossier dans lui-même
- [x] Injection de commande Windows à l'ouverture d'un fichier
- [x] Corbeille : index non fiable (suppression / restauration hors workspace)
- [x] Corbeille : index corrompu écrasé silencieusement
- [x] Écritures non atomiques + mises à jour perdues (favoris, tags, corbeille, réglages)
- [x] Fichiers piégés (MP4 aux milliards d'échantillons, PDF objet 999999999, >160 Mo)
- [x] « Remplacer » l'original non atomique ; « Télécharger » (mémoire, extension)
- [x] WebView : nonce de session, schémas externes en liste blanche, cadre principal seul
- [x] Sauvegarde Android désactivée (cookie de session)

## Tâches (toutes traitées)

| # | Tâche | Statut | Résultat / vérification |
|---|---|---|---|
| T1 | Noms de fichiers/dossiers sûrs (noms réservés Windows, points/espaces, contrôle, longueur, noms cachés `.x`) | ✅ | `sanitizeFileName` + `test/file_names_test.dart` (a révélé une erreur d'échappement, corrigée) |
| T2 | Création sans course : réservation exclusive du nom (`create(exclusive: true)`) pour notes, imports, copies, déplacements, restauration | ✅ | `test/race_test.dart` (25 notes simultanées, 12 imports simultanés, move sans écrasement). A révélé que `exists()` est peu fiable sous Windows pendant une copie : on se base sur l'erreur « existe » |
| T3 | Purge des copies nettoyées orphelines du dossier temporaire | ✅ | `purgeStaleCleanCopies` + `test/stale_copies_test.dart`, appelée à l'ouverture de la page de nettoyage |
| T4 | Déconnexion reseller : cookies/stockage/cache du WebView effacés, `reseller=false` + mode `clipboard` en une écriture | ✅ | `test/reseller_test.dart` (dialogue, annulation, confirmation). A révélé un **débordement de 60 px** de l'en-tête sur petit écran, corrigé + tests à 320/360 dp |
| T5 | `MANAGE_EXTERNAL_STORAGE` : demande déjà paresseuse ; ajout du retour utilisateur si refus + repli « dossier de l'app » sans permission ; doc de déclaration Play | ✅ | `test/workspace_permission_test.dart` ; `docs/developer/android-storage-permission.md` |
| T6 | `reseller=true` documenté : voulu, jamais un contrôle d'accès | ✅ | `docs/developer/architecture/reseller-mode.md` + commentaire dans `AppSettings` |
| T7 | Vérification finale | ✅ | voir la fin du document |

## Hors périmètre (nécessitent un humain / un appareil)

- Relecture du malgache par un locuteur natif.
- Test réel sur téléphone (connexion reseller, badge, deeplink).
- Configuration iOS (identifiant et équipe Apple absents).
- Remplacement complet de `MANAGE_EXTERNAL_STORAGE` par le Storage Access Framework
  (réécriture du moteur de fichiers : projet à part).
