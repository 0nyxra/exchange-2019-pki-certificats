# Semaine 6 — Flux de courrier vers Internet et dépannage (EMS)

# Files d'attente
Get-Queue
Get-Queue | Where-Object Status -eq 'Retry' | Format-List Identity, LastError

# Journaux DNS du service de transport : quel serveur DNS Exchange interroge-t-il vraiment ?
Set-TransportService WINEX -DnsLogEnabled $true -DnsLogPath "C:\ProtocolLogs\DNS"
Restart-Service MSExchangeTransport
# Get-Content (Get-ChildItem C:\ProtocolLogs\DNS\*.log | Sort LastWriteTime | Select -Last 1) -Tail 30

# Correctif : le connecteur doit utiliser les DNS externes
Set-TransportService WINEX -ExternalDNSServers 8.8.8.8,1.1.1.1 -ExternalDNSAdapterEnabled $false
Set-SendConnector "Internet" -UseExternalDNSServersEnabled $true
Restart-Service MSExchangeTransport
Get-SendConnector "Internet" | Format-List UseExternalDNSServersEnabled

# Relancer les files en Retry (jamais Submission)
Get-Queue | Where-Object { $_.Status -eq 'Retry' -and $_.Identity -notlike '*Submission' } | Retry-Queue
