# Cortex Data Foundation

The Cortex Data Foundation is the core architectural component of
[Google Cloud Cortex Framework](https://cloud.google.com/solutions/cortex).
Cortex Framework provides reference architectures, deployable solutions, and
packaged implementation services to kickstart your Data and AI Cloud journey.
Cortex Framework incorporates your source data into tools and services that help ingest,
transform, and load it to get insights faster from pre-defined data models that can be automatically
deployed for use with [Google Cloud BigQuery](https://cloud.google.com/bigquery)

This repository contains the Entity Relationship (ERD) diagrams, scripts and files
to deploy the Cortex Framework. For more information and instructions, see our
official [Cortex Framework documentation site](https://cloud.google.com/cortex/docs).

# Data sources and workloads

Cortex Framework focuses on solving specific problems and offers pre built solutions
for business areas like Marketing, Sales, Supply Chain, Manufacturing, Finance, and Sustainability.
Cortex Framework is flexible and it can include data from sources beyond what is prebuilt.
The following are the data sources available. For more information about each one, click any
of them.

**Marketing**:

*   [Salesforce Marketing Cloud](https://cloud.google.com/cortex/docs/marketing-salesforce)
*   [Google Ads](https://cloud.google.com/cortex/docs/marketing-googleads)
*   [Campaign Manager 360 (CM360)](https://cloud.google.com/cortex/docs/marketing-cm360)
*   [TikTok](https://cloud.google.com/cortex/docs/marketing-tiktok)
*   [Meta](https://cloud.google.com/cortex/docs/marketing-meta)
*   [LiveRamp](https://cloud.google.com/cortex/docs/marketing-liveramp)
*   [YouTube (with DV360)](https://cloud.google.com/cortex/docs/marketing-dv360)
*   [Google Analytics 4](https://cloud.google.com/cortex/docs/marketing-google-analytics)
*   [Cross Media & Product Connected Insights](https://cloud.google.com/cortex/docs/marketing-cross-media)

**Operational**:

*   [SAP (ECC and S/4)](https://cloud.google.com/cortex/docs/operational-sap)
*   [Salesforce Sales Cloud](https://cloud.google.com/cortex/docs/operational-salesforce)
*   [Oracle EBS](https://cloud.google.com/cortex/docs/operational-oracle-ebs)

**Sustainability**:

*   [Dun & Bradstreet with SAP](https://cloud.google.com/cortex/docs/dun-and-bradstreet)

**Note**: If you want to know more about which entities are covered in each data source, see the
Entity-Relationship Diagrams (ERD) in the [docs](https://github.com/GoogleCloudPlatform/cortex-data-foundation/tree/main/docs) folder.

# WEBER Specific Settings

The current configuration is adapted for the production environment. The following tables have been identified as empty and have been removed from all configurations:

- BUT000
- BUT020
- MSFD
- MKOL

These tables have been removed from all configuration files, and their components in the SQL reporting scripts have been manually removed to ensure proper functionality.

- For Chart of Accounts (CoA) / Kontenplan and for P&L structure FSV, WEBER-specific codes were used: 'YIKR', 'YIKH' as configured in the [financial_statement_version.sql](src/SAP/SAP_REPORTING/local_k9/fsv_hierarchy/financial_statement_version.sql) procedure call
- The [fiscal_date_dim.sql](src/SAP/SAP_REPORTING/fiscal_date_dim.sql) script was modified to correctly handle non-standard fiscal year variants (like V3). The logic for CASE 3 (custom variants) was updated to check for both NULL and empty strings in `t009` flags (`xkale`, `xjabh`) and to accurately calculate the `FiscalYearActual` for year-independent variants (`t009b.bdatj = '0000'`) with year shifts (`reljr = -1`).
- In [FinancialStatement](src/SAP/SAP_REPORTING/ecc/FinancialStatement.sql) (especially for [financial_statement.sql](src/SAP/SAP_REPORTING/financial_statement.sql)), the query for BKPF was changed from "XREVERSAL IS NULL" to "XREVERSAL = ''" to enable data retrieval from BKPF.
- To load [FinancialStatement](src/SAP/SAP_REPORTING/ecc/FinancialStatement.sql), the following refreshes / DAGs must be triggered beforehand: fiscal_date_dim, CurrencyConvUtil, CurrencyConversion, currency_conversion, financial_statement_version, financial_statement_initial_load
- To load [BalanceSheet](src/SAP/SAP_REPORTING/ecc/BalanceSheet.sql), the following refreshes / DAGs must be triggered beforehand: fiscal_date_dim, CompaniesMD, CurrencyConversion, FinancialStatement, GLAccountsMD
- To load [ProfitAndLoss](src/SAP/SAP_REPORTING/ecc/ProfitAndLoss.sql), the following refreshes / DAGs must be triggered beforehand: Languages_T002, fiscal_date_dim, CompaniesMD, CurrencyConversion, FinancialStatement, GLAccountsMD

# Deployment

For Cortex Framework deployment instructions, see the following:

*   **Quickstart Demo**: a [quickstart demo](https://cloud.google.com/cortex/docs/quickstart-demo) to
test the Cortex Framework set up process with sample data within just a few clicks. *This demo deployment
is not suitable for production environments*.
*   **Deployment steps**: after reading the [prerequisites](https://cloud.google.com/cortex/docs/deployment-prerequisites) for Cortex Data Foundation deployment, follow the steps for deployment in production environments:
    1. [Establish workloads](https://cloud.google.com/cortex/docs/deployment-step-one)
    2. [Clone repository](https://cloud.google.com/cortex/docs/deployment-step-two)
    3. [Determine integration mechanism](https://cloud.google.com/cortex/docs/deployment-step-three)
    4. [Set up components](https://cloud.google.com/cortex/docs/deployment-step-four)
    5. [Configure deployment](https://cloud.google.com/cortex/docs/deployment-step-five)
    6. [Execute deployment](https://cloud.google.com/cortex/docs/deployment-step-six)

## Optional steps

You can customize your Cortex Framework deployment with the following optional steps:

*   [Use different projects to segregate access](https://cloud.google.com//cortex/docs/optional-step-segregate-access)
*   [Use Cloud Build features](https://cloud.google.com//cortex/docs/optional-step-cloud-build-features)
*   [Configure external datasets for K9](https://cloud.google.com//cortex/docs/optional-step-external-datasets)
*   [Enable Turbo Mode](https://cloud.google.com/cortex/docs/optional-step-turbo-mode)
*   [Telemetry](https://cloud.google.com/cortex/docs/optional-step-telemetry)
*   [Configure Common Dimensions](https://cloud.google.com/cortex/docs/optional-step-common-dimensions)

## Looker Blocks and Dashboards

After Cortex Framework deployment, you can take advantage of prebuilt Looker Blocks and Dashboards for some of the Cortex Framework data sources.
For more information, see [Looker Blocks and Dashboards overview](https://cloud.google.com/cortex/docs/looker-block-overview).

The following are the Looker Blocks and Dashboards available in Cortex Framework:

* Looker Blocks
    *   **Operational**
        *   [Looker Block for SAP](https://cloud.google.com/cortex/docs/looker-block-sap)
        *   [Looker Block for Salesforce](https://cloud.google.com/cortex/docs/looker-block-salesforce)
        *   [Looker Block for Oracle EBS](https://cloud.google.com/cortex/docs/looker-block-oracle-ebs)
    *   **Marketing**
        *   [Looker Block for Salesforce Marketing Cloud](https://cloud.google.com/cortex/docs/looker-block-salesforce-marketing)
        *   [Looker Block for Meta](https://cloud.google.com/cortex/docs/looker-block-meta)
        *   [Looker Block for YouTube (with DV360)](https://cloud.google.com/cortex/docs/looker-block-youtube)
        *   [Looker Block for Cross Media & Product Connected Insights](https://cloud.google.com/cortex/docs/looker-block-cross-media)
* Looker Studio Dashboards
    *   **Sustainability**
        *   [Looker Studio Dashboard for Dun & Bradstreet](https://cloud.google.com/cortex/docs/looker-dashboard-dun-and-bradstreet)

Note: If you are looking for the README files before Release 6.0, see the
[deprecated docs folder](https://github.com/GoogleCloudPlatform/cortex-data-foundation/tree/main/docs/deprecated).
