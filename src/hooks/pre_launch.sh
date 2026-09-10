# shellcheck shell=bash
# pre_launch hook for comfyui-minimax
# Installs container cgroup memory detection for psutil so ComfyUI knows
# the container's real RAM limit (50GB) instead of the host machine's (257GB).

cat << 'EOF' > /usr/lib/python3.12/sitecustomize.py
import os
import psutil
from collections import namedtuple

_orig_virtual_memory = psutil.virtual_memory

def cgroup_virtual_memory():
    orig = _orig_virtual_memory()
    limit = None
    usage = None

    # Check cgroup v2
    if os.path.exists('/sys/fs/cgroup/memory.max'):
        try:
            with open('/sys/fs/cgroup/memory.max') as f:
                val = f.read().strip()
                if val != 'max':
                    limit = int(val)
            with open('/sys/fs/cgroup/memory.current') as f:
                usage = int(f.read().strip())
        except Exception:
            pass
    # Check cgroup v1
    elif os.path.exists('/sys/fs/cgroup/memory/memory.limit_in_bytes'):
        try:
            with open('/sys/fs/cgroup/memory/memory.limit_in_bytes') as f:
                limit = int(f.read().strip())
            with open('/sys/fs/cgroup/memory/memory.usage_in_bytes') as f:
                usage = int(f.read().strip())
        except Exception:
            pass

    if limit is not None and 0 < limit < orig.total:
        used = usage or 0
        available = max(0, limit - used)
        percent = (used / limit) * 100.0 if limit > 0 else 0.0
        svmem = namedtuple('svmem', ['total', 'available', 'percent', 'used', 'free', 'active', 'inactive', 'buffers', 'cached', 'shared', 'slab'])
        return svmem(
            total=limit,
            available=available,
            percent=percent,
            used=used,
            free=available,
            active=orig.active,
            inactive=orig.inactive,
            buffers=orig.buffers,
            cached=orig.cached,
            shared=orig.shared,
            slab=orig.slab
        )
    return orig

psutil.virtual_memory = cgroup_virtual_memory
EOF

echo "✅ Container cgroup memory patch (sitecustomize.py) successfully installed."
