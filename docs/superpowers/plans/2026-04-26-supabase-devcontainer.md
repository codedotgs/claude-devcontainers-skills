# Supabase Devcontainer Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Étendre les skills `repo-analyzer` et `devcontainer` pour générer automatiquement un dev container intégrant les services Supabase (profil minimal ou full), sans CLI dans le container, sans socket Docker exposé, sans Docker-in-Docker.

**Architecture:** Approche compose-frères : les services Supabase sont déclarés dans `.devcontainer/docker-compose.yml` au même niveau que le dev container, sur le même réseau Docker. Détection automatique du profil (`minimal` = `supabase/postgres` seul ; `full` = stack complet avec GoTrue, PostgREST, Realtime, Storage, Kong, Studio) via `repo-analyzer`. Override utilisateur possible.

**Tech Stack:** Markdown (skill files), YAML (docker-compose, kong), TOML (config), Bash (validation snippets), images Docker `supabase/*`.

**Spec source:** [docs/superpowers/specs/2026-04-26-supabase-devcontainer-design.md](../specs/2026-04-26-supabase-devcontainer-design.md)

---

## File Structure

| Fichier | Action | Responsabilité |
| ------- | ------ | -------------- |
| `.claude/skills/devcontainer/references/services/supabase.md` | CREATE | Référence canonique : profils compose, env vars, ports, validation |
| `.claude/skills/devcontainer/templates/supabase/kong.yml` | CREATE | Config Kong minimale (gateway Supabase) |
| `.claude/skills/devcontainer/templates/supabase/env.example` | CREATE | Template `.env` pour Supabase (clés/secrets dev) |
| `.claude/skills/devcontainer/templates/supabase/scaffolding/config.toml` | CREATE | Scaffold optionnel `supabase/config.toml` |
| `.claude/skills/devcontainer/templates/supabase/scaffolding/migrations/.gitkeep` | CREATE | Scaffold optionnel `supabase/migrations/` |
| `.claude/skills/devcontainer/templates/supabase/scaffolding/seed.sql` | CREATE | Scaffold optionnel `supabase/seed.sql` |
| `.claude/skills/repo-analyzer/SKILL.md` | MODIFY | Ajouter section "7. Détection Supabase" + format de rapport étendu |
| `.claude/skills/devcontainer/SKILL.md` | MODIFY | Ajouter section "Services Supabase" + flux UX + référence vers `references/services/supabase.md` |
| `CLAUDE.md` (racine) | MODIFY | Sous-section "Supabase" + convention de ports (54321/22/23, +10/repo) |

**Note préalable** — versions d'images Supabase : avant de figer les tags dans la référence (Task 1) et l'`env.example` (Task 3), récupérer les versions actuelles depuis le `docker-compose.yml` officiel `supabase/supabase` (https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml). Ne jamais utiliser `latest`.

---

## Task 1 : Créer la référence Supabase

**Files:**
- Create: `.claude/skills/devcontainer/references/services/supabase.md`

- [ ] **Step 1 : Vérifier que le dossier parent existe (création si besoin)**

```bash
mkdir -p .claude/skills/devcontainer/references/services
```

- [ ] **Step 2 : Récupérer les versions d'images Supabase courantes**

Consulter le `docker-compose.yml` officiel : https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml

Noter les tags exacts pour : `supabase/postgres`, `supabase/gotrue`, `postgrest/postgrest`, `supabase/realtime`, `supabase/storage-api`, `darthsim/imgproxy`, `supabase/postgres-meta`, `supabase/studio`, `kong`. Garder la liste sous la main pour Steps 3 et Task 3.

- [ ] **Step 3 : Écrire le fichier de référence**

Contenu de `.claude/skills/devcontainer/references/services/supabase.md` :

````markdown
# Référence : Services Supabase

Profils compose à insérer dans `.devcontainer/docker-compose.yml` selon la détection produite par `repo-analyzer`.

## Quand utiliser quel profil

- `minimal` : projet utilise Supabase comme **Postgres-augmenté** (extensions, RLS) sans Auth/Realtime/Storage. Détection : seul `@supabase/supabase-js` (ou équivalent Python) sans usage de `auth.*`, `.channel()`, `storage.*`.
- `full` : projet utilise Auth, Realtime ou Storage. Détection : signaux dans la spec (`supabase.auth.*`, `@supabase/ssr`, `.channel()`, `supabase.storage.*`, dossier `supabase/functions/`).

## Profil minimal

Service unique. À fusionner avec le service `app` du dev container.

```yaml
services:
  app:
    # ... dev container existant
    depends_on:
      db:
        condition: service_healthy

  db:
    image: supabase/postgres:<VERSION>
    restart: unless-stopped
    ports:
      - "54322:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    volumes:
      - <repo>-db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  <repo>-db-data:
```

`<VERSION>` : tag actuel récupéré depuis `supabase/supabase` (ex. `15.8.1.060`). Jamais `latest`.

## Profil full

Au-dessus du minimal, ajouter les services suivants. Tous sur le même réseau compose par défaut.

| Service | Image | Rôle | Port hôte |
| ------- | ----- | ---- | --------- |
| `kong` | `kong:<VERSION>` | Gateway API (point d'entrée unique) | 54321 |
| `auth` | `supabase/gotrue:<VERSION>` | Authentification (GoTrue) | (interne) |
| `rest` | `postgrest/postgrest:<VERSION>` | API REST auto-générée | (interne) |
| `realtime` | `supabase/realtime:<VERSION>` | Souscriptions WebSocket | (interne) |
| `storage` | `supabase/storage-api:<VERSION>` | Stockage fichiers | (interne) |
| `imgproxy` | `darthsim/imgproxy:<VERSION>` | Transformations images | (interne) |
| `meta` | `supabase/postgres-meta:<VERSION>` | API méta-DB (requis par Studio) | (interne) |
| `studio` | `supabase/studio:<VERSION>` | UI web | 54323 |

Le fichier `kong.yml` (template `templates/supabase/kong.yml`) est copié dans `.devcontainer/supabase/kong.yml` et monté dans le service `kong`.

## Variables d'environnement

Générer `.devcontainer/.env` à partir du template `templates/supabase/env.example`. Le fichier porte un en-tête commenté :

```
# Valeurs locales sandboxées — ne jamais réutiliser en prod.
```

Variables :

- `POSTGRES_PASSWORD=postgres`
- `JWT_SECRET=<32 caractères, fixe pour le dev local>`
- `ANON_KEY=<JWT signé avec JWT_SECRET, role=anon, exp=long>`
- `SERVICE_ROLE_KEY=<JWT signé avec JWT_SECRET, role=service_role, exp=long>`
- `SITE_URL=http://localhost:3000`
- `API_EXTERNAL_URL=http://localhost:54321`

`.env` est ajouté au `.gitignore` ; `.env.example` est versionné (sans valeurs sensibles, juste les clés).

## Conventions de ports

| Port hôte | Service | Note |
| --------- | ------- | ---- |
| 54321 | Kong | Point d'entrée API Supabase |
| 54322 | Postgres | Connexions outils desktop |
| 54323 | Studio | UI web |

Si plusieurs repos Supabase coexistent, incrémenter par tranche de +10 (54331/32/33, 54341/42/43, …). Vérifier le registre des ports dans `CLAUDE.md` racine avant d'attribuer.

## Checklist de validation

- [ ] Tags d'images épinglés (jamais `latest`)
- [ ] Aucun socket Docker monté (`/var/run/docker.sock`) dans le dev container
- [ ] Pas de Docker-in-Docker (feature `docker-in-docker` absente)
- [ ] `.env` listé dans `.gitignore`, `.env.example` versionné
- [ ] Volume nommé pour la persistance Postgres (jamais `tmpfs` ni anonymous)
- [ ] Ports non en collision avec les autres repos du registre
- [ ] `devcontainer.json` reste un JSON/JSONC valide
- [ ] `remoteUser: vscode` (non-root) sauf raison explicite
- [ ] `healthcheck` sur `db`, `depends_on.condition: service_healthy` côté `app`
````

Substituer `<VERSION>` par les tags récupérés au Step 2.

- [ ] **Step 4 : Vérifier la création**

Run :
```bash
test -f .claude/skills/devcontainer/references/services/supabase.md && echo OK
```
Expected: `OK`

- [ ] **Step 5 : Commit**

```bash
git add .claude/skills/devcontainer/references/services/supabase.md
git commit -m "feat(devcontainer): add Supabase services reference"
```

---

## Task 2 : Créer le template Kong

**Files:**
- Create: `.claude/skills/devcontainer/templates/supabase/kong.yml`

- [ ] **Step 1 : Créer le dossier**

```bash
mkdir -p .claude/skills/devcontainer/templates/supabase
```

- [ ] **Step 2 : Écrire le template kong.yml**

Contenu (déclaratif, version "decK" supportée par Kong 2.x) :

```yaml
_format_version: "2.1"
_transform: true

consumers:
  - username: anon
    keyauth_credentials:
      - key: ${ANON_KEY}
  - username: service_role
    keyauth_credentials:
      - key: ${SERVICE_ROLE_KEY}

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  - name: auth-v1
    url: http://auth:9999/
    routes:
      - name: auth-v1-route
        strip_path: true
        paths:
          - /auth/v1/
    plugins:
      - name: cors

  - name: rest-v1
    url: http://rest:3000/
    routes:
      - name: rest-v1-route
        strip_path: true
        paths:
          - /rest/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: realtime-v1
    url: http://realtime:4000/socket/
    routes:
      - name: realtime-v1-route
        strip_path: true
        paths:
          - /realtime/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: storage-v1
    url: http://storage:5000/
    routes:
      - name: storage-v1-route
        strip_path: true
        paths:
          - /storage/v1/
    plugins:
      - name: cors

  - name: meta
    url: http://meta:8080/
    routes:
      - name: meta-route
        strip_path: true
        paths:
          - /pg/
    plugins:
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
```

- [ ] **Step 3 : Vérifier la syntaxe YAML**

Run :
```bash
python3 -c "import yaml; yaml.safe_load(open('.claude/skills/devcontainer/templates/supabase/kong.yml'))" && echo "YAML OK"
```
Expected: `YAML OK`

Si `python3` indisponible, fallback :
```bash
docker run --rm -v "$PWD/.claude/skills/devcontainer/templates/supabase/kong.yml:/k.yml" mikefarah/yq:4 e '.' /k.yml > /dev/null && echo "YAML OK"
```

- [ ] **Step 4 : Commit**

```bash
git add .claude/skills/devcontainer/templates/supabase/kong.yml
git commit -m "feat(devcontainer): add Supabase Kong gateway template"
```

---

## Task 3 : Créer le template `.env`

**Files:**
- Create: `.claude/skills/devcontainer/templates/supabase/env.example`

- [ ] **Step 1 : Récupérer JWT_SECRET et clés ANON/SERVICE_ROLE par défaut**

Référence : `supabase/supabase/docker/.env.example`. Les valeurs **dev-only** standardisées de Supabase local :

- `JWT_SECRET=super-secret-jwt-token-with-at-least-32-characters-long`
- `ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE2NDE3NjkyMDAsImV4cCI6MTc5OTUzNTYwMH0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE`
- `SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UtZGVtbyIsImlhdCI6MTY0MTc2OTIwMCwiZXhwIjoxNzk5NTM1NjAwfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q`

(Ce sont les clés démo officielles publiées par Supabase pour le dev local — déjà publiques, pas un secret à protéger.)

- [ ] **Step 2 : Écrire le template**

Contenu de `.claude/skills/devcontainer/templates/supabase/env.example` :

```bash
# =============================================================================
# Supabase — variables locales pour dev container
# =============================================================================
# Valeurs sandboxées pour le développement local UNIQUEMENT.
# NE JAMAIS réutiliser ces clés en production.
# =============================================================================

# Postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
POSTGRES_PORT=5432

# JWT (signature des clés ANON / SERVICE_ROLE ci-dessous)
JWT_SECRET=super-secret-jwt-token-with-at-least-32-characters-long
JWT_EXPIRY=3600

# Clés API publiques (dérivées de JWT_SECRET, valeurs démo Supabase)
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE2NDE3NjkyMDAsImV4cCI6MTc5OTUzNTYwMH0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UtZGVtbyIsImlhdCI6MTY0MTc2OTIwMCwiZXhwIjoxNzk5NTM1NjAwfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q

# URLs (vues depuis l'hôte)
SITE_URL=http://localhost:3000
API_EXTERNAL_URL=http://localhost:54321
SUPABASE_PUBLIC_URL=http://localhost:54321

# URLs (vues depuis le réseau compose interne)
GOTRUE_API_HOST=0.0.0.0
GOTRUE_API_PORT=9999
GOTRUE_DB_DRIVER=postgres
GOTRUE_DB_DATABASE_URL=postgres://supabase_auth_admin:${POSTGRES_PASSWORD}@db:5432/postgres

# Storage
STORAGE_BACKEND=file
FILE_SIZE_LIMIT=52428800

# Studio
STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project
```

- [ ] **Step 3 : Vérifier que le fichier parse comme un .env valide**

Run :
```bash
grep -E '^[A-Z_]+=' .claude/skills/devcontainer/templates/supabase/env.example | wc -l
```
Expected: nombre > 10 (plusieurs lignes de variables).

- [ ] **Step 4 : Commit**

```bash
git add .claude/skills/devcontainer/templates/supabase/env.example
git commit -m "feat(devcontainer): add Supabase .env template with dev-only keys"
```

---

## Task 4 : Créer les templates de scaffolding

**Files:**
- Create: `.claude/skills/devcontainer/templates/supabase/scaffolding/config.toml`
- Create: `.claude/skills/devcontainer/templates/supabase/scaffolding/migrations/.gitkeep`
- Create: `.claude/skills/devcontainer/templates/supabase/scaffolding/seed.sql`

- [ ] **Step 1 : Créer la structure de dossiers**

```bash
mkdir -p .claude/skills/devcontainer/templates/supabase/scaffolding/migrations
```

- [ ] **Step 2 : Écrire `config.toml`**

Contenu minimal aligné sur le format Supabase CLI (clés essentielles uniquement, pour rester compatible avec `supabase` CLI si l'utilisateur l'installe plus tard hors-container) :

```toml
# Configuration Supabase locale (générée par le skill devcontainer).
# Compatible avec la CLI Supabase si l'utilisateur l'installe hors-container.

project_id = "local"

[api]
enabled = true
port = 54321
schemas = ["public", "storage", "graphql_public"]
extra_search_path = ["public", "extensions"]
max_rows = 1000

[db]
port = 54322
shadow_port = 54320
major_version = 15

[studio]
enabled = true
port = 54323

[auth]
enabled = true
site_url = "http://localhost:3000"
additional_redirect_urls = ["https://localhost:3000"]
jwt_expiry = 3600
enable_signup = true

[storage]
enabled = true
file_size_limit = "50MiB"

[realtime]
enabled = true
```

- [ ] **Step 3 : Créer `migrations/.gitkeep`**

```bash
touch .claude/skills/devcontainer/templates/supabase/scaffolding/migrations/.gitkeep
```

- [ ] **Step 4 : Écrire `seed.sql`**

Contenu (vide, juste un commentaire d'amorçage) :

```sql
-- Données de seed pour le développement local.
-- Exécuté après les migrations sur `db` au démarrage.
-- Exemple :
--   insert into public.profiles (id, name) values ('00000000-0000-0000-0000-000000000001', 'demo');
```

- [ ] **Step 5 : Vérifier la création des trois fichiers**

```bash
ls -la .claude/skills/devcontainer/templates/supabase/scaffolding/ \
       .claude/skills/devcontainer/templates/supabase/scaffolding/migrations/
```
Expected : `config.toml`, `seed.sql`, `migrations/.gitkeep` présents.

- [ ] **Step 6 : Vérifier la syntaxe TOML**

Run :
```bash
python3 -c "import tomllib; tomllib.load(open('.claude/skills/devcontainer/templates/supabase/scaffolding/config.toml','rb'))" && echo "TOML OK"
```
Expected: `TOML OK`

Si Python < 3.11, fallback : copier le fichier dans un projet Supabase et lancer `supabase status`. Si ni l'un ni l'autre, vérification visuelle suffisante.

- [ ] **Step 7 : Commit**

```bash
git add .claude/skills/devcontainer/templates/supabase/scaffolding/
git commit -m "feat(devcontainer): add Supabase scaffolding templates"
```

---

## Task 5 : Étendre `repo-analyzer/SKILL.md` avec la détection Supabase

**Files:**
- Modify: `.claude/skills/repo-analyzer/SKILL.md` (ajouter section "7" + format de rapport)

- [ ] **Step 1 : Lire la fin actuelle du fichier pour repérer les points d'insertion**

Lire `.claude/skills/repo-analyzer/SKILL.md`. La section "## Format du rapport" est à la fin. Insérer une nouvelle section `### 7. Détection Supabase` juste **avant** la section "## Format du rapport" (donc après la section 6 "Détection des outils de dev").

- [ ] **Step 2 : Insérer la nouvelle section "7. Détection Supabase"**

Insérer ce contenu juste avant `## Format du rapport` :

````markdown
### 7. Détection Supabase

Vérifier si le repo utilise Supabase et déterminer le **profil** requis (`minimal` ou `full`).

#### Signaux "Supabase utilisé" (déclenche `detected: true`)

- `package.json` → présence d'une de ces dépendances :
  - `@supabase/supabase-js`
  - `@supabase/ssr`
  - `@supabase/auth-helpers-*`
  - `@supabase/realtime-js`
- `requirements.txt` ou `pyproject.toml` → `supabase` ou `supabase-py`
- Présence d'un dossier `supabase/` à la racine du repo
- `.env.example` / `.env.sample` contient au moins une de :
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `NEXT_PUBLIC_SUPABASE_*`
- Code source : `import { createClient } from '@supabase/...'` (rg/grep sur `*.ts`, `*.tsx`, `*.js`, `*.py`)

Au moins un signal positif → `detected: true`.

#### Signaux "profil complet" (sinon → `minimal`)

Si **au moins un** des signaux ci-dessous est présent, le profil est `full` :

- **Auth** : `supabase.auth.*`, dépendance `@supabase/auth-helpers-*`, dépendance `@supabase/ssr`
- **Realtime** : import de `@supabase/realtime-js`, appels `.channel()` / `.subscribe()`
- **Storage** : `supabase.storage.*`, références à `.from('<bucket>')` côté storage
- **Edge Functions** : présence du dossier `supabase/functions/`

Sinon → `minimal` (Postgres seul avec extensions).

#### Format de sortie

Ajouter au rapport :

```
**Supabase** : détecté (profil: full)
Signaux :
  - @supabase/ssr (package.json)
  - supabase.auth.signIn() (src/lib/auth.ts)
  - supabase.storage.from() (src/lib/upload.ts)
```

Si non détecté :

```
**Supabase** : non détecté
```
````

- [ ] **Step 3 : Étendre la section "## Format du rapport"**

Dans l'exemple de rapport existant, ajouter une ligne `**Supabase**` juste sous `**Services requis**` :

```
**Services requis** :
- PostgreSQL (DATABASE_URL dans .env.example, Prisma ORM détecté)
- Redis (REDIS_URL dans .env.example)

**Supabase** : non détecté

**Outils de dev** :
...
```

- [ ] **Step 4 : Vérifier que le fichier reste un Markdown valide**

Run :
```bash
grep -c '^### ' .claude/skills/repo-analyzer/SKILL.md
```
Expected: `7` (les 6 sections existantes + la nouvelle "7. Détection Supabase").

- [ ] **Step 5 : Commit**

```bash
git add .claude/skills/repo-analyzer/SKILL.md
git commit -m "feat(repo-analyzer): add Supabase detection step"
```

---

## Task 6 : Étendre `devcontainer/SKILL.md` avec la gestion Supabase

**Files:**
- Modify: `.claude/skills/devcontainer/SKILL.md`

- [ ] **Step 1 : Repérer le point d'insertion**

Lire `.claude/skills/devcontainer/SKILL.md`. La section "### 5. Services courants" contient le tableau des services. Une nouvelle section "### 5bis. Gestion spéciale : Supabase" sera insérée juste **après** cette section (avant "### 6. Validation").

- [ ] **Step 2 : Insérer la sous-section "5bis. Gestion spéciale : Supabase"**

Insérer ce contenu juste avant `### 6. Validation` :

````markdown
### 5bis. Gestion spéciale : Supabase

Si le rapport `repo-analyzer` indique `Supabase: détecté`, suivre ce flux dédié au lieu du choix générique de services.

#### Flux UX

1. **Afficher le profil détecté** à l'utilisateur, avec les signaux :

   ```
   Supabase détecté (profil: full)
   Signaux :
     - @supabase/ssr (package.json)
     - supabase.auth.signIn() (src/lib/auth.ts)
   ```

2. **Demander confirmation** : `Confirmer ce profil ? [full / minimal / annuler]`

   L'utilisateur peut override (utile pour faux positifs ou choix volontairement plus léger).

3. **Vérifier le dossier `supabase/`** à la racine du repo :
   - S'il existe → l'utiliser tel quel.
   - S'il n'existe pas → demander : `Aucun dossier supabase/ trouvé. Scaffolder un squelette minimal (config.toml, migrations/, seed.sql) ? [o/n]`

4. **Générer les fichiers** :
   - `.devcontainer/devcontainer.json` (mode `dockerComposeFile`)
   - `.devcontainer/docker-compose.yml` (app + services Supabase selon le profil)
   - `.devcontainer/Dockerfile` (si nécessaire pour l'app)
   - `.devcontainer/.env` (copie de `templates/supabase/env.example`)
   - `.devcontainer/.env.example` (versionné, mêmes clés sans valeurs sensibles)
   - `.devcontainer/supabase/kong.yml` (copie de `templates/supabase/kong.yml`, **profil full uniquement**)
   - `supabase/{config.toml, migrations/.gitkeep, seed.sql}` (**si scaffolding accepté**)

5. **Mettre à jour le `CLAUDE.md` racine** : registre des ports + note `Supabase: profil <minimal|full>` dans la ligne du repo.

#### Détails techniques

- **Profils compose** : voir `references/services/supabase.md` (snippets prêts à copier).
- **Conventions de ports** :
  - 54321 (Kong), 54322 (Postgres), 54323 (Studio).
  - Si plusieurs repos Supabase coexistent : +10 par repo additionnel (54331/32/33, …).
- **Sécurité** :
  - Aucun socket Docker monté (`/var/run/docker.sock` interdit).
  - Pas de feature `docker-in-docker`.
  - `.env` ajouté au `.gitignore`, `.env.example` versionné.
- **Persistance** : volume nommé `<repo>-db-data` pour Postgres.

#### Anti-patterns spécifiques Supabase

- **Ne pas embarquer la CLI Supabase** dans le dev container — elle nécessiterait Docker socket ou DinD, ce qui défait l'isolation.
- **Ne pas utiliser le `postgres` officiel** — utiliser `supabase/postgres` qui embarque les extensions requises (`pgcrypto`, `pgjwt`, `pg_graphql`).
- **Ne jamais committer `.env`** — uniquement `.env.example`.
- **Ne pas figer les clés JWT en prod** — les clés démo publiées par Supabase sont **dev-only**.
````

- [ ] **Step 3 : Mettre à jour la section "### 5. Services courants"**

Ajouter une ligne dans le tableau des services courants pour pointer vers le flux dédié :

```markdown
| Supabase (stack) | voir `references/services/supabase.md` | 54321, 54322, 54323 |
```

À insérer en bas du tableau existant.

- [ ] **Step 4 : Vérifier la cohérence du fichier**

Run :
```bash
grep -E '^### ' .claude/skills/devcontainer/SKILL.md
```
Expected : voir les sections 1, 2, 3, 4, 5, **5bis**, 6, 7 dans l'ordre.

- [ ] **Step 5 : Vérifier que la référence Supabase est mentionnée**

Run :
```bash
grep -c 'references/services/supabase.md' .claude/skills/devcontainer/SKILL.md
```
Expected : `>= 2` (mention dans la section 5bis ET dans le tableau des services).

- [ ] **Step 6 : Commit**

```bash
git add .claude/skills/devcontainer/SKILL.md
git commit -m "feat(devcontainer): add Supabase services handling section"
```

---

## Task 7 : Mettre à jour le `CLAUDE.md` racine

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1 : Lire la structure actuelle**

Lire `CLAUDE.md`. Repérer la section "## Conventions" (qui contient déjà les sous-sections "Dev Containers", "Nommage", "Ports", "Extensions VS Code"). Une nouvelle sous-section "### Supabase" sera ajoutée à la fin de "## Conventions".

- [ ] **Step 2 : Ajouter la sous-section "### Supabase"**

Insérer juste avant "## Registre des ports" :

```markdown
### Supabase

Quand un repo utilise Supabase, les skills `repo-analyzer` et `devcontainer` détectent automatiquement le profil requis (`minimal` ou `full`) et génèrent un dev container intégrant les services Supabase comme **services frères** sur le réseau compose (jamais via la CLI Supabase à l'intérieur du container, jamais via le socket Docker hôte, jamais en Docker-in-Docker).

- **Référence détaillée** : `.claude/skills/devcontainer/references/services/supabase.md`
- **Profils** :
  - `minimal` : `supabase/postgres` seul (extensions Supabase, sans Auth/Realtime/Storage).
  - `full` : Postgres + Auth (GoTrue) + PostgREST + Realtime + Storage + Kong + Studio.
- **Convention de ports** (par repo Supabase) : 54321 (Kong), 54322 (Postgres), 54323 (Studio).
  - Si plusieurs repos Supabase coexistent, incrémenter par tranche de **+10** : repo 2 utilise 54331/32/33, repo 3 utilise 54341/42/43, etc. À documenter dans le registre ci-dessous.
```

- [ ] **Step 3 : Vérifier la structure**

Run :
```bash
grep -n '^### ' CLAUDE.md
```
Expected : voir "Dev Containers", "Nommage", "Ports", "Extensions VS Code", "Supabase" — dans cet ordre.

- [ ] **Step 4 : Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Supabase convention to root CLAUDE.md"
```

---

## Task 8 : Vérification d'intégration end-to-end

**Files:** aucun changement de code, uniquement vérification.

Cette tâche valide que les 7 précédentes produisent un ensemble cohérent. Pas de fichier à créer.

- [ ] **Step 1 : Vérifier l'arborescence finale**

Run :
```bash
find .claude/skills -type f | sort
```

Expected (au minimum) :
```
.claude/skills/devcontainer/SKILL.md
.claude/skills/devcontainer/references/base-images.md
.claude/skills/devcontainer/references/features.md
.claude/skills/devcontainer/references/services/supabase.md
.claude/skills/devcontainer/references/stacks/node.md
.claude/skills/devcontainer/references/stacks/python.md
.claude/skills/devcontainer/scripts/post-create-template.sh
.claude/skills/devcontainer/templates/supabase/env.example
.claude/skills/devcontainer/templates/supabase/kong.yml
.claude/skills/devcontainer/templates/supabase/scaffolding/config.toml
.claude/skills/devcontainer/templates/supabase/scaffolding/migrations/.gitkeep
.claude/skills/devcontainer/templates/supabase/scaffolding/seed.sql
.claude/skills/repo-analyzer/SKILL.md
```

- [ ] **Step 2 : Vérifier la cohérence des références croisées**

Run (depuis la racine du repo) :
```bash
grep -l 'references/services/supabase.md' .claude/skills/devcontainer/SKILL.md CLAUDE.md
```
Expected : les deux fichiers sont listés.

- [ ] **Step 3 : Vérifier la cohérence du flux UX décrit**

Lire dans cet ordre, et vérifier que les étapes du flux UX correspondent exactement entre les documents :

- `docs/superpowers/specs/2026-04-26-supabase-devcontainer-design.md` (section "Flux UX")
- `.claude/skills/devcontainer/SKILL.md` (section "5bis. Gestion spéciale : Supabase" → "Flux UX")

Les 5 étapes (afficher profil → confirmer → vérifier dossier `supabase/` → générer fichiers → mettre à jour `CLAUDE.md`) doivent figurer dans les deux. Si divergence, corriger le SKILL.md (la spec est la source de vérité).

- [ ] **Step 4 : Test manuel (mental walkthrough)**

Imaginer un repo fictif `repo-test/` avec :
- `package.json` contenant `"@supabase/ssr"` et `"@supabase/supabase-js"`
- Code source utilisant `supabase.auth.signIn(...)`
- Pas de dossier `supabase/`

Dérouler mentalement les skills :

1. `repo-analyzer` produit un rapport contenant `**Supabase** : détecté (profil: full)` avec les signaux listés. ✓
2. `devcontainer` lit le rapport, affiche le profil, demande confirmation. ✓
3. L'utilisateur confirme `full`. ✓
4. `devcontainer` ne trouve pas `supabase/` → demande à scaffolder. ✓
5. L'utilisateur accepte → fichiers `supabase/{config.toml, migrations/.gitkeep, seed.sql}` créés. ✓
6. `.devcontainer/{devcontainer.json, docker-compose.yml, .env, .env.example, supabase/kong.yml}` générés. ✓
7. `CLAUDE.md` racine mis à jour avec le port 54321/22/23 et la note `Supabase: profil full`. ✓

Si l'une des étapes ne fonctionne pas avec le contenu actuel des skills, identifier le fichier en cause et corriger avant le commit final.

- [ ] **Step 5 : Vérifier qu'aucun anti-pattern n'a été introduit**

Run :
```bash
grep -rn 'docker.sock\|docker-in-docker\|:latest' .claude/skills/devcontainer/templates/ \
                                                   .claude/skills/devcontainer/references/services/ \
  || echo "Aucun anti-pattern détecté"
```
Expected : `Aucun anti-pattern détecté`.

- [ ] **Step 6 : Commit final (optionnel, si corrections en Step 4)**

Si des corrections ont été apportées au Step 4 :
```bash
git add -A
git commit -m "fix(devcontainer,repo-analyzer): align Supabase flow with spec"
```

Sinon, rien à committer pour cette tâche : le travail est terminé.

---

## Self-Review Checklist (à exécuter par l'auteur du plan, fait)

- **Spec coverage** :
  - ✓ Architecture compose-frères (Tasks 1, 6)
  - ✓ Détection automatique des profils (Task 5)
  - ✓ Override utilisateur du profil (Task 6, Step 2 - flux UX)
  - ✓ Scaffolding conditionnel (Tasks 4, 6)
  - ✓ Profils minimal et full (Tasks 1, 2, 3)
  - ✓ Variables d'environnement dev-only (Task 3)
  - ✓ Convention de ports (Tasks 1, 7)
  - ✓ Validation / anti-patterns (Tasks 1, 8)
  - ✓ Mise à jour `CLAUDE.md` racine (Task 7)
  - ✓ Hors scope (Edge Functions runtime, génération migrations) : pas de tâche, conforme.

- **Placeholders** : aucun "TBD", "TODO", "implement later". Versions d'images marquées `<VERSION>` avec instruction explicite de les récupérer (Task 1, Step 2 + Task 3).

- **Type consistency** : noms de services (`db`, `kong`, `auth`, `rest`, `realtime`, `storage`, `imgproxy`, `meta`, `studio`) cohérents entre spec, référence (Task 1) et kong.yml (Task 2). Variables d'env (`POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `SITE_URL`) identiques entre référence (Task 1) et template `.env` (Task 3).
