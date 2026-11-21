#!/usr/bin/env bash
# =============================================================================
# setup-minimart-v2.sh
# Menambahkan API v2.0 (Bab 4) ke proyek MiniMart Stock API yang sudah dibuat
# oleh setup-minimart.sh (v1.0). Pendekatan A: v1 dan v2 hidup berdampingan
# dalam satu aplikasi, kode v2 dipisah di paket com.minimart.v2.
#
# Cara pakai (dari dalam folder proyek, tempat pom.xml berada):
#   bash setup-minimart-v2.sh
#   YES=1 bash setup-minimart-v2.sh     # lewati pertanyaan konfirmasi
#   FORCE=1 bash setup-minimart-v2.sh   # timpa juga file BARU yang sudah ada
#
# File BARU yang sudah ada dilewati (kecuali FORCE=1).
# File v1 yang DIUBAH (selalu ditimpa, supaya v1 dan v2 saling cocok):
#   model/Product, model/StockMovement, repository/*, service/ProductService,
#   service/StockMovementService, config/OpenApiConfig, .github/workflows/ci.yml
# => COMMIT dulu perubahan Anda sebelum menjalankan skrip ini.
# =============================================================================
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

CREATED=0
SKIPPED=0
CHANGED=0

# write_file <path>  : file baru, dilewati bila sudah ada (kecuali FORCE=1)
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

# modify_file <path> : file yang memang harus diganti untuk v2 (selalu ditimpa)
modify_file() {
  local path="$1" existed=0
  [[ -e "$path" ]] && existed=1
  mkdir -p "$(dirname "$path")"
  cat >"$path"
  if [[ $existed -eq 1 ]]; then
    echo "  [ubah]   $path"
    CHANGED=$((CHANGED + 1))
  else
    echo "  [buat]   $path"
    CREATED=$((CREATED + 1))
  fi
}

# -----------------------------------------------------------------------------
# Pemeriksaan awal
# -----------------------------------------------------------------------------
if [[ ! -f pom.xml || ! -f src/main/java/com/minimart/model/Product.java ]]; then
  echo "pom.xml atau Product.java tidak ditemukan."
  echo "Jalankan dari folder proyek v1 (hasil setup-minimart.sh)."
  exit 1
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && [[ -n "$(git status --porcelain -- . 2>/dev/null)" ]]; then
  echo "PERINGATAN: ada perubahan yang belum di-commit di folder ini."
  echo "Skrip akan menimpa beberapa file v1 (lihat daftar di bagian atas skrip)."
  if [[ "${YES:-0}" != "1" ]]; then
    read -r -p "Lanjutkan? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Dibatalkan."; exit 1; }
  fi
fi

PROJECT_DIR="$(pwd -P)"
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_DIR")"
if [[ "$PROJECT_DIR" == "$GIT_ROOT" ]]; then
  REL="."
else
  REL="${PROJECT_DIR#"$GIT_ROOT"/}"
fi

echo "==> Menambahkan API v2.0 di: $PROJECT_DIR"

mkdir -p docs scripts

# =============================================================================
# A. MODEL, REPOSITORY, DAN SERVICE v1 (diubah agar kompatibel dengan v2)
#    Kontrak v1 TIDAK berubah: field baru disembunyikan dari JSON v1
#    (@JsonIgnore), v1 hanya melihat produk berstatus ACTIVE, dan DELETE v1
#    tetap menghapus permanen.
# =============================================================================

write_file src/main/java/com/minimart/model/ProductStatus.java <<'__MINIMART_EOF__'
package com.minimart.model;

public enum ProductStatus {
    ACTIVE,
    ARCHIVED
}
__MINIMART_EOF__

modify_file src/main/java/com/minimart/model/Product.java <<'__MINIMART_EOF__'
package com.minimart.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;

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

    // ---- kolom baru untuk v2.0 ----
    // columnDefinition memberi nilai bawaan di basis data, sehingga baris lama
    // (dibuat saat v1) tetap valid ketika kolom ditambahkan oleh ddl-auto=update.

    @Column(name = "min_stock", nullable = false, columnDefinition = "integer default 0")
    private Integer minStock = 0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "varchar(20) default 'ACTIVE'")
    private ProductStatus status = ProductStatus.ACTIVE;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    public Product() {}

    @PrePersist
    void onCreate() {
        OffsetDateTime now = OffsetDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = OffsetDateTime.now();
    }

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

    // Field v2 disembunyikan dari JSON v1 (v2 memakai DTO respons sendiri).

    @JsonIgnore
    public Integer getMinStock() { return minStock == null ? 0 : minStock; }
    public void setMinStock(Integer minStock) { this.minStock = minStock; }

    @JsonIgnore
    public ProductStatus getStatus() { return status == null ? ProductStatus.ACTIVE : status; }
    public void setStatus(ProductStatus status) { this.status = status; }

    @JsonIgnore
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }

    @JsonIgnore
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
__MINIMART_EOF__

modify_file src/main/java/com/minimart/model/StockMovement.java <<'__MINIMART_EOF__'
package com.minimart.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
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

    // kolom baru untuk v2.0 (opsional, tidak ditampilkan pada JSON v1)
    @Column(length = 255)
    private String note;

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

    @JsonIgnore
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
}
__MINIMART_EOF__

modify_file src/main/java/com/minimart/repository/ProductRepository.java <<'__MINIMART_EOF__'
package com.minimart.repository;

import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.List;

public interface ProductRepository
        extends JpaRepository<Product, Long>, JpaSpecificationExecutor<Product> {

    List<Product> findByStatus(ProductStatus status);
}
__MINIMART_EOF__

modify_file src/main/java/com/minimart/repository/StockMovementRepository.java <<'__MINIMART_EOF__'
package com.minimart.repository;

import com.minimart.model.StockMovement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface StockMovementRepository
        extends JpaRepository<StockMovement, Long>, JpaSpecificationExecutor<StockMovement> {
}
__MINIMART_EOF__

modify_file src/main/java/com/minimart/service/ProductService.java <<'__MINIMART_EOF__'
package com.minimart.service;

import com.minimart.dto.ProductPatchRequest;
import com.minimart.dto.ProductRequest;
import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.repository.ProductRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * Service untuk API v1.0. Produk yang diarsipkan lewat v2.0 dianggap
 * "tidak ada" oleh v1.0, dan DELETE v1.0 tetap menghapus secara permanen.
 */
@Service
public class ProductService {

    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    // ---- GET dan POST (2.2.1) ----

    public List<Product> findAll() {
        return productRepository.findByStatus(ProductStatus.ACTIVE);
    }

    public Product findById(Long id) {
        return productRepository.findById(id)
            .filter(p -> p.getStatus() == ProductStatus.ACTIVE)
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

modify_file src/main/java/com/minimart/service/StockMovementService.java <<'__MINIMART_EOF__'
package com.minimart.service;

import com.minimart.dto.MovementType;
import com.minimart.dto.StockMovementRequest;
import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.model.StockMovement;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.List;

/** Service untuk API v1.0. */
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
            .filter(p -> p.getStatus() == ProductStatus.ACTIVE)
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

# =============================================================================
# B. KONFIGURASI SWAGGER (grup v1 dan v2) + application.properties
# =============================================================================

modify_file src/main/java/com/minimart/config/OpenApiConfig.java <<'__MINIMART_EOF__'
package com.minimart.config;

import io.swagger.v3.oas.models.info.Info;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public GroupedOpenApi apiV2() {
        return GroupedOpenApi.builder()
            .group("v2")
            .displayName("API v2.0")
            .pathsToMatch("/api/v2/**")
            .addOpenApiCustomizer(openApi -> openApi.info(new Info()
                .title("MiniMart Stock API")
                .description("API pengelolaan stok minimarket, versi 2.0.")
                .version("2.0.0")))
            .build();
    }

    @Bean
    public GroupedOpenApi apiV1() {
        return GroupedOpenApi.builder()
            .group("v1")
            .displayName("API v1.0 (deprecated)")
            .pathsToMatch("/api/v1/**")
            .addOpenApiCustomizer(openApi -> {
                openApi.info(new Info()
                    .title("MiniMart Stock API")
                    .description("API pengelolaan stok minimarket, versi 1.0 (deprecated, gunakan v2.0).")
                    .version("1.0.0"));
                // tandai seluruh operasi v1 sebagai deprecated
                if (openApi.getPaths() != null) {
                    openApi.getPaths().values().forEach(item ->
                        item.readOperations().forEach(op -> op.setDeprecated(true)));
                }
            })
            .build();
    }
}
__MINIMART_EOF__

PROPS=src/main/resources/application.properties
if [[ -f "$PROPS" ]] && ! grep -q 'urls-primary-name' "$PROPS"; then
  printf '\n# Swagger UI: grup v2 menjadi pilihan bawaan\nspringdoc.swagger-ui.urls-primary-name=v2\n' >> "$PROPS"
  echo "  [ubah]   $PROPS (+springdoc.swagger-ui.urls-primary-name=v2)"
  CHANGED=$((CHANGED + 1))
fi

# =============================================================================
# C. API v2.0 (paket com.minimart.v2)
# =============================================================================

# ---- DTO ----

write_file src/main/java/com/minimart/v2/dto/ProductStatusFilter.java <<'__MINIMART_EOF__'
package com.minimart.v2.dto;

/** Nilai parameter ?status= pada GET /api/v2/products. */
public enum ProductStatusFilter {
    ACTIVE,
    ARCHIVED,
    ALL
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/dto/PageResponse.java <<'__MINIMART_EOF__'
package com.minimart.v2.dto;

import org.springframework.data.domain.Page;

import java.util.List;

/** Bentuk respons berhalaman v2.0 (sesuai spesifikasi OpenAPI). */
public record PageResponse<T>(
    List<T> content,
    int page,
    int size,
    long totalElements,
    int totalPages
) {
    public static <T> PageResponse<T> from(Page<T> page) {
        return new PageResponse<>(
            page.getContent(),
            page.getNumber(),
            page.getSize(),
            page.getTotalElements(),
            page.getTotalPages());
    }
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/dto/ProductV2Request.java <<'__MINIMART_EOF__'
package com.minimart.v2.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ProductV2Request(
    @NotBlank(message = "Nama produk wajib diisi")
    String name,

    @NotBlank(message = "Kategori wajib diisi")
    String category,

    @NotNull(message = "Harga wajib diisi")
    @Min(value = 0, message = "Harga tidak boleh bernilai negatif")
    Double price,

    // opsional; bila tidak dikirim bernilai 0
    @Min(value = 0, message = "minStock tidak boleh bernilai negatif")
    Integer minStock
) {}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/dto/ProductV2PatchRequest.java <<'__MINIMART_EOF__'
package com.minimart.v2.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;

public record ProductV2PatchRequest(
    @Pattern(regexp = ".*\\S.*", message = "Nama produk tidak boleh kosong")
    String name,

    @Pattern(regexp = ".*\\S.*", message = "Kategori tidak boleh kosong")
    String category,

    @Min(value = 0, message = "Harga tidak boleh bernilai negatif")
    Double price,

    @Min(value = 0, message = "minStock tidak boleh bernilai negatif")
    Integer minStock
) {}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/dto/ProductV2Response.java <<'__MINIMART_EOF__'
package com.minimart.v2.dto;

import com.minimart.model.Product;
import com.minimart.model.ProductStatus;

import java.time.OffsetDateTime;

public record ProductV2Response(
    Long id,
    String name,
    String category,
    Double price,
    Integer minStock,
    Integer stock,
    boolean lowStock,
    ProductStatus status,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {
    public static ProductV2Response from(Product p) {
        int stock = p.getStock() == null ? 0 : p.getStock();
        int minStock = p.getMinStock();
        return new ProductV2Response(
            p.getId(),
            p.getName(),
            p.getCategory(),
            p.getPrice(),
            minStock,
            stock,
            stock <= minStock,
            p.getStatus(),
            p.getCreatedAt(),
            p.getUpdatedAt());
    }
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/dto/StockMovementV2Request.java <<'__MINIMART_EOF__'
package com.minimart.v2.dto;

import com.minimart.dto.MovementType;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record StockMovementV2Request(
    @NotNull(message = "ID produk wajib diisi")
    Long productId,

    @NotNull(message = "Tipe pergerakan stok (IN/OUT) wajib diisi")
    MovementType type,

    @NotNull(message = "Jumlah stok wajib diisi")
    @Min(value = 1, message = "Jumlah minimal adalah 1")
    Integer quantity,

    @Size(max = 255, message = "Catatan maksimal 255 karakter")
    String note
) {}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/dto/StockMovementV2Response.java <<'__MINIMART_EOF__'
package com.minimart.v2.dto;

import com.minimart.dto.MovementType;
import com.minimart.model.StockMovement;

import java.time.OffsetDateTime;

public record StockMovementV2Response(
    Long id,
    Long productId,
    MovementType type,
    Integer quantity,
    String note,
    OffsetDateTime createdAt
) {
    public static StockMovementV2Response from(StockMovement m) {
        return new StockMovementV2Response(
            m.getId(),
            m.getProductId(),
            m.getType(),
            m.getQuantity(),
            m.getNote(),
            m.getCreatedAt());
    }
}
__MINIMART_EOF__

# ---- Utilitas paginasi ----

write_file src/main/java/com/minimart/v2/support/Paging.java <<'__MINIMART_EOF__'
package com.minimart.v2.support;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/** Membangun Pageable dari parameter page, size, dan sort (dengan validasi). */
public final class Paging {

    private Paging() {}

    public static Pageable of(int page, int size, String sort,
                              List<String> allowedFields, String defaultSort) {
        if (page < 0) {
            throw bad("Parameter page tidak boleh negatif");
        }
        if (size < 1 || size > 100) {
            throw bad("Parameter size harus antara 1 dan 100");
        }

        String spec = (sort == null || sort.isBlank()) ? defaultSort : sort;
        String[] parts = spec.split(",");
        String field = parts[0].trim();
        String dir = parts.length > 1 ? parts[1].trim().toLowerCase() : "asc";

        if (parts.length > 2 || !allowedFields.contains(field)) {
            throw bad("Field sort tidak valid. Pilihan: " + String.join(", ", allowedFields));
        }
        if (!dir.equals("asc") && !dir.equals("desc")) {
            throw bad("Arah sort harus asc atau desc");
        }

        Sort.Direction direction = dir.equals("desc") ? Sort.Direction.DESC : Sort.Direction.ASC;
        Sort result = Sort.by(direction, field);
        if (!field.equals("id")) {
            // urutan sekunder agar paginasi stabil
            result = result.and(Sort.by(Sort.Direction.ASC, "id"));
        }
        return PageRequest.of(page, size, result);
    }

    private static ResponseStatusException bad(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
__MINIMART_EOF__

# ---- Penanganan galat (format RFC 9457, hanya untuk paket v2) ----

write_file src/main/java/com/minimart/v2/error/V2ExceptionHandler.java <<'__MINIMART_EOF__'
package com.minimart.v2.error;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.lang.Nullable;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.ServletWebRequest;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.net.URI;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

/**
 * Format galat seragam (application/problem+json) untuk API v2.0.
 * Dibatasi pada paket com.minimart.v2 sehingga format galat v1.0 tidak berubah.
 */
@RestControllerAdvice(basePackages = "com.minimart.v2")
public class V2ExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(V2ExceptionHandler.class);

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {

        List<Map<String, String>> errors = ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> Map.of(
                "field", fe.getField(),
                "message", fe.getDefaultMessage() == null ? "Nilai tidak valid" : fe.getDefaultMessage()))
            .toList();

        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Validasi gagal");
        pd.setProperty("errors", errors);
        return handleExceptionInternal(ex, pd, headers, status, request);
    }

    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(
            HttpMessageNotReadableException ex, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {

        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST,
            "Isi permintaan tidak dapat dibaca. Periksa format JSON dan nilai enum (misalnya IN atau OUT).");
        return handleExceptionInternal(ex, pd, headers, status, request);
    }

    /** Melengkapi setiap ProblemDetail dengan instance (path) dan timestamp. */
    @Override
    protected ResponseEntity<Object> handleExceptionInternal(
            Exception ex, @Nullable Object body, HttpHeaders headers,
            HttpStatusCode statusCode, WebRequest request) {

        ResponseEntity<Object> response =
            super.handleExceptionInternal(ex, body, headers, statusCode, request);

        if (response != null && response.getBody() instanceof ProblemDetail pd) {
            if (pd.getInstance() == null && request instanceof ServletWebRequest swr) {
                pd.setInstance(URI.create(swr.getRequest().getRequestURI()));
            }
            pd.setProperty("timestamp", OffsetDateTime.now().toString());
        }
        return response;
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Object> handleUnexpected(Exception ex, WebRequest request) {
        log.error("Galat tidak terduga pada API v2", ex);
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR, "Terjadi kesalahan pada server");
        return handleExceptionInternal(ex, pd, new HttpHeaders(),
            HttpStatus.INTERNAL_SERVER_ERROR, request);
    }
}
__MINIMART_EOF__

# ---- Service ----

write_file src/main/java/com/minimart/v2/service/ProductV2Service.java <<'__MINIMART_EOF__'
package com.minimart.v2.service;

import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.repository.ProductRepository;
import com.minimart.v2.dto.PageResponse;
import com.minimart.v2.dto.ProductStatusFilter;
import com.minimart.v2.dto.ProductV2PatchRequest;
import com.minimart.v2.dto.ProductV2Request;
import com.minimart.v2.dto.ProductV2Response;
import com.minimart.v2.support.Paging;
import jakarta.persistence.criteria.Path;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.List;

@Service
public class ProductV2Service {

    private static final List<String> SORT_FIELDS =
        List.of("id", "name", "price", "stock", "createdAt");

    private final ProductRepository productRepository;

    public ProductV2Service(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    // ---------------- GET ----------------

    @Transactional(readOnly = true)
    public PageResponse<ProductV2Response> list(int page, int size, String sort,
                                                String category, String q,
                                                Boolean lowStock, ProductStatusFilter status) {
        Pageable pageable = Paging.of(page, size, sort, SORT_FIELDS, "id,asc");

        Specification<Product> spec = (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();

            if (status != ProductStatusFilter.ALL) {
                ProductStatus wanted = status == ProductStatusFilter.ARCHIVED
                    ? ProductStatus.ARCHIVED : ProductStatus.ACTIVE;
                ps.add(cb.equal(root.get("status"), wanted));
            }
            if (category != null && !category.isBlank()) {
                ps.add(cb.equal(root.get("category"), category.trim()));
            }
            if (q != null && !q.isBlank()) {
                ps.add(cb.like(cb.lower(root.<String>get("name")),
                    "%" + q.trim().toLowerCase() + "%"));
            }
            if (lowStock != null) {
                Path<Integer> stock = root.get("stock");
                Path<Integer> minStock = root.get("minStock");
                ps.add(lowStock
                    ? cb.lessThanOrEqualTo(stock, minStock)
                    : cb.greaterThan(stock, minStock));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };

        return PageResponse.from(
            productRepository.findAll(spec, pageable).map(ProductV2Response::from));
    }

    @Transactional(readOnly = true)
    public ProductV2Response get(Long id) {
        return ProductV2Response.from(find(id));
    }

    // ---------------- POST ----------------

    @Transactional
    public ProductV2Response create(ProductV2Request r) {
        Product product = new Product();
        product.setName(r.name());
        product.setCategory(r.category());
        product.setPrice(r.price());
        product.setMinStock(r.minStock() == null ? 0 : r.minStock());
        product.setStock(0);
        product.setStatus(ProductStatus.ACTIVE);
        return ProductV2Response.from(productRepository.save(product));
    }

    @Transactional
    public ProductV2Response restore(Long id) {
        Product product = find(id);
        if (product.getStatus() != ProductStatus.ARCHIVED) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk tidak dalam keadaan diarsipkan");
        }
        product.setStatus(ProductStatus.ACTIVE);
        return ProductV2Response.from(productRepository.save(product));
    }

    // ---------------- PUT, PATCH, DELETE ----------------

    @Transactional
    public ProductV2Response replace(Long id, ProductV2Request r) {
        Product product = find(id);
        requireActive(product);
        product.setName(r.name());
        product.setCategory(r.category());
        product.setPrice(r.price());
        product.setMinStock(r.minStock() == null ? 0 : r.minStock()); // PUT: ganti seluruhnya
        return ProductV2Response.from(productRepository.save(product));
    }

    @Transactional
    public ProductV2Response patch(Long id, ProductV2PatchRequest r) {
        if (r.name() == null && r.category() == null
                && r.price() == null && r.minStock() == null) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Minimal satu field harus diisi");
        }
        Product product = find(id);
        requireActive(product);
        if (r.name() != null) product.setName(r.name());
        if (r.category() != null) product.setCategory(r.category());
        if (r.price() != null) product.setPrice(r.price());
        if (r.minStock() != null) product.setMinStock(r.minStock());
        return ProductV2Response.from(productRepository.save(product));
    }

    /** Soft delete: produk diarsipkan, data dan riwayat stok tetap ada. */
    @Transactional
    public void archive(Long id) {
        Product product = find(id);
        if (product.getStatus() == ProductStatus.ARCHIVED) {
            throw notFound(id); // sudah diarsipkan = tidak ada pada daftar aktif
        }
        if (product.getStock() > 0) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk masih memiliki stok");
        }
        product.setStatus(ProductStatus.ARCHIVED);
        productRepository.save(product);
    }

    // ---------------- bantu ----------------

    private Product find(Long id) {
        return productRepository.findById(id).orElseThrow(() -> notFound(id));
    }

    private void requireActive(Product product) {
        if (product.getStatus() == ProductStatus.ARCHIVED) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk sudah diarsipkan dan tidak dapat diubah");
        }
    }

    private ResponseStatusException notFound(Long id) {
        return new ResponseStatusException(
            HttpStatus.NOT_FOUND, "Produk dengan id " + id + " tidak ditemukan");
    }
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/service/StockMovementV2Service.java <<'__MINIMART_EOF__'
package com.minimart.v2.service;

import com.minimart.dto.MovementType;
import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.model.StockMovement;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import com.minimart.v2.dto.PageResponse;
import com.minimart.v2.dto.StockMovementV2Request;
import com.minimart.v2.dto.StockMovementV2Response;
import com.minimart.v2.support.Paging;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class StockMovementV2Service {

    private static final List<String> SORT_FIELDS = List.of("id", "quantity", "createdAt");

    private final StockMovementRepository movementRepository;
    private final ProductRepository productRepository;

    public StockMovementV2Service(StockMovementRepository movementRepository,
                                  ProductRepository productRepository) {
        this.movementRepository = movementRepository;
        this.productRepository = productRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<StockMovementV2Response> list(int page, int size, String sort,
                                                      Long productId, MovementType type,
                                                      OffsetDateTime from, OffsetDateTime to) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Parameter from tidak boleh setelah to");
        }
        Pageable pageable = Paging.of(page, size, sort, SORT_FIELDS, "createdAt,desc");

        Specification<StockMovement> spec = (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (productId != null) {
                ps.add(cb.equal(root.get("productId"), productId));
            }
            if (type != null) {
                ps.add(cb.equal(root.get("type"), type));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<OffsetDateTime>get("createdAt"), from));
            }
            if (to != null) {
                ps.add(cb.lessThanOrEqualTo(root.<OffsetDateTime>get("createdAt"), to));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };

        return PageResponse.from(
            movementRepository.findAll(spec, pageable).map(StockMovementV2Response::from));
    }

    @Transactional(readOnly = true)
    public StockMovementV2Response get(Long id) {
        return movementRepository.findById(id)
            .map(StockMovementV2Response::from)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Pergerakan stok dengan id " + id + " tidak ditemukan"));
    }

    @Transactional
    public StockMovementV2Response record(StockMovementV2Request r) {
        Product product = productRepository.findById(r.productId())
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Produk dengan id " + r.productId() + " tidak ditemukan"));

        if (product.getStatus() == ProductStatus.ARCHIVED) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk diarsipkan, pergerakan stok tidak dapat dicatat");
        }

        if (r.type() == MovementType.OUT) {
            if (product.getStock() < r.quantity()) {
                throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Stok tidak mencukupi");
            }
            product.setStock(product.getStock() - r.quantity());
        } else {
            product.setStock(product.getStock() + r.quantity());
        }
        productRepository.save(product);

        StockMovement movement = new StockMovement();
        movement.setProductId(r.productId());
        movement.setType(r.type());
        movement.setQuantity(r.quantity());
        movement.setNote(r.note() == null || r.note().isBlank() ? null : r.note().trim());
        movement.setCreatedAt(OffsetDateTime.now());
        return StockMovementV2Response.from(movementRepository.save(movement));
    }
}
__MINIMART_EOF__

# ---- Controller ----

write_file src/main/java/com/minimart/v2/controller/ProductV2Controller.java <<'__MINIMART_EOF__'
package com.minimart.v2.controller;

import com.minimart.v2.dto.PageResponse;
import com.minimart.v2.dto.ProductStatusFilter;
import com.minimart.v2.dto.ProductV2PatchRequest;
import com.minimart.v2.dto.ProductV2Request;
import com.minimart.v2.dto.ProductV2Response;
import com.minimart.v2.service.ProductV2Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v2/products")
@Tag(name = "Products", description = "Pengelolaan data master produk")
public class ProductV2Controller {

    private final ProductV2Service productService;

    public ProductV2Controller(ProductV2Service productService) {
        this.productService = productService;
    }

    @GetMapping
    @Operation(summary = "Ambil daftar produk (berhalaman)")
    public ResponseEntity<PageResponse<ProductV2Response>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Boolean lowStock,
            @RequestParam(defaultValue = "ACTIVE") ProductStatusFilter status) {
        return ResponseEntity.ok(
            productService.list(page, size, sort, category, q, lowStock, status));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Ambil detail produk")
    public ResponseEntity<ProductV2Response> get(@PathVariable Long id) {
        return ResponseEntity.ok(productService.get(id));
    }

    @PostMapping
    @Operation(summary = "Tambah produk baru")
    public ResponseEntity<ProductV2Response> create(@Valid @RequestBody ProductV2Request request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(productService.create(request));
    }

    @PostMapping("/{id}/restore")
    @Operation(summary = "Pulihkan produk yang diarsipkan")
    public ResponseEntity<ProductV2Response> restore(@PathVariable Long id) {
        return ResponseEntity.ok(productService.restore(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Ganti seluruh data produk")
    public ResponseEntity<ProductV2Response> replace(
            @PathVariable Long id, @Valid @RequestBody ProductV2Request request) {
        return ResponseEntity.ok(productService.replace(id, request));
    }

    @PatchMapping("/{id}")
    @Operation(summary = "Ubah sebagian data produk")
    public ResponseEntity<ProductV2Response> patch(
            @PathVariable Long id, @Valid @RequestBody ProductV2PatchRequest request) {
        return ResponseEntity.ok(productService.patch(id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Arsipkan produk (soft delete)")
    public ResponseEntity<Void> archive(@PathVariable Long id) {
        productService.archive(id);
        return ResponseEntity.noContent().build();
    }
}
__MINIMART_EOF__

write_file src/main/java/com/minimart/v2/controller/StockMovementV2Controller.java <<'__MINIMART_EOF__'
package com.minimart.v2.controller;

import com.minimart.dto.MovementType;
import com.minimart.v2.dto.PageResponse;
import com.minimart.v2.dto.StockMovementV2Request;
import com.minimart.v2.dto.StockMovementV2Response;
import com.minimart.v2.service.StockMovementV2Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;

@RestController
@RequestMapping("/api/v2/stock-movements")
@Tag(name = "Stock Movements", description = "Pencatatan pergerakan stok (hanya tambah)")
public class StockMovementV2Controller {

    private final StockMovementV2Service movementService;

    public StockMovementV2Controller(StockMovementV2Service movementService) {
        this.movementService = movementService;
    }

    @GetMapping
    @Operation(summary = "Ambil riwayat pergerakan stok (berhalaman)")
    public ResponseEntity<PageResponse<StockMovementV2Response>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort,
            @RequestParam(required = false) Long productId,
            @RequestParam(required = false) MovementType type,
            @RequestParam(required = false)
                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false)
                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to) {
        return ResponseEntity.ok(
            movementService.list(page, size, sort, productId, type, from, to));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Ambil detail pergerakan stok")
    public ResponseEntity<StockMovementV2Response> get(@PathVariable Long id) {
        return ResponseEntity.ok(movementService.get(id));
    }

    @PostMapping
    @Operation(summary = "Catat stok masuk atau keluar")
    public ResponseEntity<StockMovementV2Response> record(
            @Valid @RequestBody StockMovementV2Request request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(movementService.record(request));
    }
}
__MINIMART_EOF__

# =============================================================================
# D. SPESIFIKASI OPENAPI v2.0 (4.1)
# =============================================================================

write_file docs/openapi-v2.yaml <<'__MINIMART_EOF__'
openapi: 3.0.3
info:
  title: MiniMart Stock API
  description: API pengelolaan stok minimarket, versi 2.0.
  version: 2.0.0

servers:
  - url: http://{host}
    description: Istio Ingress Gateway (minikube)
    variables:
      host:
        default: localhost:8080

tags:
  - name: Products
    description: Pengelolaan data master produk
  - name: Stock Movements
    description: Pencatatan pergerakan stok (hanya tambah, tidak dapat diubah)

paths:
  /api/v2/products:
    get:
      summary: Ambil daftar produk (berhalaman)
      tags: [Products]
      parameters:
        - $ref: '#/components/parameters/Page'
        - $ref: '#/components/parameters/Size'
        - name: sort
          in: query
          description: "Format `field,arah`. Field: id, name, price, stock, createdAt."
          schema:
            type: string
            default: id,asc
            example: price,desc
        - name: category
          in: query
          schema:
            type: string
            example: Minuman
        - name: q
          in: query
          description: Cari berdasarkan nama produk (mengandung teks).
          schema:
            type: string
            example: susu
        - name: lowStock
          in: query
          description: "true = hanya produk dengan stock <= minStock."
          schema:
            type: boolean
        - name: status
          in: query
          schema:
            type: string
            enum: [ACTIVE, ARCHIVED, ALL]
            default: ACTIVE
      responses:
        '200':
          description: Daftar produk berhasil diambil
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductPage'
        '400':
          $ref: '#/components/responses/BadRequest'
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
          $ref: '#/components/responses/BadRequest'

  /api/v2/products/{id}:
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
          $ref: '#/components/responses/NotFound'
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
          $ref: '#/components/responses/BadRequest'
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'
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
          $ref: '#/components/responses/BadRequest'
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'
    delete:
      summary: Arsipkan produk (soft delete)
      description: >
        Mengubah status produk menjadi ARCHIVED. Ditolak dengan 409
        jika stok masih lebih dari nol.
      tags: [Products]
      parameters:
        - $ref: '#/components/parameters/ProductId'
      responses:
        '204':
          description: Produk berhasil diarsipkan
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'

  /api/v2/products/{id}/restore:
    post:
      summary: Pulihkan produk yang diarsipkan
      tags: [Products]
      parameters:
        - $ref: '#/components/parameters/ProductId'
      responses:
        '200':
          description: Produk berhasil dipulihkan
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'

  /api/v2/stock-movements:
    get:
      summary: Ambil riwayat pergerakan stok (berhalaman)
      tags: [Stock Movements]
      parameters:
        - $ref: '#/components/parameters/Page'
        - $ref: '#/components/parameters/Size'
        - name: sort
          in: query
          description: "Format `field,arah`. Field: id, quantity, createdAt."
          schema:
            type: string
            default: createdAt,desc
        - name: productId
          in: query
          schema:
            type: integer
            format: int64
        - name: type
          in: query
          schema:
            type: string
            enum: [IN, OUT]
        - name: from
          in: query
          description: Batas awal waktu pencatatan (inklusif).
          schema:
            type: string
            format: date-time
        - name: to
          in: query
          description: Batas akhir waktu pencatatan (inklusif).
          schema:
            type: string
            format: date-time
      responses:
        '200':
          description: Riwayat pergerakan stok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/StockMovementPage'
        '400':
          $ref: '#/components/responses/BadRequest'
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
          $ref: '#/components/responses/BadRequest'
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'

  /api/v2/stock-movements/{id}:
    get:
      summary: Ambil detail pergerakan stok
      tags: [Stock Movements]
      parameters:
        - $ref: '#/components/parameters/MovementId'
      responses:
        '200':
          description: Detail pergerakan stok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/StockMovement'
        '404':
          $ref: '#/components/responses/NotFound'

components:
  parameters:
    ProductId:
      name: id
      in: path
      required: true
      description: ID produk
      schema:
        type: integer
        format: int64
        example: 1
    MovementId:
      name: id
      in: path
      required: true
      description: ID pergerakan stok
      schema:
        type: integer
        format: int64
        example: 42
    Page:
      name: page
      in: query
      description: Nomor halaman (dimulai dari 0)
      schema:
        type: integer
        minimum: 0
        default: 0
    Size:
      name: size
      in: query
      description: Jumlah data per halaman
      schema:
        type: integer
        minimum: 1
        maximum: 100
        default: 20

  responses:
    BadRequest:
      description: Permintaan tidak valid
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetail'
          example:
            type: about:blank
            title: Bad Request
            status: 400
            detail: Validasi gagal
            instance: /api/v2/products
            timestamp: '2026-05-10T09:30:00Z'
            errors:
              - field: price
                message: Harga tidak boleh bernilai negatif
    NotFound:
      description: Sumber daya tidak ditemukan
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetail'
          example:
            type: about:blank
            title: Not Found
            status: 404
            detail: Produk dengan id 999999 tidak ditemukan
            instance: /api/v2/products/999999
            timestamp: '2026-05-10T09:30:00Z'
    Conflict:
      description: Permintaan bertentangan dengan keadaan data saat ini
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetail'
          example:
            type: about:blank
            title: Conflict
            status: 409
            detail: Produk masih memiliki stok
            instance: /api/v2/products/1
            timestamp: '2026-05-10T09:30:00Z'

  schemas:
    ProblemDetail:
      type: object
      properties:
        type:
          type: string
          example: about:blank
        title:
          type: string
          example: Bad Request
        status:
          type: integer
          example: 400
        detail:
          type: string
          example: Validasi gagal
        instance:
          type: string
          example: /api/v2/products
        timestamp:
          type: string
          format: date-time
        errors:
          type: array
          description: Daftar galat per field (hanya untuk kesalahan validasi)
          items:
            $ref: '#/components/schemas/FieldError'

    FieldError:
      type: object
      properties:
        field:
          type: string
          example: price
        message:
          type: string
          example: Harga tidak boleh bernilai negatif

    ProductRequest:
      type: object
      required: [name, category, price]
      properties:
        name:
          type: string
          example: Susu UHT
        category:
          type: string
          example: Minuman
        price:
          type: number
          format: double
          minimum: 0
          example: 6000
        minStock:
          type: integer
          minimum: 0
          default: 0
          description: Ambang batas stok menipis
          example: 5

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
        minStock:
          type: integer
          minimum: 0

    Product:
      allOf:
        - $ref: '#/components/schemas/ProductRequest'
        - type: object
          properties:
            id:
              type: integer
              format: int64
              readOnly: true
              example: 1
            stock:
              type: integer
              readOnly: true
              example: 3
            lowStock:
              type: boolean
              readOnly: true
              description: true jika stock <= minStock
              example: true
            status:
              type: string
              enum: [ACTIVE, ARCHIVED]
              readOnly: true
              example: ACTIVE
            createdAt:
              type: string
              format: date-time
              readOnly: true
            updatedAt:
              type: string
              format: date-time
              readOnly: true

    ProductPage:
      type: object
      properties:
        content:
          type: array
          items:
            $ref: '#/components/schemas/Product'
        page:
          type: integer
          example: 0
        size:
          type: integer
          example: 20
        totalElements:
          type: integer
          format: int64
          example: 57
        totalPages:
          type: integer
          example: 3

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
          example: OUT
        quantity:
          type: integer
          minimum: 1
          example: 5
        note:
          type: string
          maxLength: 255
          example: Penjualan kasir 1

    StockMovement:
      allOf:
        - $ref: '#/components/schemas/StockMovementRequest'
        - type: object
          properties:
            id:
              type: integer
              format: int64
              readOnly: true
              example: 42
            createdAt:
              type: string
              format: date-time
              readOnly: true
              example: '2026-05-10T09:30:00Z'

    StockMovementPage:
      type: object
      properties:
        content:
          type: array
          items:
            $ref: '#/components/schemas/StockMovement'
        page:
          type: integer
          example: 0
        size:
          type: integer
          example: 20
        totalElements:
          type: integer
          format: int64
          example: 120
        totalPages:
          type: integer
          example: 6
__MINIMART_EOF__

# =============================================================================
# E. PENGUJIAN JUnit + MockMvc (4.3)
# =============================================================================

write_file src/test/java/com/minimart/v2/V2TestSupport.java <<'__MINIMART_EOF__'
package com.minimart.v2;

import com.minimart.dto.MovementType;
import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.model.StockMovement;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;

/** Kelas dasar pengujian: konteks Spring, H2, dan pembantu data uji. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
abstract class V2TestSupport {

    @Autowired protected MockMvc mockMvc;
    @Autowired protected ProductRepository productRepository;
    @Autowired protected StockMovementRepository movementRepository;

    @BeforeEach
    void bersihkanData() {
        movementRepository.deleteAll();
        productRepository.deleteAll();
    }

    protected Product simpanProduk(String nama, String kategori, double harga, int stok, int minStok) {
        Product p = new Product();
        p.setName(nama);
        p.setCategory(kategori);
        p.setPrice(harga);
        p.setStock(stok);
        p.setMinStock(minStok);
        return productRepository.save(p);
    }

    protected Product simpanProduk(String nama, int stok) {
        return simpanProduk(nama, "Umum", 1000, stok, 0);
    }

    protected Product simpanProdukArsip(String nama) {
        Product p = simpanProduk(nama, 0);
        p.setStatus(ProductStatus.ARCHIVED);
        return productRepository.save(p);
    }

    protected StockMovement simpanMovement(Long productId, MovementType type, int qty, OffsetDateTime waktu) {
        StockMovement m = new StockMovement();
        m.setProductId(productId);
        m.setType(type);
        m.setQuantity(qty);
        m.setCreatedAt(waktu);
        return movementRepository.save(m);
    }
}
__MINIMART_EOF__

write_file src/test/java/com/minimart/v2/ProductV2ReadTest.java <<'__MINIMART_EOF__'
package com.minimart.v2;

import com.minimart.model.Product;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET dan POST /api/v2/products. */
class ProductV2ReadTest extends V2TestSupport {

    private void siapkanTigaProduk() {
        simpanProduk("Susu UHT", "Minuman", 6000, 10, 5); // tidak menipis
        simpanProduk("Roti", "Makanan", 8000, 3, 5);      // menipis
        simpanProduk("Kopi", "Minuman", 3000, 0, 1);      // menipis
    }

    // ---------- GET (daftar) ----------

    @Test
    void list_bawaan_berhalaman() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content", hasSize(3)))
            .andExpect(jsonPath("$.page").value(0))
            .andExpect(jsonPath("$.size").value(20))
            .andExpect(jsonPath("$.totalElements").value(3))
            .andExpect(jsonPath("$.totalPages").value(1));
    }

    @Test
    void list_paginasi_halamanKedua() throws Exception {
        for (int i = 1; i <= 5; i++) {
            simpanProduk("Produk " + i, 1);
        }

        mockMvc.perform(get("/api/v2/products").param("page", "1").param("size", "2"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content", hasSize(2)))
            .andExpect(jsonPath("$.page").value(1))
            .andExpect(jsonPath("$.totalElements").value(5))
            .andExpect(jsonPath("$.totalPages").value(3));
    }

    @Test
    void list_filterKategori() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("category", "Minuman"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(2));
    }

    @Test
    void list_pencarianNama_tidakPekaHurufBesarKecil() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("q", "susu"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].name").value("Susu UHT"));
    }

    @Test
    void list_urutHargaMenurun() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("sort", "price,desc"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content[0].name").value("Roti"))
            .andExpect(jsonPath("$.content[2].name").value("Kopi"));
    }

    @Test
    void list_stokMenipis() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("lowStock", "true"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(2));

        mockMvc.perform(get("/api/v2/products").param("lowStock", "false"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].name").value("Susu UHT"));
    }

    @Test
    void list_produkArsipTidakTampilSecaraBawaan() throws Exception {
        simpanProduk("Aktif", 0);
        simpanProdukArsip("Diarsipkan");

        mockMvc.perform(get("/api/v2/products"))
            .andExpect(jsonPath("$.totalElements").value(1));
        mockMvc.perform(get("/api/v2/products").param("status", "ARCHIVED"))
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].status").value("ARCHIVED"));
        mockMvc.perform(get("/api/v2/products").param("status", "ALL"))
            .andExpect(jsonPath("$.totalElements").value(2));
    }

    @Test
    void list_parameterTidakValid_mengembalikan400DenganProblemJson() throws Exception {
        mockMvc.perform(get("/api/v2/products").param("size", "0"))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.instance").value("/api/v2/products"))
            .andExpect(jsonPath("$.timestamp").exists());

        mockMvc.perform(get("/api/v2/products").param("size", "101"))
            .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v2/products").param("page", "-1"))
            .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v2/products").param("sort", "foo,asc"))
            .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v2/products").param("sort", "price,up"))
            .andExpect(status().isBadRequest());
    }

    // ---------- GET (detail) ----------

    @Test
    void detail_ditemukan_memuatFieldV2() throws Exception {
        Product p = simpanProduk("Roti", "Makanan", 8000, 3, 5);

        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Roti"))
            .andExpect(jsonPath("$.stock").value(3))
            .andExpect(jsonPath("$.minStock").value(5))
            .andExpect(jsonPath("$.lowStock").value(true))
            .andExpect(jsonPath("$.status").value("ACTIVE"))
            .andExpect(jsonPath("$.createdAt").exists())
            .andExpect(jsonPath("$.updatedAt").exists());
    }

    @Test
    void detail_tidakDitemukan_mengembalikan404ProblemJson() throws Exception {
        mockMvc.perform(get("/api/v2/products/{id}", 999999))
            .andExpect(status().isNotFound())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.status").value(404))
            .andExpect(jsonPath("$.detail").value("Produk dengan id 999999 tidak ditemukan"));
    }

    // ---------- POST ----------

    @Test
    void create_valid_mengembalikan201() throws Exception {
        String body = """
            {"name":"Susu UHT","category":"Minuman","price":6000,"minStock":5}
            """;

        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").exists())
            .andExpect(jsonPath("$.stock").value(0))
            .andExpect(jsonPath("$.minStock").value(5))
            .andExpect(jsonPath("$.status").value("ACTIVE"))
            .andExpect(jsonPath("$.createdAt").exists());
    }

    @Test
    void create_tanpaMinStock_bernilaiNol() throws Exception {
        String body = """
            {"name":"Roti","category":"Makanan","price":8000}
            """;

        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.minStock").value(0));
    }

    @Test
    void create_hargaNegatif_galatPerField() throws Exception {
        String body = """
            {"name":"Roti","category":"Makanan","price":-1}
            """;

        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.errors[0].field").value("price"));
    }

    @Test
    void create_bodyKosong_memuatTigaGalat() throws Exception {
        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors", hasSize(3)));
    }
}
__MINIMART_EOF__

write_file src/test/java/com/minimart/v2/ProductV2ModifyTest.java <<'__MINIMART_EOF__'
package com.minimart.v2;

import com.minimart.model.Product;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** PUT, PATCH, DELETE (arsip), dan restore pada /api/v2/products. */
class ProductV2ModifyTest extends V2TestSupport {

    // ---------- PUT ----------

    @Test
    void put_valid_menggantiDataTanpaMenyentuhStok() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 25, 5);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000,"minStock":2}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Teh Botol"))
            .andExpect(jsonPath("$.price").value(5000.0))
            .andExpect(jsonPath("$.minStock").value(2))
            .andExpect(jsonPath("$.stock").value(25));
    }

    @Test
    void put_tanpaMinStock_kembaliKeNol() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 0, 5);
        String body = """
            {"name":"Susu","category":"Minuman","price":6000}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.minStock").value(0));
    }

    @Test
    void put_tidakLengkap_mengembalikan400() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Hanya nama\"}"))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }

    @Test
    void put_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"name":"X","category":"Y","price":1}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    @Test
    void put_produkDiarsipkan_mengembalikan409() throws Exception {
        Product p = simpanProdukArsip("Lama");
        String body = """
            {"name":"X","category":"Y","price":1}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());
    }

    // ---------- PATCH ----------

    @Test
    void patch_hanyaHarga_fieldLainTetap() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 7, 5);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":4000}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.price").value(4000.0))
            .andExpect(jsonPath("$.name").value("Susu"))
            .andExpect(jsonPath("$.minStock").value(5))
            .andExpect(jsonPath("$.stock").value(7));
    }

    @Test
    void patch_minStock_berubah() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 7, 5);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"minStock\":10}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.minStock").value(10))
            .andExpect(jsonPath("$.lowStock").value(true));
    }

    @Test
    void patch_bodyKosong_mengembalikan400() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_hargaNegatif_mengembalikan400() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":-5}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors[0].field").value("price"));
    }

    @Test
    void patch_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(patch("/api/v2/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":1}"))
            .andExpect(status().isNotFound());
    }

    @Test
    void patch_produkDiarsipkan_mengembalikan409() throws Exception {
        Product p = simpanProdukArsip("Lama");

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":1}"))
            .andExpect(status().isConflict());
    }

    // ---------- DELETE (soft delete) ----------

    @Test
    void delete_stokNol_mengarsipkanProduk() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(delete("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isNoContent());

        // data tetap ada, hanya statusnya berubah
        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ARCHIVED"));
    }

    @Test
    void delete_masihAdaStok_mengembalikan409() throws Exception {
        Product p = simpanProduk("Susu", 5);

        mockMvc.perform(delete("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isConflict())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.detail").value("Produk masih memiliki stok"));
    }

    @Test
    void delete_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(delete("/api/v2/products/{id}", 999999))
            .andExpect(status().isNotFound());
    }

    @Test
    void delete_sudahDiarsipkan_mengembalikan404() throws Exception {
        Product p = simpanProdukArsip("Lama");

        mockMvc.perform(delete("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isNotFound());
    }

    // ---------- RESTORE ----------

    @Test
    void restore_produkDiarsipkan_kembaliAktif() throws Exception {
        Product p = simpanProdukArsip("Lama");

        mockMvc.perform(post("/api/v2/products/{id}/restore", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void restore_produkSudahAktif_mengembalikan409() throws Exception {
        Product p = simpanProduk("Aktif", 0);

        mockMvc.perform(post("/api/v2/products/{id}/restore", p.getId()))
            .andExpect(status().isConflict());
    }

    @Test
    void restore_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(post("/api/v2/products/{id}/restore", 999999))
            .andExpect(status().isNotFound());
    }
}
__MINIMART_EOF__

write_file src/test/java/com/minimart/v2/StockMovementV2Test.java <<'__MINIMART_EOF__'
package com.minimart.v2;

import com.minimart.dto.MovementType;
import com.minimart.model.Product;
import com.minimart.model.StockMovement;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.OffsetDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET dan POST /api/v2/stock-movements. */
class StockMovementV2Test extends V2TestSupport {

    private static final OffsetDateTime LAMA = OffsetDateTime.parse("2020-01-01T00:00:00Z");

    // ---------- POST ----------

    @Test
    void record_stokMasuk_menambahStokDanMenyimpanCatatan() throws Exception {
        Product p = simpanProduk("Teh", 0);
        String body = """
            {"productId":%d,"type":"IN","quantity":10,"note":"Restock"}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.type").value("IN"))
            .andExpect(jsonPath("$.quantity").value(10))
            .andExpect(jsonPath("$.note").value("Restock"))
            .andExpect(jsonPath("$.createdAt").exists());

        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(10));
    }

    @Test
    void record_stokKeluarMelebihiStok_mengembalikan409() throws Exception {
        Product p = simpanProduk("Teh", 3);
        String body = """
            {"productId":%d,"type":"OUT","quantity":5}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.detail").value("Stok tidak mencukupi"));

        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(3));
    }

    @Test
    void record_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"productId":999999,"type":"IN","quantity":1}
            """;

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    @Test
    void record_produkDiarsipkan_mengembalikan409() throws Exception {
        Product p = simpanProdukArsip("Lama");
        String body = """
            {"productId":%d,"type":"IN","quantity":1}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());
    }

    @Test
    void record_tipeTidakDikenal_mengembalikan400() throws Exception {
        Product p = simpanProduk("Teh", 3);
        String body = """
            {"productId":%d,"type":"SIDEWAYS","quantity":1}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }

    @Test
    void record_jumlahNol_galatPerField() throws Exception {
        Product p = simpanProduk("Teh", 3);
        String body = """
            {"productId":%d,"type":"IN","quantity":0}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors[0].field").value("quantity"));
    }

    // ---------- GET ----------

    @Test
    void list_filterProductIdDanType() throws Exception {
        Product a = simpanProduk("A", 0);
        Product b = simpanProduk("B", 0);
        simpanMovement(a.getId(), MovementType.IN, 5, OffsetDateTime.now());
        simpanMovement(a.getId(), MovementType.OUT, 2, OffsetDateTime.now());
        simpanMovement(b.getId(), MovementType.IN, 7, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements").param("productId", a.getId().toString()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(2));

        mockMvc.perform(get("/api/v2/stock-movements").param("type", "IN"))
            .andExpect(jsonPath("$.totalElements").value(2));

        mockMvc.perform(get("/api/v2/stock-movements")
                .param("productId", b.getId().toString()).param("type", "OUT"))
            .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void list_filterRentangWaktu() throws Exception {
        Product a = simpanProduk("A", 0);
        simpanMovement(a.getId(), MovementType.IN, 1, LAMA);
        simpanMovement(a.getId(), MovementType.IN, 2, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements").param("from", "2025-01-01T00:00:00Z"))
            .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(get("/api/v2/stock-movements").param("to", "2021-01-01T00:00:00Z"))
            .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(get("/api/v2/stock-movements")
                .param("from", "2025-01-01T00:00:00Z").param("to", "2021-01-01T00:00:00Z"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void list_urutBawaanTerbaruDulu() throws Exception {
        Product a = simpanProduk("A", 0);
        simpanMovement(a.getId(), MovementType.IN, 1, LAMA);
        simpanMovement(a.getId(), MovementType.IN, 2, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements"))
            .andExpect(jsonPath("$.content[0].quantity").value(2))
            .andExpect(jsonPath("$.content[1].quantity").value(1));
    }

    @Test
    void detail_ditemukanDanTidakDitemukan() throws Exception {
        Product a = simpanProduk("A", 0);
        StockMovement m = simpanMovement(a.getId(), MovementType.IN, 5, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements/{id}", m.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.quantity").value(5));

        mockMvc.perform(get("/api/v2/stock-movements/{id}", 999999))
            .andExpect(status().isNotFound())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }
}
__MINIMART_EOF__

write_file src/test/java/com/minimart/v2/V1CompatibilityTest.java <<'__MINIMART_EOF__'
package com.minimart.v2;

import com.minimart.model.Product;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Memastikan kontrak v1.0 tidak berubah setelah v2.0 ditambahkan. */
class V1CompatibilityTest extends V2TestSupport {

    @Test
    void v1_responsTidakMemuatFieldBaruV2() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 4, 5);

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").exists())
            .andExpect(jsonPath("$.name").value("Susu"))
            .andExpect(jsonPath("$.stock").value(4))
            .andExpect(jsonPath("$.minStock").doesNotExist())
            .andExpect(jsonPath("$.lowStock").doesNotExist())
            .andExpect(jsonPath("$.status").doesNotExist())
            .andExpect(jsonPath("$.createdAt").doesNotExist())
            .andExpect(jsonPath("$.updatedAt").doesNotExist());
    }

    @Test
    void v1_daftarTetapBerupaLarikDanHanyaProdukAktif() throws Exception {
        simpanProduk("Aktif", 0);
        simpanProdukArsip("Diarsipkan");

        mockMvc.perform(get("/api/v1/products"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(1)))
            .andExpect(jsonPath("$[0].name").value("Aktif"));
    }

    @Test
    void v1_produkArsipDianggapTidakAda() throws Exception {
        Product p = simpanProdukArsip("Diarsipkan");

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNotFound());
    }

    @Test
    void v1_deleteTetapPermanen() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(delete("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNoContent());

        assertTrue(productRepository.findById(p.getId()).isEmpty());
    }
}
__MINIMART_EOF__

# =============================================================================
# F. SKRIP CURL + JQ (4.3)
# =============================================================================

write_file scripts/lib.sh <<'__MINIMART_EOF__'
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
__MINIMART_EOF__

write_file scripts/test-v2-get-post.sh <<'__MINIMART_EOF__'
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
__MINIMART_EOF__

write_file scripts/test-v2-put-patch-delete.sh <<'__MINIMART_EOF__'
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
__MINIMART_EOF__

chmod +x scripts/*.sh

# =============================================================================
# G. CI/CD (4.4): build + test, lalu uji asap (smoke test) terhadap PostgreSQL
#    File diletakkan di ROOT repositori Git, karena GitHub Actions hanya
#    membaca .github/workflows dari root repositori.
# =============================================================================

CI_FILE="$GIT_ROOT/.github/workflows/ci.yml"

modify_file "$CI_FILE" < <(sed "s|__WORKDIR__|$REL|g" <<'__MINIMART_EOF__'
name: CI

on:
  push:
    branches: [main, dev]
  pull_request:

defaults:
  run:
    working-directory: __WORKDIR__

jobs:
  test:
    name: Build dan test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: maven

      - name: Build dan test (JUnit + MockMvc, basis data H2)
        run: mvn -B verify

      - name: Unggah laporan pengujian
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: surefire-reports
          path: __WORKDIR__/target/surefire-reports

  smoke:
    name: Uji asap API v2 (curl + jq)
    needs: test
    runs-on: ubuntu-latest
    env:
      DB_URL: jdbc:postgresql://localhost:5432/minimart
      DB_USERNAME: minimart
      DB_PASSWORD: minimart
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: minimart
          POSTGRES_USER: minimart
          POSTGRES_PASSWORD: minimart
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U minimart"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: maven

      - name: Package
        run: mvn -B -DskipTests package

      - name: Jalankan API
        run: |
          nohup java -jar target/minimart-stock-api-*.jar > app.log 2>&1 &
          for i in $(seq 1 40); do
            if curl -sf http://localhost:8080/v3/api-docs/v2 >/dev/null; then
              echo "API siap"
              exit 0
            fi
            sleep 3
          done
          echo "API tidak kunjung siap"
          cat app.log
          exit 1

      - name: Uji GET dan POST
        run: bash scripts/test-v2-get-post.sh

      - name: Uji PUT, PATCH, dan DELETE
        run: bash scripts/test-v2-put-patch-delete.sh

      - name: Tampilkan log aplikasi bila gagal
        if: failure()
        run: cat app.log
__MINIMART_EOF__
)

if [[ "$GIT_ROOT" != "$PROJECT_DIR" && -f "$PROJECT_DIR/.github/workflows/ci.yml" ]]; then
  echo "  [catatan] $PROJECT_DIR/.github/workflows/ci.yml (hasil skrip v1) tidak dipakai GitHub;"
  echo "            workflow yang berlaku ada di $CI_FILE. Hapus berkas lama itu bila tidak diperlukan."
fi

# =============================================================================
# H. README
# =============================================================================

if [[ -f README.md ]] && ! grep -q 'API v2.0' README.md; then
  cat >> README.md <<'__MINIMART_EOF__'

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
__MINIMART_EOF__
  echo "  [ubah]   README.md (+bagian API v2.0)"
  CHANGED=$((CHANGED + 1))
fi

echo
echo "==> Selesai: $CREATED file dibuat, $CHANGED diubah, $SKIPPED dilewati."
echo
echo "Langkah berikutnya:"
echo "  ./mvnw test                  # JUnit v1 + v2 (H2, tanpa PostgreSQL)"
echo "  ./mvnw spring-boot:run       # jalankan API (butuh PostgreSQL)"
echo "  bash scripts/test-v2-get-post.sh"
echo "  bash scripts/test-v2-put-patch-delete.sh"
echo "  Swagger UI: http://localhost:8080/swagger-ui.html"