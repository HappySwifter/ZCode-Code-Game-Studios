#!/bin/bash

# Обёртка SessionStart-хуков для ZCode.
# В Claude Code plain-text stdout хука попадал в контекст модели; ZCode такой
# вывод молча игнорирует — принимается только JSON вида {"additionalContext": ...}
# (проверено по схеме вывода хуков ZCode). Обёртка запускает целевой скрипт,
# собирает его stdout и отдаёт его как additionalContext, не меняя сам скрипт —
# так проще синхронизироваться с апстримом.
#
# Использование: zcode-wrap-context.sh <script.sh>
# stdin пробрасывается в целевой скрипт (на случай, если он его читает).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 0
TARGET="$DIR/${1:-}"
case "$TARGET" in
  *.sh) ;;
  *) exit 0 ;;
esac
[ -f "$TARGET" ] || exit 0

OUT=$(cat | bash "$TARGET" 2>/dev/null)

# Пустой вывод — не тратим python на JSON ради пустоты.
[ -n "$OUT" ] || exit 0

# python3 обязателен по требованиям шаблона (README); без него тихо уходим —
# хук advisory, fail-open.
command -v python3 >/dev/null 2>&1 || exit 0

printf '%s' "$OUT" | python3 -c 'import json,sys; sys.stdout.write(json.dumps({"additionalContext": sys.stdin.read()}))'

exit 0
