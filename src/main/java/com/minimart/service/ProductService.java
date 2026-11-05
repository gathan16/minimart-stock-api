package com.minimart.service;

import com.minimart.dto.ProductPatchRequest;
import com.minimart.dto.ProductRequest;
import com.minimart.model.Product;
import com.minimart.repository.ProductRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class ProductService {

    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    // ---- GET dan POST (2.2.1) ----

    public List<Product> findAll() {
        return productRepository.findAll();
    }

    public Product findById(Long id) {
        return productRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Produk tidak ditemukan"));
    }

    @Transactional
    public Product create(ProductRequest request) {
        Product product = new Product();
        product.setName(request.name());
        product.setCategory(request.category());
        product.setPrice(request.price());
        product.setStock(0); // stok awal selalu 0
        return productRepository.save(product);
    }

    // ---- PUT, PATCH, dan DELETE (2.2.2) ----

    @Transactional
    public Product replace(Long id, ProductRequest request) {
        Product product = findById(id); // 404 jika tidak ditemukan
        product.setName(request.name());
        product.setCategory(request.category());
        product.setPrice(request.price());
        return productRepository.save(product);
    }

    @Transactional
    public Product patch(Long id, ProductPatchRequest request) {
        if (request.name() == null
                && request.category() == null
                && request.price() == null) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Minimal satu field harus diisi");
        }
        Product product = findById(id); // 404 jika tidak ditemukan
        if (request.name() != null) {
            product.setName(request.name());
        }
        if (request.category() != null) {
            product.setCategory(request.category());
        }
        if (request.price() != null) {
            product.setPrice(request.price());
        }
        return productRepository.save(product);
    }

    @Transactional
    public void delete(Long id) {
        Product product = findById(id); // 404 jika tidak ditemukan
        if (product.getStock() > 0) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Produk masih memiliki stok");
        }
        productRepository.delete(product);
    }
}
