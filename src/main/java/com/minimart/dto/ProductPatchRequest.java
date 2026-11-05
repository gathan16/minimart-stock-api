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
