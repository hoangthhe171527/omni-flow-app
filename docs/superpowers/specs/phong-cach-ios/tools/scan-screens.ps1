param([string]$Root = "d:\_omnicrm\omni-flow-app\lib", [string]$Out)
# Quét mọi file có màn (…Page) hoặc sheet (…Sheet) và đếm dấu hiệu kiểu kính cũ.
$sig = [ordered]@{
  glass     = 'OmniGlass\(|OmniGlassLens|OmniGlassSheet|OmniGlassAlert|_Glass\w+'
  blur      = 'BackdropFilter|ImageFilter\.blur'
  btnDeco   = 'OmniGlass\.buttonDecoration'
  selWhite  = 'OmniGlass\.selectionOf'
  circle    = 'OmniGlassCircle'
  tinted    = 'OmniTintedButtons'
  fab       = 'OmniLiquidFab|OmniFabLayer|FloatingActionButton'
  seg       = 'OmniSegmented|SegmentedButton|ChoiceChip|FilterChip'
  brand     = 'OmniBrandMark|BrandAnchor'
  topbar    = 'OmniTopBar\('
  sheetFn   = 'showOmniSheet|showModalBottomSheet'
  colorText = 'color:\s*(scheme\.primary|OmniColors\.(warning|success|destructive|danger)\w*)'
  material  = '\b(ListTile|AlertDialog|showDatePicker|DropdownButton)\b'
}
$rows = foreach ($f in Get-ChildItem $Root -Recurse -Filter *.dart) {
  $t = [IO.File]::ReadAllText($f.FullName)
  $types = [regex]::Matches($t, 'class (\w+(Page|Sheet|Screen))\b') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch 'State$' } | Select-Object -Unique
  if (-not $types) { continue }
  $rel = $f.FullName.Substring($Root.Length + 1) -replace '\\', '/'
  $mod = if ($rel -match '^modules/([^/]+)/') { $Matches[1] } elseif ($rel -match '^app/([^/]+)/') { 'app/' + $Matches[1] } else { ($rel -split '/')[0] }
  $o = [ordered]@{ module = $mod; file = $rel; classes = ($types -join ', '); lines = ($t -split "`n").Count }
  foreach ($k in $sig.Keys) { $o[$k] = [regex]::Matches($t, $sig[$k]).Count }
  [pscustomobject]$o
}
$rows | Sort-Object module, file | Export-Csv -NoTypeInformation -Encoding UTF8 $Out
"files=$($rows.Count) pages=$(($rows | Where-Object classes -match 'Page|Screen').Count)"
