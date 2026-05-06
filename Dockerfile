# ── Stage 1 : build & test ────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# Dépendances systèmes minimales
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Exécute les tests au build pour échouer tôt
RUN pytest test_app.py --tb=short -q

# ── Stage 2 : image finale (sans dépendances de test) ─────────────────────────
FROM python:3.12-slim AS production

WORKDIR /app

# Utilisateur non-root (sécurité)
RUN groupadd -r appuser && useradd -r -g appuser appuser

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /app/app.py .

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
