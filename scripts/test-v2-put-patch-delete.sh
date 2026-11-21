#!/usr/bin/env bash
# Pengujian manual API v2.0: PUT, PATCH, DELETE (arsip), dan restore.
#   bash scripts/test-v2-put-patch-delete.sh
#   BASE_URL=http://host:port bash scripts/test-v2-put-patch-delete.sh
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

API="$BASE/api/v2"
RUN="$(date +%s)"
CAT="UJI-$RUN"

echo "== Persiapan: produk dengan stok 10 =="
req POST "$API/products" "{\"name\":\"Susu-$RUN\",\"category\":\"$CAT\",\"price\":6000,\"minStock\":5}"
check "Buat produk" 201
PID=$(echo "$BODY" | jq -r '.id')
req POST "$API/stock-movements" "{\"productId\":$PID,\"type\":\"IN\",\"quantity\":10}"
check "Tambah stok 10" 201
echo "  (id produk uji = $PID)"

echo "== PUT /products/{id} =="
req PUT "$API/products/$PID" "{\"name\":\"Teh-$RUN\",\"category\":\"$CAT\",\"price\":5000,\"minStock\":2}"
check "PUT lengkap" 200
check_json "Nama berubah" '.name' "Teh-$RUN"
check_json "Harga berubah" '.price' 5000
check_json "minStock berubah" '.minStock' 2
check_json "Stok tidak berubah oleh PUT" '.stock' 10

req PUT "$API/products/$PID" "{\"name\":\"Teh-$RUN\",\"category\":\"$CAT\",\"price\":5000,\"minStock\":2}"
check "PUT diulang (idempotent)" 200
check_json "Hasil tetap sama" '.price' 5000

req PUT "$API/products/$PID" "{\"name\":\"Teh-$RUN\",\"category\":\"$CAT\",\"price\":5000}"
check "PUT tanpa minStock" 200
check_json "minStock kembali ke 0" '.minStock' 0

req PUT "$API/products/$PID" '{"name":"Hanya nama"}'
check "PUT tidak lengkap" 400
check_ctype "Galat bertipe problem+json"

req PUT "$API/products/999999" '{"name":"X","category":"Y","price":1}'
check "PUT produk yang tidak ada" 404

echo "== PATCH /products/{id} =="
req PATCH "$API/products/$PID" '{"price":4000}'
check "PATCH hanya harga" 200
check_json "Harga berubah" '.price' 4000
check_json "Nama tidak berubah" '.name' "Teh-$RUN"

req PATCH "$API/products/$PID" '{"minStock":10}'
check "PATCH minStock" 200
check_json "minStock berubah" '.minStock' 10
check_json "Produk kini menipis" '.lowStock' true

req PATCH "$API/products/$PID" '{}'
check "PATCH body kosong" 400

req PATCH "$API/products/$PID" '{"price":-5}'
check "PATCH harga negatif" 400
check_json "Galat pada field price" 'any(.errors[]; .field == "price")' true

req PATCH "$API/products/999999" '{"price":1}'
check "PATCH produk yang tidak ada" 404

echo "== DELETE /products/{id} (soft delete) =="
req DELETE "$API/products/$PID"
check "DELETE saat stok masih ada" 409
check_ctype "Galat bertipe problem+json"

req POST "$API/stock-movements" "{\"productId\":$PID,\"type\":\"OUT\",\"quantity\":10}"
check "Kosongkan stok" 201

req DELETE "$API/products/$PID"
check "DELETE saat stok 0 (arsip)" 204

req GET "$API/products/$PID"
check "Detail produk yang diarsipkan masih ada" 200
check_json "Status ARCHIVED" '.status' ARCHIVED

req GET "$API/products?category=$CAT"
check_json "Tidak tampil pada daftar bawaan" '.totalElements' 0
req GET "$API/products?category=$CAT&status=ARCHIVED"
check_json "Tampil pada status=ARCHIVED" '.totalElements' 1
req GET "$API/products?category=$CAT&status=ALL"
check_json "Tampil pada status=ALL" '.totalElements' 1

req DELETE "$API/products/$PID"
check "DELETE produk yang sudah diarsipkan" 404

req PUT "$API/products/$PID" "{\"name\":\"X\",\"category\":\"$CAT\",\"price\":1}"
check "PUT pada produk arsip" 409
req PATCH "$API/products/$PID" '{"price":1}'
check "PATCH pada produk arsip" 409
req POST "$API/stock-movements" "{\"productId\":$PID,\"type\":\"IN\",\"quantity\":1}"
check "Stok masuk pada produk arsip" 409

echo "== POST /products/{id}/restore =="
req POST "$API/products/$PID/restore"
check "Pulihkan produk" 200
check_json "Status kembali ACTIVE" '.status' ACTIVE

req POST "$API/products/$PID/restore"
check "Pulihkan produk yang sudah aktif" 409

req POST "$API/products/999999/restore"
check "Pulihkan produk yang tidak ada" 404

req GET "$API/products?category=$CAT"
check_json "Tampil kembali pada daftar bawaan" '.totalElements' 1

summary
