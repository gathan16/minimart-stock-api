package com.minimart.v2.service;

import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.repository.ProductRepository;
import com.minimart.v2.dto.PageResponse;
import com.minimart.v2.dto.ProductStatusFilter;
import com.minimart.v2.dto.ProductV2PatchRequest;
import com.minimart.v2.dto.ProductV2Request;
import com.minimart.v2.dto.ProductV2Response;
import com.minimart.v2.support.Paging;
import jakarta.persistence.criteria.Path;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.List;

@Service
public class ProductV2Service {

    private static final List<String> SORT_FIELDS =
        List.of("id", "name", "price", "stock", "createdAt");

    private final ProductRepository productRepository;

    public ProductV2Service(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    // ---------------- GET ----------------

    @Transactional(readOnly = true)
    public PageResponse<ProductV2Response> list(int page, int size, String sort,
                                                String category, String q,
                                                Boolean lowStock, ProductStatusFilter status) {
        Pageable pageable = Paging.of(page, size, sort, SORT_FIELDS, "id,asc");

        Specification<Product> spec = (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();

            if (status != ProductStatusFilter.ALL) {
                ProductStatus wanted = status == ProductStatusFilter.ARCHIVED
                    ? ProductStatus.ARCHIVED : ProductStatus.ACTIVE;
                ps.add(cb.equal(root.get("status"), wanted));
            }
            if (category != null && !category.isBlank()) {
                ps.add(cb.equal(root.get("category"), category.trim()));
            }
            if (q != null && !q.isBlank()) {
                ps.add(cb.like(cb.lower(root.<String>get("name")),
                    "%" + q.trim().toLowerCase() + "%"));
            }
            if (lowStock != null) {
                Path<Integer> stock = root.get("stock");
                Path<Integer> minStock = root.get("minStock");
                ps.add(lowStock
                    ? cb.lessThanOrEqualTo(stock, minStock)
                    : cb.greaterThan(stock, minStock));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };

        return PageResponse.from(
            productRepository.findAll(spec, pageable).map(ProductV2Response::from));
    }

    @Transactional(readOnly = true)
    public ProductV2Response get(Long id) {
        return ProductV2Response.from(find(id));
    }

    // ---------------- POST ----------------

    @Transactional
    public ProductV2Response create(ProductV2Request r) {
        Product product = new Product();
        product.setName(r.name());
        product.setCategory(r.category());
        product.setPrice(r.price());
        product.setMinStock(r.minStock() == null ? 0 : r.minStock());
        product.setStock(0);
        product.setStatus(ProductStatus.ACTIVE);
        return ProductV2Response.from(productRepository.save(product));
    }

    @Transactional
    public ProductV2Response restore(Long id) {
        Product product = find(id);
        if (product.getStatus() != ProductStatus.ARCHIVED) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk tidak dalam keadaan diarsipkan");
        }
        product.setStatus(ProductStatus.ACTIVE);
        return ProductV2Response.from(productRepository.save(product));
    }

    // ---------------- PUT, PATCH, DELETE ----------------

    @Transactional
    public ProductV2Response replace(Long id, ProductV2Request r) {
        Product product = find(id);
        requireActive(product);
        product.setName(r.name());
        product.setCategory(r.category());
        product.setPrice(r.price());
        product.setMinStock(r.minStock() == null ? 0 : r.minStock()); // PUT: ganti seluruhnya
        return ProductV2Response.from(productRepository.save(product));
    }

    @Transactional
    public ProductV2Response patch(Long id, ProductV2PatchRequest r) {
        if (r.name() == null && r.category() == null
                && r.price() == null && r.minStock() == null) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Minimal satu field harus diisi");
        }
        Product product = find(id);
        requireActive(product);
        if (r.name() != null) product.setName(r.name());
        if (r.category() != null) product.setCategory(r.category());
        if (r.price() != null) product.setPrice(r.price());
        if (r.minStock() != null) product.setMinStock(r.minStock());
        return ProductV2Response.from(productRepository.save(product));
    }

    /** Soft delete: produk diarsipkan, data dan riwayat stok tetap ada. */
    @Transactional
    public void archive(Long id) {
        Product product = find(id);
        if (product.getStatus() == ProductStatus.ARCHIVED) {
            throw notFound(id); // sudah diarsipkan = tidak ada pada daftar aktif
        }
        if (product.getStock() > 0) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk masih memiliki stok");
        }
        product.setStatus(ProductStatus.ARCHIVED);
        productRepository.save(product);
    }

    // ---------------- bantu ----------------

    private Product find(Long id) {
        return productRepository.findById(id).orElseThrow(() -> notFound(id));
    }

    private void requireActive(Product product) {
        if (product.getStatus() == ProductStatus.ARCHIVED) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk sudah diarsipkan dan tidak dapat diubah");
        }
    }

    private ResponseStatusException notFound(Long id) {
        return new ResponseStatusException(
            HttpStatus.NOT_FOUND, "Produk dengan id " + id + " tidak ditemukan");
    }
}
