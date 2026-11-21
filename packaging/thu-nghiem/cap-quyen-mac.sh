#!/bin/bash
# Cấp quyền điều khiển máy (Trợ năng + Ghi màn hình) cho TISA BOT bản thử trên macOS, rồi khởi động lại để quyền có tác dụng.
#
#   curl -fsSL https://raw.githubusercontent.com/tieusangstudio-hash/tisa-bot-thu-nghiem/main/packaging/thu-nghiem/cap-quyen-mac.sh | bash
#
# Vì sao cần (21/11/2026, máy thứ 2 của chủ): bộ cài thử chạy TISA BOT bằng Python trong thư mục ẩn (uv), nên macOS cấp quyền
# cho ĐÚNG chương trình python đó chứ không phải "TISA BOT". Bật quyền xong mà không khởi động lại thì máy chủ vẫn coi là chưa có quyền
# (tải lại trang F5 không khởi động lại máy chủ).
set -u
DIR="${TISA_DIR:-$HOME/tisa-bot-thu}"
PORT="${TISA_PORT:-7790}"
LABEL="com.tisa.bot-thu-${PORT}"
PY_LINK="$DIR/.venv/bin/python"
[ -e "$PY_LINK" ] || { echo "Không thấy TISA BOT bản thử ở $DIR. Cài trước bằng lệnh cài."; exit 1; }
PY="$("$PY_LINK" -c 'import os, sys; print(os.path.realpath(sys.executable))' 2>/dev/null)"
[ -n "$PY" ] || PY="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$PY_LINK")"
TEN="$(basename "$PY")"

cho() { printf '\n   %s\n   Xong thì quay lại cửa sổ này, bấm Enter... ' "$1"; read -r _ </dev/tty; }
huong_dan() {   # <tên mục> <đường mở Cài đặt>
  printf '%s' "$PY" | pbcopy
  echo ""
  echo "== $1"
  echo "   Cửa sổ Cài đặt hệ thống vừa mở. Làm như sau:"
  echo "   1. Tìm dòng \"$TEN\" trong danh sách. Có thì BẬT công tắc sang xanh."
  echo "   2. Chưa có: bấm dấu + ở dưới danh sách, nhập mật khẩu máy nếu hỏi,"
  echo "      bấm Cmd+Shift+G, bấm Cmd+V (em đã chép sẵn đường dẫn), Enter, rồi bấm Mở."
  echo "      Đường dẫn: $PY"
  echo "   3. Thấy dòng \"$TEN\" bật xanh là được."
  open "$2"
}

echo "== Cấp quyền điều khiển máy cho TISA BOT bản thử (cổng $PORT)"
echo "   Chương trình cần cấp quyền: $TEN"
huong_dan "Bước 1/2: Trợ năng (để AI bấm chuột, gõ phím, dùng chuột riêng màu cam)" \
  "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
cho "Bật xong quyền Trợ năng cho \"$TEN\"."
huong_dan "Bước 2/2: Ghi màn hình và âm thanh hệ thống (để AI chụp, xem màn hình)" \
  "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
echo "   (Nếu macOS hỏi \"Thoát và mở lại\" thì bấm \"Để sau\": em tự khởi động lại TISA BOT ở bước cuối.)"
cho "Bật xong quyền Ghi màn hình cho \"$TEN\"."

echo ""
echo "== Khởi động lại TISA BOT để nhận quyền mới..."
launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null || { launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$LABEL.plist"; }
for _ in $(seq 1 60); do curl -sf -m 2 -o /dev/null "http://127.0.0.1:${PORT}/health" && break; sleep 2; done
if curl -sf -m 2 -o /dev/null "http://127.0.0.1:${PORT}/health"; then
  echo "== XONG. Mở TISA BOT, bấm \"Hội thoại mới\" (đừng dùng ô chat cũ) rồi gõ: chụp màn hình máy này và cho anh biết đang mở gì"
  echo "   Lần đầu mở Chrome, macOS có thể hỏi \"cho phép điều khiển Google Chrome\": bấm OK."
else
  echo "TISA BOT chưa chạy lại. Gửi em 30 dòng cuối của: $DIR/server/tisa.log"
fi
