package com.aiassistant.repository;

import com.aiassistant.model.Document;
import com.aiassistant.model.DocumentChunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DocumentChunkRepository extends JpaRepository<DocumentChunk, Long> {
    
    List<DocumentChunk> findByDocument(Document document);
    
    void deleteByDocument(Document document);
    
    @Query(value = """
        SELECT dc.id, dc.document_id, dc.chunk_index, dc.content, dc.token_count, 
               dc.embedding, dc.created_at,
               1 - (dc.embedding::vector <=> CAST(:queryEmbedding AS vector)) AS similarity
        FROM document_chunks dc
        WHERE dc.document_id IN :documentIds
          AND dc.embedding IS NOT NULL
          AND 1 - (dc.embedding::vector <=> CAST(:queryEmbedding AS vector)) > :threshold
        ORDER BY dc.embedding::vector <=> CAST(:queryEmbedding AS vector)
        LIMIT :limit
        """, nativeQuery = true)
    List<Object[]> findSimilarChunks(
        @Param("queryEmbedding") String queryEmbedding,
        @Param("documentIds") List<Long> documentIds,
        @Param("threshold") double threshold,
        @Param("limit") int limit
    );
    
    @Query(value = """
        SELECT dc.id, dc.document_id, dc.chunk_index, dc.content, dc.token_count, 
               dc.embedding, dc.created_at,
               1 - (dc.embedding::vector <=> CAST(:queryEmbedding AS vector)) AS similarity
        FROM document_chunks dc
        INNER JOIN documents d ON dc.document_id = d.id
        WHERE d.user_id = :userId
          AND dc.embedding IS NOT NULL
          AND 1 - (dc.embedding::vector <=> CAST(:queryEmbedding AS vector)) > :threshold
        ORDER BY dc.embedding::vector <=> CAST(:queryEmbedding AS vector)
        LIMIT :limit
        """, nativeQuery = true)
    List<Object[]> findSimilarChunksByUser(
        @Param("queryEmbedding") String queryEmbedding,
        @Param("userId") Long userId,
        @Param("threshold") double threshold,
        @Param("limit") int limit
    );
}
