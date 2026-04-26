# Design — Support Supabase dans les skills `repo-analyzer` et `devcontainer`

**Date** : 2026-04-26
**Statut** : design validé, prêt pour planification d'implémentation

## Contexte et objectif

Le projet est un monorepo racine qui regroupe plusieurs repositories indépendants. Pour chaque repo, on génère un dev container afin de le lancer **localement, de manière sandboxée et reproductible**. L'objectif principal est l'**isolation/sécurité** : protéger la machine hôte des dépendances potentiellement compromises (ex. paquets npm véreux).

Aujourd'hui, deux skills couvrent ce besoin :

- `repo-analyzer` : détecte le stack technique (langage, framework, services).
- `devcontainer` : génère la configuration `.devcontainer/` adaptée.

**Manque** : quand un repo utilise Supabase, l'utilisateur doit assembler manuellement le stack Supabase local. Ce design étend les deux skills pour produire automatiquement un dev container intégrant les services Supabase appropriés, **sans CLI dans le container, sans socket Docker exposé, sans Docker-in-Docker**.

## Décisions clés

1. **Architecture compose-frères** : les services Supabase sont déclarés dans `.devcontainer/docker-compose.yml` au même niveau que le dev container, sur le même réseau Docker. Pas de CLI Supabase dans le dev container, pas de socket Docker monté → isolation forte respectée.
2. **Deux profils, détection automatique** : `minimal` (Postgres seul) ou `full` (stack Supabase complet). Choix par `repo-analyzer` selon les usages détectés ; override possible par l'utilisateur.
3. **Scaffolding du dossier `supabase/` conditionnel** : proposé seulement si Supabase est détecté **et** que le dossier n'existe pas dans le repo.
4. **Aucun nouveau skill** : extension chirurgicale des deux skills existants + une nouvelle référence + un dossier de templates.

### Pourquoi pas la CLI Supabase dans le dev container

`supabase start` orchestre des containers Docker. Pour fonctionner depuis l'intérieur du dev container, il faudrait :

- **Monter le socket Docker de l'hôte** → trou de sécurité (un paquet npm compromis pourrait piloter Docker sur l'hôte = équivalent root). Défait l'objectif d'isolation.
- **Activer Docker-in-Docker** → plus lourd, plus lent, configuration complexe.

L'approche compose-frères évite ces deux écueils.

## Architecture

### Vue d'ensemble

```
┌──────────────────────────────────────────────────────────┐
│  .devcontainer/                                          │
│  ├── devcontainer.json   (mode dockerComposeFile)        │
│  ├── docker-compose.yml  (app + services Supabase)       │
│  ├── Dockerfile          (si nécessaire)                 │
│  ├── .env                (dev-only, gitignoré)           │
│  ├── .env.example        (versionné)                     │
│  └── supabase/                                           │
│      └── kong.yml        (profil full uniquement)        │
└──────────────────────────────────────────────────────────┘
```

Le dev container et les services Supabase sont sur le même réseau compose. Le dev container parle aux services par DNS interne (`db`, `kong`, `auth`, etc.). Quelques ports sont exposés à l'hôte uniquement pour permettre l'accès depuis des outils desktop optionnels (Studio, DBeaver, Postman).

### Détection (côté `repo-analyzer`)

Nouvelle étape "7. Détection Supabase". Sortie ajoutée au rapport :

```
**Supabase** : détecté (profil: full)
Signaux : @supabase/ssr, supabase.auth.signIn(), supabase.storage.from()
```

#### Signaux "Supabase utilisé" (déclenche `detected: true`)

- `package.json` → `@supabase/supabase-js`, `@supabase/ssr`, `@supabase/auth-helpers-*`, `@supabase/realtime-js`
- `requirements.txt`, `pyproject.toml` → `supabase`, `supabase-py`
- Présence d'un dossier `supabase/` à la racine du repo
- `.env.example` / `.env.sample` → `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_SUPABASE_*`
- Code source : `import { createClient } from '@supabase/...'`

#### Signaux "profil complet" (sinon → `minimal`)

- **Auth** : usage de `supabase.auth.*`, `@supabase/auth-helpers-*`, `@supabase/ssr` → besoin de **GoTrue + Kong**
- **Realtime** : import de `@supabase/realtime-js`, usage de `.channel()`, `.subscribe()` → besoin de **Realtime**
- **Storage** : usage de `supabase.storage.*`, références à des buckets → besoin de **Storage + imgproxy**
- **Edge Functions** : dossier `supabase/functions/` → flag `full`

Si **aucun** de ces signaux supplémentaires → `minimal` (Postgres seul avec extensions Supabase).

#### Format du rapport étendu

```
supabase:
  detected: true
  profile: minimal | full
  signals:
    - "@supabase/supabase-js (package.json)"
    - "supabase.auth.signIn() (src/lib/auth.ts)"
```

### Profils compose

#### Profil `minimal`

Un seul service ajouté au `docker-compose.yml` :

```yaml
services:
  app:
    # ... le dev container
    depends_on: [db]

  db:
    image: supabase/postgres:15.8.1.060
    restart: unless-stopped
    ports: ["54322:5432"]
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    volumes:
      - <repo>-db-data:/var/lib/postgresql/data

volumes:
  <repo>-db-data:
```

Choix de `supabase/postgres` (pas le `postgres` officiel) : embarque les extensions requises (`pgcrypto`, `pgjwt`, `pg_graphql`, `pg_stat_statements`, etc.). Port hôte `54322` aligné sur la convention Supabase CLI.

#### Profil `full`

Services additionnels au-dessus du minimal :

| Service | Image | Rôle | Port hôte |
| ------- | ----- | ---- | --------- |
| `db` | `supabase/postgres` | Postgres + extensions | 54322 |
| `kong` | `kong` | API gateway, point d'entrée unique | 54321 |
| `auth` | `supabase/gotrue` | Service d'authentification | (interne) |
| `rest` | `postgrest/postgrest` | API REST auto-générée | (interne) |
| `realtime` | `supabase/realtime` | Souscriptions WebSocket | (interne) |
| `storage` | `supabase/storage-api` | Stockage fichiers | (interne) |
| `imgproxy` | `darthsim/imgproxy` | Transformations images (requis par storage) | (interne) |
| `meta` | `supabase/postgres-meta` | API méta-DB (requis par Studio) | (interne) |
| `studio` | `supabase/studio` | UI web | 54323 |

**Versions** : à épingler à l'implémentation en s'alignant sur les tags actuels du `docker-compose.yml` officiel `supabase/supabase`. Jamais de `latest`. Le fichier `kong.yml` (config minimale du gateway) est livré comme template par la skill et copié dans `.devcontainer/supabase/kong.yml`.

### Variables d'environnement

Un `.devcontainer/.env` est généré avec des valeurs **dev-only** :

- `POSTGRES_PASSWORD=postgres`
- `JWT_SECRET=<secret fixe documenté>`
- `ANON_KEY=<calculée à partir du JWT_SECRET>`
- `SERVICE_ROLE_KEY=<calculée à partir du JWT_SECRET>`
- `SITE_URL=http://localhost:3000` (configurable)

Le fichier porte un en-tête commenté : *« valeurs locales sandboxées, ne jamais réutiliser en prod »*. Il est gitignoré ; un `.env.example` versionné liste les clés (sans valeurs sensibles).

### Réseau & ports

| Port hôte | Service | Usage |
| --------- | ------- | ----- |
| 54321 | Kong | Point d'entrée API Supabase |
| 54322 | Postgres | Connexions outils desktop (DBeaver, psql) |
| 54323 | Studio | UI web |

Convention : si plusieurs repos Supabase coexistent, incrémenter par tranche de +10 (54331/32/33, 54341/42/43, …). Le registre des ports dans `CLAUDE.md` racine est mis à jour à chaque génération.

## Flux UX

```
1. repo-analyzer scanne → rapport (avec section Supabase)
                ↓
2. devcontainer reçoit le rapport
   ├─ Pas de Supabase détecté → flux normal, fin
   └─ Supabase détecté → suite
                ↓
3. devcontainer affiche le profil détecté + signaux
   "Confirmer ce profil ? [full / minimal / annuler]"
                ↓
4. Vérification du dossier supabase/ à la racine
   ├─ Existe → continue
   └─ Absent → "Scaffolder un squelette minimal ? [o/n]"
                ↓
5. Génération des fichiers
   - .devcontainer/devcontainer.json
   - .devcontainer/docker-compose.yml
   - .devcontainer/Dockerfile (si besoin)
   - .devcontainer/.env  +  .env.example
   - .devcontainer/supabase/kong.yml (si full)
   - supabase/{config.toml, migrations/, seed.sql} (si scaffolding accepté)
                ↓
6. Mise à jour du CLAUDE.md racine
   - Registre des ports
   - Note "Supabase: profil <minimal|full>"
                ↓
7. Validation (anti-patterns)
```

L'utilisateur peut **toujours override** le profil détecté à l'étape 3 (utile pour faux positifs ou choix volontaire d'un profil plus léger). Le scaffolding (étape 4) ne se déclenche **que** si Supabase est détecté et que le dossier n'existe pas.

Tout est idempotent : si `.devcontainer/` existe déjà, le skill demande confirmation avant d'écraser.

## Organisation des fichiers de la skill

Modifications chirurgicales, pas de réécriture.

```
.claude/skills/
├── repo-analyzer/
│   └── SKILL.md                          ← MODIFIÉ
│       └── ajouter section "7. Détection Supabase"
│           + format de rapport étendu
│
└── devcontainer/
    ├── SKILL.md                          ← MODIFIÉ
    │   └── ajouter section "Services Supabase"
    │       + flux UX (sections 3 & 4)
    │       + référence à references/services/supabase.md
    │
    ├── references/
    │   └── services/
    │       └── supabase.md               ← NOUVEAU
    │           ├── profil minimal (snippet compose)
    │           ├── profil full (snippet compose)
    │           ├── variables d'env + JWT pré-calculé
    │           ├── ports & conventions
    │           └── checklist de validation
    │
    └── templates/                        ← NOUVEAU dossier
        └── supabase/
            ├── kong.yml                  ← config Kong minimale
            ├── env.example               ← template .env Supabase
            └── scaffolding/              ← copié si user accepte
                ├── config.toml
                ├── migrations/.gitkeep
                └── seed.sql
```

## Validation (anti-patterns à vérifier en sortie)

- [ ] Tags d'images épinglés (jamais `latest`)
- [ ] Aucun socket Docker monté dans le dev container
- [ ] Pas de Docker-in-Docker
- [ ] `.env` listé dans `.gitignore`, `.env.example` versionné
- [ ] Volumes nommés pour la persistance Postgres
- [ ] Ports non en collision avec les autres repos du registre
- [ ] `devcontainer.json` reste un JSON/JSONC valide
- [ ] `remoteUser: vscode` (non-root) sauf raison explicite

## Hors scope (YAGNI)

Confirmé par l'utilisateur — les points suivants seront traités dans une itération ultérieure si le besoin se confirme :

- **Edge Functions runtime** : pas embarqué dans le compose, ni minimal ni full. Si le repo a un dossier `supabase/functions/`, le profil détecté est `full` mais sans runtime — on verra plus tard.
- **Génération automatique de migrations** : pas de scaffolding intelligent à partir d'un schéma existant. Si l'utilisateur accepte le scaffolding, on dépose un squelette vide (`migrations/.gitkeep`, `seed.sql` vide). On verra plus tard pour un mode plus avancé.
- **Multi-tenant Supabase** : un seul Supabase par dev container.
- **Profil custom à la carte** : uniquement `minimal` ou `full`. Ajustable plus tard si un cas réel le justifie.
- **Mirror de prod Supabase Cloud** : pas le cas d'usage du projet (objectif = isolation locale).

## Documentation associée (en aval)

À l'implémentation, mettre à jour le `CLAUDE.md` racine pour :

- Ajouter une sous-section « Supabase » sous « Services courants » pointant vers `references/services/supabase.md`.
- Documenter la convention de ports (54321/22/23, +10 par repo additionnel).
