# Mode `reseller` (espace professionnel)

Code : `lib/features/reseller/`, page `/about` et route `/pro`
(`lib/features/about/`), état dans `AppSettings` (`reseller`, `appMode`).

## Parcours

1. **Réglages → icône « ? »** (à droite de la ligne Influencor) ouvre `/about`.
2. **`/about` → « Accès professionnel »** ouvre `/pro` : un WebView sur
   `https://reseller.poma-original.com/login`.
3. Après chaque page chargée sur un hôte de confiance, l'app exécute une sonde
   (`ResellerConfig.sessionProbe`) qui interroge `/api/auth/session` du site et
   renvoie **un seul booléen** par le canal `PomaSession`. Un nonce secret,
   propre au contrôleur, empêche une iframe tierce de simuler une session.
4. Dès qu'une session existe : variable cachée `reseller = true`, mode `reseller`,
   retour à l'accueil.
5. **Badge repliable** sous « Influencor » (accueil) : `clipboard` / `reseller`
   (mots volontairement non traduits). Visible si `reseller = true` ou si l'on est
   dans l'espace reseller (pour toujours pouvoir revenir).
6. En mode `reseller`, tout l'accueil est le site `reseller.poma-original.com/*`
   (sans barre de navigation) ; l'en-tête garde le badge, **Actualiser** et
   **Se déconnecter**.
7. **Se déconnecter** efface cookies, stockage local et cache du WebView, remet
   `reseller = false` et le mode `clipboard` en **une seule** écriture.

## Deeplinks

`https://reseller.poma-original.com/*` ouvre l'espace reseller d'Influencor
(Android App Links, `app_links`). Voir le projet `poma-original`,
`docs/03-mobile/deep-links.md` (assetlinks.json : Influencor en premier, puis
Pôma Original).

## Ce que `reseller = true` veut dire — et ne veut pas dire

- Il veut dire : **« une session a été créée dans le WebView »** (règle produit).
  Un client ordinaire qui se connecte l'active aussi : ce n'est pas un défaut, le
  site gère lui-même la suite (vitrine du programme, candidature, activation).
- Il **n'est jamais un contrôle d'accès**. Il vit côté client (modifiable sur un
  appareil débloqué) et ne fait que révéler le badge. Toute donnée ou action
  revendeur est protégée **côté serveur** (`auth()` sur chaque route
  `/api/reseller/*`). Ne jamais s'appuyer sur ce drapeau pour autoriser quoi que
  ce soit.
- Il retombe à `false` si la sonde constate qu'il n'y a plus de session
  (déconnexion sur le site, expiration) et lors de « Se déconnecter ».

## Garde-fous du WebView

- Navigation « page principale » limitée à `poma-original.com` et ses
  sous-domaines en `https` ; les iframes sont du contenu de page.
- Hors de ces hôtes, seuls `https`, `http`, `mailto`, `tel`, `sms`, `whatsapp`
  sont confiés au système ; `intent:`, `file:`, `javascript:`, `data:` sont
  abandonnés.
- `allowBackup="false"` : le cookie de session ne part pas dans la sauvegarde
  Android.
- Plateformes sans plugin WebView (Windows, Linux, web) : l'espace s'ouvre dans
  le navigateur système.
