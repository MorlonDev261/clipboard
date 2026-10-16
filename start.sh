#!/bin/sh
# =============================================================================
# start.sh — Influencor (web) sur un serveur Mi Kandra.
#
# Plus déployée par défaut : influencor.mi-kandra.org sert désormais le site vitrine
# (dépôt influencor-web). Pour remettre l'app web Flutter en ligne, donnez-lui un autre
# domaine dans .env (INFLUENCOR_DOMAIN). `--stop` reste utilisable pour l'arrêter.
#
#   ./start.sh            démarre nginx (sert build/web), cohabite avec les autres stacks
#   ./start.sh --build    construit d'abord le site (flutter build web --release)
#   ./start.sh --stop     arrête le conteneur
#   ./start.sh --status   état Mi Kandra (mode, routes) + sonde publique
#
# Modes (détectés par scripts/edge/mi-kandra-edge.sh) : autonome (80/443 libres, nginx les
# publie), partagé (routeur Mi Kandra actif), en attente (80/443 pris par un voisin → `adopt`).
# =============================================================================
set -eu

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$PROJECT_ROOT"
EDGE="sh scripts/edge/mi-kandra-edge.sh"

die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }

# Valeur d'une clé du .env (sans guillemets).
env_value() { [ -f .env ] && sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '"\r' || true; }

[ -f .env ] || { cp .env.example .env && chmod 600 .env 2>/dev/null; echo "→ .env créé depuis .env.example (vérifiez-le)."; }
DOMAIN=$(env_value INFLUENCOR_DOMAIN)
# Domaine désormais servi par le site vitrine (dépôt influencor-web).
SITE_DOMAIN=influencor.mi-kandra.org

command -v docker >/dev/null 2>&1 || die "docker est requis."

# --stop / --status restent utilisables pour arrêter une ancienne instance.
case "${1:-}" in
  --stop|--status) : ;;
  *) case "$DOMAIN" in
       "")             die "INFLUENCOR_DOMAIN est vide dans .env : l'app web Flutter n'est plus déployée par défaut (voir l'en-tête de ce fichier)." ;;
       "$SITE_DOMAIN") die "$SITE_DOMAIN sert désormais le site vitrine (dépôt influencor-web).
  Pour arrêter l'app web Flutter : ./start.sh --stop
  Pour la garder en ligne : donnez-lui un autre domaine dans .env (INFLUENCOR_DOMAIN)." ;;
     esac ;;
esac

case "${1:-}" in
  --stop)   exec docker compose down ;;
  --status) $EDGE status; [ -n "$DOMAIN" ] || exit 0; exec sh scripts/edge/mi-kandra-dns.sh probe "$DOMAIN" ;;
  --build)  command -v flutter >/dev/null 2>&1 || die "flutter est requis pour --build."
            flutter build web --release --no-wasm-dry-run ;;
  "") : ;;
  *) die "option inconnue : $1 (voir l'en-tête de ce fichier)" ;;
esac

[ -f build/web/index.html ] || die "build/web est absent : lancez ./start.sh --build (ou copiez le build web)."
CERT=$(env_value SSL_CERT_PATH); CERT=${CERT:-/etc/nginx/certs/fullchain.pem}
[ -f "nginx/certs/$(basename "$CERT")" ] || die "certificat manquant : placez fullchain.pem et privkey.pem dans nginx/certs/ (Cloudflare Origin Certificate ou Let's Encrypt)."

# Cohabitation : choix mémorisé, puis ports de publication adaptés au mode détecté.
[ -f scripts/edge/mi-kandra-edge.sh ] && {
  $EDGE choose || true
  eval "$($EDGE env 2>/dev/null)" || true
}

docker compose up -d --remove-orphans

# Enregistre la route dans le routeur partagé (sans effet en mode autonome).
case "${MI_KANDRA_EDGE_MODE:-standalone}" in
  shared)  $EDGE sync || true ;;
  pending) [ "${MI_KANDRA_EDGE_AUTOADOPT:-0}" = 1 ] && $EDGE adopt --yes || true ;;
esac

echo "→ Influencor : https://$DOMAIN"
sh scripts/edge/mi-kandra-dns.sh probe "$DOMAIN" || true
