# Semaines 1 et 2 — Prérequis et installation

← [Retour au README](../README.md)

## Semaine 1 — Préparation de l'environnement

1. Installation de WINAD (10.168.151.1), WINEX (10.168.151.2) et WINCLIENT (10.168.151.3).
2. AD DS sur WINAD avec le domaine **sd6.com**; WINEX et WINCLIENT joints au domaine.
3. Création des utilisateurs Brent Smith (`bsmith`), Zach Myers (`zmyers`) et Eric Bass (`ebass`).
4. Sur WINCLIENT : connexion avec `bsmith`, ajout de *Domain Users* au groupe administrateurs local, installation d'Office.
5. Sur WINEX, connecté en administrateur du domaine : ISO d'Exchange 2019 monté, Visual C++ 2013 et UCMA 4.0 installés.

```powershell
Add-WindowsFeature RSAT-ADDS-tools

Install-WindowsFeature RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, `
  RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, `
  Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, `
  Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, `
  Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Service, `
  Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, `
  Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, NET-WCF-HTTP-Activation45
```

Puis .NET Framework 4.8 et le module IIS URL Rewrite 2.1.

## Semaine 2 — Installation en ligne de commande

```powershell
Setup /PrepareSchema /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF
Setup /PrepareAD /OrganizationName:"Shinedown" /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF
Setup /Mode:Install /Role:Mailbox /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /Restart
```

### Vérifications après l'installation

**Journal `C:\ExchangeSetupLogs\ExchangeSetup.log`** — j'y ai trouvé l'erreur `0x80072030` (*There is no such object on the server*). Elle est **normale** : juste après, le log continue avec *Creating Active Directory objects…*. Le setup vérifie d'abord si l'objet existe dans AD avant de le créer; lors d'une première installation, il n'existe pas encore. La ligne *The Exchange Server setup operation completed successfully* à la fin confirme que ce n'est pas bloquant.

**Event Viewer** — des erreurs concernant `MSExchangeMigrationWorkflow` et `MSExchangeStoreObjectsService`. Ces deux services ne sont pas installés sur cette configuration (ils sont liés à des scénarios hybrides/Exchange Online). Le setup tente de les démarrer par précaution : erreur cosmétique, sans impact.

**Services** — tous les services critiques (Transport, Information Store, Mailbox Assistants, RPC, ADTopology…) sont *Running*. Ceux qui sont arrêtés le sont **volontairement** :

| Service arrêté | Pourquoi c'est normal |
|---|---|
| IMAP4, IMAP4 Backend, POP3, POP3 Backend | Désactivés par défaut; utiles seulement si on active ces protocoles |
| vmickvpexchange | Lié à Hyper-V |
| wsbexchange | Lié à Windows Server Backup |

```powershell
Get-ExchangeServer | Format-Table Name, ServerRole, AdminDisplayVersion, Edition -AutoSize
```

Dans *Active Directory Users and Computers*, l'OU **Microsoft Exchange Security Groups** confirme que `/PrepareAD` a créé les groupes (Organization Management, Recipient Management, etc.); j'ai lu la description de chacun.

### Deux cartes réseau (dual-homed)

WINEX a une carte privée et une carte Internet. Sur les deux, IPv6 est désactivé. Sur la carte Internet, j'ai désactivé :
- *Client for Microsoft Networks* et *File and Printer Sharing*;
- la recherche LMHOSTS et NetBIOS sur TCP/IP;
- *Register this connection's addresses in DNS*.

Sans ça, le serveur risque de s'enregistrer dans le DNS avec la mauvaise adresse et de mal résoudre son propre nom.

### DNS

- Accès à l'EAC depuis WINEX : `https://winex/ecp` (avertissement de certificat attendu à ce stade : le certificat est encore auto-signé).
- **CNAME** `mail` → `winex.sd6.com`, pour utiliser un nom convivial : `https://mail.sd6.com`.
- **MX** dans la zone `sd6.com` : hôte vide (domaine parent), serveur `winex.sd6.com`, priorité 10.

➡️ Suite : [Semaine 3 — Certificats et PKI](02-certificats-pki.md)
