package com.aiassistant.repository;

import com.aiassistant.model.AuditLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {
    
    Page<AuditLog> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);
    
    Page<AuditLog> findByActionOrderByCreatedAtDesc(String action, Pageable pageable);
    
    @Query("SELECT SUM(a.tokenCount) FROM AuditLog a WHERE a.userId = :userId AND a.createdAt >= :since")
    Long getTotalTokensByUserSince(@Param("userId") Long userId, @Param("since") LocalDateTime since);
    
    @Query("SELECT SUM(a.cost) FROM AuditLog a WHERE a.userId = :userId AND a.createdAt >= :since")
    Double getTotalCostByUserSince(@Param("userId") Long userId, @Param("since") LocalDateTime since);
    
    @Query("SELECT SUM(a.cost) FROM AuditLog a WHERE a.createdAt >= :since")
    Double getTotalCostSince(@Param("since") LocalDateTime since);
    
    void deleteByCreatedAtBefore(LocalDateTime date);
}
