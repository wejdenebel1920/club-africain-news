# Club Africain News — Portail Football (FR / عربي)

Agrégateur quotidien d'actualités et portail football du **Club Africain** avec **Site Web Public** et **Console d'Administration & Modération** (100% sources gratuites, zéro dépendance externe sous Windows).

## Fonctionnalités

### 1. Site Web Public (`/`)
- **Bilingue Français / Arabe (RTL / LTR)** avec bascule instantanée.
- **Bandeau Flash Info (Breaking News)** configurable en temps réel.
- **Bannière Prochain Match & Billetterie** (Ligue des Champions CAF, Ligue 1, Coupe).
- **Section « À la Une »** mettant en avant les actualités prioritaires ou épinglées.
- **Filtres par rubriques** : Ligue des Champions CAF, Ligue 1 & Coupes, Effectif & Infirmerie, Mercato, Officiel & Vidéos.
- **Recherche temps réel et tri** (Pertinence / Fraîcheur).
- **Lecteur intégré** pour les communiqués et articles de fond rédigés en interne.
- **Sidebar officielle** : flux vidéos YouTube officiels et accès direct aux plateformes officielles & scores en direct.

### 2. Console d'Administration (`/admin`)
- **Authentification sécurisée** (mot de passe par défaut : `ca1920`, modifiable dans les paramètres).
- **Tableau de bord** : KPIs en direct (total, publiés, masqués, à la une, rédaction manuelle, santé des flux RSS).
- **Modération & Rédaction d'articles** :
  - Publication / Masquage en un clic.
  - Épinglage « À la Une ».
  - Actions groupées (masquer les rumeurs, publier les officiels).
  - Rédaction manuelle de nouveaux articles avec titre, résumé, corps complet et miniature.
- **Gestion des Bandeaux** : modification du texte Flash Info et des informations du prochain match.
- **Gestion des Sources & Flux RSS** : ajout, activation/désactivation de flux RSS / YouTube Atom et ajustement des coefficients de scoring.
- **Paramètres généraux** : titre/sous-titre du site, seuil de score minimal pour auto-publication.

### 3. Moteur de Collecte & Scoring (/100)
- Collecte 100% gratuite (Flux RSS directs Mosaïque FM, Kawarji, Diwan FM, YouTube Atom officiel CA, agrégation Google News FR & AR).
- Score basé sur : Fiabilité (30%) + Réactivité (25%) + Couverture Club Africain (20%) + Données (15%) + Propreté (10%) + Bonus de recoupement multi-sources - Pénalité rumeur.

## Lancement rapide (Windows)

1. Double-cliquez sur **`start.bat`** :
   - Collecte les flux RSS en direct.
   - Démarre le serveur local et ouvre le navigateur.
2. Accédez aux interfaces :
   - **Site public** : `http://localhost:8088/`
   - **Console d'administration** : `http://localhost:8088/admin` (mot de passe : `ca1920`)
3. Lancement manuel en ligne de commande :
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\collect.ps1
   powershell -ExecutionPolicy Bypass -File scripts\server.ps1 -Port 8088
   ```

