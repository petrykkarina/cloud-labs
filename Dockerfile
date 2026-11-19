# Base image pinned to an exact version (never "latest"): the build is
# reproducible and does not change silently when upstream publishes a new tag.
FROM python:3.12.16-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Unprivileged user with a fixed UID; the process will not run as root.
RUN useradd --system --uid 10001 --no-create-home appuser

WORKDIR /code

# 1) Dependencies first: this layer is rebuilt only when requirements.txt
#    changes, so editing the code reuses the cached pip install.
COPY requirements.txt .
RUN pip install -r requirements.txt

# 2) Application code last: it changes most often.
COPY app ./app

# Commit hash passed by CI (docker build --build-arg GIT_SHA=...).
ARG GIT_SHA=dev
ENV APP_VERSION=$GIT_SHA

USER 10001
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
