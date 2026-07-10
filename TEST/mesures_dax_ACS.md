# Mesures DAX — Base ACS (Power BI)

## ⚠️ Prérequis indispensable : relations avec DIM_TEMPS

`FAIT_OPERATIONS_TECHNIQUES` a **4 clés étrangères** vers `DIM_TEMPS` (Émission, Encaissement,
Reversement, Commission). Power BI n'autorise qu'**une seule relation active** entre deux tables.

**Recommandation :** laissez active la relation sur `FK_Date_Emission` (c'est l'axe temporel le
plus naturel pour un dashboard : "quand la prime a été générée"). Pour toute mesure qui doit
utiliser Encaissement, Reversement ou Commission, on active la relation ponctuellement avec
`USERELATIONSHIP()` à l'intérieur d'un `CALCULATE`.

Pensez aussi à marquer `DIM_TEMPS` comme **table de dates officielle** dans Power BI
(Outils de table → Marquer comme table de dates → colonne `Date_Exacte`).

---

## 1. Vérifier les données (équivalent du script de contrôle)

```dax
Nombre_Clients = DISTINCTCOUNT(DIM_CLIENT[PK_Client])

Nombre_Compagnies = DISTINCTCOUNT(DIM_COMPAGNIE[PK_Compagnie])

Nombre_Conventions = DISTINCTCOUNT(DIM_CONVENTION[PK_Convention])

Nombre_Polices = DISTINCTCOUNT(DIM_POLICE[PK_Police])

Nombre_Dates = DISTINCTCOUNT(DIM_TEMPS[PK_Temps])

Nombre_Operations = COUNTROWS(FAIT_OPERATIONS_TECHNIQUES)
```
Placez ces 6 mesures dans des cartes (KPI cards) pour un visuel de contrôle rapide, exactement
comme le SELECT de vérification.

---

## 2. Commissions par compagnie

```dax
Commission_Theorique_Totale = SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Theorique])

Commission_Recue_Totale = SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Recue])

Ecart_Commission = [Commission_Theorique_Totale] - [Commission_Recue_Totale]
```
**Visuel :** table/matrice avec `DIM_COMPAGNIE[Nom_Complet_Assureur]` en lignes + les 3 mesures.
Pour filtrer 2023-2025 (comme le `WHERE` du script), ajoutez un slicer sur `DIM_TEMPS[Annee]`
(fonctionne car la relation active — Émission — sert de base par défaut).

---

## 3. Primes encaissées par mois

Ici on a besoin de la date **d'encaissement**, qui n'est pas la relation active : on doit forcer
la relation avec `USERELATIONSHIP`.

```dax
Primes_Encaissees =
CALCULATE(
    SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Encaisse_Client]),
    USERELATIONSHIP(FAIT_OPERATIONS_TECHNIQUES[FK_Date_Encaissement], DIM_TEMPS[PK_Temps])
)
```
**Visuel :** graphique en colonnes avec `DIM_TEMPS[Nom_Mois]` (triée par `DIM_TEMPS[Mois]`) en axe
et `DIM_TEMPS[Annee]` en légende ou en filtre — remplace vos deux requêtes 2022/2023 en un seul
visuel dynamique.

---

## 4. Retards de reversement

Comme les 2 dates (encaissement, reversement) sont sur la même ligne de fait, on utilise
`LOOKUPVALUE` plutôt que `RELATED` (qui ne suit que la relation active) :

```dax
Jours_Retard_Reversement =
VAR DateEnc =
    LOOKUPVALUE(
        DIM_TEMPS[Date_Exacte],
        DIM_TEMPS[PK_Temps], FAIT_OPERATIONS_TECHNIQUES[FK_Date_Encaissement]
    )
VAR DateRev =
    LOOKUPVALUE(
        DIM_TEMPS[Date_Exacte],
        DIM_TEMPS[PK_Temps], FAIT_OPERATIONS_TECHNIQUES[FK_Date_Reversement]
    )
RETURN
    DATEDIFF(DateEnc, DateRev, DAY)
```
*(Colonne calculée dans `FAIT_OPERATIONS_TECHNIQUES`, pas une mesure.)*

```dax
Nb_Operations_Retard_Reversement =
CALCULATE(
    COUNTROWS(FAIT_OPERATIONS_TECHNIQUES),
    FAIT_OPERATIONS_TECHNIQUES[Jours_Retard_Reversement] > 5
)

Retard_Moyen_Reversement_Jours =
AVERAGE(FAIT_OPERATIONS_TECHNIQUES[Jours_Retard_Reversement])
```
**Visuel :** table détaillée filtrée (`Jours_Retard_Reversement > 5`) avec compagnie, n° de
police, montant reversé — reproduit directement votre requête.

---

## 5. Écarts de commission

```dax
Nb_Operations_Ecart_Commission =
CALCULATE(
    COUNTROWS(FAIT_OPERATIONS_TECHNIQUES),
    FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Theorique]
        <> FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Recue]
)
```
`Ecart_Commission` (section 2) sert de mesure de tri. **Visuel :** table avec un filtre visuel
"Écart ≠ 0" sur `Montant_Commission_Theorique` vs `Montant_Commission_Recue`, triée par écart
décroissant.

---

## 6. Rentabilité par branche de risque

```dax
Primes_Totales = SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Brute_TTC])

Commissions_Totales = SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Recue])

Taux_Rentabilite_Pct = DIVIDE([Commissions_Totales], [Primes_Totales]) * 100
```
`DIVIDE()` remplace la division brute du SQL : elle gère nativement la division par zéro (renvoie
`BLANK()` au lieu d'une erreur), ce qui est essentiel en DAX. **Visuel :** table/graphique en
barres avec `DIM_CONVENTION[Branche_Risque]` en lignes.

---

## 7. Mesures supplémentaires — Dashboard de suivi des créances

Le cœur du sujet : une créance ici, ce sont des sommes **dues mais pas (encore) encaissées ou
reversées**. On distingue 3 natures de créances dans votre modèle, qu'il ne faut **pas
additionner entre elles** (parties prenantes différentes) mais suivre côte à côte :

- **Créance client** : ce que le client doit encore payer au courtier
- **Créance compagnie** : ce que le courtier doit encore reverser à la compagnie
- **Créance commission** : ce que la compagnie doit encore verser au courtier

### 7.1 Montants de créances (les 3 piliers)

```dax
Creance_Client =
SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Brute_TTC])
    - SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Encaisse_Client])

Creance_A_Reverser_Cie =
SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Nette_Cie])
    - SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Reverse_Cie])

Creance_Commission_A_Recevoir =
SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Theorique])
    - SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Recue])
```

### 7.2 Taux de recouvrement / de règlement

```dax
Taux_Encaissement_Pct =
DIVIDE(
    SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Encaisse_Client]),
    SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Brute_TTC])
) * 100

Taux_Reversement_Pct =
DIVIDE(
    SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Reverse_Cie]),
    SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Nette_Cie])
) * 100

Taux_Perception_Commission_Pct =
DIVIDE(
    SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Recue]),
    SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Commission_Theorique])
) * 100
```
Ces 3 indicateurs font un excellent bandeau de KPI cards en haut du dashboard.

### 7.3 Ancienneté des créances (balance âgée / aging)

Colonne calculée : nombre de jours écoulés depuis l'émission pour les opérations non soldées.

```dax
Anciennete_Creance_Jours =
VAR DateEmission =
    LOOKUPVALUE(
        DIM_TEMPS[Date_Exacte],
        DIM_TEMPS[PK_Temps], FAIT_OPERATIONS_TECHNIQUES[FK_Date_Emission]
    )
RETURN
    DATEDIFF(DateEmission, TODAY(), DAY)
```

Colonne calculée : tranche d'ancienneté (bucket), pour un graphique en entonnoir/barres empilées.

```dax
Tranche_Anciennete =
VAR J = FAIT_OPERATIONS_TECHNIQUES[Anciennete_Creance_Jours]
RETURN
    SWITCH(
        TRUE(),
        J <= 30, "0-30 jours",
        J <= 60, "31-60 jours",
        J <= 90, "61-90 jours",
        "Plus de 90 jours"
    )
```

Mesure associée, à croiser avec `Tranche_Anciennete` en axe :

```dax
Montant_Creance_Client_Par_Tranche =
CALCULATE(
    [Creance_Client],
    FAIT_OPERATIONS_TECHNIQUES[Etat_Reversement] <> "Soldé"
)
```

### 7.4 Indicateur type "DSO" (Days Sales Outstanding) simplifié

```dax
DSO_Approx_Jours =
VAR CreanceMoyenne = [Creance_Client]
VAR CA_Periode = SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Brute_TTC])
VAR NbJoursPeriode = DATEDIFF(MIN(DIM_TEMPS[Date_Exacte]), MAX(DIM_TEMPS[Date_Exacte]), DAY) + 1
RETURN
    DIVIDE(CreanceMoyenne, CA_Periode) * NbJoursPeriode
```
Donne le "nombre de jours de chiffre d'affaires" encore en créance — indicateur classique de
pilotage de trésorerie.

### 7.5 Répartition des créances par statut

```dax
Pct_Operations_Soldees =
DIVIDE(
    CALCULATE(COUNTROWS(FAIT_OPERATIONS_TECHNIQUES), FAIT_OPERATIONS_TECHNIQUES[Etat_Reversement] = "Soldé"),
    COUNTROWS(FAIT_OPERATIONS_TECHNIQUES)
) * 100

Pct_Operations_En_Attente =
DIVIDE(
    CALCULATE(COUNTROWS(FAIT_OPERATIONS_TECHNIQUES), FAIT_OPERATIONS_TECHNIQUES[Etat_Reversement] = "En attente"),
    COUNTROWS(FAIT_OPERATIONS_TECHNIQUES)
) * 100
```
Idéal pour un donut chart "Soldé / Partiel / En attente".

### 7.6 Top créances (clients et compagnies à risque)

```dax
Rang_Client_Par_Creance =
RANKX(
    ALL(DIM_CLIENT[Nom_Raison_Sociale]),
    [Creance_Client],
    , DESC
)
```
**Visuel :** table triée par `Creance_Client` décroissant, filtrée Top N (via un filtre visuel
"Top 10") sur `DIM_CLIENT[Nom_Raison_Sociale]` — identifie immédiatement les gros débiteurs.

Idem côté compagnies, pour visualiser les montants encore dus par ACS à chaque assureur :

```dax
Rang_Compagnie_Par_Creance_A_Reverser =
RANKX(
    ALL(DIM_COMPAGNIE[Nom_Complet_Assureur]),
    [Creance_A_Reverser_Cie],
    , DESC
)
```

### 7.7 Créances sur polices à risque (résiliées/expirées)

Une créance sur une police déjà résiliée est plus critique à recouvrer qu'une créance sur une
police active — utile pour prioriser les relances.

```dax
Creance_Client_Polices_A_Risque =
CALCULATE(
    [Creance_Client],
    DIM_POLICE[Statut_Police] IN {"Résiliée", "Expirée"}
)
```

### 7.8 Évolution mensuelle des créances (tendance)

```dax
Creance_Client_Cumulee =
CALCULATE(
    [Creance_Client],
    FILTER(
        ALL(DIM_TEMPS),
        DIM_TEMPS[Date_Exacte] <= MAX(DIM_TEMPS[Date_Exacte])
    )
)
```
**Visuel :** courbe temporelle (axe = `DIM_TEMPS[Nom_Mois]`/`Annee`, relation active Émission) —
montre si le stock de créances se dégrade ou s'améliore dans le temps.

---

## Suggestion de structure de dashboard (page "Créances")

| Zone | Contenu |
|---|---|
| Bandeau KPI (haut) | `Creance_Client`, `Creance_A_Reverser_Cie`, `Creance_Commission_A_Recevoir`, `Taux_Encaissement_Pct` |
| Graphique principal | `Creance_Client_Cumulee` par mois (tendance) |
| Balance âgée | Barres empilées : `Tranche_Anciennete` × `Montant_Creance_Client_Par_Tranche` |
| Répartition statut | Donut : `Pct_Operations_Soldees` / `Pct_Operations_En_Attente` |
| Top débiteurs | Table Top 10 clients par `Creance_Client` |
| Top compagnies à reverser | Table Top 10 compagnies par `Creance_A_Reverser_Cie` |
| Alertes | Table filtrée : polices Résiliées/Expirées avec créance > 0, triée décroissant |
