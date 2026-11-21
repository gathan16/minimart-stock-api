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
