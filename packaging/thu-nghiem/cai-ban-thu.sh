#!/bin/bash
# Cài TISA BOT BẢN THỬ NGHIỆM (Nhiều máy) trên macOS, chạy SONG SONG với TISA BOT đang có:
#   thư mục riêng (mặc định ~/tisa-bot-thu), cổng riêng (mặc định 7790), dữ liệu Đội Quân riêng, dịch vụ launchd riêng.
#   KHÔNG đụng TISA BOT cũ (~/tisa-os, cổng 7777) và không đụng /Applications/TISA BOT.app.
#
#   curl -fsSL https://raw.githubusercontent.com/tieusangstudio-hash/tisa-bot-thu-nghiem/main/packaging/thu-nghiem/cai-ban-thu.sh | bash
#
# Đổi chỗ cài / cổng: TISA_DIR=~/tisa-bot-2 TISA_PORT=7790 bash cai-ban-thu.sh
# Gỡ: bash ~/tisa-bot-thu/packaging/thu-nghiem/cai-ban-thu.sh go   (dừng dịch vụ, giữ nguyên thư mục dữ liệu)
set -euo pipefail
REPO="${TISA_REPO:-tieusangstudio-hash/tisa-bot-thu-nghiem}"
DIR="${TISA_DIR:-$HOME/tisa-bot-thu}"
PORT="${TISA_PORT:-7790}"
BPORT="${TISA_BOARD_PORT:-$((PORT + 1))}"
LABEL="com.tisa.bot-thu-${PORT}"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ "${1:-}" = "go" ]; then
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Đã dừng và gỡ dịch vụ ${LABEL}. Thư mục ${DIR} vẫn còn (xóa tay nếu không cần)."
  exit 0
fi

case "$DIR" in "$HOME/tisa-os"|"$HOME/tisa-os/"*) echo "DỪNG: không cài bản thử vào thư mục TISA BOT đang dùng (~/tisa-os)."; exit 1;; esac
if [ "$PORT" = "7777" ]; then echo "DỪNG: cổng 7777 là của TISA BOT đang dùng. Chọn cổng khác (TISA_PORT=7790)."; exit 1; fi
if curl -sf -m 2 -o /dev/null "http://127.0.0.1:${PORT}/health" && [ ! -f "$PLIST" ]; then echo "DỪNG: cổng ${PORT} đang có chương trình khác chạy."; exit 1; fi

echo "== Cài TISA BOT bản thử nghiệm vào ${DIR}, cổng ${PORT}"
command -v git >/dev/null || { echo "Thiếu git. Chạy: xcode-select --install rồi chạy lại lệnh này."; exit 1; }
PY=""
for c in python3.13 python3.12 python3.11 /opt/homebrew/bin/python3 /usr/local/bin/python3 python3; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then PY="$(command -v "$c")"; break; fi
done
[ -n "$PY" ] || { echo "Cần Python 3.10 trở lên. Cài bằng: brew install python@3.12 (hoặc tải ở python.org) rồi chạy lại."; exit 1; }
echo "   Python: $PY"

if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull -q --ff-only || echo "   (không cập nhật được mã, giữ bản đang có)"
else
  git clone -q --depth 1 "https://github.com/${REPO}.git" "$DIR"
fi
[ -x "$DIR/.venv/bin/python" ] || "$PY" -m venv "$DIR/.venv"
echo "   Đang cài thư viện Python (vài phút lần đầu)..."
"$DIR/.venv/bin/python" -m pip install -q --upgrade pip >/dev/null 2>&1 || true
"$DIR/.venv/bin/python" -m pip install -q -r "$DIR/requirements.txt"
mkdir -p "$DIR/_doi-quan/home" "$HOME/Library/LaunchAgents"

NODE_DIR=""
command -v node >/dev/null 2>&1 && NODE_DIR="$(dirname "$(command -v node)"):"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key><array>
    <string>${DIR}/.venv/bin/python</string><string>-m</string><string>uvicorn</string><string>main:app</string>
    <string>--host</string><string>127.0.0.1</string><string>--port</string><string>${PORT}</string>
  </array>
  <key>WorkingDirectory</key><string>${DIR}/server</string>
  <key>EnvironmentVariables</key><dict>
    <key>TISA_PORT</key><string>${PORT}</string>
    <key>TISA_BOARD_PORT</key><string>${BPORT}</string>
    <key>DOI_QUAN_HOME</key><string>${DIR}/_doi-quan/home</string>
    <key>DOI_QUAN_ENV</key><string>${DIR}/_doi-quan/.env</string>
    <key>TISA_CLAUDE_AUTO_UPDATE</key><string>0</string>
    <key>PATH</key><string>${NODE_DIR}${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${DIR}/server/tisa.log</string>
  <key>StandardErrorPath</key><string>${DIR}/server/tisa.log</string>
</dict></plist>
EOF
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "   Đang khởi động..."
for i in $(seq 1 90); do curl -sf -m 2 -o /dev/null "http://127.0.0.1:${PORT}/health" && break; sleep 2; done
if curl -sf -m 2 -o /dev/null "http://127.0.0.1:${PORT}/health"; then
  echo "== XONG. Mở: http://127.0.0.1:${PORT}/  (lần đầu tạo tài khoản quản trị), rồi vào menu Nhiều máy."
  open "http://127.0.0.1:${PORT}/" 2>/dev/null || true
else
  echo "Chưa thấy TISA BOT trả lời. Xem nhật ký: ${DIR}/server/tisa.log"
  exit 1
fi
