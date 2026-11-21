#!/usr/bin/env bash
# Fungsi bersama untuk skrip pengujian curl. Dipakai lewat `source`, bukan dijalankan.
BASE="${BASE_URL:-http://localhost:8080}"
PASS=0
FAIL=0
STATUS=""
BODY=""
CTYPE=""

command -v curl >/dev/null || { echo "curl tidak ditemukan"; exit 2; }
command -v jq   >/dev/null || { echo "jq tidak ditemukan (sudo apt install jq)"; exit 2; }

# req METHOD URL [JSON] -> mengisi STATUS, BODY, dan CTYPE
req() {
  local method="$1" url="$2" data="${3:-}" out rest
  if [[ -n "$data" ]]; then
    out=$(curl -s -w $'\n%{http_code}\n%{content_type}' -X "$method" \
          -H 'Content-Type: application/json' -d "$data" "$url")
  else
    out=$(curl -s -w $'\n%{http_code}\n%{content_type}' -X "$method" "$url")
  fi
  CTYPE="${out##*$'\n'}"
  rest="${out%$'\n'*}"
  STATUS="${rest##*$'\n'}"
  BODY="${rest%$'\n'*}"
}

# check "deskripsi" kode_diharapkan
check() {
  if [[ "$STATUS" == "$2" ]]; then
    echo "  [PASS] $1 -> $STATUS"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 -> diharapkan $2, didapat $STATUS"; echo "         $BODY"
    FAIL=$((FAIL + 1))
  fi
}

# check_json "deskripsi" filter_jq nilai_diharapkan
# Bila kedua nilai berupa angka, dibandingkan secara numerik (5000 == 5000.0).
check_json() {
  local actual ok=0
  local num='^-?[0-9]+([.][0-9]+)?$'
  actual=$(echo "$BODY" | jq -r "$2" 2>/dev/null)

  if [[ "$3" =~ $num && "$actual" =~ $num ]]; then
    [[ "$(jq -n --argjson a "$actual" --argjson b "$3" '$a == $b')" == "true" ]] && ok=1
  else
    [[ "$actual" == "$3" ]] && ok=1
  fi

  if [[ "$ok" -eq 1 ]]; then
    echo "  [PASS] $1 ($2 = $actual)"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 ($2 diharapkan '$3', didapat '$actual')"; FAIL=$((FAIL + 1))
  fi
}

# check_ctype "deskripsi" : galat harus bertipe application/problem+json
check_ctype() {
  if [[ "$CTYPE" == application/problem+json* ]]; then
    echo "  [PASS] $1 ($CTYPE)"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 (didapat '$CTYPE')"; FAIL=$((FAIL + 1))
  fi
}

summary() {
  echo
  echo "Ringkasan: $PASS lulus, $FAIL gagal"
  [[ "$FAIL" -eq 0 ]]
}
