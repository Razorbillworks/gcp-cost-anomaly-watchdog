# GCP Cost & Anomaly Watchdog

An event-driven document intelligence pipeline on Google Cloud Platform, paired with automated cloud cost anomaly detection - built to explore both application-level serverless architecture and FinOps/cost-governance practices, which most student cloud projects skip entirely.

## What it does

1. **Document Pipeline**: A user uploads an image (invoice, note, ID, etc.) to Cloud Storage. This automatically triggers a Cloud Function that runs OCR (Vision API), detects the language, translates it to English if needed (Translation API), and stores the structured result in BigQuery.
2. **Cost Anomaly Detection**: GCP's native Billing Export streams daily cost data into BigQuery. A scheduled Cloud Function runs a SQL query daily (via Cloud Scheduler) comparing each day's spend per service against a 7-day rolling average, flagging genuine spikes while filtering out sub-cent noise.
3. **Dashboard**: A live Looker Studio dashboard visualizes documents processed, language breakdown, and recent activity.
4. **Infrastructure as Code**: The entire stack is defined in Terraform for reproducibility.

## Why this project

Most beginner/intermediate cloud projects stop at "I deployed an app to the cloud." This project goes further by adding **cost observability** - a practice usually reserved for production systems - on top of a working event-driven application. The goal was to combine practical serverless architecture with an operational skill (cost governance) that's rarely demonstrated in student portfolios.

## Architecture

```
                    ┌─────────────────┐
   User uploads  →  │  Cloud Storage   │
   document          │     Bucket       │
                    └────────┬─────────┘
                             │ triggers (Eventarc)
                             ▼
                    ┌─────────────────┐
                    │  Cloud Function  │
                    │ process-document │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌─────────────┐  ┌──────────┐
        │ Vision   │  │ Translation │  │ BigQuery │
        │   API    │  │     API     │  │  (write) │
        └──────────┘  └─────────────┘  └──────────┘


   GCP Billing  →  Billing Export  →  BigQuery
                                          │
                                          ▼
                                 ┌──────────────────┐
                Cloud Scheduler │  Cloud Function    │
                  (daily 9AM) → │  check-anomalies   │
                                 └──────────────────┘
                                    (SQL: 7-day rolling
                                     average spike detection)
```

## Tech Stack

| Layer | Technology |
|---|---|
| Storage | Cloud Storage |
| Compute | Cloud Functions (Gen 2, Python 3.12) |
| OCR | Vision API |
| Translation | Cloud Translation API |
| Data warehouse | BigQuery |
| Scheduling | Cloud Scheduler |
| Dashboard | Looker Studio |
| Infrastructure as Code | Terraform |
| Query language | SQL (window functions) |

## Repository Structure

```
├── functions/
│   ├── process-document/       # OCR + Translation pipeline
│   │   ├── main.py
│   │   └── requirements.txt
│   └── check-anomalies/        # Scheduled cost anomaly detector
│       ├── main.py
│       └── requirements.txt
├── terraform/                  # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── .terraform.lock.hcl
├── sql/
│   └── anomaly_detection_query.sql
├── docs/
│   └── architecture-diagram.png
└── README.md
```

## Key Design Decisions

- **Event-driven, not polling**: The document pipeline reacts to uploads via Cloud Storage triggers rather than checking on a schedule - no wasted compute.
- **Noise filtering in anomaly detection**: The SQL query includes a minimum cost threshold (`daily_cost > 0.01`) to avoid flagging statistically meaningless spikes on near-zero spend days - a detail that separates a naive multiplier check from a usable one.
- **Infrastructure as Code**: All resources are defined in Terraform. Note: resources were initially provisioned via console during development and later codified in Terraform for reproducibility and documentation - `terraform plan` has been validated against the file definitions.

## Live Demo

- **Dashboard**: https://datastudio.google.com/reporting/dbf3bd7f-18b7-41ab-8778-ea99b7968c5a
- **Sample output**: See `docs/` for example processed documents and anomaly query results.

## Setup

1. Enable required APIs: Cloud Storage, Cloud Functions, Cloud Build, Vision, Translation, BigQuery, Cloud Scheduler.
2. Deploy `functions/process-document` with a Storage trigger on your upload bucket.
3. Deploy `functions/check-anomalies` as an HTTP-triggered function.
4. Enable Billing Export to BigQuery (standard usage cost) in your billing account settings.
5. Create a Cloud Scheduler job pointing to `check-anomalies`'s URL, running daily.
6. (Optional) Run `terraform plan` in `terraform/` to validate infrastructure definitions.

## Author

Built by [razorbillworks](https://github.com/razorbillworks) as part of an ongoing exploration of cloud architecture, AI/ML integration, and FinOps practices.
