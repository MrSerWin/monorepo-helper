#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-fiber-app" "$@"
header "Go + Fiber v3 + GORM + PostgreSQL + Docker"

create_project_dir

MODULE_NAME="github.com/user/${PROJECT_NAME}"

# ── go.mod ────────────────────────────────────────────────────
section "Go module"
write_file_heredoc go.mod << EOF
module ${MODULE_NAME}

go 1.23

require (
	github.com/gofiber/fiber/v3 v3.0.0-beta.4
	github.com/joho/godotenv v1.5.1
	gorm.io/driver/postgres v1.5.11
	gorm.io/gorm v1.25.12
)
EOF
success "Created go.mod"

touch go.sum

# ── Source files ──────────────────────────────────────────────
section "Application source files"

mkdir -p cmd/server internal/handler internal/model internal/database internal/config

# internal/config/config.go
write_file_heredoc internal/config/config.go << GOEOF
package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL string
	Port        string
}

func Load() *Config {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	return &Config{
		DatabaseURL: os.Getenv("DATABASE_URL"),
		Port:        port,
	}
}
GOEOF
success "Created internal/config/config.go"

# internal/model/user.go
write_file_heredoc internal/model/user.go << 'GOEOF'
package model

import "time"

type User struct {
	ID        string    `gorm:"primaryKey;default:gen_random_uuid()" json:"id"`
	Email     string    `gorm:"uniqueIndex;not null" json:"email"`
	Name      *string   `json:"name"`
	Posts     []Post    `gorm:"foreignKey:AuthorID" json:"posts,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Post struct {
	ID        string    `gorm:"primaryKey;default:gen_random_uuid()" json:"id"`
	Title     string    `gorm:"not null" json:"title"`
	Content   *string   `json:"content"`
	Published bool      `gorm:"default:false" json:"published"`
	AuthorID  string    `gorm:"not null" json:"author_id"`
	Author    *User     `gorm:"foreignKey:AuthorID" json:"author,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
GOEOF
success "Created internal/model/user.go"

# internal/database/database.go
write_file_heredoc internal/database/database.go << GOEOF
package database

import (
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"${MODULE_NAME}/internal/model"
)

func Connect(dsn string) *gorm.DB {
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	if err := db.AutoMigrate(&model.User{}, &model.Post{}); err != nil {
		log.Fatalf("failed to run migrations: %v", err)
	}

	return db
}
GOEOF
success "Created internal/database/database.go"

# internal/handler/user.go
write_file_heredoc internal/handler/user.go << GOEOF
package handler

import (
	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"${MODULE_NAME}/internal/model"
)

type UserHandler struct {
	db *gorm.DB
}

func NewUserHandler(db *gorm.DB) *UserHandler {
	return &UserHandler{db: db}
}

func (h *UserHandler) RegisterRoutes(app *fiber.App) {
	users := app.Group("/api/users")
	users.Get("/", h.List)
	users.Get("/:id", h.Get)
	users.Post("/", h.Create)
	users.Delete("/:id", h.Delete)
}

func (h *UserHandler) List(c fiber.Ctx) error {
	var users []model.User
	if err := h.db.Preload("Posts").Find(&users).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(users)
}

func (h *UserHandler) Get(c fiber.Ctx) error {
	id := c.Params("id")
	var user model.User
	if err := h.db.Preload("Posts").First(&user, "id = ?", id).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "User not found"})
	}
	return c.JSON(user)
}

type createUserRequest struct {
	Email string  \`json:"email"\`
	Name  *string \`json:"name"\`
}

func (h *UserHandler) Create(c fiber.Ctx) error {
	var req createUserRequest
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	user := model.User{Email: req.Email, Name: req.Name}
	if err := h.db.Create(&user).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(fiber.StatusCreated).JSON(user)
}

func (h *UserHandler) Delete(c fiber.Ctx) error {
	id := c.Params("id")
	if err := h.db.Delete(&model.User{}, "id = ?", id).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.SendStatus(fiber.StatusNoContent)
}
GOEOF
success "Created internal/handler/user.go"

# cmd/server/main.go
write_file_heredoc cmd/server/main.go << GOEOF
package main

import (
	"log"
	"time"

	"github.com/gofiber/fiber/v3"

	"${MODULE_NAME}/internal/config"
	"${MODULE_NAME}/internal/database"
	"${MODULE_NAME}/internal/handler"
)

func main() {
	cfg := config.Load()

	db := database.Connect(cfg.DatabaseURL)

	app := fiber.New(fiber.Config{
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	})

	app.Get("/health", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "timestamp": time.Now().Format(time.RFC3339)})
	})

	userHandler := handler.NewUserHandler(db)
	userHandler.RegisterRoutes(app)

	log.Printf("Server running on http://localhost:%s", cfg.Port)
	log.Fatal(app.Listen(":" + cfg.Port))
}
GOEOF
success "Created cmd/server/main.go"

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
.PHONY: dev build run test lint db-up db-down

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
EOF
success "Created Makefile"

# ── .env ──────────────────────────────────────────────────────
write_file_heredoc .env.example << 'EOF'
DATABASE_URL="postgres://postgres:postgres@localhost:5432/app?sslmode=disable"
PORT=8080
EOF
success "Created .env.example"
cp .env.example .env

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" "bin/" "tmp/"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Go + Fiber v3 + GORM + PostgreSQL API" \
  "go mod download" \
  "make dev"

finish "go mod download" "make db-up && make dev"
