# Docker Containerization Task Documentation

Submitted by: Dhaval Gowder

---

## 1. Deployment Approach & Problems Faced

### Approach
The deployment strategy relies on **containerization orchestration** via Docker Compose. The objective was to create an isolated environment where a human-facing web layer, a programmatic api-server runtime, and a transactional relational database could interact cleanly without assuming any globally installed host dependencies. 

To achieve optimal security and footprint size, both application layers utilize isolated **Multi-Stage Builds**. This ensures compilation tools (like NPM or the Golang compiler SDK) are discarded entirely from the final production runtime images.

### Problems Faced & Mitigations
* **Database Race Conditions:** Initially, the API server would boot up faster than the PostgreSQL kernel could initialize internal storage schemas, causing immediate backend crashes. 
  * *Mitigation:* Implemented a native Docker health check running `pg_isready` directly within the database container, paired with a strict `condition: service_healthy` clause inside the API container's dependency trees.
* **Internal Name Resolution (502 Bad Gateway):** During early iterations, Nginx failed to forward UI traffic down to the backend application server. 
  * *Mitigation:* Identified that using a dynamic dynamic-routing variable inside Nginx (`set $upstream`) forced it to depend on Docker's internal DNS daemon resolver (`127.0.0.11`), dropping standard fallback hostnames. The configuration was refactored to explicitly use hardcoded upstream directives (`proxy_pass http://api-server:8080;`), allowing direct, reliable container-to-container routing via the shared bridge network.

---

## 2. How to Build and Run the Application

The entire stack is engineered to spin up via a single orchestrated execution loop. To clean out stale data layers, initialize fresh migration seeding, and compile the system assets from absolute scratch, run these commands sequentially in your terminal:

bash code:
### 1. Stop all execution instances and completely clear persistent volume caches
docker compose down -v --remove-orphans

### 2. Build and launch all image states, completely ignoring historical layer caching
docker compose up --build --force-recreate

#### Once initialized, the complete platform can be reached via your browser at: http://localhost

---

## 3. Services, Architecture, and Port Assignments
The application isolates its processes inside a custom bridge network called spider-net. Traffic flows logically through three dedicated service layers:

### Gateway Service (gateway)

Image/Context: Built from ./frontend/Dockerfile using a lightweight Nginx container.

Ports: Internal 80 mapped to External 80.

Responsibility: Acts as the edge ingress reverse proxy. It serves the statically compiled front-end production bundle directly to user browsers and securely proxies all traffic starting with /api/ down to the internal API layer.

### API Server (api-server)

Image/Context: Built from ./backend/Dockerfile as a minimal Alpine container wrapping the compiled Go binary.

Ports: Internal 8080 (Not exposed to the host machine).

Responsibility: Houses the core business logic. It handles programmatic incoming requests, verifies credentials, and queries/mutates the underlying data tier.

### Timetable Cache Database (timetable-cache)

Image/Context: Uses the official postgres:15-alpine image.

Ports: Internal 5432 (Not exposed to the host machine).

Responsibility: Serves as the relational data tier, permanently storing timetable records, indexes, and administrative user profiles.


---

## 4. How the Frontend Reaches the Backend
Because the client-side browser application cannot see Docker's internal networks directly, all communication is unified through a reverse-proxy routing architecture:

The browser UI loads via http://localhost. When a user fires an action (like a login submission), the frontend fires an asynchronous HTTP request directed to the local path relative origin: /api/timetable or /api/login.

The Nginx edge ingress container (gateway) receives this request on port 80.

Nginx evaluates the path configuration matching the block location /api/.

It strips or passes the request parameters down to the network hostname address target http://api-server:8080 using internal Docker network DNS mappings.

The backend Go app processes the request, returns JSON, and Nginx handles the response payload gracefully back to the browser.

---

## 5. PostgreSQL Configuration
The relational storage service is configured natively inside the Docker Compose layout via standard structural environment controls:

Database Username: postgres

Database Password: postgres

Target Database Catalog Name: cr45_reduced

Internal Database Engine Port: 5432

Data preservation across container termination cycles is secured via an explicitly declared local named driver volume mapping:
spider_storage:/var/lib/postgresql/data

---

## 6. Migration Handling
Migrations are decoupled from manual execution lines and managed programmatically on container startup.

The backend Golang directory contains raw structured migration SQL scripts within the ./migrations subdirectory.

During the compilation of ./backend/Dockerfile, this whole folder is copied into the runtime Alpine deployment slice.

When api-server finishes waiting for the database health check to clear, its internal entry point initializes database connection handles.

The Go binary automatically checks the state of the targeted database schema tables, reads the compiled sql migration sequences sequentially, updates structural layouts, and seeds default records (such as the default admin account profile setup) before opening its port to process incoming UI operations.

---

## 7. Common Failure Cases and How to Debug Them
### A. HTTP 502 Bad Gateway Error
Cause: The edge Nginx ingress container is healthy, but it cannot establish a backend connection link because the target container is unresponsive or cannot be found by its network identity label.

Debugging Command: Inspect internal resolution parameters and check if the Go application experienced a runtime crash:

Bash code:

docker compose logs api-server

### B. Changes to Source Code Aren't Reflecting in the Browser
Cause: Docker's build layer caching optimization is reading older compilation steps to save time instead of re-evaluating edited local repository updates.

Debugging Command: Evict cached layer memory blocks on rebuild:

Bash Code:

docker compose build --no-cache

### C. Missing Database Tables or Authentication State Mismatches
Cause: Altered schema layouts are out-of-sync with old, stale database structures still lingering within the local named data volume.

Debugging Command: Completely wipe out persistent storage layers to re-trigger fresh migrations on the next start:

Bash Code:

docker compose down -v


