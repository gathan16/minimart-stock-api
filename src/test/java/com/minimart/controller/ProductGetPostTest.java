package com.minimart.controller;

import com.minimart.model.Product;
import com.minimart.repository.ProductRepository;
import com.minimart.repository.StockMovementRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProductGetPostTest {

    @Autowired MockMvc mockMvc;
    @Autowired ProductRepository productRepository;
    @Autowired StockMovementRepository movementRepository;

    @BeforeEach
    void bersihkanData() {
        movementRepository.deleteAll();
        productRepository.deleteAll();
    }

    private Product simpanProduk(String nama, int stok) {
        Product p = new Product();
        p.setName(nama);
        p.setCategory("Makanan");
        p.setPrice(3500.0);
        p.setStock(stok);
        return productRepository.save(p);
    }

    // ---------- GET /products ----------

    @Test
    void getAllProducts_mengembalikan200() throws Exception {
        simpanProduk("Mie Instan Goreng", 10);
        simpanProduk("Teh Botol", 5);

        mockMvc.perform(get("/api/v1/products"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(2)));
    }

    // ---------- GET /products/{id} ----------

    @Test
    void getProductById_ditemukan_mengembalikan200() throws Exception {
        Product p = simpanProduk("Mie Instan Goreng", 120);

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Mie Instan Goreng"))
            .andExpect(jsonPath("$.stock").value(120));
    }

    @Test
    void getProductById_tidakDitemukan_mengembalikan404() throws Exception {
        mockMvc.perform(get("/api/v1/products/{id}", 999999))
            .andExpect(status().isNotFound());
    }

    // ---------- POST /products ----------

    @Test
    void createProduct_valid_mengembalikan201DenganStokAwalNol() throws Exception {
        String body = """
            {"name":"Mie Instan Goreng","category":"Makanan","price":3500}
            """;

        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").exists())
            .andExpect(jsonPath("$.name").value("Mie Instan Goreng"))
            .andExpect(jsonPath("$.stock").value(0));
    }

    @Test
    void createProduct_hargaNegatif_mengembalikan400() throws Exception {
        String body = """
            {"name":"Mie Instan Goreng","category":"Makanan","price":-1}
            """;

        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void createProduct_namaKosong_mengembalikan400() throws Exception {
        String body = """
            {"name":"","category":"Makanan","price":3500}
            """;

        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void createProduct_fieldWajibHilang_mengembalikan400() throws Exception {
        mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest());
    }

    // ---------- GET /stock-movements ----------

    @Test
    void getAllMovements_mengembalikan200() throws Exception {
        mockMvc.perform(get("/api/v1/stock-movements"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(0)));
    }

    // ---------- POST /stock-movements ----------

    @Test
    void recordMovement_stokMasuk_mengembalikan201DanMenambahStok() throws Exception {
        Product p = simpanProduk("Teh Botol", 0);
        String body = """
            {"productId":%d,"type":"IN","quantity":10}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.type").value("IN"))
            .andExpect(jsonPath("$.quantity").value(10))
            .andExpect(jsonPath("$.createdAt").exists());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(10));
    }

    @Test
    void recordMovement_stokKeluar_mengurangiStok() throws Exception {
        Product p = simpanProduk("Teh Botol", 10);
        String body = """
            {"productId":%d,"type":"OUT","quantity":4}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(6));
    }

    @Test
    void recordMovement_stokKeluarMelebihiStok_mengembalikan409() throws Exception {
        Product p = simpanProduk("Teh Botol", 3);
        String body = """
            {"productId":%d,"type":"OUT","quantity":5}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(3));
    }

    @Test
    void recordMovement_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"productId":999999,"type":"IN","quantity":5}
            """;

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    @Test
    void recordMovement_jumlahNol_mengembalikan400() throws Exception {
        Product p = simpanProduk("Teh Botol", 3);
        String body = """
            {"productId":%d,"type":"IN","quantity":0}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void recordMovement_tipeTidakValid_mengembalikan400() throws Exception {
        Product p = simpanProduk("Teh Botol", 3);
        String body = """
            {"productId":%d,"type":"SIDEWAYS","quantity":1}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v1/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }
}
