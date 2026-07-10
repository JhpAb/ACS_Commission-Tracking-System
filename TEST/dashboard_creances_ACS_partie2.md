# Dashboard de suivi des créances — ACS
## Partie 2 : Mesures complémentaires + architecture du dashboard

*Ce document complète `mesures_dax_ACS.md` (mesures de base + créances). Il ajoute les
mesures de comparaison période vs période, les provisions pour créances douteuses, puis
détaille la structure complète du dashboard, page par page.*

---

## 8. Comparaisons période vs période (time intelligence)

Ces mesures exploitent le fait que `DIM_TEMPS` est marquée comme table de dates officielle
(colonne continue `Date_Exacte`, sans trou). Elles utilisent la relation active
(Émission) sauf mention contraire.

### 8.1 Variation mensuelle (Mois vs Mois précédent)

```dax
Creance_Client_Mois_Precedent =
CALCULATE(
    [Creance_Client],
    DATEADD(DIM_TEMPS[Date_Exacte], -1, MONTH)
)

Variation_Creance_Client =
[Creance_Client] - [Creance_Client_Mois_Precedent]

Variation_Creance_Client_Pct =
DIVIDE([Variation_Creance_Client], [Creance_Client_Mois_Precedent])
```

### 8.2 Variation annuelle (Année vs Année précédente — YoY)

```dax
Creance_Client_Annee_Precedente =
CALCULATE(
    [Creance_Client],
    SAMEPERIODLASTYEAR(DIM_TEMPS[Date_Exacte])
)

Variation_Creance_Client_YoY_Pct =
DIVIDE(
    [Creance_Client] - [Creance_Client_Annee_Precedente],
    [Creance_Client_Annee_Precedente]
)
```

Même logique applicable à `Creance_A_Reverser_Cie` et `Creance_Commission_A_Recevoir` (dupliquer
les 2 mesures en remplaçant la mesure de base).

### 8.3 Cumul depuis le début de l'année (YTD)

```dax
Primes_Encaissees_YTD =
TOTALYTD(
    CALCULATE(
        SUM(FAIT_OPERATIONS_TECHNIQUES[Montant_Encaisse_Client]),
        USERELATIONSHIP(FAIT_OPERATIONS_TECHNIQUES[FK_Date_Encaissement], DIM_TEMPS[PK_Temps])
    ),
    DIM_TEMPS[Date_Exacte]
)

Creance_Client_YTD =
TOTALYTD([Creance_Client], DIM_TEMPS[Date_Exacte])
```

### 8.4 Indicateur de tendance (flèche verte/rouge)

```dax
Indicateur_Tendance_Creance =
VAR Variation = [Variation_Creance_Client_Pct]
RETURN
    SWITCH(
        TRUE(),
        ISBLANK(Variation), "→ N/A",
        Variation > 0.02, "↑ Dégradation",
        Variation < -0.02, "↓ Amélioration",
        "→ Stable"
    )
```
*(Une hausse de la créance client est une dégradation ; le sens inverse s'applique à
`Taux_Encaissement_Pct`.)*

---

## 9. Provisions pour créances douteuses (méthode par ancienneté)

Approche standard : plus une créance est ancienne, plus la probabilité de non-recouvrement
augmente, donc plus le taux de provision est élevé. **Les taux ci-dessous sont indicatifs** —
à ajuster selon votre politique comptable (ex. référentiel SYSCOHADA en vigueur en zone
UEMOA/CIMA, ou politique interne de gestion du risque client).

### 9.1 Taux de provision par tranche d'ancienneté

Colonne calculée dans `FAIT_OPERATIONS_TECHNIQUES` (s'appuie sur `Anciennete_Creance_Jours`
défini dans la Partie 1) :

```dax
Taux_Provision =
VAR J = FAIT_OPERATIONS_TECHNIQUES[Anciennete_Creance_Jours]
RETURN
    SWITCH(
        TRUE(),
        J <= 30, 0,
        J <= 60, 0.10,
        J <= 90, 0.25,
        J <= 180, 0.50,
        1.00
    )
```

### 9.2 Montant de provision

```dax
Provision_Creances_Douteuses =
SUMX(
    FAIT_OPERATIONS_TECHNIQUES,
    (FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Brute_TTC]
        - FAIT_OPERATIONS_TECHNIQUES[Montant_Encaisse_Client])
    * FAIT_OPERATIONS_TECHNIQUES[Taux_Provision]
)
```
*(Le résidu "prime brute − encaissé" est nul pour les opérations déjà soldées : elles ne
contribuent donc pas à la provision, sans avoir besoin d'un filtre supplémentaire.)*

### 9.3 Mesures dérivées

```dax
Creance_Client_Nette_Provisionnee =
[Creance_Client] - [Provision_Creances_Douteuses]

Taux_Provision_Moyen_Pct =
DIVIDE([Provision_Creances_Douteuses], [Creance_Client]) * 100
```

### 9.4 Provision sur créances à risque élevé (polices résiliées/expirées)

```dax
Provision_Polices_A_Risque =
CALCULATE(
    [Provision_Creances_Douteuses],
    DIM_POLICE[Statut_Police] IN {"Résiliée", "Expirée"}
)
```

---

## 10. Architecture complète du dashboard (multi-pages)

Structure recommandée : **6 pages**, de la vue synthétique vers le détail opérationnel. Tous les
visuels partagent les mêmes slicers globaux (synchronisés) : `DIM_TEMPS[Annee]`,
`DIM_COMPAGNIE[Nom_Complet_Assureur]`, `DIM_CONVENTION[Branche_Risque]`.

---

### 📊 Page 1 — Résumé exécutif (Executive Summary)

*Vue destinée à la direction : l'essentiel en un coup d'œil, avec alertes.*

| Zone | Contenu | Mesures utilisées |
|---|---|---|
| Bandeau KPI (5 cartes) | Créance client, Créance à reverser, Créance commission, Provision créances douteuses, Taux d'encaissement global | `Creance_Client`, `Creance_A_Reverser_Cie`, `Creance_Commission_A_Recevoir`, `Provision_Creances_Douteuses`, `Taux_Encaissement_Pct` |
| Sous-bandeau tendance | Variation vs mois précédent (flèches colorées) | `Variation_Creance_Client_Pct`, `Indicateur_Tendance_Creance` |
| Graphique central | Courbe 12 mois glissants de la créance client + primes encaissées | `Creance_Client_Cumulee`, `Primes_Encaissees` |
| Jauge | Taux de recouvrement global vs objectif (ex. 90 %) | `Taux_Encaissement_Pct` (jauge avec cible) |
| Carte d'alerte | Nombre de polices résiliées/expirées avec créance encore ouverte | `Nb_Operations_Ecart_Commission` + mesure similaire sur créances à risque (§10.1 ci-dessous) |
| Top 5 | Top 5 clients débiteurs + Top 5 compagnies à reverser (mini-tables côte à côte) | `Rang_Client_Par_Creance`, `Rang_Compagnie_Par_Creance_A_Reverser` |

Mesure d'alerte supplémentaire à créer pour cette page :
```dax
Nb_Polices_A_Risque_Avec_Creance =
CALCULATE(
    DISTINCTCOUNT(FAIT_OPERATIONS_TECHNIQUES[FK_Police]),
    DIM_POLICE[Statut_Police] IN {"Résiliée", "Expirée"},
    FAIT_OPERATIONS_TECHNIQUES[Montant_Prime_Brute_TTC]
        > FAIT_OPERATIONS_TECHNIQUES[Montant_Encaisse_Client]
)
```

---

### 📊 Page 2 — Créances clients (encaissement)

| Zone | Contenu | Mesures |
|---|---|---|
| KPI | Créance client totale, Taux d'encaissement, DSO | `Creance_Client`, `Taux_Encaissement_Pct`, `DSO_Approx_Jours` |
| Balance âgée | Barres empilées par tranche d'ancienneté | `Tranche_Anciennete` × `Montant_Creance_Client_Par_Tranche` |
| Évolution | Courbe mensuelle avec comparaison N vs N-1 | `Creance_Client`, `Creance_Client_Annee_Precedente` |
| Table détaillée | Client, police, prime brute, encaissé, créance, ancienneté — triée décroissant | Colonnes brutes + `Anciennete_Creance_Jours` |
| Répartition | Donut par `Type_Client` (Particulier/Entreprise) | `Creance_Client` avec `DIM_CLIENT[Type_Client]` en légende |
| Top débiteurs | Table Top 10-20 avec filtre visuel | `Rang_Client_Par_Creance` |

---

### 📊 Page 3 — Reversements aux compagnies

| Zone | Contenu | Mesures |
|---|---|---|
| KPI | Créance à reverser totale, Taux de reversement, Nb opérations en retard | `Creance_A_Reverser_Cie`, `Taux_Reversement_Pct`, `Nb_Operations_Retard_Reversement` |
| Retards | Table des opérations avec retard > 5 jours (ou seuil configurable) | `Jours_Retard_Reversement`, `Retard_Moyen_Reversement_Jours` |
| Par compagnie | Graphique en barres : montant à reverser par compagnie | `Creance_A_Reverser_Cie` par `DIM_COMPAGNIE` |
| Par statut | Donut `Etat_Reversement` (Soldé/Partiel/En attente) | `Pct_Operations_Soldees`, `Pct_Operations_En_Attente` |
| Évolution | Courbe mensuelle du reversement effectif vs dû | `Montant_Reverse_Cie` (SUM) vs `Montant_Prime_Nette_Cie` (SUM) |

---

### 📊 Page 4 — Commissions

| Zone | Contenu | Mesures |
|---|---|---|
| KPI | Commission théorique, Commission reçue, Écart, Taux de perception | `Commission_Theorique_Totale`, `Commission_Recue_Totale`, `Ecart_Commission`, `Taux_Perception_Commission_Pct` |
| Par compagnie | Table triée par écart décroissant | Section 2 du document précédent |
| Par branche de risque | Barres : commission par `Branche_Risque` | `Commission_Theorique_Totale`/`Commission_Recue_Totale` avec `DIM_CONVENTION[Branche_Risque]` |
| Évolution | Courbe mensuelle commission reçue vs théorique | Mêmes mesures, axe temporel Commission (`USERELATIONSHIP`) |
| Table détaillée | Opérations avec écart ≠ 0 | `Nb_Operations_Ecart_Commission` |

---

### 📊 Page 5 — Rentabilité par compagnie / branche

| Zone | Contenu | Mesures |
|---|---|---|
| KPI | Primes totales, Commissions totales, Taux de rentabilité global | `Primes_Totales`, `Commissions_Totales`, `Taux_Rentabilite_Pct` |
| Matrice croisée | Branche de risque × Compagnie, valeur = taux de rentabilité | `Taux_Rentabilite_Pct` |
| Classement | Barres horizontales : rentabilité par branche, triée décroissante | `Taux_Rentabilite_Pct` par `Branche_Risque` |
| Volume vs rentabilité | Nuage de points (scatter) : `Primes_Totales` (X) vs `Taux_Rentabilite_Pct` (Y), taille = nombre de polices | Identifie les branches "gros volume/faible marge" vs "petit volume/forte marge" |

---

### 📊 Page 6 — Balance âgée & provisions (créances douteuses)

*Page dédiée à la vision "risque de non-recouvrement", orientée direction financière.*

| Zone | Contenu | Mesures |
|---|---|---|
| KPI | Provision totale, Créance nette provisionnée, Taux de provision moyen | `Provision_Creances_Douteuses`, `Creance_Client_Nette_Provisionnee`, `Taux_Provision_Moyen_Pct` |
| Balance âgée détaillée | Barres empilées : montant brut vs provisionné par tranche | `Montant_Creance_Client_Par_Tranche`, `Provision_Creances_Douteuses` |
| Focus polices à risque | Table : polices résiliées/expirées avec créance + provision associée | `Creance_Client_Polices_A_Risque`, `Provision_Polices_A_Risque` |
| Simulation | Slicer interactif sur les seuils de tranches (via paramètre "What-if") pour tester différentes politiques de provisionnement | Paramètre Power BI + mesure `Taux_Provision` paramétrée |

---

## 11. Bonnes pratiques de mise en page

- **Slicers globaux synchronisés** (Année, Compagnie, Branche de risque) sur toutes les pages via
  le panneau "Synchroniser les slicers", pour une navigation cohérente.
- **Bouton de navigation** entre les pages (icônes en haut, type onglets) plutôt que l'onglet natif
  Power BI, pour un rendu plus "dashboard exécutif".
- **Code couleur cohérent** dans tout le rapport : rouge = créance/retard, vert = encaissé/soldé,
  orange = partiel/attention — à définir une fois dans un thème Power BI (fichier `.json`) et
  appliquer à tout le rapport.
- **Infobulles (tooltips) personnalisées** sur les graphiques de tendance, affichant le détail
  N vs N-1 au survol.
- **Format des grands nombres** : appliquer un format `#,##0,,"M"` ou `#,##0,"K"` sur les cartes KPI
  pour rester lisible avec des montants en FCFA.

---

## Récapitulatif : toutes les mesures par thème

| Thème | Mesures |
|---|---|
| Contrôle | Nombre_Clients, Nombre_Compagnies, Nombre_Conventions, Nombre_Polices, Nombre_Dates, Nombre_Operations |
| Commissions | Commission_Theorique_Totale, Commission_Recue_Totale, Ecart_Commission, Nb_Operations_Ecart_Commission, Taux_Perception_Commission_Pct |
| Primes | Primes_Encaissees, Primes_Totales, Primes_Encaissees_YTD |
| Reversements | Jours_Retard_Reversement, Nb_Operations_Retard_Reversement, Retard_Moyen_Reversement_Jours, Taux_Reversement_Pct |
| Rentabilité | Commissions_Totales, Taux_Rentabilite_Pct |
| Créances (piliers) | Creance_Client, Creance_A_Reverser_Cie, Creance_Commission_A_Recevoir |
| Créances (recouvrement) | Taux_Encaissement_Pct, Pct_Operations_Soldees, Pct_Operations_En_Attente, DSO_Approx_Jours |
| Créances (ancienneté) | Anciennete_Creance_Jours, Tranche_Anciennete, Montant_Creance_Client_Par_Tranche |
| Créances (risque) | Creance_Client_Polices_A_Risque, Nb_Polices_A_Risque_Avec_Creance |
| Classements | Rang_Client_Par_Creance, Rang_Compagnie_Par_Creance_A_Reverser |
| Tendances | Creance_Client_Mois_Precedent, Variation_Creance_Client, Variation_Creance_Client_Pct, Creance_Client_Annee_Precedente, Variation_Creance_Client_YoY_Pct, Indicateur_Tendance_Creance, Creance_Client_YTD |
| Provisions | Taux_Provision, Provision_Creances_Douteuses, Creance_Client_Nette_Provisionnee, Taux_Provision_Moyen_Pct, Provision_Polices_A_Risque |
