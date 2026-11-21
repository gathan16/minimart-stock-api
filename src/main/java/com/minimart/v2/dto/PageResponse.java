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
