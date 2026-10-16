# Web — app Flutter (retirée de influencor.mi-kandra.org)

[← Documentation développeur](../README.md)

> **Retirée de `influencor.mi-kandra.org`.** Ce domaine sert désormais le site vitrine et
> les téléchargements (dépôt [`influencor-web`](https://github.com/MorlonDev261/influencor-web)).
> L'app web Flutter n'est plus déployée par défaut : `start.sh` refuse de démarrer tant que
> `INFLUENCOR_DOMAIN` est vide ou vaut `influencor.mi-kandra.org`. Sur un serveur où elle
> tourne encore : `./start.sh --stop`, puis lancer `influencor-web`.

Le build web Flutter (`build/web`) est servi par un nginx Docker « origin » Mi Kandra,
comme `poma-original` et `mga-follow-up-v1` : mêmes scripts `scripts/edge/`, mêmes labels
`org.mi-kandra.*`, même cohabitation sur un serveur.

| Élément | Valeur |
|---|---|
| Domaine | aucun par défaut (variable `INFLUENCOR_DOMAIN`, autre que `influencor.mi-kandra.org`) |
| Projet / alias origin | `influencor` / `influencor-origin` |
| Ports de diagnostic (loopback) | `18084` (HTTP) · `18447` (HTTPS) |
| Projet Compose | `influencor` |

## Fichiers

* `docker-compose.yml` — nginx durci (read-only, capacités réduites), labels Mi Kandra.
* `nginx/templates/influencor.conf.template` — vhost (HTTP→HTTPS, cache, repli SPA sur `index.html`).
* `nginx/snippets/` — IP réelle (routeur + Cloudflare) et TLS, identiques aux autres projets.
* `nginx/certs/` — `fullchain.pem` + `privkey.pem` (jamais versionnés).
* `scripts/edge/` — copie identique des autres projets ; seul `project.env` diffère.
* `start.sh` — démarrage (`--build`, `--stop`, `--status`).
* `.env.example` — `INFLUENCOR_DOMAIN` (vide par défaut), chemins des certificats.

## Mise en service (sur un autre domaine)

1. **Cloudflare — DNS** : zone `mi-kandra.org`, enregistrement du sous-domaine choisi (A vers l'IP du VPS, ou le
   même que Pôma), nuage orange accepté.
2. **Cloudflare — SSL/TLS** : mode **Full (strict)**. Créer un *Origin Certificate* pour
   ce domaine (ou `*.mi-kandra.org`) et le déposer dans `nginx/certs/`
   (`fullchain.pem`, `privkey.pem`, droits 600).
3. Sur le serveur : `./start.sh --build` (ou copier un `build/web` déjà construit), puis `./start.sh`.
4. Cohabitation avec Pôma/MGA : `start.sh` pose la question une fois (`choose`). Si 80/443 sont pris :
   `sh scripts/edge/mi-kandra-edge.sh adopt --yes`. Seul, le nginx publie 80/443 lui-même (mode autonome).

## Vérification

```bash
sh scripts/edge/mi-kandra-edge.sh doctor --probe   # mode, routes, certificat
sh scripts/edge/mi-kandra-dns.sh probe <INFLUENCOR_DOMAIN>         # chemin réel d'un visiteur
sh scripts/edge/mi-kandra-cfips.sh update          # plages IP Cloudflare à jour
sh scripts/edge/mi-kandra-audit.sh
```

Voir aussi la documentation Mi Kandra de `poma-original`
(`docs/07-deployment/mi-kandra-multi-stack.md`, `dns-cloudflare-registrar.md`).
