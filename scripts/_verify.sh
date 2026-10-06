#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Проверка публикации: сравнивает файлы на сайте с файлами в рабочей папке.
# Подключается в stage.sh и promote.sh:
#   source scripts/_verify.sh
#   verify_published <адрес сайта> <файл> [<файл> ...]
#
# Важно: просто «страница открывается» ничего не доказывает — GitHub Pages
# ещё какое-то время отдаёт предыдущую сборку. Поэтому сверяем содержимое
# каждого изменившегося файла побайтово.
# ---------------------------------------------------------------------------
verify_published() {
  local base="$1"; shift
  local files=("$@")
  if [ ${#files[@]} -eq 0 ]; then
    echo "   сверять нечего (служебные файлы)"
    return 0
  fi

  for attempt in $(seq 1 24); do
    local pending=0
    for f in "${files[@]}"; do
      [ -f "$f" ] || continue                      # удалённые файлы пропускаем
      if ! curl -s --max-time 30 "$base/$f?t=$(date +%s)$attempt" -o /tmp/_verify.$$ 2>/dev/null; then
        pending=$((pending + 1)); continue
      fi
      cmp -s "$f" /tmp/_verify.$$ || pending=$((pending + 1))
    done
    rm -f /tmp/_verify.$$

    if [ "$pending" -eq 0 ]; then
      echo "   ✔ опубликовано: файлов сверено — ${#files[@]}"
      return 0
    fi
    echo "   ждём сборку… осталось файлов: $pending (попытка $attempt)"
    sleep 10
  done

  echo "   ⚠ за 4 минуты сайт не отдал новые файлы. Проверьте через минуту вручную"
  echo "     и загляните в раздел Actions репозитория — там видно статус сборки."
  return 1
}
