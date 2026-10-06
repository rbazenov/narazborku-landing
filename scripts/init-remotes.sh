#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Восстановление доступа к репозиториям лендинга.
#
# Зачем: в рабочей среде репозитории (тест и прод) прописаны с токеном доступа,
# и этот файл настроек не сохраняется при переносе рабочей папки. Если команды
# git перестали видеть GitHub — запустите этот скрипт, он пропишет адреса заново.
#
# Запуск:  GITHUB_TOKEN=ghp_xxxx bash scripts/init-remotes.sh
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

: "${GITHUB_TOKEN:?Не задан GITHUB_TOKEN. Возьмите токен: https://github.com/settings/tokens (scope repo)}"

git config user.name "НаРазборку"
git config user.email "admin@narazborku.ru"

set_remote() {
  local name="$1" repo="$2"
  if git remote | grep -qx "$name"; then
    git remote set-url "$name" "https://${GITHUB_TOKEN}@github.com/${repo}.git"
  else
    git remote add "$name" "https://${GITHUB_TOKEN}@github.com/${repo}.git"
  fi
}

set_remote origin rbazenov/narazborku-landing-stage   # тест (основное направление отправки)
set_remote prod   rbazenov/narazborku-landing         # прод

echo "готово — адреса прописаны:"
git remote -v | sed -E 's#https://[^@]*@#https://***@#' | sed 's/^/   /'
