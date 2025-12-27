#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Pulling schema from prod..."
cd "${PROJECT_ROOT}/supabase/prod"
supabase db pull --yes

echo "Pushing schema to stage..."
cd "${PROJECT_ROOT}/supabase/stage"
supabase db push --yes

echo "Done! Stage schema is now synced with production."
