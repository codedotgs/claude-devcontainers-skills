#!/bin/bash
# post-create.sh — Script de post-création du dev container
# Ce script est exécuté une seule fois après la création du container.
# Adapter selon le stack du repo.

set -e

echo "🔧 Post-create setup starting..."

# ─── Installer les dépendances ────────────────────────────────
# Décommenter la ligne appropriée :

# Node.js (npm)
# npm install

# Node.js (pnpm)
# corepack enable && pnpm install

# Node.js (yarn)
# corepack enable && yarn install

# Python (pip)
# pip install -r requirements.txt

# Python (poetry)
# pip install poetry && poetry install

# Python (uv)
# uv sync

# Go
# go mod download

# Rust
# cargo build

# ─── Setup base de données ────────────────────────────────────
# Décommenter si applicable :

# Django
# python manage.py migrate
# python manage.py collectstatic --noinput

# Prisma
# npx prisma generate
# npx prisma db push

# Rails
# bundle exec rails db:setup

# ─── Autres ───────────────────────────────────────────────────
# Copier .env si nécessaire
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
  cp .env.example .env
  echo "📄 .env créé depuis .env.example"
fi

echo "✅ Post-create setup complete!"
