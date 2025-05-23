# Change Log

## v2.1.0
    * The default model in apps.example for Claude updated to Claude Sonnet v4.

## v2.0.3
    * Corrected indentation in the SecurityAdministratorAccess.yaml file
    * Changes to the README

## v2.0.2
    * Fixed documentation links to use OpenSecOps-Org instead of CloudSecOps-Org.

## v2.0.1
    * Moved documentation to dedicated Documentation repository and updated references.

## v2.0.0
    * OpenSecOps-Org is now the only publishing target GitHub organisation.

## v1.9.7
    * Updated the scripts README.

## v1.9.6
    * Updated apps.example with ProductName explicitly given for the SOAR.

## v1.9.5
    * Removed "AB".

## v1.9.4
    * List corrected.

## v1.9.3
    * Spaces encoded correctly in doc file names.

## v1.9.2
    * Updated the README with the installation manual paths.

## v1.9.1
    * Repo URLs corrected.

## v1.9.0
    * Added docs folder with all manuals for Foundation and SOAR.

## v1.8.3
    * Updated GitHub organization name from CloudSecOps-Org to OpenSecOps-Org.
    * All references to CloudSecOps updated to OpenSecOps.

## v1.8.2
    * File paths corrected for the name name of the installer.

## v1.8.1
    * The license is now MPL 2.0, Mozilla Public License v2.0.

## v1.8.0
    * Started the process of renaming "Delegat" to "CloudSecOps".

## v1.7.6
    * Testing dual deployment.

## v1.7.5
    * Added dual remote push capability to CloudSecOps-Org repositories.

## v1.7.4
    * Made emptying the Control Tower S3 access every hour the default.

## v1.7.3
    * Update to the deploy script: formatting stackset updates improved.

## v1.7.2
    * Now using "pip" rather than "pip3".

## v1.7.1
    * Example config now uses Claude 3.7 with a US inference profile.

## v1.7.0
    * Updated the README.

## v1.6.2
    * Updated the standard GenAI model to Claude 3.5 Sonnet v2.

## v1.6.1
    * Added newline and OK for cloned repos.

## v1.6.0
    * More compact and informative ./init output.

## v1.5.1
    * Fixed typo in the CHANGELOG.

## v1.5.0
    * Added Foundation-resource-control-policies (be sure to include its new section in parameters.toml as per the example in apps.example/parameters.toml)

## v1.4.7
    * Added SkipPrefixes.

## v1.4.6
    * Added the Org account ID as a parameter to Foundation-new-account-created-sns-topic.

## v1.4.5
    * Added AmazonQDeveloperAccess to all applicable SSO permission sets.

## v1.4.4
    * Added security admin access to core accounts.

## v1.4.3
    * Added section to the README about updates and recovery.

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
