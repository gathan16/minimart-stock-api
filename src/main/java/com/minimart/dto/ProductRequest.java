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
