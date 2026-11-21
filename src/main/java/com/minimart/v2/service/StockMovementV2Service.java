package com.minimart.v2.service;

import com.minimart.dto.MovementType;
import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.model.StockMovement;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import com.minimart.v2.dto.PageResponse;
import com.minimart.v2.dto.StockMovementV2Request;
import com.minimart.v2.dto.StockMovementV2Response;
import com.minimart.v2.support.Paging;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class StockMovementV2Service {

    private static final List<String> SORT_FIELDS = List.of("id", "quantity", "createdAt");

    private final StockMovementRepository movementRepository;
    private final ProductRepository productRepository;

    public StockMovementV2Service(StockMovementRepository movementRepository,
                                  ProductRepository productRepository) {
        this.movementRepository = movementRepository;
        this.productRepository = productRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<StockMovementV2Response> list(int page, int size, String sort,
                                                      Long productId, MovementType type,
                                                      OffsetDateTime from, OffsetDateTime to) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Parameter from tidak boleh setelah to");
        }
        Pageable pageable = Paging.of(page, size, sort, SORT_FIELDS, "createdAt,desc");

        Specification<StockMovement> spec = (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (productId != null) {
                ps.add(cb.equal(root.get("productId"), productId));
            }
            if (type != null) {
                ps.add(cb.equal(root.get("type"), type));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<OffsetDateTime>get("createdAt"), from));
            }
            if (to != null) {
                ps.add(cb.lessThanOrEqualTo(root.<OffsetDateTime>get("createdAt"), to));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };

        return PageResponse.from(
            movementRepository.findAll(spec, pageable).map(StockMovementV2Response::from));
    }

    @Transactional(readOnly = true)
    public StockMovementV2Response get(Long id) {
        return movementRepository.findById(id)
            .map(StockMovementV2Response::from)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Pergerakan stok dengan id " + id + " tidak ditemukan"));
    }

    @Transactional
    public StockMovementV2Response record(StockMovementV2Request r) {
        Product product = productRepository.findById(r.productId())
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Produk dengan id " + r.productId() + " tidak ditemukan"));

        if (product.getStatus() == ProductStatus.ARCHIVED) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk diarsipkan, pergerakan stok tidak dapat dicatat");
        }

        if (r.type() == MovementType.OUT) {
            if (product.getStock() < r.quantity()) {
                throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Stok tidak mencukupi");
            }
            product.setStock(product.getStock() - r.quantity());
        } else {
            product.setStock(product.getStock() + r.quantity());
        }
        productRepository.save(product);

        StockMovement movement = new StockMovement();
        movement.setProductId(r.productId());
        movement.setType(r.type());
        movement.setQuantity(r.quantity());
        movement.setNote(r.note() == null || r.note().isBlank() ? null : r.note().trim());
        movement.setCreatedAt(OffsetDateTime.now());
        return StockMovementV2Response.from(movementRepository.save(movement));
    }
}
