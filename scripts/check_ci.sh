#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "==> Checking RAP/CDS comment syntax"
if grep -RInE '^[[:space:]]*"' serialized \
  --include='*.asbdef' \
  --include='*.asddls' \
  --include='*.asdcls' \
  --include='*.asddlxs'; then
  echo 'Phát hiện comment kiểu ABAP (") trong artifact CDS/BDEF/DCL/MDE.'
  echo 'Các artifact này phải dùng // cho comment một dòng.'
  exit 1
fi

if grep -RInE '^[[:space:]]*(//|"|/\*|\*/)' serialized \
  --include='*.srvdsrv'; then
  echo 'Phát hiện comment trong Service Definition (*.srvdsrv).'
  echo 'ADT không hỗ trợ comment trong Service Definition; phải xóa comment khỏi source.'
  exit 1
fi

echo "==> Checking RAP activation-risk patterns"
python3 scripts/check_rap_patterns.py

echo "==> Running abaplint 2.120.35"
npx --yes @abaplint/cli@2.120.35
