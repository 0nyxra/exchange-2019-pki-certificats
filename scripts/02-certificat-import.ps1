# Semaine 3 — Import et activation du certificat signé (EMS sur WINEX)

# État actuel : repérer les PendingRequest orphelines avant d'importer
Get-ExchangeCertificate -Server WINEX | Format-List Thumbprint, Subject, Status, Services, PrivateKeyExportable

# Nettoyage d'une demande orpheline (remplacer par le bon thumbprint)
# Remove-ExchangeCertificate -Thumbprint <THUMBPRINT>

$cert = Import-ExchangeCertificate -FileData ([System.IO.File]::ReadAllBytes('C:\cert\certnew3.p7b')) -Server WINEX
Enable-ExchangeCertificate -Thumbprint $cert.Thumbprint -Services IIS,SMTP

# Ensuite dans IIS Manager : liaison HTTPS du "Default Web Site" ET de "Exchange Back End"
# sur le certificat mail.sd6.com. Garder la liaison HTTP (port 80) du Default Web Site.
netsh http show sslcert
