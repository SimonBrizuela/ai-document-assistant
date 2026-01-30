package com.aiassistant.controller;

import com.aiassistant.dto.ApiResponse;
import com.aiassistant.dto.DocumentResponse;
import com.aiassistant.model.Document;
import com.aiassistant.model.User;
import com.aiassistant.security.UserPrincipal;
import com.aiassistant.service.DocumentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/api/documents")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Documents", description = "Document management endpoints")
public class DocumentController {

    private final DocumentService documentService;

    @PostMapping("/upload")
    @Operation(summary = "Upload a document")
    public ResponseEntity<ApiResponse> uploadDocument(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        try {
            User user = User.builder().id(userPrincipal.getId()).build();
            Document document = documentService.uploadDocument(file, user);
            
            CompletableFuture.runAsync(() -> documentService.processDocument(document.getId()));
            
            DocumentResponse response = DocumentResponse.fromEntity(document);
            return ResponseEntity.ok(ApiResponse.success("Document uploaded successfully", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Failed to upload document: " + e.getMessage()));
        }
    }

    @GetMapping
    @Operation(summary = "Get user's documents")
    public ResponseEntity<Page<DocumentResponse>> getDocuments(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        User user = User.builder().id(userPrincipal.getId()).build();
        Page<Document> documents = documentService.getUserDocuments(user, PageRequest.of(page, size));
        Page<DocumentResponse> response = documents.map(DocumentResponse::fromEntity);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get document by ID")
    public ResponseEntity<DocumentResponse> getDocument(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        User user = User.builder().id(userPrincipal.getId()).build();
        Document document = documentService.getDocument(id, user);
        DocumentResponse response = DocumentResponse.fromEntity(document);
        
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a document")
    public ResponseEntity<ApiResponse> deleteDocument(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        try {
            User user = User.builder().id(userPrincipal.getId()).build();
            documentService.deleteDocument(id, user);
            return ResponseEntity.ok(ApiResponse.success("Document deleted successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Failed to delete document: " + e.getMessage()));
        }
    }
}
