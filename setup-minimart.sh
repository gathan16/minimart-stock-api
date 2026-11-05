#!/usr/bin/env bash
# =============================================================================
# setup-minimart.sh
# Membuat seluruh struktur dan file proyek MiniMart Stock API (Bab 2, API v1.0)
# sehingga tidak perlu copy-paste kode satu per satu dari dokumen.
#
# Cara pakai (jalankan dari root repositori Git):
#   cd minimart-stock-api
#   bash setup-minimart.sh              # buat di direktori saat ini
#   bash setup-minimart.sh /path/lain   # atau buat di direktori lain
#   FORCE=1 bash setup-minimart.sh      # timpa file yang sudah ada
#
# Secara bawaan file yang SUDAH ADA tidak ditimpa (dilewati).
# =============================================================================
set -euo pipefail

ROOT="${1:-.}"
mkdir -p "$ROOT"
cd "$ROOT"

CREATED=0
SKIPPED=0

# write_file <path>  -> isi file dibaca dari stdin (heredoc)
write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  if [[ -e "$path" && "${FORCE:-0}" != "1" ]]; then
    cat >/dev/null
    echo "  [lewati] $path (sudah ada)"
    SKIPPED=$((SKIPPED + 1))
  else
    cat >"$path"
    echo "  [buat]   $path"
    CREATED=$((CREATED + 1))
  fi
}

echo "==> Membuat proyek di: $(pwd)"

# -----------------------------------------------------------------------------
# Direktori kosong (sesuai struktur proyek)
# -----------------------------------------------------------------------------
mkdir -p k8s docs scripts .github/workflows
[[ -e k8s/.gitkeep ]] || touch k8s/.gitkeep

# -----------------------------------------------------------------------------
# pom.xml
# -----------------------------------------------------------------------------
write_file pom.xml <<'__MINIMART_EOF__'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.5</version>
    <relativePath/>
  </parent>

  <groupId>com.minimart</groupId>
  <artifactId>minimart-stock-api</artifactId>
  <version>1.0.0</version>
  <name>minimart-stock-api</name>
  <description>MiniMart Stock API - layanan pengelolaan stok minimarket</description>

  <properties>
    <java.version>17</java.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
      <groupId>org.postgresql</groupId>
      <artifactId>postgresql</artifactId>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>org.springdoc</groupId>
      <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
      <version>2.6.0</version>
    </dependency>

    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>com.h2database</groupId>
      <artifactId>h2</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# .gitignore
# -----------------------------------------------------------------------------
write_file .gitignore <<'__MINIMART_EOF__'
# Maven
target/
!.mvn/wrapper/maven-wrapper.jar

# IDE
.idea/
*.iml
.vscode/
.classpath
.project
.settings/
*.swp

# OS
.DS_Store
Thumbs.db

# Log & env
*.log
.env
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# README.md
# -----------------------------------------------------------------------------
write_file README.md <<'__MINIMART_EOF__'
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
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# docs/openapi-v1.yaml  (gabungan 2.1.1 + 2.1.2)
# -----------------------------------------------------------------------------
write_file docs/openapi-v1.yaml <<'__MINIMART_EOF__'
openapi: 3.0.3
info:
  title: MiniMart Stock API
  description: API pengelolaan stok minimarket.
  version: 1.0.0
servers:
  - url: http://localhost:8080
    description: API Gateway (lokal)
paths:
  /api/v1/products:
    get:
      summary: Ambil daftar produk
      tags: [Products]
      responses:
        '200':
          description: Daftar produk berhasil diambil
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Product'
    post:
      summary: Tambah produk baru
      tags: [Products]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductRequest'
      responses:
        '201':
          description: Produk berhasil dibuat
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '400':
          description: Data permintaan tidak valid
  /api/v1/products/{id}:
    get:
      summary: Ambil detail produk
      tags: [Products]
      parameters:
        - $ref: '#/components/parameters/ProductId'
      responses:
        '200':
          description: Detail produk
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '404':
          description: Produk tidak ditemukan
    put:
      summary: Ganti seluruh data produk
      tags: [Products]
      parameters:
        - $ref: '#/components/parameters/ProductId'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductRequest'
      responses:
        '200':
          description: Produk berhasil diperbarui
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '400':
          description: Data permintaan tidak valid
        '404':
          description: Produk tidak ditemukan
    patch:
      summary: Ubah sebagian data produk
      tags: [Products]
      parameters:
        - $ref: '#/components/parameters/ProductId'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductPatchRequest'
      responses:
        '200':
          description: Produk berhasil diperbarui
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '400':
          description: Data permintaan tidak valid
        '404':
          description: Produk tidak ditemukan
    delete:
      summary: Hapus produk
      tags: [Products]
      parameters:
        - $ref: '#/components/parameters/ProductId'
      responses:
        '204':
          description: Produk berhasil dihapus
        '404':
          description: Produk tidak ditemukan
        '409':
          description: Produk masih memiliki stok
  /api/v1/stock-movements:
    get:
      summary: Ambil riwayat pergerakan stok
      tags: [Stock Movements]
      responses:
        '200':
          description: Riwayat pergerakan stok
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/StockMovement'
    post:
      summary: Catat stok masuk atau keluar
      tags: [Stock Movements]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/StockMovementRequest'
      responses:
        '201':
          description: Pergerakan stok berhasil dicatat
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/StockMovement'
        '400':
          description: Data permintaan tidak valid
        '404':
          description: Produk tidak ditemukan
        '409':
          description: Stok tidak mencukupi
components:
  parameters:
    ProductId:
      name: id
      in: path
      required: true
      schema:
        type: integer
        format: int64
  schemas:
    ProductRequest:
      type: object
      required: [name, category, price]
      properties:
        name:
          type: string
          example: Mie Instan Goreng
        category:
          type: string
          example: Makanan
        price:
          type: number
          format: double
          minimum: 0
          example: 3500
    ProductPatchRequest:
      type: object
      minProperties: 1
      properties:
        name:
          type: string
        category:
          type: string
        price:
          type: number
          format: double
          minimum: 0
          example: 4000
    Product:
      allOf:
        - $ref: '#/components/schemas/ProductRequest'
        - type: object
          properties:
            id:
              type: integer
              format: int64
              example: 1
            stock:
              type: integer
              example: 120
    StockMovementRequest:
      type: object
      required: [productId, type, quantity]
      properties:
        productId:
          type: integer
          format: int64
          example: 1
        type:
          type: string
          enum: [IN, OUT]
        quantity:
          type: integer
          minimum: 1
          example: 10
    StockMovement:
      allOf:
        - $ref: '#/components/schemas/StockMovementRequest'
        - type: object
          properties:
            id:
              type: integer
              format: int64
            createdAt:
              type: string
              format: date-time
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# Aplikasi utama
# -----------------------------------------------------------------------------
write_file src/main/java/com/minimart/MinimartStockApiApplication.java <<'__MINIMART_EOF__'
package com.minimart;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class MinimartStockApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(MinimartStockApiApplication.class, args);
    }
}
__MINIMART_EOF__

write_file src/main/resources/application.properties <<'__MINIMART_EOF__'
spring.application.name=minimart-stock-api
server.port=8080

# PostgreSQL (dapat ditimpa lewat variabel lingkungan)
spring.datasource.url=${DB_URL:jdbc:postgresql://localhost:5432/minimart}
spring.datasource.username=${DB_USERNAME:minimart}
spring.datasource.password=${DB_PASSWORD:minimart}

spring.jpa.hibernate.ddl-auto=update
spring.jpa.open-in-view=false

# springdoc-openapi (Swagger UI)
springdoc.swagger-ui.path=/swagger-ui.html
springdoc.api-docs.path=/v3/api-docs
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# DTO
# -----------------------------------------------------------------------------
write_file src/main/java/com/minimart/dto/MovementType.java <<'__MINIMART_EOF__'
package com.minimart.dto;

public enum MovementType {
    IN,
    OUT
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/dto/ProductRequest.java <<'__MINIMART_EOF__'
package com.minimart.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ProductRequest(
    @NotBlank(message = "Nama produk wajib diisi")
    String name,

    @NotBlank(message = "Kategori wajib diisi")
    String category,

    @NotNull(message = "Harga wajib diisi")
    @Min(value = 0, message = "Harga tidak boleh bernilai negatif")
    Double price
) {}
__MINIMART_EOF__

write_file src/main/java/com/minimart/dto/StockMovementRequest.java <<'__MINIMART_EOF__'
package com.minimart.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public record StockMovementRequest(
    @NotNull(message = "ID produk wajib diisi")
    Long productId,

    @NotNull(message = "Tipe pergerakan stok (IN/OUT) wajib diisi")
    MovementType type, // Enum: IN, OUT

    @NotNull(message = "Jumlah stok wajib diisi")
    @Min(value = 1, message = "Jumlah minimal adalah 1")
    Integer quantity
) {}
__MINIMART_EOF__

write_file src/main/java/com/minimart/dto/ProductPatchRequest.java <<'__MINIMART_EOF__'
package com.minimart.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;

public record ProductPatchRequest(
    @Pattern(regexp = ".*\\S.*", message = "Nama produk tidak boleh kosong")
    String name,

    @Pattern(regexp = ".*\\S.*", message = "Kategori tidak boleh kosong")
    String category,

    @Min(value = 0, message = "Harga tidak boleh bernilai negatif")
    Double price
) {}
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# Model (entity) -- tidak ada di dokumen, dibuat mengikuti skema OpenAPI
# -----------------------------------------------------------------------------
write_file src/main/java/com/minimart/model/Product.java <<'__MINIMART_EOF__'
package com.minimart.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "products")
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String category;

    @Column(nullable = false)
    private Double price;

    @Column(nullable = false)
    private Integer stock = 0;

    public Product() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public Double getPrice() { return price; }
    public void setPrice(Double price) { this.price = price; }

    public Integer getStock() { return stock; }
    public void setStock(Integer stock) { this.stock = stock; }
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/model/StockMovement.java <<'__MINIMART_EOF__'
package com.minimart.model;

import com.minimart.dto.MovementType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;

@Entity
@Table(name = "stock_movements")
public class StockMovement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long productId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private MovementType type;

    @Column(nullable = false)
    private Integer quantity;

    @Column(nullable = false)
    private OffsetDateTime createdAt;

    public StockMovement() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }

    public MovementType getType() { return type; }
    public void setType(MovementType type) { this.type = type; }

    public Integer getQuantity() { return quantity; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# Repository
# -----------------------------------------------------------------------------
write_file src/main/java/com/minimart/repository/ProductRepository.java <<'__MINIMART_EOF__'
package com.minimart.repository;

import com.minimart.model.Product;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, Long> {
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/repository/StockMovementRepository.java <<'__MINIMART_EOF__'
package com.minimart.repository;

import com.minimart.model.StockMovement;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StockMovementRepository extends JpaRepository<StockMovement, Long> {
}
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# Service
# -----------------------------------------------------------------------------
write_file src/main/java/com/minimart/service/ProductService.java <<'__MINIMART_EOF__'
package com.minimart.service;

import com.minimart.dto.ProductPatchRequest;
import com.minimart.dto.ProductRequest;
import com.minimart.model.Product;
import com.minimart.repository.ProductRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class ProductService {

    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    // ---- GET dan POST (2.2.1) ----

    public List<Product> findAll() {
        return productRepository.findAll();
    }

    public Product findById(Long id) {
        return productRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Produk tidak ditemukan"));
    }

    @Transactional
    public Product create(ProductRequest request) {
        Product product = new Product();
        product.setName(request.name());
        product.setCategory(request.category());
        product.setPrice(request.price());
        product.setStock(0); // stok awal selalu 0
        return productRepository.save(product);
    }

    // ---- PUT, PATCH, dan DELETE (2.2.2) ----

    @Transactional
    public Product replace(Long id, ProductRequest request) {
        Product product = findById(id); // 404 jika tidak ditemukan
        product.setName(request.name());
        product.setCategory(request.category());
        product.setPrice(request.price());
        return productRepository.save(product);
    }

    @Transactional
    public Product patch(Long id, ProductPatchRequest request) {
        if (request.name() == null
                && request.category() == null
                && request.price() == null) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Minimal satu field harus diisi");
        }
        Product product = findById(id); // 404 jika tidak ditemukan
        if (request.name() != null) {
            product.setName(request.name());
        }
        if (request.category() != null) {
            product.setCategory(request.category());
        }
        if (request.price() != null) {
            product.setPrice(request.price());
        }
        return productRepository.save(product);
    }

    @Transactional
    public void delete(Long id) {
        Product product = findById(id); // 404 jika tidak ditemukan
        if (product.getStock() > 0) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk masih memiliki stok");
        }
        productRepository.delete(product);
    }
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/service/StockMovementService.java <<'__MINIMART_EOF__'
package com.minimart.service;

import com.minimart.dto.MovementType;
import com.minimart.dto.StockMovementRequest;
import com.minimart.model.Product;
import com.minimart.model.StockMovement;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.List;

@Service
public class StockMovementService {

    private final StockMovementRepository movementRepository;
    private final ProductRepository productRepository;

    public StockMovementService(StockMovementRepository movementRepository,
                                ProductRepository productRepository) {
        this.movementRepository = movementRepository;
        this.productRepository = productRepository;
    }

    public List<StockMovement> findAll() {
        return movementRepository.findAll();
    }

    @Transactional
    public StockMovement recordMovement(StockMovementRequest request) {
        Product product = productRepository.findById(request.productId())
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Produk tidak ditemukan"));

        if (request.type() == MovementType.OUT) {
            if (product.getStock() < request.quantity()) {
                throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Stok tidak mencukupi");
            }
            product.setStock(product.getStock() - request.quantity());
        } else {
            product.setStock(product.getStock() + request.quantity());
        }
        productRepository.save(product);

        StockMovement movement = new StockMovement();
        movement.setProductId(request.productId());
        movement.setType(request.type());
        movement.setQuantity(request.quantity());
        movement.setCreatedAt(OffsetDateTime.now());
        return movementRepository.save(movement);
    }
}
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# Controller
# -----------------------------------------------------------------------------
write_file src/main/java/com/minimart/controller/ProductController.java <<'__MINIMART_EOF__'
package com.minimart.controller;

import com.minimart.dto.ProductPatchRequest;
import com.minimart.dto.ProductRequest;
import com.minimart.model.Product;
import com.minimart.service.ProductService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping
    public ResponseEntity<List<Product>> getAllProducts() {
        return ResponseEntity.ok(productService.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable Long id) {
        return ResponseEntity.ok(productService.findById(id));
    }

    @PostMapping
    public ResponseEntity<Product> createProduct(@Valid @RequestBody ProductRequest request) {
        Product createdProduct = productService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(createdProduct);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Product> replaceProduct(
            @PathVariable Long id,
            @Valid @RequestBody ProductRequest request) {
        return ResponseEntity.ok(productService.replace(id, request));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<Product> updateProductPartially(
            @PathVariable Long id,
            @Valid @RequestBody ProductPatchRequest request) {
        return ResponseEntity.ok(productService.patch(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        productService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/controller/StockMovementController.java <<'__MINIMART_EOF__'
package com.minimart.controller;

import com.minimart.dto.StockMovementRequest;
import com.minimart.model.StockMovement;
import com.minimart.service.StockMovementService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/stock-movements")
public class StockMovementController {

    private final StockMovementService stockMovementService;

    public StockMovementController(StockMovementService stockMovementService) {
        this.stockMovementService = stockMovementService;
    }

    @GetMapping
    public ResponseEntity<List<StockMovement>> getAllMovements() {
        return ResponseEntity.ok(stockMovementService.findAll());
    }

    @PostMapping
    public ResponseEntity<StockMovement> recordMovement(
            @Valid @RequestBody StockMovementRequest request) {
        StockMovement movement = stockMovementService.recordMovement(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(movement);
    }
}
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# Pengujian JUnit + MockMvc (bagian 2.3 pada dokumen masih kosong -> dibuat di sini)
# -----------------------------------------------------------------------------
write_file src/test/resources/application-test.properties <<'__MINIMART_EOF__'
# Basis data H2 in-memory khusus pengujian (tidak membutuhkan PostgreSQL)
spring.datasource.url=jdbc:h2:mem:minimart-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1
spring.datasource.driver-class-name=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.open-in-view=false
__MINIMART_EOF__

write_file src/test/java/com/minimart/controller/ProductGetPostTest.java <<'__MINIMART_EOF__'
package com.minimart.controller;

import com.minimart.model.Product;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProductGetPostTest {

    @Autowired MockMvc mockMvc;
    @Autowired ProductRepository productRepository;
    @Autowired StockMovementRepository movementRepository;

    @BeforeEach
    void bersihkanData() {
        movementRepository.deleteAll();
        productRepository.deleteAll();
    }

    private Product simpanProduk(String nama, int stok) {
        Product p = new Product();
        p.setName(nama);
        p.setCategory("Makanan");
        p.setPrice(3500.0);
        p.setStock(stok);
        return productRepository.save(p);
    }

    // ---------- GET /products ----------

    @Test
    void getAllProducts_mengembalikan200() throws Exception {
        simpanProduk("Mie Instan Goreng", 10);
        simpanProduk("Teh Botol", 5);

        mockMvc.perform(get("/api/v1/products"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(2)));
    }

    // ---------- GET /products/{id} ----------

    @Test
    void getProductById_ditemukan_mengembalikan200() throws Exception {
        Product p = simpanProduk("Mie Instan Goreng", 120);

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Mie Instan Goreng"))
            .andExpect(jsonPath("$.stock").value(120));
    }

    @Test
    void getProductById_tidakDitemukan_mengembalikan404() throws Exception {
        mockMvc.perform(get("/api/v1/products/{id}", 999999))
            .andExpect(status().isNotFound());
    }

    // ---------- POST /products ----------

    @Test
    void createProduct_valid_mengembalikan201DenganStokAwalNol() throws Exception {
        String body = """
            {"name":"Mie Instan Goreng","category":"Makanan","price":3500}
            """;

        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").exists())
            .andExpect(jsonPath("$.name").value("Mie Instan Goreng"))
            .andExpect(jsonPath("$.stock").value(0));
    }

    @Test
    void createProduct_hargaNegatif_mengembalikan400() throws Exception {
        String body = """
            {"name":"Mie Instan Goreng","category":"Makanan","price":-1}
            """;

        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void createProduct_namaKosong_mengembalikan400() throws Exception {
        String body = """
            {"name":"","category":"Makanan","price":3500}
            """;

        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void createProduct_fieldWajibHilang_mengembalikan400() throws Exception {
        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest());
    }

    // ---------- GET /stock-movements ----------

    @Test
    void getAllMovements_mengembalikan200() throws Exception {
        mockMvc.perform(get("/api/v1/stock-movements"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(0)));
    }

    // ---------- POST /stock-movements ----------

    @Test
    void recordMovement_stokMasuk_mengembalikan201DanMenambahStok() throws Exception {
        Product p = simpanProduk("Teh Botol", 0);
        String body = """
            {"productId":%d,"type":"IN","quantity":10}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.type").value("IN"))
            .andExpect(jsonPath("$.quantity").value(10))
            .andExpect(jsonPath("$.createdAt").exists());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(10));
    }

    @Test
    void recordMovement_stokKeluar_mengurangiStok() throws Exception {
        Product p = simpanProduk("Teh Botol", 10);
        String body = """
            {"productId":%d,"type":"OUT","quantity":4}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(6));
    }

    @Test
    void recordMovement_stokKeluarMelebihiStok_mengembalikan409() throws Exception {
        Product p = simpanProduk("Teh Botol", 3);
        String body = """
            {"productId":%d,"type":"OUT","quantity":5}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(3));
    }

    @Test
    void recordMovement_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"productId":999999,"type":"IN","quantity":5}
            """;

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    @Test
    void recordMovement_jumlahNol_mengembalikan400() throws Exception {
        Product p = simpanProduk("Teh Botol", 3);
        String body = """
            {"productId":%d,"type":"IN","quantity":0}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void recordMovement_tipeTidakValid_mengembalikan400() throws Exception {
        Product p = simpanProduk("Teh Botol", 3);
        String body = """
            {"productId":%d,"type":"SIDEWAYS","quantity":1}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }
}
__MINIMART_EOF__

write_file src/test/java/com/minimart/controller/ProductModifyTest.java <<'__MINIMART_EOF__'
package com.minimart.controller;

import com.minimart.model.Product;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProductModifyTest {

    @Autowired MockMvc mockMvc;
    @Autowired ProductRepository productRepository;
    @Autowired StockMovementRepository movementRepository;

    @BeforeEach
    void bersihkanData() {
        movementRepository.deleteAll();
        productRepository.deleteAll();
    }

    private Product simpanProduk(int stok) {
        Product p = new Product();
        p.setName("Mie Instan Goreng");
        p.setCategory("Makanan");
        p.setPrice(3500.0);
        p.setStock(stok);
        return productRepository.save(p);
    }

    // ---------- PUT ----------

    @Test
    void put_valid_mengganti_dataTanpaMenyentuhStok() throws Exception {
        Product p = simpanProduk(25);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Teh Botol"))
            .andExpect(jsonPath("$.category").value("Minuman"))
            .andExpect(jsonPath("$.price").value(5000.0))
            .andExpect(jsonPath("$.stock").value(25));
    }

    @Test
    void put_idempotent_hasilSamaSetiapPemanggilan() throws Exception {
        Product p = simpanProduk(0);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000}
            """;

        String pertama = mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(content().json(pertama));
    }

    @Test
    void put_fieldTidakLengkap_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);
        String body = """
            {"name":"Teh Botol"}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void put_hargaNegatif_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":-10}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void put_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    // ---------- PATCH ----------

    @Test
    void patch_hanyaHarga_fieldLainTidakBerubah() throws Exception {
        Product p = simpanProduk(7);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":4000}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.price").value(4000.0))
            .andExpect(jsonPath("$.name").value("Mie Instan Goreng"))
            .andExpect(jsonPath("$.category").value("Makanan"))
            .andExpect(jsonPath("$.stock").value(7));
    }

    @Test
    void patch_bodyKosong_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_hargaNegatif_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":-5}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_namaHanyaSpasi_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"   \"}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(patch("/api/v1/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":4000}"))
            .andExpect(status().isNotFound());
    }

    // ---------- DELETE ----------

    @Test
    void delete_stokNol_mengembalikan204DanProdukHilang() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(delete("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNotFound());
    }

    @Test
    void delete_masihAdaStok_mengembalikan409() throws Exception {
        Product p = simpanProduk(5);

        mockMvc.perform(delete("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isConflict());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isOk());
    }

    @Test
    void delete_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(delete("/api/v1/products/{id}", 999999))
            .andExpect(status().isNotFound());
    }
}
__MINIMART_EOF__

# -----------------------------------------------------------------------------
# Skrip curl (bagian 2.3.1 dan 2.3.2 pada dokumen masih kosong -> dibuat di sini)
# -----------------------------------------------------------------------------
write_file scripts/test-get-post.sh <<'__MINIMART_EOF__'
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
__MINIMART_EOF__

write_file scripts/test-put-patch-delete.sh <<'__MINIMART_EOF__'
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
  local actual
  actual=$(echo "$BODY" | jq -r "$2" 2>/dev/null)
  if [[ "$actual" == "$3" ]]; then
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
__MINIMART_EOF__

chmod +x scripts/*.sh

# -----------------------------------------------------------------------------
# CI (Bab 4.4 pada dokumen masih kosong -> kerangka minimal)
# -----------------------------------------------------------------------------
write_file .github/workflows/ci.yml <<'__MINIMART_EOF__'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: maven

      - name: Build dan test
        run: mvn -B verify
__MINIMART_EOF__

echo
echo "==> Selesai: $CREATED file dibuat, $SKIPPED dilewati."
echo
echo "Langkah berikutnya:"
echo "  mvn test                 # jalankan JUnit (pakai H2, tanpa PostgreSQL)"
echo "  mvn spring-boot:run      # jalankan API (butuh PostgreSQL, lihat README.md)"
echo "  bash scripts/test-get-post.sh"
echo "  bash scripts/test-put-patch-delete.sh"