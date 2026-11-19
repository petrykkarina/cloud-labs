"""Cache-aside on top of Redis.

    1. look in Redis;
    2. HIT  -> return the stored value, the database is not touched;
    3. MISS -> run the real query, store the result for CACHE_TTL_SECONDS, return it.

Settings (environment variables):
    CACHE_ENABLED      "true" / "false"  - on/off switch for the experiment
    CACHE_TTL_SECONDS  how long a value lives in Redis (30 by default)
    REDIS_URL          redis://:password@host:6379/0

Hit/miss counters are kept in Redis itself, so they are shared by all replicas.
If Redis is down the app keeps working and simply reads from the database.
"""

import logging
import os
from collections.abc import Callable

import redis

logger = logging.getLogger("app.cache")

CACHE_ENABLED = os.getenv("CACHE_ENABLED", "false").lower() == "true"
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "30"))
REDIS_URL = os.getenv("REDIS_URL", "")

STATS_KEY = "cache:stats"

# Short timeouts: a slow cache must not make the API slower than the database.
_client = (
    redis.Redis.from_url(REDIS_URL, socket_timeout=0.5, socket_connect_timeout=0.5)
    if CACHE_ENABLED and REDIS_URL
    else None
)


def get_or_set(key: str, produce: Callable[[], str]) -> tuple[str, str]:
    """Return (json_body, status) where status is HIT, MISS or OFF."""
    if _client is None:
        return produce(), "OFF"

    try:
        cached = _client.get(key)
    except redis.RedisError as error:
        logger.warning("redis get failed: %s", error)
        cached = None

    if cached is not None:
        _count("hits")
        return cached.decode(), "HIT"

    body = produce()
    try:
        _client.set(key, body, ex=CACHE_TTL_SECONDS)
    except redis.RedisError as error:
        logger.warning("redis set failed: %s", error)
    _count("misses")
    return body, "MISS"


def _count(field: str) -> None:
    try:
        _client.hincrby(STATS_KEY, field, 1)
    except redis.RedisError:
        pass


def stats() -> dict:
    result = {"enabled": CACHE_ENABLED, "ttl_seconds": CACHE_TTL_SECONDS}
    if _client is None:
        return result
    try:
        raw = _client.hgetall(STATS_KEY)
    except redis.RedisError as error:
        return result | {"error": str(error)}
    hits = int(raw.get(b"hits", 0))
    misses = int(raw.get(b"misses", 0))
    total = hits + misses
    return result | {
        "hits": hits,
        "misses": misses,
        "hit_ratio": round(hits / total, 4) if total else None,
    }


def reset_stats() -> None:
    if _client is not None:
        _client.delete(STATS_KEY)
