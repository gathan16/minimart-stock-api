package com.minimart.v2;

import com.minimart.model.Product;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Memastikan kontrak v1.0 tidak berubah setelah v2.0 ditambahkan. */
class V1CompatibilityTest extends V2TestSupport {

    @Test
    void v1_responsTidakMemuatFieldBaruV2() throws Exception {
        Product p = simpanProduk("Susu", "Minuman", 6000, 4, 5);

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").exists())
            .andExpect(jsonPath("$.name").value("Susu"))
            .andExpect(jsonPath("$.stock").value(4))
            .andExpect(jsonPath("$.minStock").doesNotExist())
            .andExpect(jsonPath("$.lowStock").doesNotExist())
            .andExpect(jsonPath("$.status").doesNotExist())
            .andExpect(jsonPath("$.createdAt").doesNotExist())
            .andExpect(jsonPath("$.updatedAt").doesNotExist());
    }

    @Test
    void v1_daftarTetapBerupaLarikDanHanyaProdukAktif() throws Exception {
        simpanProduk("Aktif", 0);
        simpanProdukArsip("Diarsipkan");

        mockMvc.perform(get("/api/v1/products"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(1)))
            .andExpect(jsonPath("$[0].name").value("Aktif"));
    }

    @Test
    void v1_produkArsipDianggapTidakAda() throws Exception {
        Product p = simpanProdukArsip("Diarsipkan");

        mockMvc.perform(get("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNotFound());
    }

    @Test
    void v1_deleteTetapPermanen() throws Exception {
        Product p = simpanProduk("Susu", 0);

        mockMvc.perform(delete("/api/v1/products/{id}", p.getId()))
            .andExpect(status().isNoContent());

        assertTrue(productRepository.findById(p.getId()).isEmpty());
    }
}
