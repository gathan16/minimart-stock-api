package com.minimart.v2;

import com.minimart.dto.MovementType;
import com.minimart.model.Product;
import com.minimart.model.StockMovement;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.OffsetDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET dan POST /api/v2/stock-movements. */
class StockMovementV2Test extends V2TestSupport {

    private static final OffsetDateTime LAMA = OffsetDateTime.parse("2020-01-01T00:00:00Z");

    // ---------- POST ----------

    @Test
    void record_stokMasuk_menambahStokDanMenyimpanCatatan() throws Exception {
        Product p = simpanProduk("Teh", 0);
        String body = """
            {"productId":%d,"type":"IN","quantity":10,"note":"Restock"}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.type").value("IN"))
            .andExpect(jsonPath("$.quantity").value(10))
            .andExpect(jsonPath("$.note").value("Restock"))
            .andExpect(jsonPath("$.createdAt").exists());

        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(10));
    }

    @Test
    void record_stokKeluarMelebihiStok_mengembalikan409() throws Exception {
        Product p = simpanProduk("Teh", 3);
        String body = """
            {"productId":%d,"type":"OUT","quantity":5}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.detail").value("Stok tidak mencukupi"));

        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(jsonPath("$.stock").value(3));
    }

    @Test
    void record_produkTidakAda_mengembalikan404() throws Exception {
        String body = """
            {"productId":999999,"type":"IN","quantity":1}
            """;

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isNotFound());
    }

    @Test
    void record_produkDiarsipkan_mengembalikan409() throws Exception {
        Product p = simpanProdukArsip("Lama");
        String body = """
            {"productId":%d,"type":"IN","quantity":1}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());
    }

    @Test
    void record_tipeTidakDikenal_mengembalikan400() throws Exception {
        Product p = simpanProduk("Teh", 3);
        String body = """
            {"productId":%d,"type":"SIDEWAYS","quantity":1}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }

    @Test
    void record_jumlahNol_galatPerField() throws Exception {
        Product p = simpanProduk("Teh", 3);
        String body = """
            {"productId":%d,"type":"IN","quantity":0}
            """.formatted(p.getId());

        mockMvc.perform(post("/api/v2/stock-movements")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors[0].field").value("quantity"));
    }

    // ---------- GET ----------

    @Test
    void list_filterProductIdDanType() throws Exception {
        Product a = simpanProduk("A", 0);
        Product b = simpanProduk("B", 0);
        simpanMovement(a.getId(), MovementType.IN, 5, OffsetDateTime.now());
        simpanMovement(a.getId(), MovementType.OUT, 2, OffsetDateTime.now());
        simpanMovement(b.getId(), MovementType.IN, 7, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements").param("productId", a.getId().toString()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(2));

        mockMvc.perform(get("/api/v2/stock-movements").param("type", "IN"))
            .andExpect(jsonPath("$.totalElements").value(2));

        mockMvc.perform(get("/api/v2/stock-movements")
                .param("productId", b.getId().toString()).param("type", "OUT"))
            .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void list_filterRentangWaktu() throws Exception {
        Product a = simpanProduk("A", 0);
        simpanMovement(a.getId(), MovementType.IN, 1, LAMA);
        simpanMovement(a.getId(), MovementType.IN, 2, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements").param("from", "2025-01-01T00:00:00Z"))
            .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(get("/api/v2/stock-movements").param("to", "2021-01-01T00:00:00Z"))
            .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(get("/api/v2/stock-movements")
                .param("from", "2025-01-01T00:00:00Z").param("to", "2021-01-01T00:00:00Z"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void list_urutBawaanTerbaruDulu() throws Exception {
        Product a = simpanProduk("A", 0);
        simpanMovement(a.getId(), MovementType.IN, 1, LAMA);
        simpanMovement(a.getId(), MovementType.IN, 2, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements"))
            .andExpect(jsonPath("$.content[0].quantity").value(2))
            .andExpect(jsonPath("$.content[1].quantity").value(1));
    }

    @Test
    void detail_ditemukanDanTidakDitemukan() throws Exception {
        Product a = simpanProduk("A", 0);
        StockMovement m = simpanMovement(a.getId(), MovementType.IN, 5, OffsetDateTime.now());

        mockMvc.perform(get("/api/v2/stock-movements/{id}", m.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.quantity").value(5));

        mockMvc.perform(get("/api/v2/stock-movements/{id}", 999999))
            .andExpect(status().isNotFound())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }
}
