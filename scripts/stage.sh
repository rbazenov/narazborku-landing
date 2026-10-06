#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Публикация правок в ТЕСТОВУЮ среду лендинга «НаРазборку».
#
# Прод этой командой НЕ затрагивается: изменения уходят только в тестовый
# репозиторий (narazborku-landing-stage), который отдаёт страницу по адресу
#   https://rbazenov.github.io/narazborku-landing-stage/
#
# Запуск:  bash scripts/stage.sh "что изменили"
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

STAGE_URL="https://rbazenov.github.io/narazborku-landing-stage/"
MSG="${1:-Правки лендинга}"

echo "== 1. собираю текущие правки =="
git add -A
if git diff --cached --quiet; then
  echo "   новых изменений в файлах нет — публикую то, что уже есть в ветке"
else
  git commit -q -m "$MSG"
  echo "   изменения зафиксированы: $MSG"
fi

echo "== 2. подтягиваю правки, сделанные прямо на GitHub =="
git fetch -q origin main
if ! git merge-base --is-ancestor origin/main HEAD; then
  git rebase -q origin/main || { git rebase --abort; echo "   ⚠ конфликт: правки в браузере и в файлах пересеклись, нужна ручная развязка"; exit 1; }
  echo "   правки с GitHub подтянуты"
fi

echo "== 3. отправляю в тест =="
git push -q origin HEAD:main
echo "   отправлено"

echo "== 4. жду публикацию (обычно 30–90 секунд) =="
for i in $(seq 1 24); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$STAGE_URL?t=$(date +%s)" || echo 000)
  if [ "$CODE" = "200" ]; then
    SIZE=$(curl -s --max-time 30 "$STAGE_URL?t=$(date +%s)" | wc -c | tr -d ' ')
    echo "   ✔ страница отвечает (${SIZE} байт)"
    break
  fi
  sleep 10
done

echo
echo "ТЕСТ:  $STAGE_URL"
echo "ПРОД:  https://rbazenov.github.io/narazborku-landing/   ← не изменялся"
echo
echo "Если всё верно — перенос в прод:  bash scripts/promote.sh --yes"
