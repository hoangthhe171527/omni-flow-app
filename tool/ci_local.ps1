# CI chạy tại máy (thay workflow CI trên GitHub, đã tắt có chủ đích 22/11/2026).
#
# Chỉ kiểm PHẠM VI thay đổi so với nhánh gốc, giới hạn 2 tiến trình test — chạy
# cả bộ test trên laptop làm treo máy. Chạy trước khi mở PR / merge:
#
#   powershell -ExecutionPolicy Bypass -File tool/ci_local.ps1
#   powershell -ExecutionPolicy Bypass -File tool/ci_local.ps1 -Base origin/main
#
# Các bước (dừng ở bước hỏng đầu tiên, mã thoát khác 0):
#   1. dart format --set-exit-if-changed  — file .dart đã đổi
#   2. flutter analyze                    — file .dart đã đổi
#   3. flutter test --concurrency=2       — test/architecture + test đã đổi +
#      test import một file lib đã đổi (theo đường dẫn package hoặc tên file)
param(
  [string]$Base = 'origin/main',
  [int]$Batch = 25
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$flutter = 'flutter'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  if (Test-Path 'D:\_tools\flutter\bin\flutter.bat') { $flutter = 'D:\_tools\flutter\bin\flutter.bat' }
  else { Write-Error 'Không thấy flutter trên PATH.' }
}
$dart = Join-Path (Split-Path $((Get-Command $flutter).Source)) 'dart.bat'
if (-not (Test-Path $dart)) { $dart = 'dart' }

$changed = @(
  git diff --name-only --diff-filter=d "$Base...HEAD"
  git diff --name-only --diff-filter=d
  git diff --name-only --diff-filter=d --cached
  git ls-files --others --exclude-standard
) | Where-Object { $_ -like '*.dart' -and (Test-Path $_) } | Sort-Object -Unique

if ($changed.Count -eq 0) { Write-Host 'Không có file .dart nào đổi so với' $Base; exit 0 }
Write-Host "== $($changed.Count) file .dart đổi so với $Base"

Write-Host '== 1/3 dart format'
& $dart format --output=none --set-exit-if-changed $changed
if ($LASTEXITCODE -ne 0) { Write-Error 'Chưa format. Chạy: dart format <các file trên>' }

Write-Host '== 2/3 flutter analyze'
& $flutter analyze $changed
if ($LASTEXITCODE -ne 0) { Write-Error 'analyze báo lỗi.' }

Write-Host '== 3/3 flutter test (phạm vi)'
$libChanged = $changed | Where-Object { $_ -like 'lib/*' }
$tests = New-Object System.Collections.Generic.HashSet[string]
Get-ChildItem test/architecture -Filter *_test.dart | ForEach-Object { [void]$tests.Add(("test/architecture/" + $_.Name)) }
$changed | Where-Object { $_ -like 'test/*_test.dart' } | ForEach-Object { [void]$tests.Add($_) }
if ($libChanged.Count -gt 0) {
  $needles = foreach ($f in $libChanged) {
    'package:omni_app/' + $f.Substring(4)
    '/' + (Split-Path $f -Leaf) + "'"
  }
  Get-ChildItem test -Recurse -Filter *_test.dart | ForEach-Object {
    $text = Get-Content $_.FullName -Raw
    foreach ($n in $needles) {
      if ($text.Contains($n)) {
        [void]$tests.Add((Resolve-Path -Relative $_.FullName).TrimStart('.', '\').Replace('\', '/'))
        break
      }
    }
  }
}
$list = @($tests) | Sort-Object
Write-Host "   $($list.Count) file test"
$failed = $false
for ($i = 0; $i -lt $list.Count; $i += $Batch) {
  $chunk = $list[$i..([Math]::Min($i + $Batch - 1, $list.Count - 1))]
  & $flutter test --concurrency=2 $chunk
  if ($LASTEXITCODE -ne 0) { $failed = $true }
}
if ($failed) { Write-Error 'Có test hỏng.' }
Write-Host '== CI local: XANH'
