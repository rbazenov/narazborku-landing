#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Перенос проверенных правок из ТЕСТА в ПРОД.
#
# Особенность: в прод-репозитории лежит служебный файл CNAME (он сообщает
# GitHub Pages, что адрес сайта — finklass.online). Файл создаёт сам GitHub,
# в тестовом репозитории его быть не должно, иначе домен будет «перетягивать»
# тестовую копию. Поэтому перенос идёт отдельным коммитом, который сохраняет
# CNAME на месте.
#
# Запуск:  bash scripts/promote.sh --yes
#          (без --yes команда ничего не делает — защита от случайного запуска)
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_verify.sh

PROD_URL="https://finklass.online/"
STAGE_URL="https://rbazenov.github.io/narazborku-landing-stage/"

if [ "${1:-}" != "--yes" ]; then
  echo "Это перенос правок в ПРОД (боевую страницу для посетителей)."
  echo "Проверьте тестовую версию: $STAGE_URL"
  echo "Если всё верно, запустите:  bash scripts/promote.sh --yes"
  exit 1
fi

echo "== 1. сверяю тест и прод =="
git fetch -q origin main
git fetch -q prod main
STAGE=$(git rev-parse origin/main)

# содержимое прода без учёта служебного CNAME
if git diff --quiet prod/main origin/main -- . ':(exclude)CNAME'; then
  echo "   тест и прод совпадают — переносить нечего"
  exit 0
fi

# правки в проде, сделанные в обход теста (служебные коммиты и CNAME не в счёт)
UNEXPECTED=$(git log --format='%h %s' origin/main..prod/main \
  --invert-grep --grep='^sync:' -- . ':(exclude)CNAME' || true)
if [ -n "$UNEXPECTED" ]; then
  echo "   ⚠ В ПРОДЕ есть правки, которых нет в тесте:"
  echo "$UNEXPECTED" | sed 's/^/     /'
  echo "   Сначала приведите их в тест, чтобы ничего не потерять."
  exit 1
fi

echo "== 2. что уедет в прод =="
git diff --stat prod/main origin/main -- . ':(exclude)CNAME' | sed 's/^/   /'
mapfile -t CHANGED < <(git diff --name-only prod/main origin/main -- . ':(exclude)CNAME' | grep -v '^$')

echo "== 3. переношу в прод (CNAME сохраняется) =="
git checkout -q -B _promote prod/main
git rm -rq --cached .
git checkout -q origin/main -- .
git checkout -q prod/main -- CNAME
git commit -q -m "sync: прод ← тест (перенос проверенных правок)"
git push -q prod _promote:main
git checkout -q main
git branch -qD _promote
echo "   отправлено"

echo "== 4. жду публикацию и сверяю содержимое с тестом =="
verify_published "$PROD_URL" "${CHANGED[@]}" || true

echo
echo "ПРОД обновлён:  $PROD_URL"
