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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProductModifyTest {

    @Autowired MockMvc mockMvc;
    @Autowired ProductRepository productRepository;
    @Autowired StockMovementRepository movementRepository;

    @BeforeEach
    void bersihkanData() {
        movementRepository.deleteAll();
        productRepository.deleteAll();
    }

    private Product simpanProduk(int stok) {
        Product p = new Product();
        p.setName("Mie Instan Goreng");
        p.setCategory("Makanan");
        p.setPrice(3500.0);
        p.setStock(stok);
        return productRepository.save(p);
    }

    // ---------- PUT ----------

    @Test
    void put_valid_mengganti_dataTanpaMenyentuhStok() throws Exception {
        Product p = simpanProduk(25);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Teh Botol"))
            .andExpect(jsonPath("$.category").value("Minuman"))
            .andExpect(jsonPath("$.price").value(5000.0))
            .andExpect(jsonPath("$.stock").value(25));
    }

    @Test
    void put_idempotent_hasilSamaSetiapPemanggilan() throws Exception {
        Product p = simpanProduk(0);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000}
            """;

        String pertama = mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(content().json(pertama));
    }

    @Test
    void put_fieldTidakLengkap_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);
        String body = """
            {"name":"Teh Botol"}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void put_hargaNegatif_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":-10}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void put_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000}
            """;

        mockMvc.perform(put("/api/v1/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    // ---------- PATCH ----------

    @Test
    void patch_hanyaHarga_fieldLainTidakBerubah() throws Exception {
        Product p = simpanProduk(7);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":4000}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.price").value(4000.0))
            .andExpect(jsonPath("$.name").value("Mie Instan Goreng"))
            .andExpect(jsonPath("$.category").value("Makanan"))
            .andExpect(jsonPath("$.stock").value(7));
    }

    @Test
    void patch_bodyKosong_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_hargaNegatif_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":-5}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_namaHanyaSpasi_mengembalikan400() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(patch("/api/v1/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"   \"}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(patch("/api/v1/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":4000}"))
            .andExpect(status().isNotFound());
    }

    // ---------- DELETE ----------

    @Test
    void delete_stokNol_mengembalikan204DanProdukHilang() throws Exception {
        Product p = simpanProduk(0);

        mockMvc.perform(delete("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNotFound());
    }

    @Test
    void delete_masihAdaStok_mengembalikan409() throws Exception {
        Product p = simpanProduk(5);

        mockMvc.perform(delete("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isConflict());

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isOk());
    }

    @Test
    void delete_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(delete("/api/v1/products/{id}", 999999))
            .andExpect(status().isNotFound());
    }
}
