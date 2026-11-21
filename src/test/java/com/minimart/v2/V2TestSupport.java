package com.minimart.v2;

import com.minimart.dto.MovementType;
import com.minimart.model.Product;
import com.minimart.model.ProductStatus;
import com.minimart.model.StockMovement;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;

/** Kelas dasar pengujian: konteks Spring, H2, dan pembantu data uji. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
abstract class V2TestSupport {

    @Autowired protected MockMvc mockMvc;
    @Autowired protected ProductRepository productRepository;
    @Autowired protected StockMovementRepository movementRepository;

    @BeforeEach
    void bersihkanData() {
        movementRepository.deleteAll();
        productRepository.deleteAll();
    }

    protected Product simpanProduk(String nama, String kategori, double harga, int stok, int minStok) {
        Product p = new Product();
        p.setName(nama);
        p.setCategory(kategori);
        p.setPrice(harga);
        p.setStock(stok);
        p.setMinStock(minStok);
        return productRepository.save(p);
    }

    protected Product simpanProduk(String nama, int stok) {
        return simpanProduk(nama, "Umum", 1000, stok, 0);
    }

    protected Product simpanProdukArsip(String nama) {
        Product p = simpanProduk(nama, 0);
        p.setStatus(ProductStatus.ARCHIVED);
        return productRepository.save(p);
    }

    protected StockMovement simpanMovement(Long productId, MovementType type, int qty, OffsetDateTime waktu) {
        StockMovement m = new StockMovement();
        m.setProductId(productId);
        m.setType(type);
        m.setQuantity(qty);
        m.setCreatedAt(waktu);
        return movementRepository.save(m);
    }
}
