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
