package com.minimart.v2;

import com.minimart.model.Product;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET dan POST /api/v2/products. */
class ProductV2ReadTest extends V2TestSupport {

    private void siapkanTigaProduk() {
        simpanProduk("Susu UHT", "Minuman", 6000, 10, 5); // tidak menipis
        simpanProduk("Roti", "Makanan", 8000, 3, 5);      // menipis
        simpanProduk("Kopi", "Minuman", 3000, 0, 1);      // menipis
    }

    // ---------- GET (daftar) ----------

    @Test
    void list_bawaan_berhalaman() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content", hasSize(3)))
            .andExpect(jsonPath("$.page").value(0))
            .andExpect(jsonPath("$.size").value(20))
            .andExpect(jsonPath("$.totalElements").value(3))
            .andExpect(jsonPath("$.totalPages").value(1));
    }

    @Test
    void list_paginasi_halamanKedua() throws Exception {
        for (int i = 1; i <= 5; i++) {
            simpanProduk("Produk " + i, 1);
        }

        mockMvc.perform(get("/api/v2/products").param("page", "1").param("size", "2"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content", hasSize(2)))
            .andExpect(jsonPath("$.page").value(1))
            .andExpect(jsonPath("$.totalElements").value(5))
            .andExpect(jsonPath("$.totalPages").value(3));
    }

    @Test
    void list_filterKategori() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("category", "Minuman"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(2));
    }

    @Test
    void list_pencarianNama_tidakPekaHurufBesarKecil() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("q", "susu"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].name").value("Susu UHT"));
    }

    @Test
    void list_urutHargaMenurun() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("sort", "price,desc"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content[0].name").value("Roti"))
            .andExpect(jsonPath("$.content[2].name").value("Kopi"));
    }

    @Test
    void list_stokMenipis() throws Exception {
        siapkanTigaProduk();

        mockMvc.perform(get("/api/v2/products").param("lowStock", "true"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(2));

        mockMvc.perform(get("/api/v2/products").param("lowStock", "false"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].name").value("Susu UHT"));
    }

    @Test
    void list_produkArsipTidakTampilSecaraBawaan() throws Exception {
        simpanProduk("Aktif", 0);
        simpanProdukArsip("Diarsipkan");

        mockMvc.perform(get("/api/v2/products"))
            .andExpect(jsonPath("$.totalElements").value(1));
        mockMvc.perform(get("/api/v2/products").param("status", "ARCHIVED"))
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].status").value("ARCHIVED"));
        mockMvc.perform(get("/api/v2/products").param("status", "ALL"))
            .andExpect(jsonPath("$.totalElements").value(2));
    }

    @Test
    void list_parameterTidakValid_mengembalikan400DenganProblemJson() throws Exception {
        mockMvc.perform(get("/api/v2/products").param("size", "0"))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.instance").value("/api/v2/products"))
            .andExpect(jsonPath("$.timestamp").exists());

        mockMvc.perform(get("/api/v2/products").param("size", "101"))
            .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v2/products").param("page", "-1"))
            .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v2/products").param("sort", "foo,asc"))
            .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v2/products").param("sort", "price,up"))
            .andExpect(status().isBadRequest());
    }

    // ---------- GET (detail) ----------

    @Test
    void detail_ditemukan_memuatFieldV2() throws Exception {
        Product p = simpanProduk("Roti", "Makanan", 8000, 3, 5);

        mockMvc.perform(get("/api/v2/products/{id}", p.getId()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Roti"))
            .andExpect(jsonPath("$.stock").value(3))
            .andExpect(jsonPath("$.minStock").value(5))
            .andExpect(jsonPath("$.lowStock").value(true))
            .andExpect(jsonPath("$.status").value("ACTIVE"))
            .andExpect(jsonPath("$.createdAt").exists())
            .andExpect(jsonPath("$.updatedAt").exists());
    }

    @Test
    void detail_tidakDitemukan_mengembalikan404ProblemJson() throws Exception {
        mockMvc.perform(get("/api/v2/products/{id}", 999999))
            .andExpect(status().isNotFound())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.status").value(404))
            .andExpect(jsonPath("$.detail").value("Produk dengan id 999999 tidak ditemukan"));
    }

    // ---------- POST ----------

    @Test
    void create_valid_mengembalikan201() throws Exception {
        String body = """
            {"name":"Susu UHT","category":"Minuman","price":6000,"minStock":5}
            """;

        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").exists())
            .andExpect(jsonPath("$.stock").value(0))
            .andExpect(jsonPath("$.minStock").value(5))
            .andExpect(jsonPath("$.status").value("ACTIVE"))
            .andExpect(jsonPath("$.createdAt").exists());
    }

    @Test
    void create_tanpaMinStock_bernilaiNol() throws Exception {
        String body = """
            {"name":"Roti","category":"Makanan","price":8000}
            """;

        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.minStock").value(0));
    }

    @Test
    void create_hargaNegatif_galatPerField() throws Exception {
        String body = """
            {"name":"Roti","category":"Makanan","price":-1}
            """;

        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
            .andExpect(jsonPath("$.errors[0].field").value("price"));
    }

    @Test
    void create_bodyKosong_memuatTigaGalat() throws Exception {
        mockMvc.perform(post("/api/v2/products")
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors", hasSize(3)));
    }
}
