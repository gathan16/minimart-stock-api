package com.minimart.config;

import io.swagger.v3.oas.models.info.Info;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public GroupedOpenApi apiV2() {
        return GroupedOpenApi.builder()
            .group("v2")
            .displayName("API v2.0")
            .pathsToMatch("/api/v2/**")
            .addOpenApiCustomizer(openApi -> openApi.info(new Info()
                .title("MiniMart Stock API")
                .description("API pengelolaan stok minimarket, versi 2.0.")
                .version("2.0.0")))
            .build();
    }

    @Bean
    public GroupedOpenApi apiV1() {
        return GroupedOpenApi.builder()
            .group("v1")
            .displayName("API v1.0 (deprecated)")
            .pathsToMatch("/api/v1/**")
            .addOpenApiCustomizer(openApi -> {
                openApi.info(new Info()
                    .title("MiniMart Stock API")
                    .description("API pengelolaan stok minimarket, versi 1.0 (deprecated, gunakan v2.0).")
                    .version("1.0.0"));
                // tandai seluruh operasi v1 sebagai deprecated
                if (openApi.getPaths() != null) {
                    openApi.getPaths().values().forEach(item ->
                        item.readOperations().forEach(op -> op.setDeprecated(true)));
                }
            })
            .build();
    }
}
