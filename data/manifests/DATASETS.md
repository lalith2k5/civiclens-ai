# CIVICLENS AI — Dataset Manifest

## Image Classification Training Data
| Dataset | Source | License | Classes used | Path |
|---|---|---|---|---|
| Urban Issues Dataset | Kaggle (akinduhiman) | CC0 | damaged road, pothole, garbage, broken sign, fallen tree | images/complaints/urban_issues |

## Resolution-Time and Forecasting Training Data
| Dataset | Source | Rows | Key columns |
|---|---|---|---|
| BMC Complaints | Kaggle (govindaramsriram) | Public | complaint_category, ward_code, resolution_days, severity |

## Context Data (Section 10)
| Dataset | Source | Use |
|---|---|---|
| India Flood Inventory v3 | Zenodo (IIT Delhi) | Historical flood events |
| OSM Southern Zone | Geofabrik | Road network, facilities |

## Governance
- BMC data is used for ML training only; not presented as Hyderabad operational data.
- Hyderabad operational seed will be clearly marked `data_origin='seed'`.
