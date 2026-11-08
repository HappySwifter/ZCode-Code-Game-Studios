#!/bin/bash

# Замена path-scoped rules Claude Code: в ZCode нет автоматической загрузки
# правил по маске пути, поэтому этот PreToolUse(Write|Edit)-хук сам находит
# правило из .zcode/rules/, чей `paths:` совпадает с редактируемым файлом, и
# подкладывает его начало в контекст модели как {"additionalContext": ...}.
#
# Правило выбирает самый длинный (самый специфичный) совпавший паттерн.
# Хук advisory и fail-open: любая ошибка — exit 0 без вывода.

INPUT=$(cat)

# Без file_path проверять нечего; выходим до запуска python.
case "$INPUT" in *'"file_path"'*) ;; *) exit 0 ;; esac

# python3 обязателен по требованиям шаблона (README); без него тихо уходим.
command -v python3 >/dev/null 2>&1 || exit 0

# Корень проекта — два уровня вверх от каталога хуков.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
[ -n "$ROOT" ] || exit 0

# Payload во временный файл: heredoc с программой занимает stdin интерпретатора,
# поэтому пайп внутрь python здесь не работает.
PAYLOAD_FILE=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$PAYLOAD_FILE"' EXIT
printf '%s' "$INPUT" > "$PAYLOAD_FILE"

python3 - "$ROOT" "$PAYLOAD_FILE" <<'PYEOF'
import json, os, re, sys

root, payload_file = sys.argv[1], sys.argv[2]

try:
    with open(payload_file, encoding="utf-8", errors="replace") as f:
        payload = json.load(f)
    path = (payload.get("tool_input") or {}).get("file_path") or ""
except Exception:
    sys.exit(0)
if not path:
    sys.exit(0)

# Путь относительно корня проекта; проверяем только файлы внутри него.
try:
    rel = os.path.relpath(os.path.abspath(path), root)
except Exception:
    sys.exit(0)
if rel.startswith(".."):
    sys.exit(0)
rel = rel.replace(os.sep, "/")

rules_dir = os.path.join(root, ".zcode", "rules")
if not os.path.isdir(rules_dir):
    sys.exit(0)

def glob_to_re(pat):
    # ** -> любой фрагмент, **/ -> ноль или больше каталогов,
    # * -> без слеша, {a,b} -> альтернатива, ? -> один символ без слеша.
    out, i, n = [], 0, len(pat)
    while i < n:
        c = pat[i]
        if c == "*":
            if pat.startswith("**/", i):
                out.append("(?:.*/)?"); i += 3
            elif pat.startswith("**", i):
                out.append(".*"); i += 2
            else:
                out.append("[^/]*"); i += 1
        elif c == "{":
            j = pat.find("}", i)
            if j < 0:
                return None
            alts = "|".join(re.escape(x) for x in pat[i+1:j].split(","))
            out.append("(?:" + alts + ")"); i = j + 1
        elif c == "?":
            out.append("[^/]"); i += 1
        else:
            out.append(re.escape(c)); i += 1
    return re.compile("^" + "".join(out) + "$")

best = None  # (специфичность = длина паттерна, имя файла, текст правила)
for fn in sorted(os.listdir(rules_dir)):
    if not fn.endswith(".md"):
        continue
    try:
        text = open(os.path.join(rules_dir, fn), encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        continue
    for pat in re.findall(r'-\s*"([^"]+)"', m.group(1)):
        rx = glob_to_re(pat)
        if rx and rx.match(rel) and (best is None or len(pat) > best[0]):
            best = (len(pat), fn, text)

if not best:
    sys.exit(0)

_, fn, text = best
body = re.sub(r"^---\n.*?\n---\n*", "", text, flags=re.S).strip()
# Компактная выжимка: правила короткие, но ограничиваем объём инъекции.
summary = body[:1500]
print(json.dumps({
    "additionalContext": (
        "Path-scoped rule for " + rel + " (full file: .zcode/rules/" + fn + "):\n" + summary
    )
}))
PYEOF

exit 0
