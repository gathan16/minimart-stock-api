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
