package com.minimart.repository;

import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.List;

public interface ProductRepository
        extends JpaRepository<Product, Long>, JpaSpecificationExecutor<Product> {

    List<Product> findByStatus(ProductStatus status);
}
