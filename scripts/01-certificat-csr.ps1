# Semaine 3 — Autodiscover et demande de certificat (EMS sur WINEX)

Set-ClientAccessService -Identity WINEX `
  -AutoDiscoverServiceInternalUri https://mail.sd6.com/autodiscover/autodiscover.xml
Get-ClientAccessService -Identity WINEX | Format-List AutoDiscoverServiceInternalUri

# Demande de certificat (CSR) — la clé privée reste sur WINEX
New-Item -Path C:\cert -ItemType Directory -Force | Out-Null
$txtrequest = New-ExchangeCertificate -GenerateRequest -PrivateKeyExportable $true -FriendlyName "exchv3" `
  -SubjectName "c=CA,S=qc,L=st-hya,O=Exch,OU=USERS,CN=mail.sd6.com" `
  -DomainName mail.sd6.com -KeySize 4096 -Server WINEX
[System.IO.File]::WriteAllBytes('C:\cert\winex3.req', [System.Text.Encoding]::Unicode.GetBytes($txtrequest))

# -> Soumettre le contenu de winex3.req sur http://winad/certsrv (modèle Web Server)
#    et récupérer la chaîne certnew3.p7b
