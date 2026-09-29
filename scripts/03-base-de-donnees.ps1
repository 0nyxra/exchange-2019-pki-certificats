# Semaine 4 — Renommer et déplacer la base (EMS)
Get-MailboxDatabase | Format-List Name, EdbFilePath, LogFolderPath

$db = Get-MailboxDatabase | Select-Object -First 1
Set-MailboxDatabase $db.Name -Name "DB01"

Move-DatabasePath DB01 -EdbFilePath F:\Exchange\DB01.edb -LogFolderPath F:\Exchange\logs
Restart-Service MSExchangeIS
Get-MailboxDatabase | Format-List Name, EdbFilePath, LogFolderPath
