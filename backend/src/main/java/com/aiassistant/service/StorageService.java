package com.aiassistant.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

@Service
@Slf4j
public class StorageService {

    @Value("${app.storage.type}")
    private String storageType;

    @Value("${app.storage.s3.bucket:}")
    private String s3Bucket;

    @Value("${app.storage.local.path:./storage}")
    private String localStoragePath;

    private final S3Client s3Client;

    public StorageService(S3Client s3Client) {
        this.s3Client = s3Client;
    }

    public String store(MultipartFile file, Long userId, String filename) throws IOException {
        if ("s3".equals(storageType)) {
            return storeInS3(file, userId, filename);
        } else {
            return storeLocally(file, userId, filename);
        }
    }

    private String storeInS3(MultipartFile file, Long userId, String filename) throws IOException {
        String key = String.format("users/%d/documents/%s", userId, filename);
        
        try {
            PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                    .bucket(s3Bucket)
                    .key(key)
                    .contentType(file.getContentType())
                    .build();

            s3Client.putObject(putObjectRequest, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
            
            log.info("Stored file in S3: {}", key);
            return key;
        } catch (S3Exception e) {
            log.error("Failed to store file in S3", e);
            throw new IOException("Failed to store file in S3", e);
        }
    }

    private String storeLocally(MultipartFile file, Long userId, String filename) throws IOException {
        Path userDir = Paths.get(localStoragePath, "users", userId.toString(), "documents");
        Files.createDirectories(userDir);
        
        Path filePath = userDir.resolve(filename);
        Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);
        
        log.info("Stored file locally: {}", filePath);
        return filePath.toString();
    }

    public InputStream load(String path) throws IOException {
        if ("s3".equals(storageType)) {
            return loadFromS3(path);
        } else {
            return loadLocally(path);
        }
    }

    private InputStream loadFromS3(String key) throws IOException {
        try {
            GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                    .bucket(s3Bucket)
                    .key(key)
                    .build();

            return s3Client.getObject(getObjectRequest);
        } catch (S3Exception e) {
            log.error("Failed to load file from S3", e);
            throw new IOException("Failed to load file from S3", e);
        }
    }

    private InputStream loadLocally(String path) throws IOException {
        return Files.newInputStream(Paths.get(path));
    }

    public void delete(String path) {
        try {
            if ("s3".equals(storageType)) {
                deleteFromS3(path);
            } else {
                deleteLocally(path);
            }
        } catch (Exception e) {
            log.error("Failed to delete file: " + path, e);
        }
    }

    private void deleteFromS3(String key) {
        DeleteObjectRequest deleteObjectRequest = DeleteObjectRequest.builder()
                .bucket(s3Bucket)
                .key(key)
                .build();

        s3Client.deleteObject(deleteObjectRequest);
        log.info("Deleted file from S3: {}", key);
    }

    private void deleteLocally(String path) throws IOException {
        Files.deleteIfExists(Paths.get(path));
        log.info("Deleted file locally: {}", path);
    }
}
