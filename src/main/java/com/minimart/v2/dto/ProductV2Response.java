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
