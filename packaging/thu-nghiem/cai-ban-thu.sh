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
# Máy mới tinh (thấy 21/11/2026 trên máy thứ 2 của chủ: chỉ có Python 3.9 của macOS) phải tự cài đủ, không bắt người dùng làm tay.
export PATH="$HOME/.local/bin:$HOME/.tisa/node/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
mkdir -p "$HOME/.local/bin"

# Git: Command Line Tools của Apple (macOS tự hiện hộp Cài đặt).
if ! xcode-select -p >/dev/null 2>&1 || ! git --version >/dev/null 2>&1; then
  echo "   Máy chưa có Git. macOS sẽ hiện hộp thoại: bấm Cài đặt (Install) và chờ tải xong (5 đến 15 phút)."
  xcode-select --install >/dev/null 2>&1 || true
  for _ in $(seq 1 540); do xcode-select -p >/dev/null 2>&1 && git --version >/dev/null 2>&1 && break; sleep 5; done
fi
git --version >/dev/null 2>&1 || { echo "Chưa có Git. Chạy: xcode-select --install, cài xong chạy lại lệnh này."; exit 1; }

# Python 3.10+: macOS chỉ kèm 3.9, nên tải Python 3.12 riêng bằng uv vào thư mục nhà (không cần quyền quản trị).
tim_py() {
  PY=""
  for c in python3.13 python3.12 python3.11 python3.10 "$HOME/.local/bin/python3.12" /opt/homebrew/bin/python3 /usr/local/bin/python3 python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then PY="$(command -v "$c")"; return 0; fi
  done
  return 1
}
if ! tim_py; then
  echo "   Máy chưa có Python 3.10 trở lên. Đang tải Python 3.12 riêng cho TISA BOT (vài phút)..."
  command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 || true
  if command -v uv >/dev/null 2>&1; then
    uv python install 3.12 >/dev/null 2>&1 || true
    UVPY="$(uv python find 3.12 2>/dev/null || true)"
    [ -n "$UVPY" ] && [ ! -x "$HOME/.local/bin/python3.12" ] && ln -sf "$UVPY" "$HOME/.local/bin/python3.12"
  fi
  tim_py || { echo "Chưa cài được Python 3.12. Tải ở https://www.python.org/downloads/macos/ , cài xong chạy lại lệnh này."; exit 1; }
fi
echo "   Python: $PY"

# Node và Claude CLI: bộ não AI của TISA BOT. Không có Homebrew thì tải Node 22 bản chính thức vào ~/.tisa/node.
if ! command -v claude >/dev/null 2>&1; then
  if ! command -v node >/dev/null 2>&1; then
    echo "   Đang tải Node.js 22..."
    if command -v brew >/dev/null 2>&1; then brew install node@22 >/dev/null 2>&1 || true; fi
    if ! command -v node >/dev/null 2>&1; then
      na=$([ "$(uname -m)" = "arm64" ] && echo arm64 || echo x64)
      tb=$(curl -fsSL https://nodejs.org/dist/latest-v22.x/ | grep -oE "node-v22\.[0-9]+\.[0-9]+-darwin-${na}\.tar\.xz" | head -1 || true)
      if [ -n "$tb" ]; then
        tmp=$(mktemp -d); curl -fsSL "https://nodejs.org/dist/latest-v22.x/$tb" -o "$tmp/n.tar.xz" && tar xf "$tmp/n.tar.xz" -C "$tmp" \
          && rm -rf "$HOME/.tisa/node" && mkdir -p "$HOME/.tisa" && mv "$tmp"/node-v22* "$HOME/.tisa/node"
        rm -rf "$tmp"
        for b in node npm npx; do ln -sf "$HOME/.tisa/node/bin/$b" "$HOME/.local/bin/$b"; done
      fi
    fi
  fi
  if command -v npm >/dev/null 2>&1; then
    echo "   Đang cài Claude CLI..."
    npm install -g @anthropic-ai/claude-code >/dev/null 2>&1 || true
    [ -x "$HOME/.tisa/node/bin/claude" ] && ln -sf "$HOME/.tisa/node/bin/claude" "$HOME/.local/bin/claude"
  fi
  command -v claude >/dev/null 2>&1 && echo "   Claude CLI: đã cài (đăng nhập Claude trong TISA BOT sau khi ghép)." \
    || echo "   (Chưa cài được Claude CLI. TISA BOT vẫn chạy; cài sau ở trang Kết nối.)"
fi
# Cho Terminal của người dùng thấy node, npm, claude, python3.12 vừa cài vào thư mục riêng
# (21/11/2026: chủ gõ "npm install -g @openai/codex" bị "command not found: npm").
DONG_PATH='export PATH="$HOME/.local/bin:$HOME/.tisa/node/bin:$PATH"   # TISA BOT'
for rc in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  if [ "$rc" = "$HOME/.zprofile" ] || [ -f "$rc" ]; then
    grep -qF '.tisa/node/bin' "$rc" 2>/dev/null || printf '\n%s\n' "$DONG_PATH" >> "$rc"
  fi
done

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
    <key>PATH</key><string>${NODE_DIR}${HOME}/.local/bin:${HOME}/.tisa/node/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
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
  [ "${TISA_KHONG_MO:-}" = "1" ] || open "http://127.0.0.1:${PORT}/" 2>/dev/null || true
else
  echo "Chưa thấy TISA BOT trả lời. Xem nhật ký: ${DIR}/server/tisa.log"
  exit 1
fi
