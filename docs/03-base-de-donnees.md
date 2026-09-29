# Semaine 4 — Base de données et première boîte aux lettres

← [Retour au README](../README.md)

## 1. Renommer la base par défaut

```powershell
Get-MailboxDatabase | Format-List Name, EdbFilePath, LogFolderPath
```

L'installation crée une base avec un nom généré automatiquement, du type `Mailbox Database 2116642217`, et la place sur `C:`. Je la renomme pour qu'elle soit facile à identifier :

```powershell
Set-MailboxDatabase "Mailbox Database <numéro>" -Name "DB01"
Get-MailboxDatabase | Format-List Name, EdbFilePath, LogFolderPath
```

## 2. Déplacer la base et les journaux sur un disque dédié

Ajout d'un disque virtuel de 60 Go, formaté en NTFS, lettre **F:**, volume nommé *Exchange*.

```powershell
Move-DatabasePath DB01 -EdbFilePath F:\Exchange\DB01.edb -LogFolderPath F:\Exchange\logs
Restart-Service MSExchangeIS
```

Séparer la base du système est une bonne pratique : la croissance de la base et des journaux de transactions ne peut plus remplir le disque système, et les performances d'entrée/sortie sont isolées. `Move-DatabasePath` démonte la base le temps de la copie.

Vérification : `F:\Exchange` contient le fichier `.edb` et le dossier `logs`.

## 3. Première boîte aux lettres et test

1. EAC → *Recipients* → *Mailboxes* → **+** → *User Mailbox* → *Browse* → **Brent Smith** → *Save*.
2. `https://mail.sd6.com/owa` sur WINEX, connecté en administrateur : envoi d'un courriel à `bsmith`.
3. Sur WINCLIENT, connecté avec `bsmith`, Outlook reçoit le message; réponse envoyée à l'administrateur.

Le message fait l'aller-retour entre OWA et Outlook : la base, le transport et l'accès client fonctionnent.

## Semaine 5

TP1 : installation et configuration complète d'Exchange 2019, documentée dans un [dépôt séparé](https://github.com/Chahdmk/exchange-server-2019-lab).

➡️ Suite : [Semaine 6 — Flux de courrier vers Internet](04-flux-courrier-internet.md)
