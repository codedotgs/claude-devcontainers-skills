---
name: repo-analyzer
description: >
  Analyse un repository pour détecter son stack technique, ses dépendances, et ses services requis.
  Utilise ce skill quand l'utilisateur demande d'analyser, scanner, auditer, ou inspecter un repo
  avant de créer un dev container. Se déclenche aussi pour "quel est le stack de ce projet",
  "qu'est-ce que ce repo utilise", "quelles sont les dépendances", "fais un état des lieux",
  ou toute demande d'inventaire technique d'un dossier projet. Déclenche ce skill en amont du
  skill devcontainer pour obtenir les informations nécessaires à la génération.
---

# Skill : Repository Analyzer

## Objectif

Scanner un repository pour produire un rapport structuré de son stack technique.
Ce rapport sert ensuite d'input au skill `devcontainer`.

## Étapes d'analyse

### 1. Scan rapide de la racine

```bash
ls -la <repo-path>/
```

### 2. Détection du langage principal

Chercher dans cet ordre de priorité :

| Fichier | Langage / Framework |
|---------|---------------------|
| `package.json` | Node.js |
| `tsconfig.json` | TypeScript |
| `requirements.txt`, `pyproject.toml`, `Pipfile` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pom.xml` | Java (Maven) |
| `build.gradle`, `build.gradle.kts` | Java/Kotlin (Gradle) |
| `Gemfile` | Ruby |
| `composer.json` | PHP |
| `*.csproj`, `*.sln` | .NET/C# |
| `CMakeLists.txt`, `Makefile` | C/C++ |
| `mix.exs` | Elixir |
| `pubspec.yaml` | Dart/Flutter |

### 3. Détection du framework

Si Node.js, inspecter `package.json` → `dependencies` pour :
- `next` → Next.js
- `react` → React (CRA ou Vite)
- `vue` → Vue.js
- `@angular/core` → Angular
- `express` → Express
- `fastify` → Fastify
- `@nestjs/core` → NestJS

Si Python, inspecter pour :
- `django` → Django
- `flask` → Flask
- `fastapi` → FastAPI
- `jupyter` → Jupyter/Data Science

### 4. Détection des services requis

Scanner :
- `docker-compose*.yml` → services existants déclarés
- `.env.example`, `.env.sample` → variables de DB, Redis, etc.
- Code source pour imports/connexions DB :
  - `prisma/`, `drizzle/` → ORM → besoin DB
  - `DATABASE_URL` → PostgreSQL/MySQL
  - `REDIS_URL` → Redis
  - `MONGO_URI` → MongoDB
  - `AMQP_URL`, `RABBITMQ_URL` → RabbitMQ
  - `S3_`, `AWS_` → stockage S3/MinIO
  - `ELASTICSEARCH_` → Elasticsearch

### 5. Détection de la version du runtime

- Node.js : `.nvmrc`, `.node-version`, `engines.node` dans `package.json`
- Python : `python_requires` dans `pyproject.toml`, `runtime.txt`
- Go : `go` directive dans `go.mod`
- Java : `java.version` dans `pom.xml`, `sourceCompatibility` dans `build.gradle`
- Ruby : `.ruby-version`, `ruby` dans `Gemfile`

### 6. Détection des outils de dev

- Linter : `.eslintrc*`, `ruff.toml`, `.golangci.yml`, `.rubocop.yml`
- Formatter : `.prettierrc*`, `ruff`, `gofmt`
- Tests : `jest.config*`, `vitest.config*`, `pytest.ini`, `conftest.py`
- CI/CD : `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`

## Format du rapport

Produire un résumé structuré comme suit :

```
## Rapport d'analyse : <nom-du-repo>

**Langage principal** : TypeScript
**Framework** : Next.js 14
**Version runtime** : Node.js 20 (via .nvmrc)
**Gestionnaire de paquets** : pnpm (pnpm-lock.yaml détecté)

**Services requis** :
- PostgreSQL (DATABASE_URL dans .env.example, Prisma ORM détecté)
- Redis (REDIS_URL dans .env.example)

**Outils de dev** :
- ESLint + Prettier
- Vitest
- GitHub Actions CI

**Ports probables** : 3000 (Next.js default)

**Recommandation** : docker-compose (services multiples détectés)
```

Ce rapport est ensuite passé au skill `devcontainer` pour la génération.
