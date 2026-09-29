# Semaine 6 — Flux de courrier vers Internet et dépannage DNS

← [Retour au README](../README.md)

**Objectif :** envoyer un courriel de `bsmith` vers une adresse externe (Gmail, Hotmail, adresse du Cégep).

## 1. Connecteur d'envoi

Sans connecteur d'envoi, Exchange ne sait pas router le courrier hors de l'organisation.

EAC → *Mail Flow* → *Send Connectors* → **+** :
- Nom : `Internet`, type : *Internet*
- Livraison : **MX record associated with recipient domain**
- Espace d'adressage : SMTP, FQDN `*`
- Serveur source : WINEX

## 2. Symptôme : messages bloqués en `Retry`

Les courriels restaient coincés dans la file d'attente.

```powershell
Get-Queue
Get-Queue -Identity "winEX\6" | Format-List LastError   # l'erreur est sur la file, pas sur les messages
Get-Queue | Get-Message | Format-List
```

## 3. Ce que j'ai essayé (sans succès)

| Test | Résultat | Conclusion |
|---|---|---|
| `Resolve-DnsName gmail.com -Type MX` | Fonctionne | **Trompeur** : ce test n'utilise pas le même chemin de résolution qu'Exchange |
| `Test-NetConnection` sur les ports 25 et 53 | Ouverts | Pas un blocage de pare-feu |
| `Get-NetAdapterBinding -ComponentID ms_tcpip6` | IPv6 déjà désactivé | Pas la cause |
| EAC : décocher *Use the external DNS lookup settings…*, puis sur le serveur *DNS lookups* : carte Internet en externe, carte privée en interne | Sans effet | — |
| `Set-TransportService WINEX -ExternalDNSServers 8.8.8.8,1.1.1.1` | Sans effet | Ignoré tant que `ExternalDNSAdapterEnabled` est à `True` |
| `Set-TransportService WINEX -ExternalDNSAdapterEnabled $false` | Sans effet | — |

## 4. Le vrai diagnostic : les journaux DNS d'Exchange

```powershell
Set-TransportService WINEX -DnsLogEnabled $true -DnsLogPath "C:\ProtocolLogs\DNS"
Restart-Service MSExchangeTransport
```

Les journaux (`C:\ProtocolLogs\DNS\*.log`) montraient qu'Exchange interrogeait **toujours 10.168.151.1** (WINAD, le DNS interne) pour résoudre `gmail.com`, quelle que soit la configuration du service de transport. WINAD ne résout pas les domaines externes : chaque requête revenait en `Status=ServerFailure`.

## 5. La cause et la correction

Le **connecteur d'envoi** a son propre paramètre, qui a priorité sur le service de transport :

```powershell
Get-SendConnector "Internet" | Format-List UseExternalDNSServersEnabled
# False
```

Tant qu'il est à `False`, le connecteur ignore `ExternalDNSServers` et utilise le DNS interne.

```powershell
Set-SendConnector "Internet" -UseExternalDNSServersEnabled $true
Restart-Service MSExchangeTransport
Retry-Queue -Identity "winEX\6"   # jamais sur winEX\Submission
```

Le journal DNS a aussitôt affiché `Server=8.8.8.8; Status=Success` avec les vrais enregistrements MX de Gmail et du Cégep, et les messages sont partis. (Penser à vérifier le dossier *Spam* du côté destinataire : un serveur de labo sans SPF/DKIM y atterrit souvent.)

**Leçon :** quand `Resolve-DnsName` fonctionne mais qu'Exchange échoue, le problème n'est presque jamais le DNS lui-même, mais **le chemin de résolution qu'Exchange utilise**. Les journaux DNS du transport sont le seul moyen fiable de voir quel serveur il interroge réellement.

## 6. Stratégie d'adresses de messagerie

EAC → *Recipients* → `bsmith` → *Email Address* : l'adresse SMTP est `bsmith@sd6.com`.
EAC → *Mail Flow* → *Email Address Policies* → *Default Policy* : format `@sd6.com`, types de destinataires visés (*Apply to*). J'ai aussi testé l'ajout d'un autre format et le changement de domaine pour certains utilisateurs.

## Commandes de vérification à garder

| Objectif | Commande |
|---|---|
| État des files | `Get-Queue` |
| Erreur d'une file | `Get-Queue -Identity "winEX\6" \| FL LastError` |
| Relancer une file | `Retry-Queue -Identity "winEX\6"` |
| Certificats et statut | `Get-ExchangeCertificate \| FL Thumbprint,Subject,Status,Services,PrivateKeyExportable` |
| URI Autodiscover | `Get-ClientAccessService -Identity WINEX \| FL AutoDiscoverServiceInternalUri` |
| Journaux DNS du transport | `Set-TransportService WINEX -DnsLogEnabled $true -DnsLogPath "C:\ProtocolLogs\DNS"` |
| DNS externe du connecteur | `Get-SendConnector "Internet" \| FL UseExternalDNSServersEnabled` |

← [Retour au README](../README.md)
