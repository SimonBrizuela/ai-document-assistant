package com.aiassistant.repository;

import com.aiassistant.model.Conversation;
import com.aiassistant.model.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, Long> {
    
    Page<Conversation> findByUserOrderByUpdatedAtDesc(User user, Pageable pageable);
    
    Optional<Conversation> findByIdAndUser(Long id, User user);
    
    @Query("SELECT c FROM Conversation c LEFT JOIN FETCH c.messages WHERE c.id = :id AND c.user = :user")
    Optional<Conversation> findByIdAndUserWithMessages(@Param("id") Long id, @Param("user") User user);
    
    void deleteByCreatedAtBefore(LocalDateTime date);
    
    long countByUser(User user);
}
