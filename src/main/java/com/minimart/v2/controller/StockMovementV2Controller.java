package com.minimart.v2.controller;

import com.minimart.dto.MovementType;
import com.minimart.v2.dto.PageResponse;
import com.minimart.v2.dto.StockMovementV2Request;
import com.minimart.v2.dto.StockMovementV2Response;
import com.minimart.v2.service.StockMovementV2Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;

@RestController
@RequestMapping("/api/v2/stock-movements")
@Tag(name = "Stock Movements", description = "Pencatatan pergerakan stok (hanya tambah)")
public class StockMovementV2Controller {

    private final StockMovementV2Service movementService;

    public StockMovementV2Controller(StockMovementV2Service movementService) {
        this.movementService = movementService;
    }

    @GetMapping
    @Operation(summary = "Ambil riwayat pergerakan stok (berhalaman)")
    public ResponseEntity<PageResponse<StockMovementV2Response>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort,
            @RequestParam(required = false) Long productId,
            @RequestParam(required = false) MovementType type,
            @RequestParam(required = false)
                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false)
                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to) {
        return ResponseEntity.ok(
            movementService.list(page, size, sort, productId, type, from, to));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Ambil detail pergerakan stok")
    public ResponseEntity<StockMovementV2Response> get(@PathVariable Long id) {
        return ResponseEntity.ok(movementService.get(id));
    }

    @PostMapping
    @Operation(summary = "Catat stok masuk atau keluar")
    public ResponseEntity<StockMovementV2Response> record(
            @Valid @RequestBody StockMovementV2Request request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(movementService.record(request));
    }
}
