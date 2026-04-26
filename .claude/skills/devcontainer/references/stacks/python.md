# Stack Python

## Détection

Fichiers indicateurs : `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile`,
`poetry.lock`, `uv.lock`, `tox.ini`, `manage.py` (Django), `app.py` (Flask/FastAPI).

## Image de base

```jsonc
"image": "mcr.microsoft.com/devcontainers/python:3.12-bookworm"
```

Adapter selon `python_requires` ou `[tool.poetry.dependencies.python]`.

## Configuration type

```jsonc
{
  "name": "dev-<repo>",
  "image": "mcr.microsoft.com/devcontainers/python:3.12-bookworm",
  "forwardPorts": [8000],
  "postCreateCommand": "pip install -r requirements.txt",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-azuretools.vscode-docker",
        "editorconfig.editorconfig",
        "eamodio.gitlens",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/usr/local/bin/python",
        "[python]": {
          "editor.defaultFormatter": "charliermarsh.ruff",
          "editor.formatOnSave": true
        }
      }
    }
  },
  "remoteUser": "vscode"
}
```

## Variantes

### Avec Poetry
```jsonc
"postCreateCommand": "pip install poetry && poetry install"
```

### Avec uv (recommandé pour projets modernes)
```jsonc
"features": {
  "ghcr.io/devcontainers/features/common-utils:2": {}
},
"postCreateCommand": "curl -LsSf https://astral.sh/uv/install.sh | sh && uv sync"
```

### Django
```jsonc
"forwardPorts": [8000],
"postCreateCommand": "pip install -r requirements.txt && python manage.py migrate",
"customizations": {
  "vscode": {
    "extensions": [
      "ms-python.python",
      "ms-python.vscode-pylance",
      "charliermarsh.ruff",
      "batisteo.vscode-django"
    ]
  }
}
```

### FastAPI
```jsonc
"forwardPorts": [8000],
"postCreateCommand": "pip install -r requirements.txt",
"postStartCommand": "uvicorn app.main:app --host 0.0.0.0 --reload"
```

### Data Science / ML
```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/python:3.12-bookworm",
  "forwardPorts": [8888],
  "postCreateCommand": "pip install -r requirements.txt",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-toolsai.jupyter",
        "ms-toolsai.vscode-jupyter-slideshow"
      ]
    }
  }
}
```

## Extensions recommandées

| Extension | ID | Quand |
|-----------|----|-------|
| Python | `ms-python.python` | Toujours |
| Pylance | `ms-python.vscode-pylance` | Toujours |
| Ruff | `charliermarsh.ruff` | Toujours |
| Jupyter | `ms-toolsai.jupyter` | Si notebooks |
| Django | `batisteo.vscode-django` | Si Django |
| SQLAlchemy | `omegaatt.python-sqlalchemy-stubs` | Si SQLAlchemy |
