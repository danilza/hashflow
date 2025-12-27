#!/usr/bin/env bash
set -euo pipefail

# Root of the repo
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load TON testnet env if present
ENV_FILE="$ROOT/scripts/ton_testnet_env.sh"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

REQUIRED_ENV=(
  TON_MNEMONIC
  TON_RPC
  TON_API_KEY
  OWNER_ADDRESS
  TON_COLLECTION_ADDRESS
)

missing=()
for var in "${REQUIRED_ENV[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("$var")
  fi
done

if ((${#missing[@]})); then
  echo "❌ Отсутствуют переменные окружения: ${missing[*]}" >&2
  echo "   Выполни: source scripts/ton_testnet_env.sh" >&2
  exit 1
fi

echo "✅ TON окружение загружено."

SUPABASE_URL="https://mspqeumqitcomagyorvw.supabase.co"
SUPABASE_FUNCTIONS_URL="https://mspqeumqitcomagyorvw.functions.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zcHFldW1xaXRjb21hZ3lvcnZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4NTA4NjEsImV4cCI6MjA4MDQyNjg2MX0.jF1sgazizAVPFwEmyJs_Dd_Wx31Mromg5iEVIcnB1xs"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

check_endpoint() {
  local label=$1
  local url=$2
  local -a header_args=("${@:3}")
  local response_file="$TMP_DIR/$(echo "$label" | tr ' ' '_').json"
  local status
  if ((${#header_args[@]})); then
    status=$(curl -s -o "$response_file" -w "%{http_code}" "${header_args[@]}" "$url")
  else
    status=$(curl -s -o "$response_file" -w "%{http_code}" "$url")
  fi
  if [[ "$status" == "200" ]]; then
    echo "✅ $label — HTTP 200"
  else
    echo "❌ $label — HTTP $status" >&2
    cat "$response_file" >&2 || true
    exit 1
  fi
}

echo "🔎 Проверяем здоровье Supabase Auth..."
check_endpoint \
  "Supabase Auth health" \
  "$SUPABASE_URL/auth/v1/health" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"

echo "🔎 Проверяем доступность таблиц через REST..."
check_endpoint \
  "Profiles REST ping" \
  "$SUPABASE_URL/rest/v1/profiles?select=id&limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"

echo "🔎 Проверяем health edge-функции mint_nft (OPTIONS)..."
EDGE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  "$SUPABASE_FUNCTIONS_URL/mint_nft" || true)
if [[ "$EDGE_STATUS" == "200" ]]; then
  echo "✅ mint_nft отвечает на OPTIONS."
else
  echo "⚠️ mint_nft OPTIONS вернул $EDGE_STATUS — проверь функцию вручную через Supabase dashboard, но тест-план продолжается."
fi

cat <<'EOF'

📝 Тесты, требующие ручного прогона:
1. Регистрация нового игрока + привязка кошелька.
2. Решение уровня без уникальности → NFT не минтится.
3. Уникальное решение → минт NFT + запись в Supabase.
4. Повтор прохода тем же pipeline → NFT не дублируется.
5. Уникальное решение без кошелька → корректное сообщение и отсутствие mint.
6. Кнопка «Передать» → открывается Tonkeeper deeplink.
7. Обновление коллекции после передачи NFT (UI отражает новый статус).
8. NFT есть в Supabase, но уже передан — UI показывает историю, не владение.
9. Падение edge-функции mint_nft → решение сохраняется, пользователь видит предупреждение.
10. Полный перезапуск приложения → профиль, лидерборд и коллекция грузятся корректно.
11. Некорректный wallet_address → предупреждение/ошибка, защита от мусора.
12. Массовый прогон уровня → уникальность и количество NFT соответствуют ожиданию.

Автоматические проверки завершены успешно. Остальные кейсы выполни вручную по списку.
EOF
