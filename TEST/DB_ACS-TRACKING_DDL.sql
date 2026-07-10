/*===========================================================
    BASE DE DONNÉES : ACS - COURTAGE EN ASSURANCE
    VERSION AMÉLIORÉE
===========================================================*/

------------------------------------------------------------
-- DIMENSION CLIENT
------------------------------------------------------------
CREATE TABLE DIM_CLIENT (
    PK_Client INT IDENTITY(1,1) PRIMARY KEY,
    Code_Client_Unique VARCHAR(50) NOT NULL UNIQUE,
    Nom_Raison_Sociale VARCHAR(150) NOT NULL,
    Type_Client VARCHAR(20)
        CHECK(Type_Client IN ('Particulier','Entreprise')),
    Secteur_Activite VARCHAR(100),
    Localisation VARCHAR(100)
);

------------------------------------------------------------
-- DIMENSION COMPAGNIE
------------------------------------------------------------
CREATE TABLE DIM_COMPAGNIE (
    PK_Compagnie INT IDENTITY(1,1) PRIMARY KEY,
    Code_Cie VARCHAR(20) UNIQUE NOT NULL,
    Nom_Complet_Assureur VARCHAR(150) NOT NULL,
    Adresse_Siege VARCHAR(200)
);

------------------------------------------------------------
-- DIMENSION CONVENTION
-- Une convention appartient à UNE compagnie
------------------------------------------------------------
CREATE TABLE DIM_CONVENTION (

    PK_Convention INT IDENTITY(1,1) PRIMARY KEY,

    FK_Compagnie INT NOT NULL,

    Ref_Contrat_Cadre VARCHAR(80) UNIQUE NOT NULL,

    Branche_Risque VARCHAR(50)
    CHECK(
        Branche_Risque IN(
            'Santé',
            'Flotte Auto',
            'Automobile',
            'Incendie',
            'Transport',
            'RC',
            'Multirisque',
            'Voyage',
            'Risques Divers'
        )
    ),

    Taux_Commission_Contractuel DECIMAL(5,4),

    Date_Debut DATE,

    Date_Fin DATE,

    Mode_Reglement VARCHAR(30),

    Periodicite VARCHAR(20),

    Convention_Active BIT DEFAULT 1,

    FOREIGN KEY(FK_Compagnie)
        REFERENCES DIM_COMPAGNIE(PK_Compagnie)

);

------------------------------------------------------------
-- DIMENSION POLICE
------------------------------------------------------------
CREATE TABLE DIM_POLICE (

    PK_Police INT IDENTITY(1,1) PRIMARY KEY,

    Numero_Police VARCHAR(60) UNIQUE,

    FK_Client INT NOT NULL,

    FK_Convention INT NOT NULL,

    Date_Souscription DATE,

    Date_Echeance DATE,

    Statut_Police VARCHAR(20)
        CHECK(
            Statut_Police IN
            ('Active','Suspendue','Résiliée','Expirée')
        ),

    FOREIGN KEY(FK_Client)
        REFERENCES DIM_CLIENT(PK_Client),

    FOREIGN KEY(FK_Convention)
        REFERENCES DIM_CONVENTION(PK_Convention)

);

------------------------------------------------------------
-- DIMENSION TEMPS
------------------------------------------------------------
CREATE TABLE DIM_TEMPS (

    PK_Temps INT IDENTITY(1,1) PRIMARY KEY,

    Date_Exacte DATE UNIQUE,

    Jour INT,

    Mois INT,

    Nom_Mois VARCHAR(20),

    Trimestre INT,

    Semestre INT,

    Annee INT

);

------------------------------------------------------------
-- TABLE DE FAITS
------------------------------------------------------------
CREATE TABLE FAIT_OPERATIONS_TECHNIQUES (

    ID_Operation VARCHAR(80) PRIMARY KEY,

    FK_Client INT NOT NULL,

    FK_Compagnie INT NOT NULL,

    FK_Convention INT NOT NULL,

    FK_Police INT NOT NULL,

    ----------------------------------------------------
    -- Plusieurs dimensions Temps
    ----------------------------------------------------

    FK_Date_Emission INT,

    FK_Date_Encaissement INT,

    FK_Date_Reversement INT,

    FK_Date_Commission INT,

    ----------------------------------------------------
    -- Montants
    ----------------------------------------------------

    Montant_Prime_Brute_TTC DECIMAL(15,2),

    Montant_Taxes DECIMAL(15,2),

    Montant_Accessoires DECIMAL(15,2),

    Montant_Prime_Nette_Cie DECIMAL(15,2),

    Montant_Encaisse_Client DECIMAL(15,2),

    Montant_Reverse_Cie DECIMAL(15,2),

    Montant_Commission_Theorique DECIMAL(15,2),

    Montant_Commission_Recue DECIMAL(15,2),

    ----------------------------------------------------
    -- Etats
    ----------------------------------------------------

    Etat_Reversement VARCHAR(20)
    CHECK(
        Etat_Reversement IN
        ('En attente','Partiel','Soldé')
    ),

    Etat_Commission VARCHAR(20)
    CHECK(
        Etat_Commission IN
        ('Non payée','Partielle','Payée')
    ),

    ----------------------------------------------------
    -- Contraintes
    ----------------------------------------------------

    FOREIGN KEY(FK_Client)
        REFERENCES DIM_CLIENT(PK_Client),

    FOREIGN KEY(FK_Compagnie)
        REFERENCES DIM_COMPAGNIE(PK_Compagnie),

    FOREIGN KEY(FK_Convention)
        REFERENCES DIM_CONVENTION(PK_Convention),

    FOREIGN KEY(FK_Police)
        REFERENCES DIM_POLICE(PK_Police),

    FOREIGN KEY(FK_Date_Emission)
        REFERENCES DIM_TEMPS(PK_Temps),

    FOREIGN KEY(FK_Date_Encaissement)
        REFERENCES DIM_TEMPS(PK_Temps),

    FOREIGN KEY(FK_Date_Reversement)
        REFERENCES DIM_TEMPS(PK_Temps),

    FOREIGN KEY(FK_Date_Commission)
        REFERENCES DIM_TEMPS(PK_Temps)

);