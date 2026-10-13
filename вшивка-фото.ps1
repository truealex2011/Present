param(
  [string]$PhotoDir,
  [string]$Html,
  [string]$CsvMap,
  [switch]$DryRun
)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$dir=Split-Path -Parent $MyInvocation.MyCommand.Path
if(-not $PhotoDir){$PhotoDir=Join-Path $dir 'Пирожок с макаронами'}
if(-not $Html){$Html=Join-Path $dir 'Дмитрий Бакланов — zigzag (1).html'}
$mime=@{'.jpg'='image/jpeg';'.jpeg'='image/jpeg';'.png'='image/png';'.webp'='image/webp';'.gif'='image/gif';'.bmp'='image/bmp'}
$order=@('G1:7я','G1:7я2','G1:7я3','G1:7я4','G1:свадьба1','G1:свадьба2')
1..11|ForEach-Object{$order+=('G2:алекс'+$_)}
$order+=@('G3:артём1','G3:артём2')
1..8|ForEach-Object{$order+=('IF:k{0:d2}' -f $_)}
$MAP=@{
 'G1:7я'=@('7я','семь я','7 ya','семья','7ya');
 'G1:7я2'=@('7я2','7я_2','семья2','7ya2');
 'G1:7я3'=@('7я3','7я_3','семья3','7ya3');
 'G1:7я4'=@('7я4','7я_4','семья4','7ya4');
 'G1:свадьба1'=@('свадьба1','свадебная','свадьба*1*','свадьба*','svadba*','wedding*');
 'G1:свадьба2'=@('свадьба2','свадебное*','свадьба*2*','svadba*2*','wedding*2*');
 'G3:артём1'=@('Дети_Артем','Дети_Артем1','артём1','артем1','artem1','артём*','артем*');
 'G3:артём2'=@('Дети_Артем2','артём2','артем2','artem2')
}
$MAP['G2:алекс1']=@('Дети_Алекс','ДетиАлекс-1','дети алекс','алекс1','alex1')
2..11|ForEach-Object{$MAP[('G2:алекс'+$_)]=@(('Дети_Алекс{0}' -f $_),('ДетиАлекс-{0}' -f $_),('алекс{0}' -f $_),('alex{0}' -f $_))}
$MAP['IF:k01']=@('свадебная','свадьба*','svadba*','wedding*')
$MAP['IF:k02']=@('свадебное*','свадьба*2*','svadba*2*','wedding*2*','свадьба*')
$MAP['IF:k03']=@('7я','семь я','семья*','7ya*')
$MAP['IF:k04']=@('7я2','7я3','7я4','семья*2*','7ya*2*')
$MAP['IF:k05']=@('ОтцыИдети*','отцы*дети*','отцы*')
$MAP['IF:k06']=@('Охота','охота')
$MAP['IF:k07']=@('Хобби','хобби')
$MAP['IF:k08']=@('ДетиАлекс-1','Дети_Алекс','дети*алекс*','алекс*')
$explicit=@{}
if($CsvMap){
  if(-not (Test-Path -LiteralPath $CsvMap)){throw 'CsvMap: файл не найден'}
  foreach($r in (Import-Csv -LiteralPath $CsvMap -Delimiter ';' -Header 'k','f')){
    if($r.k){$explicit[$r.k.Trim()]=$r.f.Trim()}
  }
}
function Test-Img([string]$path,[string]$ext){
  $fs=[IO.File]::OpenRead($path)
  try{
    $b=New-Object byte[] 12
    $n=$fs.Read($b,0,12)
    if($n -lt 4){return $false}
    switch($ext){
      '.jpg'{return ($b[0] -eq 0xFF -and $b[1] -eq 0xD8 -and $b[2] -eq 0xFF)}
      '.jpeg'{return ($b[0] -eq 0xFF -and $b[1] -eq 0xD8 -and $b[2] -eq 0xFF)}
      '.png'{return ($b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47)}
      '.gif'{return ($b[0] -eq 0x47 -and $b[1] -eq 0x49 -and $b[2] -eq 0x46 -and $b[3] -eq 0x38)}
      '.bmp'{return ($b[0] -eq 0x42 -and $b[1] -eq 0x4D)}
      '.webp'{return ($n -ge 12 -and [System.Text.Encoding]::ASCII.GetString($b,0,4) -eq 'RIFF' -and [System.Text.Encoding]::ASCII.GetString($b,8,4) -eq 'WEBP')}
      default{return $false}
    }
  }finally{$fs.Dispose()}
}
$files=@()
if(Test-Path -LiteralPath $PhotoDir){
  $allImg=@(Get-ChildItem -LiteralPath $PhotoDir -Recurse -File | Where-Object { $_.Length -gt 0 -and $mime.ContainsKey($_.Extension.ToLower()) })
  $files=@($allImg | Where-Object { Test-Img $_.FullName $_.Extension.ToLower() } | Sort-Object FullName)
  if($allImg.Count -gt $files.Count){Write-Output ('Отброшено повреждённых (сигнатура): {0}' -f ($allImg.Count-$files.Count))}
}else{
  Write-Output ('ВНИМАНИЕ: папка не найдена: '+$PhotoDir)
}
$used=@{}
$res=@{}
Write-Output ('Слотов: {0}, фото-кандидатов: {1}' -f $order.Count,$files.Count)
foreach($k in $order){
  $pick=$null
  if($explicit.ContainsKey($k)){
    $p=Join-Path $PhotoDir $explicit[$k]
    if(Test-Path -LiteralPath $p){$pick=(Get-Item -LiteralPath $p).FullName}
  }else{
    $reuse=($k -like 'IF:*')
    foreach($pat in $MAP[$k]){
      $hit=$files|Where-Object{ ($reuse -or -not $used.ContainsKey($_.FullName)) -and ($_.BaseName -like $pat) }|Select-Object -First 1
      if($hit){$pick=$hit.FullName;break}
    }
  }
  if($pick){
    $used[$pick]=$k
    $e=[IO.Path]::GetExtension($pick).ToLower()
    $res[$k]='data:'+$mime[$e]+';base64,'+[Convert]::ToBase64String([IO.File]::ReadAllBytes($pick))
    Write-Output ('  + {0}  <-  {1}' -f $k,[IO.Path]::GetFileName($pick))
  }else{
    Write-Output ('  - {0}  [нет фото — заглушка]' -f $k)
  }
}
$cnt=$res.Count
if($cnt -eq 0){
  Write-Output ('НИЧЕГО НЕ ВШИТО: подходящих фото нет в '+$PhotoDir)
  exit 1
}
$parts=foreach($k in $order){ if($res.ContainsKey($k)){ "'"+$k+"':'"+$res[$k]+"'" } }
$js='const PB={'+([string]::Join(",`n",$parts))+'};'
$txt=[IO.File]::ReadAllText($Html,[System.Text.Encoding]::UTF8)
$rx=New-Object System.Text.RegularExpressions.Regex('const PB=\{[\s\S]*?\};')
if(-not $rx.IsMatch($txt)){throw 'маркер const PB не найден в HTML'}
$new=$rx.Replace($txt,$js,1)
if($DryRun){
  Write-Output ('DRY-RUN: вшил бы {0}/{1} слотов' -f $cnt,$order.Count)
  exit 0
}
$bak=Join-Path (Split-Path -Parent $Html) (([IO.Path]::GetFileNameWithoutExtension($Html))+' [бэкап до вшивки].html')
if(-not (Test-Path -LiteralPath $bak)){Copy-Item -LiteralPath $Html $bak}
[IO.File]::WriteAllText($Html,$new,(New-Object System.Text.UTF8Encoding $false))
Write-Output ('ГОТОВО: вшито {0}/{1} слотов. Бэкап: {2}' -f $cnt,$order.Count,[IO.Path]::GetFileName($bak))
$left=@($files|Where-Object{ -not $used.ContainsKey($_.FullName) })
if($left.Count){
  Write-Output ('Не использованы ({0}):' -f $left.Count)
  $left|ForEach-Object{Write-Output ('  ? '+$_.Name)}
}
Write-Output 'CsvMap-формат (точно задать соответствие): строки "ключ;имя_файла", например "G2:алекс3;IMG_2211.jpg"'
