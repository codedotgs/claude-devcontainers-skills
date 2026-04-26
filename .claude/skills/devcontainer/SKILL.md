---
name: devcontainer
description: >
  Génère des configurations dev container complètes (.devcontainer/) pour n'importe quel
  repository. Utilise ce skill dès que l'utilisateur mentionne "dev container", "devcontainer",
  ".devcontainer", "conteneur de développement", "sandbox", "environnement isolé",
  "dockeriser pour le dev", ou demande à lancer un projet en local de manière isolée.
  Utilise-le aussi quand l'utilisateur veut ajouter, modifier ou debugger un devcontainer.json,
  un Dockerfile de dev, ou un docker-compose de dev. Se déclenche même si l'utilisateur dit
  simplement "configure ce repo" ou "rends ce projet portable".
---

# Skill : Dev Container Generator

## Objectif

Créer une configuration `.devcontainer/` complète et fonctionnelle pour un repository donné,
en analysant son stack technique et ses dépendances.

## Étapes

### 1. Analyse du repository

Avant de générer quoi que ce soit, analyser le repo cible :

```bash
# Lister les fichiers clés à la racine
ls -la <repo-path>/

# Détecter le stack
cat <repo-path>/package.json 2>/dev/null      # Node.js
cat <repo-path>/requirements.txt 2>/dev/null   # Python pip
cat <repo-path>/pyproject.toml 2>/dev/null     # Python moderne
cat <repo-path>/Pipfile 2>/dev/null            # Python Pipenv
cat <repo-path>/go.mod 2>/dev/null             # Go
cat <repo-path>/Cargo.toml 2>/dev/null         # Rust
cat <repo-path>/pom.xml 2>/dev/null            # Java Maven
cat <repo-path>/build.gradle* 2>/dev/null      # Java/Kotlin Gradle
cat <repo-path>/Gemfile 2>/dev/null            # Ruby
cat <repo-path>/composer.json 2>/dev/null      # PHP
cat <repo-path>/docker-compose*.yml 2>/dev/null # Services existants
cat <repo-path>/.env.example 2>/dev/null       # Variables d'environnement
```

### 2. Choisir l'image de base

Consulter `references/base-images.md` pour choisir l'image Microsoft appropriée.

Règles :
- Privilégier les images `mcr.microsoft.com/devcontainers/` officielles.
- Utiliser un tag versionné (jamais `latest`).
- Si le projet a besoin de plusieurs runtimes, partir de `mcr.microsoft.com/devcontainers/base:ubuntu` et installer manuellement.

### 3. Générer les fichiers

#### Fichiers à créer

| Fichier | Obligatoire | Quand |
|---------|------------|-------|
| `devcontainer.json` | Toujours | Toujours |
| `Dockerfile` | Si customisation | Image de base insuffisante |
| `docker-compose.yml` | Si services | DB, Redis, RabbitMQ, etc. |
| `.env` | Si variables | Secrets, config locale |
| `post-create.sh` | Si setup complexe | Migrations, seeds, builds |

#### Structure du `devcontainer.json`

```jsonc
{
  // Nom du container
  "name": "dev-<nom-du-repo>",

  // Image OU build OU dockerComposeFile (un seul)
  "image": "mcr.microsoft.com/devcontainers/...",
  // OU
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  },
  // OU
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",

  // Features (outils additionnels)
  "features": {
    // Voir references/features.md
  },

  // Ports exposés
  "forwardPorts": [],

  // Commandes de cycle de vie
  "postCreateCommand": "",    // après création (install deps)
  "postStartCommand": "",     // après chaque démarrage
  "postAttachCommand": "",    // après chaque attach

  // Extensions VS Code
  "customizations": {
    "vscode": {
      "extensions": [],
      "settings": {}
    }
  },

  // Utilisateur non-root
  "remoteUser": "vscode",

  // Mounts additionnels
  "mounts": [],

  // Variables d'environnement
  "containerEnv": {}
}
```

### 4. Patterns par stack

Consulter le fichier de référence approprié dans `references/` :

- **Node.js / TypeScript** → `references/stacks/node.md`
- **Python** → `references/stacks/python.md`
- **Go** → `references/stacks/go.md`
- **Rust** → `references/stacks/rust.md`
- **Java / Kotlin** → `references/stacks/java.md`
- **Ruby** → `references/stacks/ruby.md`
- **PHP** → `references/stacks/php.md`
- **Multi-stack** → `references/stacks/multi.md`

### 5. Services courants

Si le repo nécessite des services (détectés via docker-compose existant, .env, ou code source) :

| Service | Image recommandée | Port par défaut |
|---------|--------------------|-----------------|
| PostgreSQL | `postgres:16-alpine` | 5432 |
| MySQL | `mysql:8.0` | 3306 |
| Redis | `redis:7-alpine` | 6379 |
| MongoDB | `mongo:7` | 27017 |
| RabbitMQ | `rabbitmq:3-management-alpine` | 5672, 15672 |
| Elasticsearch | `elasticsearch:8.x` | 9200 |
| MinIO (S3) | `minio/minio` | 9000, 9001 |
| MailHog | `mailhog/mailhog` | 1025, 8025 |

Quand des services sont nécessaires, utiliser `docker-compose.yml` plutôt que des features.

### 6. Validation

Après génération, vérifier :

- [ ] `devcontainer.json` est du JSON valide (ou JSONC avec commentaires).
- [ ] Les ports déclarés ne collisionnent pas avec d'autres repos (vérifier le registre dans CLAUDE.md).
- [ ] Le `postCreateCommand` installe bien toutes les dépendances.
- [ ] L'utilisateur est `vscode` (non root) sauf raison explicite.
- [ ] Les volumes de données persistent entre les rebuilds.

### 7. Mettre à jour le registre

Après création, mettre à jour le tableau des ports dans le `CLAUDE.md` racine.

## Anti-patterns à éviter

- **Ne jamais utiliser `latest`** pour les tags d'images.
- **Ne pas mélanger** `image` et `build` et `dockerComposeFile` dans le même devcontainer.json.
- **Ne pas hardcoder de secrets** dans devcontainer.json → utiliser `.env` + `.gitignore`.
- **Ne pas oublier `.devcontainer/` dans le .gitignore** des artefacts générés (mais le dossier lui-même doit être versionné).
- **Ne pas ignorer les volumes** pour les données de services (DB, etc.).
