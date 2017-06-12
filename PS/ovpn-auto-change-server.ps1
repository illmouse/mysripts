$ethName = "OVPN" # Set name for OpenVPN ethernet adapter.
$ConfFilesFilter = "*UDP.ovpn" # Set mask for .ovpn config files (here I'm taking only files ending with UDP in name)
$regexSrvAddr = "(?<=remote ).*net" # Set regular expresion to extract server address from .ovpn config file
$ovpnExe = "C:\Program Files\OpenVPN\bin\openvpn.exe" # Set openvpn.exe destination
$confDir = "C:\Program Files\OpenVPN\config\" # Set directory where you store config files
$confFiles = Get-ChildItem $confDir -Filter $ConfFilesFilter # Get list o files in config directory
$timeout = 180 # Set timeout for connection in minutes. (How often change VPN server).

while($true) {
  # Interate on each file in direcroty inside infinite loop
  forEach($config in $confFiles) {
    # Getting server name from config file
    $server = get-content ($confDir + $config) | Select-String -Pattern "$regexSrvAddr" -AllMatches | % { $_.Matches } | % { $_.Value }
    Write-Host "Checking connection to $server"
    # Testing connection to that server. If unreachable - skip.
    if (Test-Connection -computername $server) {
      # Killing previous ovpn process if exists.
      Write-Host "Connection succeed, looking for active ovpn process."
      if (($proc = Get-Process openvpn -ErrorAction SilentlyContinue) -ne $Null) {
        Stop-Process -inputobject $proc -PassThru -Force -ErrorAction SilentlyContinue
        if($?) {
          Write-host $proc " Stopped Successfully"
        }
        else {
          Write-Error $error[0]
        }
        # Write-Host "Process openvpn.exe was successfuly killed."
      } else {Write-Host "OpenVPN not started. Nothing to kill."}
      cd $confDir
      # Starting ovpn
      Start-Process -FilePath "$ovpnExe" -Argumentlist "--config","$config" -NoNewWindow
      # Give it 1 min to connect
      Start-Sleep -s 60
      # Reseting counter
      $i = 1
      # While counter haven't reached 180 (3 hours) and ethernet adapter is up do this loop. If connection drops end loop and start new connection
      while ($i -le $timeout -and (Get-NetAdapter | Where-Object Name -EQ "$ethName").Status -eq "Up") {
        $i++
        Start-Sleep -s 60
      }
    } else {continue}
  } 
}
