#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-ml-api" "$@"
header "Python 3.13 + PyTorch + FastAPI + Docker"

create_project_dir

# ── pyproject.toml ────────────────────────────────────────────
section "Python project configuration"
write_file_heredoc "pyproject.toml" << EOF
[project]
name = "$PROJECT_NAME"
version = "0.1.0"
description = "ML inference API with FastAPI and PyTorch"
requires-python = ">=3.13"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.34.0",
    "torch>=2.6.0",
    "torchvision>=0.21.0",
    "pydantic>=2.11.0",
    "python-multipart>=0.0.20",
    "numpy>=2.2.0",
    "pillow>=11.2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "httpx>=0.28.0",
    "ruff>=0.11.0",
    "mypy>=1.15.0",
]

[tool.ruff]
target-version = "py313"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B"]

[tool.mypy]
python_version = "3.13"
strict = true
warn_return_any = true

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
EOF
success "Created pyproject.toml"

# ── app/main.py ───────────────────────────────────────────────
section "Application source files"
write_file_heredoc "app/__init__.py" << 'EOF'
EOF

write_file_heredoc "app/main.py" << 'EOF'
from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.model import ModelManager
from app.routes import router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    """Load the ML model on startup, clean up on shutdown."""
    ModelManager.load_model()
    yield
    ModelManager.cleanup()


app = FastAPI(
    title="ML Inference API",
    description="PyTorch model inference API",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api/v1")


@app.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok", "model_loaded": str(ModelManager.is_loaded())}
EOF
success "Created app/main.py"

# ── app/model.py ──────────────────────────────────────────────
write_file_heredoc "app/model.py" << 'EOF'
import torch
import torch.nn as nn


class SimpleClassifier(nn.Module):
    """Example classifier model. Replace with your actual model."""

    def __init__(self, input_size: int = 784, num_classes: int = 10) -> None:
        super().__init__()
        self.flatten = nn.Flatten()
        self.network = nn.Sequential(
            nn.Linear(input_size, 256),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(128, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.flatten(x)
        return self.network(x)


class ModelManager:
    """Singleton manager for the ML model."""

    _model: SimpleClassifier | None = None
    _device: torch.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    @classmethod
    def load_model(cls, model_path: str | None = None) -> None:
        """Load model weights. Uses a fresh model if no path is given."""
        cls._model = SimpleClassifier().to(cls._device)
        if model_path:
            state_dict = torch.load(model_path, map_location=cls._device, weights_only=True)
            cls._model.load_state_dict(state_dict)
        cls._model.eval()
        print(f"Model loaded on {cls._device}")

    @classmethod
    def get_model(cls) -> SimpleClassifier:
        if cls._model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")
        return cls._model

    @classmethod
    def get_device(cls) -> torch.device:
        return cls._device

    @classmethod
    def is_loaded(cls) -> bool:
        return cls._model is not None

    @classmethod
    def cleanup(cls) -> None:
        cls._model = None
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
EOF
success "Created app/model.py"

# ── app/schemas.py ────────────────────────────────────────────
write_file_heredoc "app/schemas.py" << 'EOF'
from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    """Request body for prediction endpoint."""

    data: list[list[float]] = Field(
        ...,
        description="Input data as a 2D list of floats (batch of samples)",
        examples=[[[0.0] * 784]],
    )


class PredictionResponse(BaseModel):
    """Response from prediction endpoint."""

    predictions: list[int] = Field(description="Predicted class labels")
    probabilities: list[list[float]] = Field(description="Class probabilities for each sample")


class ModelInfoResponse(BaseModel):
    """Response from model info endpoint."""

    model_name: str
    input_size: int
    num_classes: int
    device: str
    parameters: int
EOF
success "Created app/schemas.py"

# ── app/inference.py ──────────────────────────────────────────
write_file_heredoc "app/inference.py" << 'EOF'
import torch
import torch.nn.functional as F

from app.model import ModelManager


def predict(input_data: list[list[float]]) -> tuple[list[int], list[list[float]]]:
    """Run inference on input data.

    Args:
        input_data: A batch of input samples as a 2D list.

    Returns:
        Tuple of (predicted_classes, class_probabilities).
    """
    model = ModelManager.get_model()
    device = ModelManager.get_device()

    tensor = torch.tensor(input_data, dtype=torch.float32).to(device)

    with torch.no_grad():
        logits = model(tensor)
        probabilities = F.softmax(logits, dim=1)
        predictions = torch.argmax(probabilities, dim=1)

    return (
        predictions.cpu().tolist(),
        probabilities.cpu().tolist(),
    )


def get_model_info() -> dict[str, object]:
    """Return metadata about the loaded model."""
    model = ModelManager.get_model()
    device = ModelManager.get_device()
    total_params = sum(p.numel() for p in model.parameters())

    return {
        "model_name": model.__class__.__name__,
        "input_size": 784,
        "num_classes": 10,
        "device": str(device),
        "parameters": total_params,
    }
EOF
success "Created app/inference.py"

# ── app/routes.py ─────────────────────────────────────────────
write_file_heredoc "app/routes.py" << 'EOF'
from fastapi import APIRouter, HTTPException

from app.inference import predict, get_model_info
from app.schemas import PredictionRequest, PredictionResponse, ModelInfoResponse

router = APIRouter()


@router.post("/predict", response_model=PredictionResponse)
async def run_prediction(request: PredictionRequest) -> PredictionResponse:
    """Run model inference on the provided input data."""
    try:
        predictions, probabilities = predict(request.data)
        return PredictionResponse(predictions=predictions, probabilities=probabilities)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference failed: {e}")


@router.get("/model/info", response_model=ModelInfoResponse)
async def model_info() -> ModelInfoResponse:
    """Get information about the loaded model."""
    try:
        info = get_model_info()
        return ModelInfoResponse(**info)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
EOF
success "Created app/routes.py"

# ── tests/ ────────────────────────────────────────────────────
section "Tests"
write_file_heredoc "tests/__init__.py" << 'EOF'
EOF

write_file_heredoc "tests/test_api.py" << 'EOF'
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


@pytest.mark.asyncio
async def test_predict(client: AsyncClient):
    payload = {"data": [[0.0] * 784]}
    response = await client.post("/api/v1/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "predictions" in data
    assert "probabilities" in data
    assert len(data["predictions"]) == 1


@pytest.mark.asyncio
async def test_model_info(client: AsyncClient):
    response = await client.get("/api/v1/model/info")
    assert response.status_code == 200
    data = response.json()
    assert data["model_name"] == "SimpleClassifier"
EOF
success "Created tests/test_api.py"

# ── Dockerfile ────────────────────────────────────────────────
section "Docker configuration"
write_file_heredoc "Dockerfile" << 'EOF'
FROM python:3.13-slim AS base

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY pyproject.toml .
RUN pip install --no-cache-dir .

# Copy application code
COPY app/ app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
success "Created Dockerfile"

# ── docker-compose.yml ───────────────────────────────────────
write_file_heredoc "docker-compose.yml" << 'EOF'
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - PYTHONUNBUFFERED=1
    volumes:
      - ./app:/app/app
      - ./models:/app/models
    restart: unless-stopped
EOF
success "Created docker-compose.yml"

# ── .dockerignore ─────────────────────────────────────────────
write_file_heredoc ".dockerignore" << 'EOF'
__pycache__
*.pyc
.venv
venv
.git
.gitignore
*.md
tests/
.ruff_cache
.mypy_cache
.pytest_cache
EOF
success "Created .dockerignore"

mkdir -p models

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore "*.pyc" "__pycache__/" ".ruff_cache/" ".mypy_cache/" ".pytest_cache/" "models/*.pt" "models/*.pth"
write_editorconfig

write_readme "$PROJECT_NAME" \
  "ML inference API built with Python 3.13, PyTorch, and FastAPI. Includes Docker support." \
  "pip install -e '.[dev]'" \
  "uvicorn app.main:app --reload" \
  "- \`uvicorn app.main:app --reload\` - Start development server
- \`pytest\` - Run tests
- \`docker compose up\` - Run with Docker"

finish "pip install -e '.[dev]'" "uvicorn app.main:app --reload"
