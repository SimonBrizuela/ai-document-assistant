package com.aiassistant.repository;

import com.aiassistant.model.Document;
import com.aiassistant.model.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface DocumentRepository extends JpaRepository<Document, Long> {
    
    Page<Document> findByUser(User user, Pageable pageable);
    
    List<Document> findByUser(User user);
    
    Optional<Document> findByIdAndUser(Long id, User user);
    
    @Query("SELECT d FROM Document d WHERE d.user = :user AND d.processingStatus = 'COMPLETED'")
    List<Document> findCompletedDocumentsByUser(@Param("user") User user);
    
    @Query("SELECT d FROM Document d WHERE d.processingStatus = 'PENDING' OR d.processingStatus = 'PROCESSING'")
    List<Document> findPendingDocuments();
    
    @Query("SELECT SUM(d.fileSize) FROM Document d WHERE d.user = :user")
    Long getTotalStorageByUser(@Param("user") User user);
    
    void deleteByCreatedAtBeforeAndUser(LocalDateTime date, User user);
}
