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
