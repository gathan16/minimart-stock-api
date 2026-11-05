package com.minimart.service;

import com.minimart.dto.MovementType;
import com.minimart.dto.StockMovementRequest;
import com.minimart.model.Product;
import com.minimart.model.StockMovement;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.List;

@Service
public class StockMovementService {

    private final StockMovementRepository movementRepository;
    private final ProductRepository productRepository;

    public StockMovementService(StockMovementRepository movementRepository,
                                ProductRepository productRepository) {
        this.movementRepository = movementRepository;
        this.productRepository = productRepository;
    }

    public List<StockMovement> findAll() {
        return movementRepository.findAll();
    }

    @Transactional
    public StockMovement recordMovement(StockMovementRequest request) {
        Product product = productRepository.findById(request.productId())
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Produk tidak ditemukan"));

        if (request.type() == MovementType.OUT) {
            if (product.getStock() < request.quantity()) {
                throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Stok tidak mencukupi");
            }
            product.setStock(product.getStock() - request.quantity());
        } else {
            product.setStock(product.getStock() + request.quantity());
        }
        productRepository.save(product);

        StockMovement movement = new StockMovement();
        movement.setProductId(request.productId());
        movement.setType(request.type());
        movement.setQuantity(request.quantity());
        movement.setCreatedAt(OffsetDateTime.now());
        return movementRepository.save(movement);
    }
}
