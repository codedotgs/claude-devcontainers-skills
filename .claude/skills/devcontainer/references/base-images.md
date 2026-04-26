# Images de base pour Dev Containers

## Images officielles Microsoft

| Stack | Image | Tag recommandé |
|-------|-------|-----------------|
| Node.js 22 | `mcr.microsoft.com/devcontainers/javascript-node` | `22-bookworm` |
| Node.js 20 | `mcr.microsoft.com/devcontainers/javascript-node` | `20-bookworm` |
| Python 3.12 | `mcr.microsoft.com/devcontainers/python` | `3.12-bookworm` |
| Python 3.11 | `mcr.microsoft.com/devcontainers/python` | `3.11-bookworm` |
| Go | `mcr.microsoft.com/devcontainers/go` | `1.22-bookworm` |
| Rust | `mcr.microsoft.com/devcontainers/rust` | `1-bookworm` |
| Java 21 | `mcr.microsoft.com/devcontainers/java` | `21-bookworm` |
| Java 17 | `mcr.microsoft.com/devcontainers/java` | `17-bookworm` |
| Ruby | `mcr.microsoft.com/devcontainers/ruby` | `3.3-bookworm` |
| PHP | `mcr.microsoft.com/devcontainers/php` | `8.3-bookworm` |
| .NET 8 | `mcr.microsoft.com/devcontainers/dotnet` | `8.0-bookworm` |
| C++ | `mcr.microsoft.com/devcontainers/cpp` | `1-bookworm` |
| Ubuntu (multi-stack) | `mcr.microsoft.com/devcontainers/base` | `ubuntu-22.04` |
| Alpine (léger) | `mcr.microsoft.com/devcontainers/base` | `alpine-3.19` |

## Règles de sélection

1. **Stack unique bien identifié** → image spécifique au langage.
2. **Multi-stack** (ex : Node + Python) → image `base:ubuntu` + features pour chaque runtime.
3. **Besoin de libs système spécifiques** → `Dockerfile` basé sur l'image appropriée.
4. **Projet legacy ou stack exotique** → `Dockerfile` from scratch basé sur `base:ubuntu`.
