# ═══════════════════════════════════════════════════════════════════
# CP2 — Multi-stage Production Dockerfile
# ═══════════════════════════════════════════════════════════════════

# Stage 1: builder - cài dependencies
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: runtime - gọn nhẹ, bảo mật, non-root user
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy các package đã cài từ builder stage
COPY --from=builder /install /usr/local

# Tạo non-root user
RUN useradd --create-home --uid 10001 appuser

# Copy mã nguồn ứng dụng (sau pip install để tối ưu cache)
COPY app ./app
COPY utils ./utils

# Phân quyền cho appuser
RUN chown -R appuser:appuser /app

# Chuyển sang user thường
USER appuser

EXPOSE 8000

# Healthcheck probe gọi /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# Khởi chạy uvicorn đọc cổng từ PORT (mặc định 8000)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
