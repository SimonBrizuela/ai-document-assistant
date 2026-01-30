-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create function for vector similarity search
CREATE OR REPLACE FUNCTION match_document_chunks(
    query_embedding vector(1536),
    match_threshold FLOAT,
    match_count INT,
    filter_document_ids BIGINT[]
)
RETURNS TABLE (
    id BIGINT,
    document_id BIGINT,
    content TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        dc.id,
        dc.document_id,
        dc.content,
        1 - (dc.embedding::vector <=> query_embedding) AS similarity
    FROM document_chunks dc
    WHERE 
        dc.embedding IS NOT NULL
        AND (filter_document_ids IS NULL OR dc.document_id = ANY(filter_document_ids))
        AND 1 - (dc.embedding::vector <=> query_embedding) > match_threshold
    ORDER BY dc.embedding::vector <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding ON document_chunks 
USING ivfflat (embedding::vector vector_cosine_ops)
WITH (lists = 100);
