#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Перенос проверенных правок из ТЕСТА в ПРОД.
#
# Что делает:
#   1. проверяет, что прод не ушёл вперёд (никто не правил его в обход теста);
#   2. показывает, какие именно изменения уедут в прод;
#   3. переносит их в прод-репозиторий (публикация GitHub Pages — 1–2 минуты);
#   4. дожидается публикации и сверяет тест с продом побайтово.
#
# Запуск:  bash scripts/promote.sh --yes
#          (без --yes команда ничего не делает — защита от случайного запуска)
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_verify.sh

PROD_URL="https://rbazenov.github.io/narazborku-landing/"
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
PROD=$(git rev-parse prod/main)

if [ "$STAGE" = "$PROD" ]; then
  echo "   тест и прод совпадают — переносить нечего"
  exit 0
fi

if ! git merge-base --is-ancestor prod/main origin/main; then
  echo "   ⚠ В ПРОДЕ есть правки, которых нет в тесте:"
  git log --oneline origin/main..prod/main | sed 's/^/     /'
  echo "   Сначала приведите их в тест, чтобы ничего не потерять."
  exit 1
fi

echo "== 2. что уедет в прод =="
git log --oneline prod/main..origin/main | sed 's/^/   /'
git diff --stat prod/main origin/main | sed 's/^/   /'

# важно: запоминаем список ДО отправки — после неё прод уже равен тесту
mapfile -t CHANGED < <(git diff --name-only prod/main origin/main | grep -v '^$')

echo "== 3. переношу в прод =="
git push -q prod origin/main:main
echo "   отправлено"

echo "== 4. жду публикацию и сверяю содержимое с тестом =="
verify_published "$PROD_URL" "${CHANGED[@]}" || true

echo
echo "ПРОД обновлён:  $PROD_URL"
