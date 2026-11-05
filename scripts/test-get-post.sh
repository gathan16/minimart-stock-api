#!/usr/bin/env bash
# Pengujian manual GET dan POST dengan curl + jq (API harus sudah berjalan).
#   bash scripts/test-get-post.sh
#   BASE_URL=http://host:port bash scripts/test-get-post.sh
set -uo pipefail

BASE="${BASE_URL:-http://localhost:8080}/api/v1"
PASS=0
FAIL=0
STATUS=""
BODY=""

command -v curl >/dev/null || { echo "curl tidak ditemukan"; exit 2; }
command -v jq   >/dev/null || { echo "jq tidak ditemukan (sudo apt install jq)"; exit 2; }

# req METHOD URL [JSON]  -> mengisi STATUS dan BODY
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
check_json() {
  local actual
  actual=$(echo "$BODY" | jq -r "$2" 2>/dev/null)
  if [[ "$actual" == "$3" ]]; then
    echo "  [PASS] $1 ($2 = $actual)"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 ($2 diharapkan '$3', didapat '$actual')"; FAIL=$((FAIL + 1))
  fi
}

echo "== GET /products =="
req GET "$BASE/products"
check "Ambil daftar produk" 200

echo "== POST /products =="
req POST "$BASE/products" '{"name":"Mie Instan Goreng","category":"Makanan","price":3500}'
check "Tambah produk valid" 201
check_json "Stok awal 0" '.stock' 0
PID=$(echo "$BODY" | jq -r '.id')
echo "  (id produk uji = $PID)"

req POST "$BASE/products" '{"name":"Rusak","category":"Makanan","price":-1}'
check "Tambah produk dengan harga negatif" 400

req POST "$BASE/products" '{"category":"Makanan","price":1000}'
check "Tambah produk tanpa nama" 400

echo "== GET /products/{id} =="
req GET "$BASE/products/$PID"
check "Detail produk yang ada" 200
check_json "Nama sesuai" '.name' 'Mie Instan Goreng'

req GET "$BASE/products/999999"
check "Detail produk yang tidak ada" 404

echo "== POST /stock-movements =="
req POST "$BASE/stock-movements" "{\"productId\":$PID,\"type\":\"IN\",\"quantity\":10}"
check "Stok masuk 10" 201

req GET "$BASE/products/$PID"
check_json "Stok menjadi 10" '.stock' 10

req POST "$BASE/stock-movements" "{\"productId\":$PID,\"type\":\"OUT\",\"quantity\":4}"
check "Stok keluar 4" 201

req GET "$BASE/products/$PID"
check_json "Stok menjadi 6" '.stock' 6

req POST "$BASE/stock-movements" "{\"productId\":$PID,\"type\":\"OUT\",\"quantity\":100}"
check "Stok keluar melebihi stok" 409

req POST "$BASE/stock-movements" '{"productId":999999,"type":"IN","quantity":1}'
check "Stok masuk untuk produk yang tidak ada" 404

req POST "$BASE/stock-movements" "{\"productId\":$PID,\"type\":\"IN\",\"quantity\":0}"
check "Jumlah 0 ditolak" 400

echo "== GET /stock-movements =="
req GET "$BASE/stock-movements"
check "Riwayat pergerakan stok" 200

echo
echo "Ringkasan: $PASS lulus, $FAIL gagal"
[[ "$FAIL" -eq 0 ]]
