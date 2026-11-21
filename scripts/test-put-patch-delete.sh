#!/usr/bin/env bash
# Pengujian manual PUT, PATCH, dan DELETE dengan curl + jq (API harus sudah berjalan).
#   bash scripts/test-put-patch-delete.sh
#   BASE_URL=http://host:port bash scripts/test-put-patch-delete.sh
set -uo pipefail

BASE="${BASE_URL:-http://localhost:8080}/api/v1"
PASS=0
FAIL=0
STATUS=""
BODY=""

command -v curl >/dev/null || { echo "curl tidak ditemukan"; exit 2; }
command -v jq   >/dev/null || { echo "jq tidak ditemukan (sudo apt install jq)"; exit 2; }

req() {
  local method="$1" url="$2" data="${3:-}" out
  if [[ -n "$data" ]]; then
    out=$(curl -s -w $'\n%{http_code}' -X "$method" \
          -H 'Content-Type: application/json' -d "$data" "$url")
  else
    out=$(curl -s -w $'\n%{http_code}' -X "$method" "$url")
  fi
  STATUS="${out##*$'\n'}"
  BODY="${out%$'\n'*}"
}

check() {
  if [[ "$STATUS" == "$2" ]]; then
    echo "  [PASS] $1 -> $STATUS"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 -> diharapkan $2, didapat $STATUS"; echo "         $BODY"
    FAIL=$((FAIL + 1))
  fi
}

check_json() {
  local actual ok=0
  actual=$(echo "$BODY" | jq -r "$2" 2>/dev/null)
  local num='^-?[0-9]+([.][0-9]+)?$'

  if [[ "$3" =~ $num && "$actual" =~ $num ]]; then
    # kedua nilai angka: bandingkan secara numerik (5000 == 5000.0)
    [[ "$(jq -n --argjson a "$actual" --argjson b "$3" '$a == $b')" == "true" ]] && ok=1
  else
    # selain angka: bandingkan sebagai teks
    [[ "$actual" == "$3" ]] && ok=1
  fi

  if [[ "$ok" -eq 1 ]]; then
    echo "  [PASS] $1 ($2 = $actual)"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 ($2 diharapkan '$3', didapat '$actual')"; FAIL=$((FAIL + 1))
  fi
}

echo "== Persiapan: buat produk dengan stok 10 =="
req POST "$BASE/products" '{"name":"Mie Instan Goreng","category":"Makanan","price":3500}'
check "Buat produk" 201
PID=$(echo "$BODY" | jq -r '.id')
req POST "$BASE/stock-movements" "{\"productId\":$PID,\"type\":\"IN\",\"quantity\":10}"
check "Tambah stok 10" 201
echo "  (id produk uji = $PID)"

echo "== PUT /products/{id} =="
req PUT "$BASE/products/$PID" '{"name":"Teh Botol","category":"Minuman","price":5000}'
check "PUT lengkap" 200
check_json "Nama berubah" '.name' 'Teh Botol'
check_json "Stok tidak berubah oleh PUT" '.stock' 10

req PUT "$BASE/products/$PID" '{"name":"Teh Botol","category":"Minuman","price":5000}'
check "PUT diulang (idempotent)" 200
check_json "Hasil tetap sama" '.price' 5000

req PUT "$BASE/products/$PID" '{"name":"Hanya nama"}'
check "PUT tidak lengkap" 400

req PUT "$BASE/products/999999" '{"name":"X","category":"Y","price":1}'
check "PUT produk yang tidak ada" 404

echo "== PATCH /products/{id} =="
req PATCH "$BASE/products/$PID" '{"price":4000}'
check "PATCH hanya harga" 200
check_json "Harga berubah" '.price' 4000
check_json "Nama tidak berubah" '.name' 'Teh Botol'

req PATCH "$BASE/products/$PID" '{}'
check "PATCH body kosong" 400

req PATCH "$BASE/products/$PID" '{"price":-5}'
check "PATCH harga negatif" 400

req PATCH "$BASE/products/999999" '{"price":4000}'
check "PATCH produk yang tidak ada" 404

echo "== DELETE /products/{id} =="
req DELETE "$BASE/products/$PID"
check "DELETE saat stok masih ada" 409

req POST "$BASE/stock-movements" "{\"productId\":$PID,\"type\":\"OUT\",\"quantity\":10}"
check "Kosongkan stok" 201

req DELETE "$BASE/products/$PID"
check "DELETE saat stok 0" 204

req GET "$BASE/products/$PID"
check "Produk sudah tidak ada" 404

req DELETE "$BASE/products/$PID"
check "DELETE produk yang sudah terhapus" 404

echo
echo "Ringkasan: $PASS lulus, $FAIL gagal"
[[ "$FAIL" -eq 0 ]]
