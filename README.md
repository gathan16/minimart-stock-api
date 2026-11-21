# MiniMart Stock API

API pengelolaan stok minimarket (Java 17, Spring Boot 3, Spring Data JPA, PostgreSQL).

## Menjalankan

Siapkan PostgreSQL (contoh dengan Docker):

```bash
docker run -d --name minimart-db -p 5432:5432 \
  -e POSTGRES_DB=minimart -e POSTGRES_USER=minimart -e POSTGRES_PASSWORD=minimart \
  postgres:16
```

Jalankan aplikasi:

```bash
mvn spring-boot:run
```

Konfigurasi koneksi dapat diubah lewat variabel lingkungan
`DB_URL`, `DB_USERNAME`, dan `DB_PASSWORD`.

- API: http://localhost:8080/api/v1/products
- Swagger UI: http://localhost:8080/swagger-ui.html
- Spesifikasi OpenAPI: `docs/openapi-v1.yaml`

## Pengujian

```bash
mvn test                              # JUnit + MockMvc (memakai H2 in-memory)
bash scripts/test-get-post.sh         # curl, API harus sudah berjalan
bash scripts/test-put-patch-delete.sh # curl, API harus sudah berjalan
```

Skrip curl membutuhkan `curl` dan `jq`. Alamat dasar dapat diubah dengan
`BASE_URL=http://host:port bash scripts/test-get-post.sh`.

## API v2.0

API v2.0 berjalan berdampingan dengan v1.0 (awalan `/api/v2`). Perubahan utama:
paginasi, filter, dan pengurutan pada daftar; *soft delete* (arsip) dan *restore*
produk; ambang stok menipis (`minStock`, `lowStock`); format galat seragam
`application/problem+json`. Spesifikasi: `docs/openapi-v2.yaml`.

- Swagger UI: http://localhost:8080/swagger-ui.html (pilih "API v2.0" atau "API v1.0")

```bash
mvn test                                   # semua pengujian JUnit (v1 dan v2)
bash scripts/test-v2-get-post.sh           # curl, API harus sudah berjalan
bash scripts/test-v2-put-patch-delete.sh   # curl, API harus sudah berjalan
```
