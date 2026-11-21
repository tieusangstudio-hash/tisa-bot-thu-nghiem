#!/bin/bash
# Kiểm nhanh TISA BOT bản thử trên macOS: chạy chưa, quyền điều khiển máy, MCP nào lỗi và vì sao. KHÔNG in khóa hay token.
#   curl -fsSL https://raw.githubusercontent.com/tieusangstudio-hash/tisa-bot-thu-nghiem/main/packaging/thu-nghiem/kiem-tra-mac.sh | bash
set -u
DIR="${TISA_DIR:-$HOME/tisa-bot-thu}"
PORT="${TISA_PORT:-7790}"
LOG="$DIR/server/tisa.log"
che() { sed -E 's/(Bearer|token|key|sk-|ghp_|apify_api_)[A-Za-z0-9._=-]{6,}/\1***/Ig'; }
echo "== TISA BOT bản thử: $DIR, cổng $PORT"
curl -sf -m 3 -o /dev/null "http://127.0.0.1:$PORT/health" && echo "Máy chủ: đang chạy" || echo "Máy chủ: KHÔNG trả lời"
PY="$("$DIR/.venv/bin/python" -c 'import os,sys;print(os.path.realpath(sys.executable))' 2>/dev/null)"
echo "Chương trình cần cấp quyền: $PY"
echo "Thư mục MCP tự cài: $(ls "$DIR/_mcp" 2>/dev/null | tr '\n' ' ' || echo 'KHÔNG CÓ')"
for m in node npm npx uvx claude agy codex; do printf '  %-7s %s\n' "$m" "$(command -v $m || echo '(không có)')"; done
echo ""
echo "== Quyền điều khiển máy (theo nhật ký gần nhất)"
grep -aiE "tro_nang|ghi_man_hinh|Accessibility|screen ?capture|not trusted|chuot_rieng|quyen" "$LOG" 2>/dev/null | tail -6 | che | cut -c1-220
echo ""
echo "== MCP lỗi gần đây (mỗi MCP một dòng mới nhất)"
grep -aE "^\[mcp (warm|discover)\]" "$LOG" 2>/dev/null | tail -600 | che | awk -F': ' '{k=$1; v[k]=$0} END {for (k in v) print v[k]}' | cut -c1-260
echo ""
echo "== 15 dòng lỗi khác gần nhất"
grep -aiE "error|lỗi|traceback|exception" "$LOG" 2>/dev/null | grep -avE "^\[mcp (warm|discover)\]" | tail -15 | che | cut -c1-220
echo ""
echo "Chụp màn hình toàn bộ cửa sổ này gửi em."
