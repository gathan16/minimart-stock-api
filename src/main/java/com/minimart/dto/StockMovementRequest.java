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
