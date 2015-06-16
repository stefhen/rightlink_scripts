$ErrorActionPreference = 'Stop'

$RIGHTLINK_DIR = 'C:\Program Files\RightScale\RightLink'

if ($env:SSC_SERV_VERSION) {
  $SSCServVersion = $env:SSC_SERV_VERSION
} else {
  $SSCServVersion = '3.5.0'
}

if ($env:SSC_SERV_PLATFORM) {
  $SSCServPlatform = $env:SSC_SERV_PLATFORM
} else {
  $SSCServPlatform = 'x86-64'
}

$SSCServInstaller = "SSC Serv Setup ${SSCServVersion} ${SSCServPlatform} Free Edition.exe"
(New-Object System.Net.WebClient).DownloadFile("https://ssc-serv.com/files/${SSCServInstaller}", "${PSScriptRoot}\${SSCServInstaller}")
Start-Process ".\${SSCServInstaller}" -ArgumentList @('/SILENT', '/SUPPRESSMSGBOXES', '/NOCANCEL', '/NORESTART') -Wait

$SSCServRegRoot = 'HKLM:\SOFTWARE\octo\SSC Serv'

Set-ItemProperty $SSCServRegRoot HostName $env:RS_INSTANCE_UUID
Set-ItemProperty "${SSCServRegRoot}\Network" Enabled 'false'
Remove-Item "${SSCServRegRoot}\Network\*"
Set-ItemProperty "${SSCServRegRoot}\Write_HTTP" Enabled 'true'

$ProxyPort = Get-Content 'C:\ProgramData\RightScale\RightLink\secret' | Select-String '^RS_RLL_PORT=' | % { $_ -replace '^RS_RLL_PORT=', '' }
$SSCServRegProxy = "${SSCServRegRoot}\Write_HTTP\RightLinkProxy"

if (!(Test-Path -Path $SSCServRegProxy)) {
  New-Item $SSCServRegProxy
  New-ItemProperty $SSCServRegProxy URL -Value "http://localhost:${ProxyPort}/rll/tss/collectdv5"
  New-ItemProperty $SSCServRegProxy Username -Value ""
  New-ItemProperty $SSCServRegProxy Password -Value ""
  New-ItemProperty $SSCServRegProxy StoreRates -Value true
} else {
  Set-ItemProperty $SSCServRegProxy URL -Value "http://localhost:${ProxyPort}/rll/tss/collectdv5"
  Set-ItemProperty $SSCServRegProxy Username -Value ""
  Set-ItemProperty $SSCServRegProxy Password -Value ""
  Set-ItemProperty $SSCServRegProxy StoreRates -Value true
}

& "${RIGHTLINK_DIR}\rsc.exe" rl10 put_hostname /rll/tss/hostname hostname=$env:RS_TSS
Start-Service 'SSC Service'
& "${RIGHTLINK_DIR}\rsc.exe" --rl10 cm15 multi_add /api/tags/multi_add resource_hrefs[]=$env:RS_SELF_HREF tags[]=rs_monitoring:state=auth