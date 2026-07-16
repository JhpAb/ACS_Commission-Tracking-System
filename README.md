# ACS - Commission Tracking System

## Overview
A system to track insurance commissions, prime reversements, and payment discrepancies for ACS (a brokerage firm).

## Data Sources
- **Conventions**: Agreements with insurance companies (commission rates, reversement rules).
- **Bordereaux**: Prime collection/reversement records.
- **Bank Statements**: Actual payments received.
## Data Base Schema
<img width="7943" height="3317" alt="ACS - Commission Tracking System" src="https://github.com/user-attachments/assets/f6ee78c6-8acb-4efe-b3e1-a7f7c38ce00d" />

## Data Architecture Pipeline
<img width="2720" height="2880" alt="architecture_erp_vers_powerbi" src="https://github.com/user-attachments/assets/3d8ace56-9514-4653-8629-7b042ff6524e" />

## Workflow
1. **Data Collection**: Gather conventions, bordereaux, and bank statements.
2. **Cleaning**: Validate data (e.g., check all companies in bordereaux exist in conventions).
3. **Calculation**: Compute expected commissions/reversements.
4. **Reconciliation**: Compare expected vs. actual payments.
5. **Reporting**: Generate discrepancy reports and dashboards.

## Scripts
- `data_cleaning.py`: Validate and clean raw data.
- `commission_calculator.py`: Calculate expected commissions.
- `reporting.py`: Generate reports and visualizations.

## Setup
```bash
pip install -r requirements.txt
```
----------------------------
## Repository Structure

```
ACS/
├── data/
│   ├── raw/                  # Original files (conventions, bordereaux, etc.)
│   ├── processed/            # Cleaned/transformed data
│   └── outputs/              # Reports, dashboards, or exports
├── scripts/
│   ├── data_cleaning.py      # Scripts to clean/validate data
│   ├── commission_calculator.py  # Calculate commissions/reversements
│   └── reporting.py          # Generate reports/dashboards
├── docs/
│   ├── conventions/          # Copies of company conventions (PDFs/CSVs)
│   └── workflow.md           # Documentation of processes
├── notebooks/                # Jupyter notebooks for exploratory analysis
├── README.md                 # Project overview (expand this)
└── requirements.txt          # Python dependencies
```
