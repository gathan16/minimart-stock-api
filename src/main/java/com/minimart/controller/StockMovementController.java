package com.minimart.controller;

import com.minimart.dto.StockMovementRequest;
import com.minimart.model.StockMovement;
import com.minimart.service.StockMovementService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/stock-movements")
public class StockMovementController {

    private final StockMovementService stockMovementService;

    public StockMovementController(StockMovementService stockMovementService) {
        this.stockMovementService = stockMovementService;
    }

    @GetMapping
    public ResponseEntity<List<StockMovement>> getAllMovements() {
        return ResponseEntity.ok(stockMovementService.findAll());
    }

    @PostMapping
    public ResponseEntity<StockMovement> recordMovement(
            @Valid @RequestBody StockMovementRequest request) {
        StockMovement movement = stockMovementService.recordMovement(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(movement);
    }
}
