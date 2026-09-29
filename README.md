# Exchange Server 2019 — PKI interne, certificats et flux de courrier

![Windows Server 2019](https://img.shields.io/badge/Windows%20Server-2019-0078D6?logo=windows&logoColor=white)
![Exchange 2019](https://img.shields.io/badge/Exchange%20Server-2019-0078D4?logo=microsoftexchange&logoColor=white)
![AD CS](https://img.shields.io/badge/AD%20CS-Enterprise%20Root%20CA-555)
![PowerShell](https://img.shields.io/badge/PowerShell-EMS-5391FE?logo=powershell&logoColor=white)

Suite d'exercices réalisés sur 6 semaines dans mon cours Exchange (programme réseautique et cybersécurité). Ce laboratoire va plus loin que [mon premier déploiement Exchange](https://github.com/Chahdmk/exchange-server-2019-lab), où le serveur utilisait son certificat **auto-signé** :

- mise en place d'une **autorité de certification d'entreprise (AD CS)**;
- émission d'un **vrai certificat SSL** pour `mail.sd6.com` à partir d'une demande (CSR) générée sur Exchange;
- configuration d'**Autodiscover** et des **répertoires virtuels** sur un nom convivial;
- ouverture du **flux de courrier vers Internet** avec un connecteur d'envoi, puis dépannage DNS avec les journaux d'Exchange.

La plus grande partie du travail a été du **dépannage** : chaque étape documente ce qui a échoué, pourquoi, et comment je l'ai réglé.

---

## Architecture

```
                         Domaine : sd6.com
                                                            ┌───────────┐
 ┌─────────────────────┐   ┌──────────────────────────┐     │ Internet  │
 │ WINAD               │   │ WINEX                    │─────┤ (2e carte │
 │ 10.168.151.1        │◄──│ 10.168.151.2             │     │  réseau)  │
 │ AD DS + DNS         │   │ Exchange Server 2019     │     └───────────┘
 │ AD CS (Root CA)     │   │ rôle Mailbox, dual-homed │
 │ certsrv (Web Enr.)  │   │ mail.sd6.com             │
 └─────────────────────┘   └──────────────────────────┘
            ▲                          ▲
            └──────────┬───────────────┘
              ┌─────────────────────┐
              │ WINCLIENT           │
              │ 10.168.151.3        │
              │ Windows 11 + Office │
              └─────────────────────┘
```

| Machine | IP | Rôle |
|---|---|---|
| WINAD | 10.168.151.1 | Contrôleur de domaine, DNS, **autorité de certification** (Certification Authority + Web Enrollment) |
| WINEX | 10.168.151.2 | Exchange Server 2019 (Mailbox), deux cartes réseau : privée et Internet |
| WINCLIENT | 10.168.151.3 | Windows 11 + Outlook, utilisateurs du domaine |

Utilisateurs AD : Brent Smith (`bsmith`), Zach Myers (`zmyers`), Eric Bass (`ebass`).

## Contenu par semaine

| Semaine | Sujet | Document |
|---|---|---|
| 1–2 | Prérequis, installation en ligne de commande, vérification post-install, DNS (CNAME `mail`, MX) | [docs/01-installation.md](docs/01-installation.md) |
| 3 | **PKI** : AD CS, CSR, émission et liaison du certificat, Front End / Back End IIS, Autodiscover | [docs/02-certificats-pki.md](docs/02-certificats-pki.md) |
| 4 | Base de données : renommage, déplacement vers un disque dédié, 1re boîte aux lettres | [docs/03-base-de-donnees.md](docs/03-base-de-donnees.md) |
| 5 | TP1 → [dépôt séparé](https://github.com/Chahdmk/exchange-server-2019-lab) | — |
| 6 | Flux de courrier vers Internet : connecteur d'envoi, files d'attente, **journaux DNS d'Exchange** | [docs/04-flux-courrier-internet.md](docs/04-flux-courrier-internet.md) |

## Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|---|---|---|
| `WriteAllBytes` : *The network name cannot be found* | Le partage `\\winex\cert` n'existait pas | Écriture du `.req` en local dans `C:\cert` |
| `Enable-ExchangeCertificate` : **PrivateKeyMissing** | Certificat importé sans correspondance avec une demande en attente (CSR régénérées plusieurs fois avec des noms différents, `sd5`/`sd6`) | Nettoyage des demandes orphelines (`Remove-ExchangeCertificate`), nouvelle CSR propre, import de la chaîne `.p7b` |
| Certificat valide sur le client, mais Edge signale une connexion non sécurisée | Le site IIS **Exchange Back End** (port 444) utilisait encore l'*Exchange Server Auth Certificate* | Liaison HTTPS du Back End sur le certificat `mail.sd6.com` |
| EMS ne se connecte plus après modification des liaisons IIS | Liaison HTTP (port 80) retirée du Default Web Site ; le répertoire virtuel PowerShell en a besoin | Remise de la liaison HTTP |
| Outlook configure le compte en IMAP au lieu d'Exchange | Outlook choisissait lui-même un autre type de compte | *Let me set up my account manually* → type **Exchange** (ajout aussi d'un enregistrement A `autodiscover`) |
| Courriels vers Gmail/Hotmail bloqués en `Retry` | Le connecteur d'envoi utilisait le DNS interne (WINAD), incapable de résoudre l'externe | `Set-SendConnector "Internet" -UseExternalDNSServersEnabled $true` |

## Compétences démontrées

- Déploiement d'une **PKI d'entreprise** (AD CS) et cycle de vie d'un certificat : CSR → signature → import → activation
- Compréhension de l'architecture **Front End / Back End** d'Exchange dans IIS
- Configuration d'Autodiscover, des répertoires virtuels et des enregistrements DNS (A, CNAME, MX)
- Gestion des bases de données Exchange (renommage, `Move-DatabasePath`)
- Flux de courrier sortant : connecteur d'envoi, files d'attente, résolution DNS externe
- Méthode de dépannage : lire l'erreur, Event Viewer, journaux (setup, DNS de transport), tests ciblés

## Structure du dépôt

```
exchange-2019-pki-certificats/
├── README.md
├── docs/        # Un document par bloc de semaines, avec les erreurs et leurs solutions
└── scripts/     # Commandes PowerShell regroupées par étape
```

> ⚠️ Laboratoire isolé. Les mots de passe qui apparaissent (ex. `1234` pour l'import du certificat) sont des valeurs de test imposées par l'exercice, à ne jamais utiliser en production.

---

**Chahd Merzaki** — étudiante en réseautique et cybersécurité
