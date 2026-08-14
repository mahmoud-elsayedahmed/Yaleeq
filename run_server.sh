#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Yaleq FASHN VTON 1.5 — Optimized CPU Server Runner
# Automatically configures jemalloc / tcmalloc, multi-threading & DeepCache
# ──────────────────────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Detect optimal memory allocator (jemalloc / tcmalloc)
JEMALLOC_LIB=""
for p in /usr/lib64/libjemalloc.so.2 /usr/lib64/libjemalloc.so /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 /usr/lib/x86_64-linux-gnu/libjemalloc.so; do
    if [ -f "$p" ]; then
        JEMALLOC_LIB="$p"
        break
    fi
done

if [ -n "$JEMALLOC_LIB" ]; then
    echo "⚡ [Allocator] Enabling jemalloc: $JEMALLOC_LIB"
    export LD_PRELOAD="$JEMALLOC_LIB${LD_PRELOAD:+:$LD_PRELOAD}"
    export MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:30000,muzzy_decay_ms:30000"
else
    echo "⚠️ [Allocator] jemalloc not found in standard paths, running with system allocator."
fi

# 2. Multi-threading optimization
NUM_CORES=$(nproc 2>/dev/null || echo 8)
export OMP_NUM_THREADS="$NUM_CORES"
export MKL_NUM_THREADS="$NUM_CORES"
export TORCH_NUM_THREADS="$NUM_CORES"
export OPENBLAS_NUM_THREADS="$NUM_CORES"
export VECLIB_MAXIMUM_THREADS="$NUM_CORES"
export NUMEXPR_NUM_THREADS="$NUM_CORES"

# 3. Default optimization flags (can be overridden via environment)
export FASHN_DEEPCACHE="${FASHN_DEEPCACHE:-1}"
export FASHN_DEEPCACHE_INTERVAL="${FASHN_DEEPCACHE_INTERVAL:-2}"
export FASHN_DEEPCACHE_DEPTH="${FASHN_DEEPCACHE_DEPTH:-4}"

# Optional: compile model (set FASHN_COMPILE_MODEL=1 if PyTorch C++ compiler is desired)
export FASHN_COMPILE_MODEL="${FASHN_COMPILE_MODEL:-0}"

# Optional: Token Merging ratio
export FASHN_TOME_RATIO="${FASHN_TOME_RATIO:-0.0}"

echo "================================================================="
echo "🚀 Starting Yaleq FASHN VTON Server with CPU Optimizations:"
echo "   - CPU Cores: $NUM_CORES"
echo "   - DeepCache: $FASHN_DEEPCACHE (Interval: $FASHN_DEEPCACHE_INTERVAL, Depth: $FASHN_DEEPCACHE_DEPTH)"
echo "   - Compile Model: $FASHN_COMPILE_MODEL"
echo "   - Token Merging (ToMe): $FASHN_TOME_RATIO"
echo "   - LD_PRELOAD: ${LD_PRELOAD:-None}"
echo "================================================================="

exec uvicorn api.main:app --host 0.0.0.0 --port 8000 "$@"
