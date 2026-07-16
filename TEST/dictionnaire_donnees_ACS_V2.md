# Dictionnaire de données — Base ACS (Courtage en Assurance)

**Version :** 2.0 — ajout de la table FAIT_SINISTRES
**Modèle :** Schéma en étoile (Star Schema) — 5 dimensions + 2 tables de faits
**SGBD cible :** SQL Server

---

## Vue d'ensemble du modèle

| Table | Type | Rôle |
|---|---|---|
| DIM_CLIENT | Dimension | Référentiel des assurés (particuliers/entreprises) |
| DIM_COMPAGNIE | Dimension | Référentiel des compagnies d'assurance partenaires |
| DIM_CONVENTION | Dimension | Contrats-cadres signés entre le courtier et chaque compagnie |
| DIM_POLICE | Dimension | Polices d'assurance souscrites par les clients |
| DIM_TEMPS | Dimension | Calendrier (pour l'analyse temporelle multi-dates) |
| FAIT_OPERATIONS_TECHNIQUES | Table de faits | Opérations financières (primes, reversements, commissions) |
| FAIT_SINISTRES | Table de faits | Déclarations et gestion des sinistres (dossiers) |

**Cardinalités principales :**
- 1 Compagnie → N Conventions
- 1 Client + 1 Convention → N Polices
- 1 Police → N Opérations techniques (table de faits)
- 1 Police → N Sinistres (table de faits)
- DIM_TEMPS est référencée **4 fois** par `FAIT_OPERATIONS_TECHNIQUES` (émission, encaissement,
  reversement, commission) et **2 fois** par `FAIT_SINISTRES` (survenance, règlement)

---

## 1. DIM_CLIENT

Référentiel des assurés (personnes physiques ou morales).

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| PK_Client | INT | PK, IDENTITY(1,1) | Identifiant technique auto-généré du client | 42 |
| Code_Client_Unique | VARCHAR(50) | NOT NULL, UNIQUE | Code métier unique identifiant le client (ex : matricule interne) | PART-00042 |
| Nom_Raison_Sociale | VARCHAR(150) | NOT NULL | Nom complet (particulier) ou raison sociale (entreprise) | KOUAME Jean / SOCOA SARL |
| Type_Client | VARCHAR(20) | CHECK IN ('Particulier','Entreprise') | Nature juridique du client | Entreprise |
| Secteur_Activite | VARCHAR(100) | — | Secteur d'activité économique (pour les entreprises ; "Particulier" sinon) | Transport & Logistique |
| Localisation | VARCHAR(100) | — | Ville/zone géographique du client | Abidjan |

---

## 2. DIM_COMPAGNIE

Référentiel des compagnies d'assurance partenaires (les "assureurs").

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| PK_Compagnie | INT | PK, IDENTITY(1,1) | Identifiant technique auto-généré de la compagnie | 3 |
| Code_Cie | VARCHAR(20) | NOT NULL, UNIQUE | Code interne court identifiant la compagnie | CIE003 |
| Nom_Complet_Assureur | VARCHAR(150) | NOT NULL | Dénomination officielle de la compagnie d'assurance | ALLIANZ CI |
| Adresse_Siege | VARCHAR(200) | — | Adresse du siège social de la compagnie | Abidjan, Plateau |

---

## 3. DIM_CONVENTION

Contrat-cadre négocié entre le courtier (ACS) et **une** compagnie, pour **une** branche de risque donnée. Définit notamment le taux de commission applicable.

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| PK_Convention | INT | PK, IDENTITY(1,1) | Identifiant technique auto-généré de la convention | 6 |
| FK_Compagnie | INT | NOT NULL, FK → DIM_COMPAGNIE | Compagnie signataire de la convention | 3 |
| Ref_Contrat_Cadre | VARCHAR(80) | NOT NULL, UNIQUE | Référence unique du contrat-cadre | CONV-CIE003-RC-0006 |
| Branche_Risque | VARCHAR(50) | CHECK IN ('Santé','Flotte Auto','Automobile','Incendie','Transport','RC','Multirisque','Voyage','Risques Divers') | Type de risque couvert par la convention | RC |
| Taux_Commission_Contractuel | DECIMAL(5,4) | — | Taux de commission accordé au courtier par la compagnie (ex : 0.1304 = 13,04 %) | 0.1304 |
| Date_Debut | DATE | — | Date d'entrée en vigueur de la convention | 2021-09-15 |
| Date_Fin | DATE | — | Date d'échéance de la convention | 2026-04-12 |
| Mode_Reglement | VARCHAR(30) | — | Mode de règlement prévu entre courtier et compagnie | Virement |
| Periodicite | VARCHAR(20) | — | Fréquence de reversement/facturation prévue | Mensuelle |
| Convention_Active | BIT | DEFAULT 1 | Indique si la convention est active (1) ou résiliée/arrivée à terme (0) | 1 |

> ⚠️ **Point de vigilance connu** : cette liste de `Branche_Risque` ne couvre pas encore les
> produits Vie d'ACS (Épargne Retraite, Prévoyance Décès, Frais Funéraires, Indemnité de Fin de
> Carrière). À faire évoluer si vous intégrez ces produits dans le dashboard.

---

## 4. DIM_POLICE

Police d'assurance concrète, souscrite par **un** client, rattachée à **une** convention (qui détermine la compagnie et la branche de risque).

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| PK_Police | INT | PK, IDENTITY(1,1) | Identifiant technique auto-généré de la police | 128 |
| Numero_Police | VARCHAR(60) | UNIQUE | Numéro de police (référence métier communiquée au client) | POL-003-000128 |
| FK_Client | INT | NOT NULL, FK → DIM_CLIENT | Client souscripteur de la police | 42 |
| FK_Convention | INT | NOT NULL, FK → DIM_CONVENTION | Convention (compagnie + branche) sous laquelle la police est émise | 6 |
| Date_Souscription | DATE | — | Date de souscription initiale de la police | 2024-03-10 |
| Date_Echeance | DATE | — | Date d'échéance (fin de la période de couverture) | 2025-03-10 |
| Statut_Police | VARCHAR(20) | CHECK IN ('Active','Suspendue','Résiliée','Expirée') | Statut actuel de la police | Active |

---

## 5. DIM_TEMPS

Dimension calendaire générique, utilisée pour toutes les analyses temporelles. Référencée **4 fois**
dans `FAIT_OPERATIONS_TECHNIQUES` et **2 fois** dans `FAIT_SINISTRES`, sous des rôles différents
(voir §6 et §7).

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| PK_Temps | INT | PK, IDENTITY(1,1) | Identifiant technique auto-généré de la date | 731 |
| Date_Exacte | DATE | UNIQUE | Date calendaire (une ligne par jour) | 2024-01-15 |
| Jour | INT | — | Jour du mois (1-31) | 15 |
| Mois | INT | — | Numéro du mois (1-12) | 1 |
| Nom_Mois | VARCHAR(20) | — | Nom du mois en toutes lettres | Janvier |
| Trimestre | INT | — | Trimestre de l'année (1-4) | 1 |
| Semestre | INT | — | Semestre de l'année (1-2) | 1 |
| Annee | INT | — | Année civile | 2024 |

---

## 6. FAIT_OPERATIONS_TECHNIQUES

Table de faits centrale : chaque ligne représente **une opération financière/technique** rattachée à une police (émission de prime, encaissement, reversement, commission). C'est ici que se trouvent les indicateurs mesurables (montants).

### Clés et dimensions

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| ID_Operation | VARCHAR(80) | PK | Identifiant unique de l'opération (clé métier, non auto-incrémentée) | OP-00001234 |
| FK_Client | INT | NOT NULL, FK → DIM_CLIENT | Client concerné par l'opération (redondant avec la police, pour simplifier les jointures) | 42 |
| FK_Compagnie | INT | NOT NULL, FK → DIM_COMPAGNIE | Compagnie concernée (redondant avec la convention) | 3 |
| FK_Convention | INT | NOT NULL, FK → DIM_CONVENTION | Convention sous laquelle l'opération est réalisée | 6 |
| FK_Police | INT | NOT NULL, FK → DIM_POLICE | Police concernée par l'opération | 128 |

### Dates du cycle de vie (4 rôles de DIM_TEMPS)

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| FK_Date_Emission | INT | FK → DIM_TEMPS | Date d'émission de la prime/quittance |
| FK_Date_Encaissement | INT | FK → DIM_TEMPS | Date à laquelle le client a réglé la prime |
| FK_Date_Reversement | INT | FK → DIM_TEMPS | Date à laquelle le courtier a reversé la prime nette à la compagnie |
| FK_Date_Commission | INT | FK → DIM_TEMPS | Date de comptabilisation/versement de la commission au courtier |

### Montants (indicateurs financiers)

| Colonne | Type | Description | Formule / logique |
|---|---|---|---|
| Montant_Prime_Brute_TTC | DECIMAL(15,2) | Montant total facturé au client (toutes taxes comprises) | Prime_Nette + Taxes + Accessoires |
| Montant_Taxes | DECIMAL(15,2) | Montant des taxes d'assurance appliquées | ~18 % de la prime nette (taxe CIMA) |
| Montant_Accessoires | DECIMAL(15,2) | Frais accessoires (frais de dossier, etc.) | Montant forfaitaire/variable |
| Montant_Prime_Nette_Cie | DECIMAL(15,2) | Part de la prime revenant à la compagnie (hors taxes/accessoires) | Base de calcul de la commission |
| Montant_Encaisse_Client | DECIMAL(15,2) | Montant effectivement encaissé auprès du client | ≤ Montant_Prime_Brute_TTC |
| Montant_Reverse_Cie | DECIMAL(15,2) | Montant effectivement reversé à la compagnie | Dépend de Etat_Reversement |
| Montant_Commission_Theorique | DECIMAL(15,2) | Commission due au courtier selon le taux contractuel | Prime_Nette_Cie × Taux_Commission_Contractuel (convention) |
| Montant_Commission_Recue | DECIMAL(15,2) | Commission effectivement perçue par le courtier | Dépend de Etat_Commission |

### États (statuts métier)

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| Etat_Reversement | VARCHAR(20) | CHECK IN ('En attente','Partiel','Soldé') | Avancement du reversement de la prime à la compagnie |
| Etat_Commission | VARCHAR(20) | CHECK IN ('Non payée','Partielle','Payée') | Avancement du paiement de la commission au courtier |

---

## 7. FAIT_SINISTRES *(nouvelle table)*

Table de faits secondaire : chaque ligne représente **un dossier de sinistre** déclaré sur une
police. Sert de socle aux indicateurs de sinistralité (ratio S/P, provisions techniques, délais de
règlement), complémentaires au suivi des créances.

### Clés et dimensions

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| ID_Sinistre | VARCHAR(100) | PK | Identifiant unique du dossier de sinistre (clé métier) | SIN-00000042 |
| FK_Police | INT | NOT NULL, FK → DIM_POLICE | Police sur laquelle le sinistre est survenu | 128 |
| FK_Client | INT | NOT NULL, FK → DIM_CLIENT | Client concerné (redondant avec la police, pour simplifier les jointures) | 42 |
| FK_Compagnie | INT | NOT NULL, FK → DIM_COMPAGNIE | Compagnie qui porte le risque et gère l'indemnisation | 3 |

### Dates du cycle de vie (2 rôles de DIM_TEMPS)

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| FK_Date_Survenance | INT | NOT NULL, FK → DIM_TEMPS | Date à laquelle le sinistre s'est produit |
| FK_Date_Reglement | INT | FK → DIM_TEMPS (nullable) | Date de clôture du dossier (règlement ou rejet) — NULL tant que le dossier reste ouvert/en cours |

### Nature et montants

| Colonne | Type | Contraintes | Description | Exemple |
|---|---|---|---|---|
| Nature_Sinistre | VARCHAR(100) | NOT NULL | Type d'événement à l'origine du sinistre | Vol, Bris de glace, Hospitalisation, Dégât des eaux |
| Montant_Sinistre_Paye | DECIMAL(15,2) | NOT NULL, DEFAULT 0.00, CHECK ≥ 0 | Montant effectivement indemnisé au client/bénéficiaire | 806 090,37 |
| Montant_Provision_Reserve | DECIMAL(15,2) | DEFAULT 0.00, CHECK ≥ 0 | Réserve technique constituée pour couvrir le coût futur estimé du dossier tant qu'il n'est pas soldé | 790 856,19 |

### État du dossier

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| Statut_Dossier | VARCHAR(20) | CHECK IN ('Ouvert','En cours','Réglé','Rejeté') | Avancement du traitement du sinistre |

**Logique attendue entre statut et montants :**
- `Ouvert` → rien payé, provision estimée dans son intégralité
- `En cours` → paiement partiel éventuel (acompte) + provision sur le solde restant à indemniser
- `Réglé` → montant payé = montant total indemnisé, provision ramenée à 0
- `Rejeté` → montant payé = 0, provision = 0 (dossier clos sans indemnisation)

---

## 8. Schéma relationnel (résumé)

```
DIM_COMPAGNIE (1) ──< (N) DIM_CONVENTION (1) ──< (N) DIM_POLICE (N) >── (1) DIM_CLIENT
                                │                        │
                                └───────────┬────────────┘
                                            │
                        ┌───────────────────┴───────────────────┐
                        │                                       │
              FAIT_OPERATIONS_TECHNIQUES                  FAIT_SINISTRES
                        │                                       │
        ┌───────┬───────┼───────┬───────┐               ┌──────┴──────┐
   Emission Encaissement Reversement Commission     Survenance    Reglement
        │       │       │       │                       │            │
        └───────┴───────┴───────┴───────────────────────┴────────────┘
                                            │
                                       DIM_TEMPS
                        (référencée 4 fois pour les opérations,
                              2 fois pour les sinistres)
```

---

## 9. Règles de gestion associées

1. Une convention n'appartient qu'à une seule compagnie ; une compagnie peut avoir plusieurs conventions (une par branche de risque, typiquement).
2. Une police est toujours rattachée à une convention active au moment de la souscription (règle applicative, non imposée par le schéma).
3. `Montant_Commission_Theorique` doit toujours être cohérent avec `Taux_Commission_Contractuel` de la convention associée.
4. `Montant_Reverse_Cie` = `Montant_Prime_Nette_Cie` lorsque `Etat_Reversement = 'Soldé'`.
5. `Montant_Commission_Recue` = `Montant_Commission_Theorique` lorsque `Etat_Commission = 'Payée'`.
6. La chronologie logique attendue des 4 dates d'une opération est : Émission ≤ Encaissement ≤ Reversement ≤ Commission.
7. Un sinistre (`FAIT_SINISTRES`) ne peut survenir que sur une police existante ; en toute rigueur, sa `FK_Date_Survenance` devrait se situer entre `Date_Souscription` et `Date_Echeance` de la police concernée (règle applicative, non imposée par le schéma).
8. `FK_Date_Reglement` reste `NULL` tant que `Statut_Dossier` est `Ouvert` ou `En cours` ; il est renseigné dès que le dossier passe à `Réglé` ou `Rejeté`.
9. `Montant_Provision_Reserve` doit revenir à 0 dès que le dossier est soldé (`Réglé` ou `Rejeté`) — une provision résiduelle sur un dossier clos signalerait une incohérence de gestion.
