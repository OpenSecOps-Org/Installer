# Change Log

## v1.4.2
    * Updated account profile names and comment.

## v1.4.1
    * Updated the parameter section order to match the new repo order.

## v1.4.0
    * Rearranged repo installation order.

## v1.3.0
    * AI parameters updated for Bedrock integration

## v1.2.6
    * Rearranged GPT params.

## v1.2.5
    * Updated ChatGPT models. Omni default.

## v1.2.4
    * Now using `#!/usr/bin/env zsh` for refresh.zsh.

## v1.2.3
    * Changed `init` message wording slightly for compactness.

## v1.2.2
    * Printing information about Python versions in `init`.

## v1.2.1
    * Added yq to the list of pip packages to install.

## v1.2.0
    * Now using `pyenv` and `.python-version` files to allow for multiple Python
      versions to be used.

## v1.1.32
    * Using pip3 directly, not pip.

## v1.1.31
    * Added INFRA-SOAR to the list of stacks excepted from drift detection.
      (System Manager Parameters changes always trigger drift.)

## v1.1.30
    * Updated the deploy script for CloudFormation edge case.

## v1.1.29
    * Added support for InstanceTypeList.

## v1.1.28
    * Added support for InstanceType.

## v1.1.27
    * Added DevEnvNames, StagingEnvNames, and ProdEnvNames.

## v1.1.26
    * Default AI model changed to gpt-4-turbo-preview.

## v1.1.25
    * ForensicsAMI is now ForensicsAMIs and a map.

## v1.1.24
    * DiskForensicsInvoke now controls EC2 snapshotting. DiskForensicsInvokeARN is no
      longer supported.

## v1.1.23
    * Added support for IncidentSeverity.

## v1.1.22
    * Added support for WeeklyReportTitle.

## v1.1.21
    * Added support for WeeklyReportWeekNumbers.

## v1.1.20
    * Added support for MS Sentinel for incidents.

## v1.1.19
    * Added DashboardNameExec.

## v1.1.18
    * Excepting `AWSControlTowerExecutionRole` from drift detection.

## v1.1.17
    * New version of the ./publish script.

## v1.1.16
    * Added DashboardName.

## v1.1.15
    * Added EscalationEmailSeverities.

## v1.1.14
    * Added EscalationEmailCC for overdue ticket reminders.

## v1.1.13
    * Added SkipTheseStacks to SOAR-detect-stack-drift.

## v1.1.12
    * Added the auditor group and substituted ReadOnlyWideAccess where applicable.

## v1.1.11
    * Widened the Security Administrator role.

## v1.1.10
    * Swapped two settings for clarity.

## v1.1.9
    * Added the DeferIncidents and DeferAutoRemediations parameters.

## v1.1.8
    * Added the SOAREnabled parameter

## v1.1.7
    * Added the ChatGPTOrganizationIdParameterPath parameter

## v1.1.6
    * Added EKS permissions to DeveloperAccess and developer-permission-boundary-policy.

## v1.1.5
    * Updated apps.example

## v1.1.4
    * Updated apps.example

## v1.1.3
    * Updated apps.example

## v1.1.2
    * Synced policies.

## v1.1.1
    * Added BoundaryPolicies to the apps.example/foundation dir.

## v1.1.0
    * apps.example folder created, apps/ ignored.

## v1.0.8
    * Corrected a typo, added parameters replacing hardcoded references.

## v1.0.7
    * Added Foundation-service-control-policies.
    
## v1.0.6
    * Added Foundation-AWS-Core-SSO-Configuration.
    * Delegat Installer can now run scripts.
    * Added sso-config.example folder.

## v1.0.5
    * Local repo config files 
    * Repo deployment suppression
    * Open-source credits and URLs

## v1.0.4
    * Added SOAR-SAM-Automating-Forensic-Disk-Collection.
    * Fixed installer initial stackset creation.

## v1.0.3
    * Added Foundation-control-tower-log-aggregator.

## v1.0.2
    * Added Foundation-CloudWatch2S3.

## v1.0.1
    * `--dry-run` and `--verbose` added to `deploy-all` and `deploy`.

## v1.0.0
    * Initial release.
