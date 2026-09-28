FROM python:3.11-slim AS builder

WORKDIR /install

COPY requirements.txt .
# Chi cai runtime deps (khong mang pytest/fakeredis vao image prod cho nhe,
# tranh timeout mang yeu). requirements.txt van duoc COPY de tan dung cache.
RUN pip install --no-cache-dir --timeout=100 --retries=10 --prefix=/install \
    fastapi uvicorn pydantic pydantic-settings redis python-dotenv

FROM python:3.11-slim AS runtime

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app ./app
COPY utils ./utils

RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
