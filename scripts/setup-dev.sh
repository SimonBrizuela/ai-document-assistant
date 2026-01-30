#!/bin/bash

set -e

echo "🚀 Setting up AI Document Assistant development environment..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose found${NC}"

# Setup environment file
echo -e "\n${YELLOW}Setting up environment variables...${NC}"

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env from .env.example${NC}"
    else
        echo -e "${YELLOW}Creating default .env file...${NC}"
        cat > .env << EOF
OPENAI_API_KEY=your-openai-api-key-here
JWT_SECRET=$(openssl rand -base64 32)
AWS_REGION=us-east-1
AWS_S3_BUCKET=ai-assistant-documents
EOF
        echo -e "${GREEN}✓ Created .env with generated JWT secret${NC}"
    fi
    
    echo -e "${YELLOW}⚠ Please edit .env and add your OpenAI API key${NC}"
    echo -e "${YELLOW}   Get one at: https://platform.openai.com/api-keys${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Check if OpenAI key is set
if grep -q "your-openai-api-key-here" .env; then
    echo -e "${RED}⚠ WARNING: OpenAI API key not set in .env${NC}"
    echo -e "${YELLOW}   The application will start but AI features won't work${NC}"
fi

# Pull Docker images
echo -e "\n${YELLOW}Pulling Docker images...${NC}"
docker-compose pull

# Build backend
echo -e "\n${YELLOW}Building backend...${NC}"
cd backend
if [ -f ./mvnw ]; then
    ./mvnw clean package -DskipTests
else
    mvn clean package -DskipTests
fi
cd ..
echo -e "${GREEN}✓ Backend built successfully${NC}"

# Install frontend dependencies
echo -e "\n${YELLOW}Installing frontend dependencies...${NC}"
cd frontend
npm install
cd ..
echo -e "${GREEN}✓ Frontend dependencies installed${NC}"

# Start services
echo -e "\n${YELLOW}Starting services...${NC}"
docker-compose up -d

# Wait for services to be ready
echo -e "\n${YELLOW}Waiting for services to start...${NC}"
echo -n "Waiting for backend"
for i in {1..30}; do
    if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo -e "\n${GREEN}✓ Backend is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Display status
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Development environment ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nServices:"
echo -e "  Frontend:  ${GREEN}http://localhost:3000${NC}"
echo -e "  Backend:   ${GREEN}http://localhost:8080${NC}"
echo -e "  API Docs:  ${GREEN}http://localhost:8080/swagger-ui.html${NC}"
echo -e "  Database:  ${GREEN}postgresql://localhost:5432/aiassistant${NC}"

echo -e "\nUseful commands:"
echo -e "  View logs:        ${YELLOW}docker-compose logs -f${NC}"
echo -e "  Stop services:    ${YELLOW}docker-compose down${NC}"
echo -e "  Restart services: ${YELLOW}docker-compose restart${NC}"
echo -e "  Run tests:        ${YELLOW}./scripts/test-local.sh${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Ensure your OpenAI API key is set in .env"
echo -e "  2. Open http://localhost:3000 in your browser"
echo -e "  3. Register a new account"
echo -e "  4. Upload a document and start asking questions!"
