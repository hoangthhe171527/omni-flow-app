param([string]$Csv, [string]$Out)
# Sinh bảng việc Đợt 3 theo từng file màn/sheet từ số đo của scan-screens.ps1.
$r = Import-Csv $Csv | ForEach-Object {
  foreach ($k in 'glass','blur','btnDeco','selWhite','circle','tinted','fab','seg','brand','colorText','material','lines') { $_.$k = [int]$_.$k }
  $_
}
function Codes($x) {
  $c = @()
  if ($x.glass + $x.blur -gt 0) { $c += "K$($x.glass + $x.blur)" }
  if ($x.btnDeco -gt 0)  { $c += "N$($x.btnDeco)" }
  if ($x.selWhite -gt 0) { $c += "C$($x.selWhite)" }
  if ($x.colorText -gt 0){ $c += "T$($x.colorText)" }
  if ($x.seg -gt 0)      { $c += "S$($x.seg)" }
  if ($x.fab -gt 0)      { $c += "F" }
  if ($x.brand -gt 0)    { $c += "L" }
  if ($x.material -gt 0) { $c += "M$($x.material)" }
  if ($x.circle + $x.tinted -gt 0) { $c += "A" }
  $c
}
$sb = [Text.StringBuilder]::new()
$work = $r | ForEach-Object { $c = Codes $_; [pscustomobject]@{ row = $_; codes = $c; manual = (@($c | Where-Object { $_ -notin 'A','F' })).Count } }
$total = $work.Count; $manual = @($work | Where-Object manual -gt 0).Count
[void]$sb.AppendLine("Tổng: **$total file** có màn hoặc sheet; **$manual file** phải sửa tay (có mã khác A/F). Số đo bằng script ``scan-screens.ps1`` ngày 25/11/2026, nhánh ``feat/nhan-su-app``.")
[void]$sb.AppendLine()
foreach ($g in ($work | Group-Object { $_.row.module } | Sort-Object { -(($_.Group | Measure-Object manual -Sum).Sum) }, Name)) {
  $m = ($g.Group | Measure-Object manual -Sum).Sum
  [void]$sb.AppendLine("#### $($g.Name) ($($g.Count) file)")
  [void]$sb.AppendLine()
  [void]$sb.AppendLine("| File | Màn / sheet | Việc |")
  [void]$sb.AppendLine("|---|---|---|")
  foreach ($w in ($g.Group | Sort-Object { -$_.manual }, { $_.row.file })) {
    $codes = if ($w.codes) { ($w.codes -join ' · ') } else { '—' }
    $cls = $w.row.classes -replace '^_', '' -replace ', _', ', '
    $f = $w.row.file -replace '^modules/[^/]+/', ''
    [void]$sb.AppendLine("| ``$f`` | $cls | $codes |")
  }
  [void]$sb.AppendLine()
}
[IO.File]::WriteAllText($Out, $sb.ToString(), [Text.UTF8Encoding]::new($false))
"total=$total manual=$manual"
