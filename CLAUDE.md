# Projet Multi-Repos — Dev Containers

## Contexte

Ce projet est un monorepo racine contenant plusieurs repositories indépendants.
L'objectif est de créer un **dev container** pour chaque repository afin de lancer
chaque projet en local de manière **sandboxée et reproductible**.

## Structure du projet

```
project-root/
├── CLAUDE.md                  ← ce fichier
├── .claude/
│   └── skills/
│       ├── devcontainer/      ← skill de création de dev containers
│       └── repo-analyzer/     ← skill d'analyse de repos
├── repo-alpha/
│   └── .devcontainer/
│       ├── devcontainer.json
│       └── Dockerfile
├── repo-beta/
│   └── .devcontainer/
│       ├── devcontainer.json
│       └── Dockerfile
└── ...
```

## Conventions

### Dev Containers

- Chaque repo DOIT avoir son propre dossier `.devcontainer/` à sa racine.
- Le fichier `devcontainer.json` est le point d'entrée de la configuration.
- Un `Dockerfile` dédié est créé quand l'image de base ne suffit pas.
- Un `docker-compose.yml` est ajouté seulement si le repo nécessite des services annexes (DB, cache, message broker…).

### Nommage

- Le `name` dans `devcontainer.json` suit le format : `"dev-<nom-du-repo>"`.
- Les volumes nommés suivent le format : `<nom-du-repo>-<service>-data`.

### Ports

- Chaque dev container déclare ses ports dans `forwardPorts`.
- Éviter les collisions : documenter les ports utilisés dans ce fichier.

### Extensions VS Code

- Les extensions communes à tous les repos sont listées ci-dessous.
- Les extensions spécifiques au stack d'un repo sont déclarées dans son `devcontainer.json`.

Extensions communes :

- `ms-azuretools.vscode-docker`
- `editorconfig.editorconfig`
- `eamodio.gitlens`

## Registre des ports

| Repo | Port(s) | Description |
| ---- | ------- | ----------- |
|      |         |             |

## Workflow type

1. **Analyser** le repo (stack, dépendances, services requis).
2. **Générer** le dev container adapté via le skill `devcontainer`.
3. **Tester** le build avec `devcontainer build --workspace-folder ./<repo>`.
4. **Documenter** les ports dans le registre ci-dessus.

## Commandes utiles

```bash
# Construire un dev container spécifique
devcontainer build --workspace-folder ./repo-name

# Lancer un dev container
devcontainer up --workspace-folder ./repo-name

# Lister les containers actifs
docker ps --filter "label=devcontainer"
```
