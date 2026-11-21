#!/usr/bin/env bash
# Pengujian manual API v2.0: GET dan POST (API harus sudah berjalan).
#   bash scripts/test-v2-get-post.sh
#   BASE_URL=http://host:port bash scripts/test-v2-get-post.sh
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

API="$BASE/api/v2"
RUN="$(date +%s)"
CAT="UJI-$RUN"   # kategori unik agar tidak bentrok dengan data lain

echo "== POST /products =="
req POST "$API/products" "{\"name\":\"Susu-$RUN\",\"category\":\"$CAT\",\"price\":6000,\"minStock\":5}"
check "Tambah produk valid" 201
check_json "Stok awal 0" '.stock' 0
check_json "minStock tersimpan" '.minStock' 5
check_json "Status ACTIVE" '.status' ACTIVE
P1=$(echo "$BODY" | jq -r '.id')

req POST "$API/products" "{\"name\":\"Roti-$RUN\",\"category\":\"$CAT\",\"price\":8000}"
check "Tambah produk tanpa minStock" 201
check_json "minStock bawaan 0" '.minStock' 0
P2=$(echo "$BODY" | jq -r '.id')

req POST "$API/products" "{\"name\":\"Kopi-$RUN\",\"category\":\"$CAT\",\"price\":3000,\"minStock\":1}"
check "Tambah produk ketiga" 201
P3=$(echo "$BODY" | jq -r '.id')

req POST "$API/products" '{"name":"","category":"X","price":-1}'
check "Validasi gagal" 400
check_ctype "Galat bertipe problem+json"
check_json "Galat memuat field price" 'any(.errors[]; .field == "price")' true

echo "== POST /stock-movements =="
req POST "$API/stock-movements" "{\"productId\":$P1,\"type\":\"IN\",\"quantity\":3,\"note\":\"Barang masuk $RUN\"}"
check "Stok masuk 3 (produk 1)" 201
check_json "Catatan tersimpan" '.note' "Barang masuk $RUN"
M1=$(echo "$BODY" | jq -r '.id')

req POST "$API/stock-movements" "{\"productId\":$P2,\"type\":\"IN\",\"quantity\":10}"
check "Stok masuk 10 (produk 2)" 201

req POST "$API/stock-movements" "{\"productId\":$P1,\"type\":\"OUT\",\"quantity\":100}"
check "Stok keluar melebihi stok" 409
check_ctype "Galat bertipe problem+json"

req POST "$API/stock-movements" '{"productId":999999,"type":"IN","quantity":1}'
check "Produk tidak ada" 404

req POST "$API/stock-movements" "{\"productId\":$P1,\"type\":\"IN\",\"quantity\":0}"
check "Jumlah 0 ditolak" 400
check_json "Galat pada field quantity" 'any(.errors[]; .field == "quantity")' true

req POST "$API/stock-movements" "{\"productId\":$P1,\"type\":\"SIDEWAYS\",\"quantity\":1}"
check "Tipe tidak dikenal" 400

echo "== GET /products (daftar) =="
req GET "$API/products?category=$CAT&size=2&page=0&sort=price,desc"
check "Halaman pertama" 200
check_json "Dua data per halaman" '.content | length' 2
check_json "totalElements 3" '.totalElements' 3
check_json "totalPages 2" '.totalPages' 2
check_json "Harga tertinggi lebih dulu" '.content[0].name' "Roti-$RUN"

req GET "$API/products?category=$CAT&size=2&page=1&sort=price,desc"
check "Halaman kedua" 200
check_json "Satu data tersisa" '.content | length' 1
check_json "Harga terendah terakhir" '.content[0].name' "Kopi-$RUN"

req GET "$API/products?category=$CAT&q=susu"
check "Pencarian nama (huruf kecil)" 200
check_json "Satu hasil" '.totalElements' 1

req GET "$API/products?category=$CAT&lowStock=true"
check "Filter stok menipis" 200
check_json "Dua produk menipis" '.totalElements' 2

req GET "$API/products?category=$CAT&lowStock=false"
check "Filter stok aman" 200
check_json "Satu produk aman" '.totalElements' 1

req GET "$API/products?size=0";            check "size=0 ditolak" 400
check_ctype "Galat bertipe problem+json"
req GET "$API/products?size=101";          check "size=101 ditolak" 400
req GET "$API/products?page=-1";           check "page=-1 ditolak" 400
req GET "$API/products?sort=foo,asc";      check "Field sort tidak valid" 400
req GET "$API/products?sort=price,up";     check "Arah sort tidak valid" 400

echo "== GET /products/{id} =="
req GET "$API/products/$P1"
check "Detail produk yang ada" 200
check_json "lowStock bernilai true" '.lowStock' true

req GET "$API/products/999999"
check "Detail produk yang tidak ada" 404
check_ctype "Galat bertipe problem+json"
check_json "Status galat 404" '.status' 404

echo "== GET /stock-movements =="
req GET "$API/stock-movements?productId=$P1&size=5"
check "Riwayat produk 1" 200
check_json "Satu catatan tercatat" '.totalElements' 1

req GET "$API/stock-movements?productId=$P2&type=OUT"
check "Filter tipe OUT" 200
check_json "Tidak ada stok keluar" '.totalElements' 0

req GET "$API/stock-movements?from=2999-01-01T00:00:00Z"
check "Filter waktu masa depan" 200
check_json "Tidak ada hasil" '.totalElements' 0

req GET "$API/stock-movements/$M1"
check "Detail pergerakan stok" 200
req GET "$API/stock-movements/999999"
check "Detail pergerakan stok tidak ada" 404

summary
