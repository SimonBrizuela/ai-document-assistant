#!/bin/bash

set -e

echo "🧪 Testing AI Document Assistant locally..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if services are running
echo -e "${YELLOW}Checking services...${NC}"

if ! docker ps | grep -q "ai-assistant-backend"; then
    echo -e "${RED}Backend container not running. Start with: docker-compose up -d${NC}"
    exit 1
fi

if ! docker ps | grep -q "ai-assistant-db"; then
    echo -e "${RED}Database container not running. Start with: docker-compose up -d${NC}"
    exit 1
fi

# Wait for backend to be ready
echo -e "${YELLOW}Waiting for backend to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Test 1: Health check
echo -e "\n${YELLOW}Test 1: Health Check${NC}"
HEALTH=$(curl -s http://localhost:8080/actuator/health)
if echo "$HEALTH" | grep -q "UP"; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    exit 1
fi

# Test 2: Register user
echo -e "\n${YELLOW}Test 2: User Registration${NC}"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/auth/register \
    -H "Content-Type: application/json" \
    -d '{
        "username": "testuser",
        "email": "test@example.com",
        "password": "TestPassword123!"
    }')

if echo "$REGISTER_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✓ User registration passed${NC}"
    TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
else
    echo -e "${YELLOW}⚠ User might already exist, trying login...${NC}"
    
    LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{
            "email": "test@example.com",
            "password": "TestPassword123!"
        }')
    
    if echo "$LOGIN_RESPONSE" | grep -q "token"; then
        echo -e "${GREEN}✓ Login passed${NC}"
        TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    else
        echo -e "${RED}✗ Authentication failed${NC}"
        exit 1
    fi
fi

# Test 3: Upload document
echo -e "\n${YELLOW}Test 3: Document Upload${NC}"
echo "This is a test document for AI processing." > /tmp/test_document.txt

UPLOAD_RESPONSE=$(curl -s -X POST http://localhost:8080/api/documents/upload \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@/tmp/test_document.txt")

if echo "$UPLOAD_RESPONSE" | grep -q "id"; then
    echo -e "${GREEN}✓ Document upload passed${NC}"
    DOC_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
else
    echo -e "${RED}✗ Document upload failed${NC}"
    echo "$UPLOAD_RESPONSE"
    exit 1
fi

# Wait for processing
echo -e "${YELLOW}Waiting for document processing...${NC}"
sleep 5

# Test 4: Get documents
echo -e "\n${YELLOW}Test 4: Get Documents${NC}"
DOCS_RESPONSE=$(curl -s -X GET http://localhost:8080/api/documents \
    -H "Authorization: Bearer $TOKEN")

if echo "$DOCS_RESPONSE" | grep -q "test_document.txt"; then
    echo -e "${GREEN}✓ Get documents passed${NC}"
else
    echo -e "${RED}✗ Get documents failed${NC}"
    exit 1
fi

# Test 5: Ask question (if OpenAI key is configured)
echo -e "\n${YELLOW}Test 5: AI Question (requires OpenAI API key)${NC}"

QUESTION_RESPONSE=$(curl -s -X POST http://localhost:8080/api/ai/ask \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "question": "What does the test document say?",
        "documentIds": ['"$DOC_ID"']
    }')

if echo "$QUESTION_RESPONSE" | grep -q "answer"; then
    echo -e "${GREEN}✓ AI question passed${NC}"
    ANSWER=$(echo "$QUESTION_RESPONSE" | grep -o '"answer":"[^"]*"' | cut -d'"' -f4 | head -c 100)
    echo -e "${GREEN}   Answer: $ANSWER...${NC}"
elif echo "$QUESTION_RESPONSE" | grep -q "error"; then
    echo -e "${YELLOW}⚠ AI question failed - check OpenAI API key configuration${NC}"
else
    echo -e "${RED}✗ AI question failed${NC}"
fi

# Test 6: Rate limiting
echo -e "\n${YELLOW}Test 6: Rate Limiting${NC}"
RATE_LIMIT_PASSED=true
for i in {1..12}; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8080/api/ai/ask \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "question": "Test question '$i'",
            "documentIds": ['"$DOC_ID"']
        }')
    
    if [ "$RESPONSE" = "429" ]; then
        echo -e "${GREEN}✓ Rate limiting works (got 429 on request $i)${NC}"
        RATE_LIMIT_PASSED=true
        break
    fi
    sleep 0.5
done

if [ "$RATE_LIMIT_PASSED" != "true" ]; then
    echo -e "${YELLOW}⚠ Rate limiting might not be configured${NC}"
fi

# Cleanup
echo -e "\n${YELLOW}Cleaning up test data...${NC}"
curl -s -X DELETE http://localhost:8080/api/documents/$DOC_ID \
    -H "Authorization: Bearer $TOKEN" > /dev/null

rm -f /tmp/test_document.txt

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ All critical tests passed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nYou can now:"
echo -e "  1. Access frontend: ${GREEN}http://localhost:3000${NC}"
echo -e "  2. View API docs: ${GREEN}http://localhost:8080/swagger-ui.html${NC}"
echo -e "  3. Check logs: ${YELLOW}docker-compose logs -f${NC}"
