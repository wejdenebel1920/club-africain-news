# Club Africain News — Football V1 (FR / عربي)

Agrégateur quotidien d'actualités football du **Club Africain** (100 % sources gratuites, zéro dépendance externe requise sous Windows, et prêt pour un hébergement statique gratuit sur mobile).

## Fonctionnalités
- **Bilingue Français / Arabe (RTL/LTR)** dès la V1.
- **Périmètre Football V1** : Ligue 1, Coupes nationales, Ligue des Champions CAF, Effectif & Infirmerie, Mercato, Communiqués & Vidéos officielles.
- **Collecte 100 % gratuite** :
  - Chaîne YouTube officielle (`@ClubAfricainOfficielle`) via flux Atom gratuit.
  - Flux RSS/Atom directs de la presse tunisienne (`Mosaïque FM` FR/AR, `Kawarji`, `Diwan FM`).
  - Agrégation Google News RSS (FR + AR) couvrant `La Presse`, `Le Quotidien`, `Foot24`, `Tunisie Numérique`, `beIN Sports`, `CAFOnline`, `Winwin/Kooora`, etc.
- **Console d'administration locale (`/admin`)** + **Mode Statique / PWA mobile** (`public/` autonome avec `manifest.json` et `icon.svg`).

---

## Option A — Lancement local sur PC Windows
1. Double-cliquez sur **`start.bat`** (collecte les flux en direct et ouvre `http://localhost:8088`).
2. Ou en ligne de commande :
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\collect.ps1
   powershell -ExecutionPolicy Bypass -File scripts\server.ps1 -Port 8088
   ```

---

## Option B — Mise en ligne gratuite pour téléphone (GitHub Pages + mise à jour auto)
Le dossier `public/` est désormais **100 % autonome** et accompagné du workflow `.github/workflows/deploy.yml` :
1. Créez un dépôt public sur **GitHub** (ex. `club-africain-news`) et déposez tout le contenu de `E:\club-africain-news` sur la branche `main`.
2. Sur GitHub, allez dans **Settings → Pages → Build and deployment → Source** et choisissez **GitHub Actions**.
3. Allez dans l'onglet **Actions** → **Update & Deploy Club Africain News** → cliquez sur **Run workflow** (ensuite il s'exécutera automatiquement toutes les 30 minutes).
4. Ouvrez l'URL `https://<votre-pseudo>.github.io/club-africain-news/` sur votre téléphone et utilisez **« Ajouter à l'écran d'accueil »** pour l'installer comme une application mobile.

*(Fonctionne aussi avec **Cloudflare Pages** ou **Netlify** en choisissant `public` comme dossier de publication.)*
