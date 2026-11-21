package com.minimart.v2;

import com.minimart.model.Product;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** PUT, PATCH, DELETE (arsip), dan restore pada /api/v2/products. */
class ProductV2ModifyTest extends V2TestSupport {

    // ---------- PUT ----------

    @Test
    void put_valid_menggantiDataTanpaMenyentuhStok() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 25, 5);
        String body = """
            {"name":"Teh Botol","category":"Minuman","price":5000,"minStock":2}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Teh Botol"))
            .andExpect(jsonPath("$.price").value(5000.0))
            .andExpect(jsonPath("$.minStock").value(2))
            .andExpect(jsonPath("$.stock").value(25));
    }

    @Test
    void put_tanpaMinStock_kembaliKeNol() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 0, 5);
        String body = """
            {"name":"Susu","category":"Minuman","price":6000}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.minStock").value(0));
    }

    @Test
    void put_tidakLengkap_mengembalikan400() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Hanya nama\"}"))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }

    @Test
    void put_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"name":"X","category":"Y","price":1}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    @Test
    void put_produkDiarsipkan_mengembalikan409() throws Exception {
        Product p = simpanProdukArsip("Lama");
        String body = """
            {"name":"X","category":"Y","price":1}
            """;

        mockMvc.perform(put("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());
    }

    // ---------- PATCH ----------

    @Test
    void patch_hanyaHarga_fieldLainTetap() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 7, 5);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":4000}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.price").value(4000.0))
            .andExpect(jsonPath("$.name").value("Susu"))
            .andExpect(jsonPath("$.minStock").value(5))
            .andExpect(jsonPath("$.stock").value(7));
    }

    @Test
    void patch_minStock_berubah() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 7, 5);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"minStock\":10}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.minStock").value(10))
            .andExpect(jsonPath("$.lowStock").value(true));
    }

    @Test
    void patch_bodyKosong_mengembalikan400() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void patch_hargaNegatif_mengembalikan400() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":-5}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors[0].field").value("price"));
    }

    @Test
    void patch_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(patch("/api/v2/products/{id}", 999999)
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":1}"))
            .andExpect(status().isNotFound());
    }

    @Test
    void patch_produkDiarsipkan_mengembalikan409() throws Exception {
        Product p = simpanProdukArsip("Lama");

        mockMvc.perform(patch("/api/v2/products/{id}", p.getId())
                .contentType(MediaType.APPLICATION_JSON).content("{\"price\":1}"))
            .andExpect(status().isConflict());
    }

    // ---------- DELETE (soft delete) ----------

    @Test
    void delete_stokNol_mengarsipkanProduk() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(delete("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isNoContent());

        // data tetap ada, hanya statusnya berubah
        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ARCHIVED"));
    }

    @Test
    void delete_masihAdaStok_mengembalikan409() throws Exception {
        Product p = simpanProduk("Susu", 5);

        mockMvc.perform(delete("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isConflict())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.detail").value("Produk masih memiliki stok"));
    }

    @Test
    void delete_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(delete("/api/v2/products/{id}", 999999))
            .andExpect(status().isNotFound());
    }

    @Test
    void delete_sudahDiarsipkan_mengembalikan404() throws Exception {
        Product p = simpanProdukArsip("Lama");

        mockMvc.perform(delete("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isNotFound());
    }

    // ---------- RESTORE ----------

    @Test
    void restore_produkDiarsipkan_kembaliAktif() throws Exception {
        Product p = simpanProdukArsip("Lama");

        mockMvc.perform(post("/api/v2/products/{id}/restore", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void restore_produkSudahAktif_mengembalikan409() throws Exception {
        Product p = simpanProduk("Aktif", 0);

        mockMvc.perform(post("/api/v2/products/{id}/restore", p.getId()))
            .andExpect(status().isConflict());
    }

    @Test
    void restore_produkTidakAda_mengembalikan404() throws Exception {
        mockMvc.perform(post("/api/v2/products/{id}/restore", 999999))
            .andExpect(status().isNotFound());
    }
}
