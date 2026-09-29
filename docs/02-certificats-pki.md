# Semaine 3 — PKI interne et certificat SSL pour Exchange

← [Retour au README](../README.md)

**Objectif :** remplacer le certificat auto-signé d'Exchange par un certificat émis par une autorité de certification d'entreprise, pour que `https://mail.sd6.com` soit approuvé par les clients du domaine sans avertissement.

## Vue d'ensemble du flux

```
WINEX  : New-ExchangeCertificate -GenerateRequest  → CSR (.req), la clé privée reste sur WINEX
   ↓
WINEX  : soumission du CSR à WINAD via http://winad/certsrv
   ↓
WINAD  : la CA signe la demande (modèle « Web Server ») → certificat
   ↓
WINEX  : Import-ExchangeCertificate
   ↓
WINEX  : Enable-ExchangeCertificate -Services IIS,SMTP + liaisons IIS
```

La demande et la signature sont deux étapes séparées pour une raison de sécurité : **la clé privée ne quitte jamais WINEX**. Seul le CSR, qui ne contient que la clé publique et l'identité demandée, est envoyé à la CA.

---

## 1. Autodiscover sur le nom convivial

Après l'installation, l'URI interne d'Autodiscover pointe sur le nom du serveur :

```powershell
Get-ClientAccessService -Identity WINEX | Select AutoDiscoverServiceInternalUri
# https://winex.sd6.com/Autodiscover/Autodiscover.xml

Set-ClientAccessService -Identity WINEX `
  -AutoDiscoverServiceInternalUri https://mail.sd6.com/autodiscover/autodiscover.xml
```

Autodiscover permet à Outlook de se configurer avec seulement l'adresse et le mot de passe. Pour que ça fonctionne sans avertissement via `mail.sd6.com`, **le certificat doit contenir ce nom** : c'est ce qui justifie la suite.

Ensuite : redémarrage d'IIS, puis dans l'EAC → *Servers* → *Virtual Directories*, configuration de `mail.sd6.com` pour Autodiscover, ECP, EWS, MAPI, OAB, OWA et PowerShell (interne et externe).

## 2. Autorité de certification sur WINAD

Rôle **Active Directory Certificate Services** avec les services *Certification Authority* et *Certification Authority Web Enrollment*, configuré en **Enterprise CA** → **Root CA** → nouvelle clé privée.

Une CA d'entreprise est intégrée à AD : son certificat racine est automatiquement distribué aux machines du domaine, ce qui explique que WINCLIENT fasse confiance aux certificats qu'elle émet.

## 3. Demande de certificat (CSR) sur WINEX

```powershell
$txtrequest = New-ExchangeCertificate -GenerateRequest -PrivateKeyExportable $true `
  -FriendlyName "exch" `
  -SubjectName "c=CA,S=qc,L=st-hya,O=Exch,OU=USERS,CN=mail.sd6.com" `
  -DomainName mail.sd6.com -KeySize 4096 -Server WINEX

[System.IO.File]::WriteAllBytes('C:\cert\winex.req', [System.Text.Encoding]::Unicode.GetBytes($txtrequest))
```

| Paramètre | Rôle |
|---|---|
| `-GenerateRequest` | Produit une **demande** au lieu d'un certificat final |
| `-PrivateKeyExportable $true` | Permet d'exporter la clé privée plus tard (ex. autre serveur Exchange) |
| `-FriendlyName` | Nom d'affichage, pour s'y retrouver dans `Get-ExchangeCertificate` |
| `-SubjectName` | Identité X.509 : pays, province, ville, organisation, unité, et surtout le **CN** |
| `-DomainName` | Ajoute le nom dans les **SAN**, ce que les navigateurs modernes valident réellement |
| `-KeySize 4096` | Clé RSA de 4096 bits (2048 est le minimum courant) |

`New-ExchangeCertificate -GenerateRequest` ne crée pas de fichier : il retourne le texte en mémoire. `WriteAllBytes` l'écrit sur disque en contrôlant l'encodage, pour que la CA puisse le lire.

> **Erreur rencontrée :** `WriteAllBytes` → *The network name cannot be found*, puis *Access denied*. Le partage `\\winex\cert` de l'énoncé n'existait pas.
> **Solution :** créer `C:\cert` et écrire le fichier en local.

## 4. Soumission à la CA (certsrv)

Sur `http://winad/certsrv` : *Request a certificate* → *Advanced certificate request* → **Submit a certificate request by using a base-64-encoded CMC or PKCS #10 file**.

On choisit cette option, et non *Create and submit a request to this CA*, parce que la demande existe déjà : l'autre option ferait générer une **nouvelle** paire de clés par le navigateur, hors de WINEX.

- *Saved Request* : tout le contenu du `.req`, **avec** les lignes `-----BEGIN NEW CERTIFICATE REQUEST-----` et `-----END…-----`
- *Certificate Template* : **Web Server** (la liste affichait *Administrator* par défaut)
- *Additional Attributes* : vide, le SAN est déjà dans le CSR

Téléchargement du certificat et de la chaîne, installation dans *Local Machine* → *Trusted Root Certification Authorities*. Vérification : *Issued to* `mail.sd6.com`, *Issued by* `sd6-WINAD-CA`, onglet *Certification Path* → *This certificate is OK*.

## 5. Import et activation dans Exchange

```powershell
Import-ExchangeCertificate -FileData ([System.IO.File]::ReadAllBytes('C:\cert\certnew.p7b')) -Server WINEX
Enable-ExchangeCertificate -Thumbprint <THUMBPRINT> -Services IIS,SMTP
```

### Erreur : `PrivateKeyMissing`

```
The certificate with thumbprint 6AB20BA3... was found but is not valid for use
with Exchange Server (reason: PrivateKeyMissing).
```

Un nouvel import renvoyait ensuite *A certificate with the thumbprint … already exists*.

**Diagnostic :**

```powershell
Get-ExchangeCertificate -Server WINEX | Format-List Thumbprint, Subject, Status, Services, PrivateKeyExportable
```

La liste montrait **deux demandes en attente** (`Status : PendingRequest`) avec `CN=mail.sd5.com`, restes de mes premiers essais (faute de frappe `sd5` au lieu de `sd6`, CSR régénérées plusieurs fois). Le certificat signé que j'importais ne correspondait à la clé privée d'aucune demande valide : Exchange avait le certificat, mais pas la clé qui va avec.

**Solution :**

```powershell
# 1. Supprimer les demandes orphelines
Remove-ExchangeCertificate -Thumbprint 58793FCD2F21C64D58F27FC419193097D219F1AD
Remove-ExchangeCertificate -Thumbprint 4FA2B42AE003B230FC020E07074A153E32EDA0A5

# 2. Nouvelle demande propre, CN et SAN cohérents
$txtrequest = New-ExchangeCertificate -GenerateRequest -PrivateKeyExportable $true -FriendlyName "exchv3" `
  -SubjectName "c=CA,S=qc,L=st-hya,O=Exch,OU=USERS,CN=mail.sd6.com" `
  -DomainName mail.sd6.com -KeySize 4096 -Server WINEX
[System.IO.File]::WriteAllBytes('C:\cert\winex3.req', [System.Text.Encoding]::Unicode.GetBytes($txtrequest))

# 3. Après signature par la CA : import de la chaîne .p7b puis activation
Import-ExchangeCertificate -FileData ([System.IO.File]::ReadAllBytes('C:\cert\certnew3.p7b')) -Server WINEX
Enable-ExchangeCertificate -Thumbprint AE079247B94B42BA0A3AD627FFE2820925952437 -Services IIS,SMTP
# Confirm : Overwrite the existing default SMTP certificate? → Y
```

Le certificat `mail.sd6.com` remplace alors le certificat auto-signé `CN=winEX` pour IIS et SMTP.

**Leçon :** une demande de certificat, sa clé privée et le certificat signé forment un tout. Avant de réessayer, il faut regarder l'état réel avec `Get-ExchangeCertificate` et nettoyer les demandes en attente, plutôt que de régénérer des CSR par-dessus.

## 6. Liaisons IIS : Front End et Back End

Dans *IIS Manager* → *Default Web Site* → *Bindings* → HTTPS → certificat `mail.sd6.com`.

### Problème : certificat valide sur le client, mais connexion signalée non sécurisée

Le certificat apparaissait valide sur WINCLIENT, mais Edge affichait quand même une incohérence. **Cause :** Exchange crée **deux sites IIS** :

| Site IIS | Port | Rôle |
|---|---|---|
| **Default Web Site** (Front End) | 443 / 80 | Point d'entrée des clients (Outlook, navigateur, mobile); agit comme proxy |
| **Exchange Back End** | 444 | Fait le vrai travail : accès aux boîtes et à la base |

```
Client (Edge) → Front End (443) → Back End (444) → Base de données
```

Le Back End était encore lié à l'**Exchange Server Auth Certificate**. Ce certificat sert à l'authentification **serveur à serveur** (OAuth entre composants Exchange); son nom ne correspond pas à `mail.sd6.com`.

**Solution :** lier aussi le site **Exchange Back End** au certificat `mail.sd6.com`. C'est ce qui a réglé le problème.

### Problème : l'EMS ne se connecte plus

En modifiant les liaisons, j'avais retiré la liaison **HTTP (port 80)** du Default Web Site. Le répertoire virtuel PowerShell de l'EMS s'en sert pour la négociation initiale de la session (WinRM), même si la suite passe en HTTPS.
**Solution :** remettre la liaison HTTP.

```powershell
netsh http show sslcert   # vérifier quel certificat est lié à quel port
```

## 7. Test depuis WINCLIENT

Connexion avec `bsmith` dans Edge : `https://mail.sd6.com/owa` s'ouvre **sans avertissement de certificat**.

## 8. Outlook et Autodiscover

**Symptôme :** à l'ajout du compte, Outlook (version classique) choisissait lui-même un **autre type de compte** et basculait en configuration **IMAP**, en devinant un serveur à partir du domaine de l'adresse. Le compte ne se connectait donc pas à Exchange.

**Ce que j'ai vérifié :** `nslookup autodiscover.sd6.com` ne retournait pas l'IP de WINEX. J'ai ajouté un **enregistrement A `autodiscover`** dans la zone `sd6.com` sur WINAD, ce qui règle la résolution, mais Outlook continuait de choisir le mauvais type de compte.

**Solution :** dans l'assistant d'Outlook, *Advanced options* → cocher **Let me set up my account manually** → choisir le type **Exchange**. Le compte `bsmith` s'est configuré correctement : le serveur et le certificat étaient bons, le problème venait seulement du type de compte qu'Outlook sélectionnait tout seul.

➡️ Suite : [Semaine 4 — Base de données](03-base-de-donnees.md)
