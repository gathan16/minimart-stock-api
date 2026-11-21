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
