#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-chi-app" "$@"
header "Go + Chi Router + sqlc + PostgreSQL + Docker"

create_project_dir

MODULE_NAME="github.com/user/${PROJECT_NAME}"

# ── go.mod ────────────────────────────────────────────────────
section "Go module"
write_file_heredoc go.mod << EOF
module ${MODULE_NAME}

go 1.23

require (
	github.com/go-chi/chi/v5 v5.2.1
	github.com/go-chi/cors v1.2.1
	github.com/jackc/pgx/v5 v5.7.4
	github.com/joho/godotenv v1.5.1
)

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	golang.org/x/crypto v0.37.0 // indirect
	golang.org/x/sync v0.13.0 // indirect
	golang.org/x/text v0.24.0 // indirect
)
EOF
success "Created go.mod"

# ── sqlc config ──────────────────────────────────────────────
section "sqlc configuration"
write_file_heredoc sqlc.yaml << 'EOF'
version: "2"
sql:
  - engine: "postgresql"
    queries: "sql/queries.sql"
    schema: "sql/schema.sql"
    gen:
      go:
        package: "db"
        out: "internal/db"
        sql_package: "pgx/v5"
        emit_json_tags: true
        emit_prepared_queries: false
        emit_interface: true
        emit_exact_table_names: false
EOF
success "Created sqlc.yaml"

# ── SQL ──────────────────────────────────────────────────────
mkdir -p sql

write_file_heredoc sql/schema.sql << 'EOF'
CREATE TABLE IF NOT EXISTS users (
  id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  email      TEXT UNIQUE NOT NULL,
  name       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS posts (
  id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title      TEXT NOT NULL,
  content    TEXT,
  published  BOOLEAN NOT NULL DEFAULT false,
  author_id  TEXT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
EOF
success "Created sql/schema.sql"

write_file_heredoc sql/queries.sql << 'EOF'
-- name: ListUsers :many
SELECT * FROM users ORDER BY created_at DESC;

-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: CreateUser :one
INSERT INTO users (email, name)
VALUES ($1, $2)
RETURNING *;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;

-- name: ListPosts :many
SELECT * FROM posts ORDER BY created_at DESC;

-- name: GetPost :one
SELECT * FROM posts WHERE id = $1;

-- name: CreatePost :one
INSERT INTO posts (title, content, author_id)
VALUES ($1, $2, $3)
RETURNING *;
EOF
success "Created sql/queries.sql"

# ── Internal packages ────────────────────────────────────────
section "Application source files"

mkdir -p cmd/server internal/handler internal/db

# cmd/server/main.go
write_file_heredoc cmd/server/main.go << GOEOF
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"

	"${MODULE_NAME}/internal/db"
	"${MODULE_NAME}/internal/handler"
)

func main() {
	_ = godotenv.Load()

	ctx := context.Background()

	pool, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("unable to connect to database: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("unable to ping database: %v", err)
	}

	queries := db.New(pool)

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RequestID)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: true,
	}))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, \`{"status":"ok","timestamp":"%s"}\`, time.Now().Format(time.RFC3339))
	})

	h := handler.New(queries)
	r.Route("/api/users", func(r chi.Router) {
		r.Get("/", h.ListUsers)
		r.Post("/", h.CreateUser)
		r.Get("/{id}", h.GetUser)
		r.Delete("/{id}", h.DeleteUser)
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{Addr: ":" + port, Handler: r}

	go func() {
		log.Printf("Server running on http://localhost:%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	shutdownCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("server forced to shutdown: %v", err)
	}
}
GOEOF
success "Created cmd/server/main.go"

# internal/handler/user.go
write_file_heredoc internal/handler/user.go << GOEOF
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"${MODULE_NAME}/internal/db"
)

type Handler struct {
	queries db.Querier
}

func New(queries db.Querier) *Handler {
	return &Handler{queries: queries}
}

type createUserRequest struct {
	Email string  \`json:"email"\`
	Name  *string \`json:"name"\`
}

func (h *Handler) ListUsers(w http.ResponseWriter, r *http.Request) {
	users, err := h.queries.ListUsers(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, users)
}

func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	user, err := h.queries.GetUser(r.Context(), id)
	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var req createUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	user, err := h.queries.CreateUser(r.Context(), db.CreateUserParams{
		Email: req.Email,
		Name:  req.Name,
	})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, user)
}

func (h *Handler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.queries.DeleteUser(r.Context(), id); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
GOEOF
success "Created internal/handler/user.go"

# internal/db placeholder — sqlc will generate this, but we provide the interface
write_file_heredoc internal/db/querier.go << GOEOF
package db

import "context"

// Querier is the interface generated by sqlc. This placeholder allows compilation
// before running sqlc generate. Run \`sqlc generate\` to replace this file.
type Querier interface {
	ListUsers(ctx context.Context) ([]User, error)
	GetUser(ctx context.Context, id string) (User, error)
	CreateUser(ctx context.Context, arg CreateUserParams) (User, error)
	DeleteUser(ctx context.Context, id string) error
}
GOEOF
success "Created internal/db/querier.go"

write_file_heredoc internal/db/models.go << 'GOEOF'
package db

import "time"

type User struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	Name      *string   `json:"name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Post struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Content   *string   `json:"content"`
	Published bool      `json:"published"`
	AuthorID  string    `json:"author_id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CreateUserParams struct {
	Email string  `json:"email"`
	Name  *string `json:"name"`
}
GOEOF
success "Created internal/db/models.go"

write_file_heredoc internal/db/db.go << GOEOF
package db

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Queries struct {
	pool *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Queries {
	return &Queries{pool: pool}
}

// NOTE: Run \`sqlc generate\` to generate the actual query methods.
// The methods below are minimal stubs for compilation.

func (q *Queries) ListUsers(ctx context.Context) ([]User, error) {
	return nil, nil
}

func (q *Queries) GetUser(ctx context.Context, id string) (User, error) {
	return User{}, nil
}

func (q *Queries) CreateUser(ctx context.Context, arg CreateUserParams) (User, error) {
	return User{}, nil
}

func (q *Queries) DeleteUser(ctx context.Context, id string) error {
	return nil
}
GOEOF
success "Created internal/db/db.go"

# ── Docker ───────────────────────────────────────────────────
section "Docker configuration"

write_file_heredoc Dockerfile << 'EOF'
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

FROM alpine:3.21
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /server .
EXPOSE 8080
CMD ["./server"]
EOF
success "Created Dockerfile"

write_file_heredoc docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./sql/schema.sql:/docker-entrypoint-initdb.d/schema.sql

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: "postgres://postgres:postgres@postgres:5432/app?sslmode=disable"
      PORT: "8080"
    depends_on:
      - postgres

volumes:
  pgdata:
EOF
success "Created docker-compose.yml"

# ── Makefile ─────────────────────────────────────────────────
write_file_heredoc Makefile << 'EOF'
.PHONY: dev build run test lint db-up db-down sqlc

dev:
	go run ./cmd/server

build:
	go build -o bin/server ./cmd/server

run: build
	./bin/server

test:
	go test ./...

lint:
	golangci-lint run

db-up:
	docker compose up -d postgres

db-down:
	docker compose down

sqlc:
	sqlc generate
EOF
success "Created Makefile"

# ── .env ──────────────────────────────────────────────────────
write_file_heredoc .env.example << 'EOF'
DATABASE_URL="postgres://postgres:postgres@localhost:5432/app?sslmode=disable"
PORT=8080
EOF
success "Created .env.example"
cp .env.example .env

# create go.sum placeholder
touch go.sum

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" "bin/" "tmp/"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Go + Chi Router + sqlc + PostgreSQL API" \
  "go mod download && sqlc generate" \
  "make dev"

finish "go mod download && sqlc generate" "make db-up && make dev"
