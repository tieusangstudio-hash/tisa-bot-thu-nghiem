# Cài TISA BOT BẢN THỬ NGHIỆM (Nhiều máy) trên Windows, chạy SONG SONG với TISA BOT đang có:
#   thư mục riêng (mặc định %USERPROFILE%\tisa-bot-thu), cổng riêng (mặc định 7790), dữ liệu Đội Quân riêng.
#   KHÔNG đụng TISA BOT cũ (cổng 7777).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/tieusangstudio-hash/tisa-bot-thu-nghiem/main/packaging/thu-nghiem/cai-ban-thu.ps1 | iex"
#
# Tự chạy cùng Windows qua lối tắt "TISA BOT thu" trong thư mục Startup. Gỡ: xóa lối tắt đó (Win+R, gõ shell:startup) rồi tắt cửa sổ PowerShell đang chạy bản thử.
# Ghi chú: chưa chạy thử trên máy Windows thật (21/11/2026).
$ErrorActionPreference = "Continue"
$Repo = if ($env:TISA_REPO) { $env:TISA_REPO } else { "tieusangstudio-hash/tisa-bot-thu-nghiem" }
$Dir = if ($env:TISA_DIR) { $env:TISA_DIR } else { Join-Path $env:USERPROFILE "tisa-bot-thu" }
$Port = if ($env:TISA_PORT) { [int]$env:TISA_PORT } else { 7790 }
$BPort = $Port + 1
function Dung($chu) { Write-Host $chu -ForegroundColor Red; exit 1 }
if ($Port -eq 7777) { Dung "Cổng 7777 là của TISA BOT đang dùng. Chọn cổng khác." }

Write-Host "== Cài TISA BOT bản thử nghiệm vào $Dir, cổng $Port"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Dung "Thiếu Git. Cài: winget install --id Git.Git -e, mở lại PowerShell rồi chạy lại." }

# Tìm Python 3.10+: thử 'py -3.12', 'py -3.11', rồi 'python'. Mỗi ứng viên là (lệnh, các đối số đầu).
$PyExe = $null; $PyArgs = @()
foreach ($c in @(@("py", "-3.12"), @("py", "-3.11"), @("py", "-3"), @("python"))) {
  $exe = $c[0]; $pre = @(); if ($c.Count -gt 1) { $pre = $c[1..($c.Count - 1)] }
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { continue }
  $v = & $exe @pre -c "import sys; print(sys.version_info >= (3, 10))" 2>$null
  if ($LASTEXITCODE -eq 0 -and "$v".Trim() -eq "True") { $PyExe = $exe; $PyArgs = $pre; break }
}
if (-not $PyExe) { Dung "Cần Python 3.10 trở lên. Cài: winget install --id Python.Python.3.12 -e, mở lại PowerShell rồi chạy lại." }
Write-Host "   Python: $PyExe $PyArgs"

if (Test-Path (Join-Path $Dir ".git")) {
  git -C $Dir pull -q --ff-only 2>&1 | Out-Null
} else {
  git clone -q --depth 1 "https://github.com/$Repo.git" $Dir 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Dung "Không tải được mã từ GitHub (kiểm mạng)." }
}
$Venv = Join-Path $Dir ".venv\Scripts\python.exe"
if (-not (Test-Path $Venv)) { & $PyExe @PyArgs -m venv (Join-Path $Dir ".venv") }
if (-not (Test-Path $Venv)) { Dung "Không tạo được môi trường Python trong $Dir\.venv" }
Write-Host "   Đang cài thư viện Python (vài phút lần đầu)..."
& $Venv -m pip install -q --upgrade pip 2>&1 | Out-Null
& $Venv -m pip install -q -r (Join-Path $Dir "requirements.txt") 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Dung "Cài thư viện Python lỗi. Chạy lại lệnh này; vẫn lỗi thì chụp màn hình gửi em." }
New-Item -ItemType Directory -Force -Path (Join-Path $Dir "_doi-quan\home") | Out-Null

# Tập lệnh chạy bản thử (PowerShell, UTF-8: tên thư mục người dùng có dấu vẫn đúng). Tự chạy lại nếu máy chủ dừng.
$Run = Join-Path $Dir "chay-ban-thu.ps1"
$noi = @"
`$env:TISA_PORT = "$Port"
`$env:TISA_BOARD_PORT = "$BPort"
`$env:DOI_QUAN_HOME = "$Dir\_doi-quan\home"
`$env:DOI_QUAN_ENV = "$Dir\_doi-quan\.env"
`$env:TISA_CLAUDE_AUTO_UPDATE = "0"
Set-Location "$Dir\server"
while (`$true) {
  & "$Venv" -m uvicorn main:app --host 127.0.0.1 --port $Port *>> "$Dir\server\tisa.log"
  Start-Sleep -Seconds 5
}
"@
Set-Content -Path $Run -Value $noi -Encoding UTF8

$PsExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$Startup = [Environment]::GetFolderPath("Startup")
$Sh = New-Object -ComObject WScript.Shell
$S = $Sh.CreateShortcut((Join-Path $Startup "TISA BOT thu.lnk"))
$S.TargetPath = $PsExe
$S.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$Run`""
$S.WorkingDirectory = (Join-Path $Dir "server")
$S.WindowStyle = 7
$S.Save()
Start-Process -FilePath $PsExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Minimized", "-File", "`"$Run`"" -WindowStyle Minimized
Write-Host "   Đang khởi động..."
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://127.0.0.1:$Port/health" | Out-Null; $ok = $true; break } catch { Start-Sleep 2 }
}
if ($ok) {
  Write-Host "== XONG. Mở http://127.0.0.1:$Port/ (lần đầu tạo tài khoản quản trị), rồi vào menu Hệ thống, Nhiều máy." -ForegroundColor Green
  if ($env:TISA_KHONG_MO -ne "1") { Start-Process "http://127.0.0.1:$Port/" }
} else { Write-Host "Chưa thấy TISA BOT trả lời. Xem nhật ký: $Dir\server\tisa.log" -ForegroundColor Yellow }
