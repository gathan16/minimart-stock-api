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
