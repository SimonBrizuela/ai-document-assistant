package com.aiassistant.service;

import com.aiassistant.model.Document;
import com.aiassistant.model.DocumentChunk;
import com.aiassistant.model.User;
import com.aiassistant.repository.DocumentChunkRepository;
import com.aiassistant.repository.DocumentRepository;
import com.aiassistant.service.ai.AIProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.xwpf.extractor.XWPFWordExtractor;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DocumentService {

    private final DocumentRepository documentRepository;
    private final DocumentChunkRepository documentChunkRepository;
    private final StorageService storageService;
    private final AIProvider aiProvider;

    @Value("${app.document.chunk-size}")
    private int chunkSize;

    @Value("${app.document.chunk-overlap}")
    private int chunkOverlap;

    @Transactional
    public Document uploadDocument(MultipartFile file, User user) throws IOException {
        String originalFilename = file.getOriginalFilename();
        String filename = UUID.randomUUID().toString() + "_" + originalFilename;
        String storagePath = storageService.store(file, user.getId(), filename);

        Document document = Document.builder()
                .filename(filename)
                .originalFilename(originalFilename)
                .contentType(file.getContentType())
                .fileSize(file.getSize())
                .storagePath(storagePath)
                .user(user)
                .processingStatus(Document.ProcessingStatus.PENDING)
                .build();

        return documentRepository.save(document);
    }

    @Transactional
    public void processDocument(Long documentId) {
        Document document = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        try {
            document.setProcessingStatus(Document.ProcessingStatus.PROCESSING);
            documentRepository.save(document);

            String text = extractText(document);
            document.setExtractedText(text);

            List<String> chunks = chunkText(text);
            int chunkIndex = 0;
            
            for (String chunkContent : chunks) {
                List<Double> embedding = aiProvider.generateEmbedding(chunkContent);
                String embeddingStr = formatEmbedding(embedding);

                DocumentChunk chunk = DocumentChunk.builder()
                        .document(document)
                        .chunkIndex(chunkIndex++)
                        .content(chunkContent)
                        .tokenCount(aiProvider.estimateTokens(chunkContent))
                        .embedding(embeddingStr)
                        .build();

                documentChunkRepository.save(chunk);
            }

            document.setProcessingStatus(Document.ProcessingStatus.COMPLETED);
            document.setProcessedAt(LocalDateTime.now());
            documentRepository.save(document);

            log.info("Successfully processed document {} with {} chunks", documentId, chunks.size());
        } catch (Exception e) {
            log.error("Failed to process document " + documentId, e);
            document.setProcessingStatus(Document.ProcessingStatus.FAILED);
            document.setProcessingError(e.getMessage());
            documentRepository.save(document);
        }
    }

    private String extractText(Document document) throws IOException {
        InputStream inputStream = storageService.load(document.getStoragePath());
        String contentType = document.getContentType();

        if (contentType.equals("application/pdf")) {
            return extractFromPdf(inputStream);
        } else if (contentType.equals("application/vnd.openxmlformats-officedocument.wordprocessingml.document")) {
            return extractFromDocx(inputStream);
        } else if (contentType.equals("text/plain")) {
            return new String(inputStream.readAllBytes(), StandardCharsets.UTF_8);
        } else {
            throw new IllegalArgumentException("Unsupported file type: " + contentType);
        }
    }

    private String extractFromPdf(InputStream inputStream) throws IOException {
        try (PDDocument document = PDDocument.load(inputStream)) {
            PDFTextStripper stripper = new PDFTextStripper();
            return stripper.getText(document);
        }
    }

    private String extractFromDocx(InputStream inputStream) throws IOException {
        try (XWPFDocument document = new XWPFDocument(inputStream);
             XWPFWordExtractor extractor = new XWPFWordExtractor(document)) {
            return extractor.getText();
        }
    }

    private List<String> chunkText(String text) {
        List<String> chunks = new ArrayList<>();
        String[] sentences = text.split("(?<=[.!?])\\s+");
        
        StringBuilder currentChunk = new StringBuilder();
        
        for (String sentence : sentences) {
            if (currentChunk.length() + sentence.length() > chunkSize) {
                if (currentChunk.length() > 0) {
                    chunks.add(currentChunk.toString().trim());
                    
                    int overlapStart = Math.max(0, currentChunk.length() - chunkOverlap);
                    currentChunk = new StringBuilder(currentChunk.substring(overlapStart));
                }
            }
            currentChunk.append(sentence).append(" ");
        }
        
        if (currentChunk.length() > 0) {
            chunks.add(currentChunk.toString().trim());
        }
        
        return chunks;
    }

    private String formatEmbedding(List<Double> embedding) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < embedding.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append(embedding.get(i));
        }
        sb.append("]");
        return sb.toString();
    }

    @Transactional(readOnly = true)
    public Page<Document> getUserDocuments(User user, Pageable pageable) {
        return documentRepository.findByUser(user, pageable);
    }

    @Transactional(readOnly = true)
    public Document getDocument(Long id, User user) {
        return documentRepository.findByIdAndUser(id, user)
                .orElseThrow(() -> new RuntimeException("Document not found"));
    }

    @Transactional
    public void deleteDocument(Long id, User user) {
        Document document = getDocument(id, user);
        storageService.delete(document.getStoragePath());
        documentRepository.delete(document);
    }

    @Transactional(readOnly = true)
    public List<DocumentChunk> findSimilarChunks(String query, User user, int limit) {
        List<Double> queryEmbedding = aiProvider.generateEmbedding(query);
        String embeddingStr = formatEmbedding(queryEmbedding);
        
        List<Object[]> results = documentChunkRepository.findSimilarChunksByUser(
                embeddingStr, user.getId(), 0.7, limit);
        
        List<DocumentChunk> chunks = new ArrayList<>();
        for (Object[] row : results) {
            DocumentChunk chunk = new DocumentChunk();
            chunk.setId(((Number) row[0]).longValue());
            chunk.setContent((String) row[3]);
            chunks.add(chunk);
        }
        
        return chunks;
    }
}
