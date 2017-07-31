$ethName = "OVPN" # Set name for OpenVPN ethernet adapter.
$ethernet = Get-NetAdapter | Where-Object Name -EQ "$ethName" # Getting eth adapter by name for futher checking.
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
    Write-Host "Checking connection to $server" -foreground "Green"
    # Testing connection to that server. If unreachable - skip.
    if (Test-Connection -computername $server -Quiet) {
      # Killing previous ovpn process if exists.
      Write-Host "Connection succeed, looking for active ovpn process." -foreground "Green"
      if (($proc = Get-Process openvpn -ErrorAction SilentlyContinue) -ne $Null) {
        Stop-Process -inputobject $proc -PassThru -Force -ErrorAction SilentlyContinue
        if($?) {
          Write-host $proc "Stopped Successfully" -foreground "Green"
        }
        else {
          Write-Error $error[0] -foreground "Red"
        }
        # Write-Host "Process openvpn.exe was successfuly killed."
      } else {Write-Host "OpenVPN not started. Nothing to kill." -foreground "Green"} 
      cd $confDir
      # Starting ovpn
      Start-Process -FilePath "$ovpnExe" -Argumentlist "--config","$config" -NoNewWindow
      # Give it 1 min to connect
      Start-Sleep -s 120
      # Reseting counter
      $i = 1
      # While counter haven't reached 180 (3 hours) and ethernet adapter is up do this loop. If connection drops end loop and start new connection
      while ($i -le $timeout -and $ethernet.Status -eq "Up") {
        $i++
        Start-Sleep -s 60
      }
    } else {
        Write-host $proc "Connection to $server failed. Moving to the next one" -foreground "Green"
        continue
      }
  } 
}
