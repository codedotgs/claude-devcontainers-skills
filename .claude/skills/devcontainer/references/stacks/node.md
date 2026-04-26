# Stack Node.js / TypeScript

## Détection

Fichiers indicateurs : `package.json`, `yarn.lock`, `pnpm-lock.yaml`, `package-lock.json`,
`tsconfig.json`, `.nvmrc`, `.node-version`.

## Image de base

```jsonc
"image": "mcr.microsoft.com/devcontainers/javascript-node:22-bookworm"
```

Adapter la version selon `.nvmrc` ou `engines.node` dans `package.json`.

## Configuration type

```jsonc
{
  "name": "dev-<repo>",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:22-bookworm",
  "forwardPorts": [3000],
  "postCreateCommand": "npm install",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-azuretools.vscode-docker",
        "editorconfig.editorconfig",
        "eamodio.gitlens",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode"
      }
    }
  },
  "remoteUser": "node"
}
```

## Variantes

### Avec pnpm
```jsonc
"postCreateCommand": "corepack enable && pnpm install"
```

### Avec yarn
```jsonc
"postCreateCommand": "corepack enable && yarn install"
```

### Monorepo (Turborepo, Nx)
```jsonc
"postCreateCommand": "corepack enable && pnpm install",
"forwardPorts": [3000, 3001, 3002]
```

### Avec base de données

Passer à docker-compose. Voir le SKILL.md principal, section "Services courants".

## Extensions recommandées

| Extension | ID | Quand |
|-----------|----|-------|
| ESLint | `dbaeumer.vscode-eslint` | Toujours |
| Prettier | `esbenp.prettier-vscode` | Toujours |
| Tailwind CSS IntelliSense | `bradlc.vscode-tailwindcss` | Si Tailwind |
| Prisma | `Prisma.prisma` | Si Prisma ORM |
| GraphQL | `GraphQL.vscode-graphql` | Si GraphQL |
| Jest | `Orta.vscode-jest` | Si Jest |
| Vitest | `vitest.explorer` | Si Vitest |

## Utilisateur

L'image Node.js utilise `node` comme utilisateur non-root (pas `vscode`).
