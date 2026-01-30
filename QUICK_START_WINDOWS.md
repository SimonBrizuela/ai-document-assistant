# Quick Start Guide for Windows

## Prerequisites Installation

### Option 1: Install Docker Desktop (Recommended - Easiest)

1. **Download Docker Desktop**
   - Go to: https://www.docker.com/products/docker-desktop
   - Download "Docker Desktop for Windows"
   - Run the installer
   - **Important**: Enable WSL 2 during installation

2. **Start Docker Desktop**
   - Launch Docker Desktop from Start Menu
   - Wait for it to say "Docker Desktop is running"
   - You should see the whale icon in system tray

3. **Verify Installation**
   ```powershell
   docker --version
   docker compose version
   ```

### Option 2: Manual Installation (For Development)

If you prefer not to use Docker, install these individually:

1. **Java 17+**
   - Download: https://adoptium.net/temurin/releases/
   - Choose: Windows x64, JDK 17 (LTS)
   - Install and verify: `java -version`

2. **Node.js 18+**
   - Download: https://nodejs.org/
   - Choose: LTS version
   - Install and verify: `node --version`

3. **PostgreSQL 15+**
   - Download: https://www.postgresql.org/download/windows/
   - During installation, remember your password
   - Add to PATH: `C:\Program Files\PostgreSQL\15\bin`
   - Verify: `psql --version`

4. **Maven (Optional - backend includes wrapper)**
   - Download: https://maven.apache.org/download.cgi
   - Extract to C:\maven
   - Add to PATH: `C:\maven\bin`

## Running with Docker Desktop (Easiest Method)

### Step 1: Setup Environment

```powershell
# Navigate to project directory
cd path\to\ai-document-assistant

# Create .env file
Copy-Item .env.example .env

# Edit .env and set your OpenAI API key
notepad .env
```

**Important**: Replace `sk-your-openai-api-key-here` with your actual OpenAI API key from https://platform.openai.com/api-keys

### Step 2: Start the Application

```powershell
# Start all services
docker compose up -d

# Wait about 60 seconds for services to start

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### Step 3: Access the Application

Open in your browser:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080
- **API Documentation**: http://localhost:8080/swagger-ui.html

### Step 4: Test the Application

1. Register a new account at http://localhost:3000
2. Upload a test document (create a .txt file with some content)
3. Ask questions about the document!

### Troubleshooting Docker

**Problem**: "docker: command not found"
- **Solution**: Start Docker Desktop, wait for it to fully load

**Problem**: Containers not starting
```powershell
# Check logs
docker compose logs

# Restart services
docker compose down
docker compose up -d
```

**Problem**: Port already in use
```powershell
# Stop existing services
docker compose down

# Check what's using ports
netstat -ano | findstr "3000"
netstat -ano | findstr "8080"
netstat -ano | findstr "5432"
```

## Running Manually (Without Docker)

### Step 1: Setup PostgreSQL

```powershell
# Create database (using psql)
psql -U postgres
```

In psql console:
```sql
CREATE DATABASE aiassistant;
\c aiassistant
CREATE EXTENSION IF NOT EXISTS vector;  -- Note: requires pgvector extension
\q
```

**Note**: pgvector extension requires manual installation. See: https://github.com/pgvector/pgvector

### Step 2: Setup Environment Variables

Create a file `backend\.env.local`:
```
DATABASE_URL=jdbc:postgresql://localhost:5432/aiassistant
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=your_postgres_password
OPENAI_API_KEY=sk-your-key-here
JWT_SECRET=your-very-long-jwt-secret-minimum-256-bits
AWS_REGION=us-east-1
AWS_S3_BUCKET=ai-assistant-documents
STORAGE_TYPE=local
LOCAL_STORAGE_PATH=./storage
```

### Step 3: Start Backend

```powershell
cd backend

# Install dependencies and build
.\mvnw.cmd clean install -DskipTests

# Run the application
.\mvnw.cmd spring-boot:run
```

Keep this terminal open. Backend should start on port 8080.

### Step 4: Start Frontend

Open a **new terminal**:

```powershell
cd frontend

# Install dependencies
npm install

# Create .env.local
@"
NEXT_PUBLIC_API_URL=http://localhost:8080/api
"@ | Out-File -FilePath .env.local -Encoding utf8

# Start development server
npm run dev
```

Frontend should start on port 3000.

### Step 5: Access the Application

- **Frontend**: http://localhost:3000
- **Backend**: http://localhost:8080
- **API Docs**: http://localhost:8080/swagger-ui.html

## Useful Commands

### Docker Commands

```powershell
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f backend
docker compose logs -f frontend

# Restart a service
docker compose restart backend

# Rebuild after code changes
docker compose up -d --build

# Stop and remove everything (including volumes)
docker compose down -v
```

### Manual Commands

```powershell
# Backend (in backend folder)
.\mvnw.cmd clean install        # Build
.\mvnw.cmd spring-boot:run      # Run
.\mvnw.cmd test                 # Test

# Frontend (in frontend folder)
npm install                     # Install dependencies
npm run dev                     # Development mode
npm run build                   # Production build
npm start                       # Run production build

# Database
psql -U postgres -d aiassistant # Connect to database
```

## Testing the Application

### Create a Test Document

1. Create a file `test.txt`:
```
The AI Document Assistant is a production-grade application.
It uses RAG (Retrieval-Augmented Generation) to answer questions.
The system is built with Spring Boot and Next.js.
```

2. Upload this file in the application

3. Ask questions like:
   - "What is the AI Document Assistant?"
   - "What technology is used?"
   - "What does RAG stand for?"

### Check System Health

```powershell
# Health check
curl http://localhost:8080/actuator/health

# API endpoints (requires authentication)
curl http://localhost:8080/swagger-ui.html
```

## Common Issues

### Issue: "Cannot connect to database"

**Solution**:
1. Check PostgreSQL is running:
   ```powershell
   # Check PostgreSQL service
   Get-Service | Where-Object {$_.Name -like "*postgresql*"}
   ```

2. Start PostgreSQL if not running:
   ```powershell
   # Via Services or:
   net start postgresql-x64-15  # Adjust version number
   ```

### Issue: "OpenAI API error"

**Solution**:
1. Verify API key is correct in `.env`
2. Check you have credits: https://platform.openai.com/account/usage
3. Ensure no extra spaces in the key

### Issue: Frontend can't connect to backend

**Solution**:
1. Check backend is running: `curl http://localhost:8080/actuator/health`
2. Check CORS settings if using different domains
3. Verify `NEXT_PUBLIC_API_URL` in frontend `.env.local`

### Issue: Port already in use

**Solution**:
```powershell
# Find process using port 8080
netstat -ano | findstr "8080"

# Kill process (use PID from above)
taskkill /PID <PID> /F

# Or change ports in docker-compose.yml or application.yml
```

## Next Steps

Once the application is running:

1. **Register an account** at http://localhost:3000
2. **Upload documents** (PDF, TXT, DOCX)
3. **Ask questions** about your documents
4. **View API documentation** at http://localhost:8080/swagger-ui.html
5. **Check logs** for debugging: `docker compose logs -f`

## Development Tips

### Hot Reload

- **Backend**: Code changes require restart (`docker compose restart backend`)
- **Frontend**: Next.js auto-reloads on save

### Debugging

```powershell
# Backend logs
docker compose logs -f backend

# Frontend logs
docker compose logs -f frontend

# Database logs
docker compose logs -f postgres

# Connect to containers
docker compose exec backend bash
docker compose exec postgres psql -U postgres -d aiassistant
```

### Reset Everything

```powershell
# Stop and remove all data
docker compose down -v

# Remove images
docker compose down --rmi all -v

# Fresh start
docker compose up -d --build
```

## Getting Help

- Check logs: `docker compose logs -f`
- Review documentation in `docs/` folder
- Check `ASSESSMENT_COMPLETION.md` for feature overview
- See `docs/ARCHITECTURE.md` for system design

## Production Deployment

For AWS deployment, see: `docs/DEPLOYMENT_GUIDE.md`

For infrastructure setup, see: `infrastructure/terraform/README.md`
