# Dev Container Features

Les features sont des modules installables dans n'importe quel dev container.
Documentation complète : https://containers.dev/features

## Features les plus utiles

### Outils généraux

```jsonc
"features": {
  // Docker-in-Docker (pour builds dans le container)
  "ghcr.io/devcontainers/features/docker-in-docker:2": {},

  // Docker-outside-of-Docker (utilise le daemon hôte)
  "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {},

  // Git (déjà inclus dans la plupart des images, utile pour base minimale)
  "ghcr.io/devcontainers/features/git:1": {},

  // GitHub CLI
  "ghcr.io/devcontainers/features/github-cli:1": {},

  // Outils communs (curl, wget, jq, etc.)
  "ghcr.io/devcontainers/features/common-utils:2": {}
}
```

### Runtimes additionnels

```jsonc
"features": {
  // Ajouter Node.js à un container non-Node
  "ghcr.io/devcontainers/features/node:1": {
    "version": "22"
  },

  // Ajouter Python à un container non-Python
  "ghcr.io/devcontainers/features/python:1": {
    "version": "3.12"
  },

  // Ajouter Go
  "ghcr.io/devcontainers/features/go:1": {
    "version": "1.22"
  },

  // Ajouter Rust
  "ghcr.io/devcontainers/features/rust:1": {},

  // Ajouter Java
  "ghcr.io/devcontainers/features/java:1": {
    "version": "21",
    "installGradle": true,
    "installMaven": true
  }
}
```

### Bases de données (clients uniquement)

```jsonc
"features": {
  // PostgreSQL client
  "ghcr.io/robbert229/devcontainer-features/postgresql-client:1": {},

  // MySQL client
  "ghcr.io/devcontainers-community/features/mysql-client:1": {}
}
```

### Outils cloud & infra

```jsonc
"features": {
  // AWS CLI
  "ghcr.io/devcontainers/features/aws-cli:1": {},

  // Google Cloud CLI
  "ghcr.io/devcontainers-community/features/gcloud-cli:1": {},

  // Azure CLI
  "ghcr.io/devcontainers/features/azure-cli:1": {},

  // Terraform
  "ghcr.io/devcontainers/features/terraform:1": {},

  // kubectl
  "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {}
}
```

## Quand utiliser features vs Dockerfile

| Situation | Recommandation |
|-----------|----------------|
| Ajouter un runtime standard | Feature |
| Installer un outil CLI courant | Feature |
| Besoin de libs système (libxml, ffmpeg…) | Dockerfile |
| Configuration complexe multi-étapes | Dockerfile |
| Combiner 3+ runtimes | Dockerfile (plus fiable) |
