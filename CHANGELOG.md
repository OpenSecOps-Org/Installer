# Change Log

## v3.0.14
    * Acknowledge `PYSEC-2025-183` / `CVE-2025-45768` against `pyjwt` (transitive via `sigstore`). The advisory is disputed by the supplier — the alleged "weak encryption" concerns the JWT signing-key length, which is chosen by the consuming application rather than the library, and the Installer does not sign JWTs (pyjwt is used read-only by `sigstore` to verify Rekor/Fulcio responses during release verification). All `pyjwt` versions are listed as affected and no fix version is published. Recorded in `.security-config.toml`; `SECURITY.md` §12 regenerated.

## v3.0.13
    * `README.md` gains the OpenSSF Best Practices Passing-level badge (project entry [bestpractices.dev/projects/12827](https://www.bestpractices.dev/projects/12827)).

## v3.0.12
    * Libraryless conversion path. `publish.zsh` now auto-detects components with no Python library dependencies (zero `requirements.in` files under the repo, excluding the usual non-source dirs) and emits a deterministic `git archive HEAD` source archive plus a SLSA Build L1 in-toto provenance attesting to it, both Sigstore-signed. Repos with `.in` files continue to use the existing SBOM + evidence + provenance path — backward compatible, no change for the 12 originally converted repos. Detection is filesystem-based; no config flag needed. Documented in `convert-component` skill under "Procedure (libraryless repos)".
    * `STRICT_VERIFICATION = True` in `_verify_release.py`. Phase 10 closed on 2026-05-13 — every repo in `apps/foundation/repos.toml` and `apps/soar/repos.toml` now ships signed releases. The "skipped, work in progress" banner path is gone; a converted release without signed bundles now fails closed.
    * `_verify_release.py` uses `.security-config.toml` presence on the local checkout as the "expect signed bundles" signal. A converted repo (config file present) whose remote release has no `.bundle` assets is flagged as a downgrade attack (release stripped after signing) and refuses to proceed — independent of `STRICT_VERIFICATION`.

## v3.0.11
    * Security: customer-side release verification, three layers deep. A new shared `scripts/_verify_release.py` module is the single source of truth for the trust anchor (`peter@peterbengtson.com` via `https://github.com/login/oauth`), the public org (`OpenSecOps-Org`), the `STRICT_VERIFICATION` toggle, and the verifier itself. Distributed by `refresh` to every converted component so both Installer (`init.py`) and components (`deploy.py`) call the same function. To rotate the trust anchor, edit one file and ship an Installer release.
    * Layer 1 — **Installer self-verification at init time** (closes the bootstrap gap). After `pip install --require-hashes` finishes, `init.py` calls `verify_release("Installer", repo_dir=_installer_root())`. A customer who has just pulled a tampered Installer is caught here before any component is touched. (TOFU applies only to first ever install; every subsequent `git pull` of Installer is verified.)
    * Layer 2 — **Eager component verification at init time**. After each `clone_repo()` of an OpenSecOps component, `init.py` immediately verifies the cloned/updated tree. Problems surface at init rather than waiting until deploy. The list of failed components is summarised at the end of init so the customer knows where not to run `./deploy`.
    * Layer 3 — **Just-in-time verification at deploy time**. `scripts/deploy.py` calls `verify_release(repo_name)` after `git pull`, before any `sam build` / `cfn deploy` / script execution. Tampered artefacts, wrong signer, or missing bundles fail the deploy.
    * Implementation: pure Python via the `sigstore` package (added to `requirements.in`, pinned `>=4.0.0,<5.0.0`). Installed by the existing `pip install --require-hashes` step. No new customer-side tooling required (no `cosign`, no Go runtime, no OIDC dance — verification is read-only against public Sigstore infrastructure).
    * Behaviour during the rolling Phase 10 conversion: components without a signed GitHub Release print a yellow "verification is skipped for now as the repo has not yet been signed. This is a work in progress; we will complete it in a day or two, no more." banner and the caller proceeds. Once every OpenSecOps-Org repo ships signed releases, `STRICT_VERIFICATION` in `_verify_release.py` flips to `True` and the skip path disappears.
    * New `--unsafe-untagged` flag on `./deploy`: prints a loud red audit banner (`OVERRIDE: deploying <repo> at untagged commit <sha> by <$USER>`) and proceeds without verification. Intended for emergencies; not for routine use.
    * Distributed to all 12 converted components via `./refresh --dev --push`; each re-releases independently to carry the new verifying `deploy.py` + `_verify_release.py`.

## v3.0.10
    * Tooling: `compile-requirements.sh` now accepts `--upgrade` and `--upgrade-package PKG` (repeatable) flags, plumbed through to `uv pip compile`. Previously the script only used existing locks as preferences, which meant any package with a newer in-range release on PyPI since the last compile would cause the release-gate's reproducible mode (clean cache, no preferences) to report drift and refuse to publish. Maintainers can now run `./compile-requirements --upgrade` to refresh every lock, or `./compile-requirements --upgrade-package urllib3` for a minimum-change CVE patch. Active mode is surfaced in the banner (`uv args: --upgrade-package urllib3`). Distributed to all converted components via `refresh`; available on each component's next release cycle.

## v3.0.9
    * Security: bump `urllib3` floor to `>=2.7.0` in canonical `templates/boto3.in` to remediate CVE-2026-44431 and CVE-2026-44432 (both affect urllib3 ≤ 2.6.3, fixed in 2.7.0). `boto3==1.42.94` previously resolved urllib3 transitively to 2.6.3 across the fleet; the new floor forces resolution to 2.7.0 in every component that imports `boto3.in`. Distributed via `refresh` to all components; each component re-releases independently with recompiled locks.
    * Installer's own `requirements.txt` recompiled (urllib3 → 2.7.0); no code changes.

## v3.0.8
    * Enable auto-close workflow for external pull requests, enforcing the cathedral governance policy uniformly across all OpenSecOps repositories. Pull requests from non-team authors are closed automatically with a redirect comment pointing to the bug-report template, the GitHub Security Advisory flow, and the fork-under-MPL-2.0 path. Distributed by `refresh` to all components.
    * `SECURITY.md.template` §14 now carries a Trust-page cross-link ([opensecops.org/trust.html](https://www.opensecops.org/trust.html)) alongside the existing canonical supply-chain document link, positioning the Trust page as the lighter customer-facing synthesis. Installer's own `SECURITY.md` regenerated to match; distributed to all components via `refresh` and rendered on each component's next publish.

## v3.0.7

- `SECURITY.md` and `README` updated re: OpenSSF Scorecard publication status. See [supply-chain documentation](https://github.com/OpenSecOps-Org/Documentation/blob/main/docs/security/supply-chain.md) §5.5.

## v3.0.6
    * CI workflow action versions bumped for Node 24 readiness ahead of GitHub's June 2026 deprecation. No customer action required.

## v3.0.5
    * Daily CVE scan + OpenSSF Scorecard public badges. See `SECURITY.md` §4 / §5 and the badges at the top of `README.md`.

## v3.0.4
    * Release artefacts now Sigstore-signed. See `SECURITY.md` §11 for the `cosign verify-blob` recipe.

## v3.0.3
    * `SECURITY.md.template` §4 (Continuous detection) rewritten as a two-bullet "two layers operate today" structure: release-time gate plus push-based GitHub Dependabot alerts, now enabled on every OpenSecOps repository. Alerts-only mode (auto-PR security updates and routine version-update PRs are explicitly disabled, consistent with the cathedral governance model). No SLA on detection-to-notification latency. Poll-based daily-scan CI carries a pointer-only follow-up note. Refresh-distributed to every component repo; `Installer/SECURITY.md` regenerated from the updated template.
    * No customer action required. `./init` and `./deploy-all` workflows are unchanged.

## v3.0.2
    * `SECURITY.md` §14 now links to the OpenSecOps Documentation supply-chain page.

## v3.0.1
    * Aggregate CycloneDX SBOM hardening: `metadata.tools` now records the cyclonedx-py and uv versions used to produce each release; `metadata.lifecycles` declares `build`; component hashes are emitted at the canonical `component.hashes[]` path (in addition to `externalReferences[].hashes[]`); `bom-ref` values are derived from each component's `purl` so they remain stable across regenerations instead of using cyclonedx-py's line-numbered `requirements-LN`. The redundant `description` field that re-stated the requirements line + every hash is dropped from each component, shrinking the released SBOM significantly.
    * New release asset: `Installer-vX.Y.Z-evidence.tar.gz`, a deterministic per-function evidence bundle of every `requirements.cdx.json` and `requirements.provenance.json` in the source tree. Reviewers performing CycloneDX-mature deep audit pull the tarball; the aggregate SBOM remains the inventory summary. Tarball is byte-deterministic across regenerations (PAX format, zeroed mtime/uid/gid, sorted entries, repo-root-anchored arcnames).
    * CVE acknowledged-and-deferred override mechanism now wired end-to-end: each entry in `acknowledged_cves` in `.security-config.toml` is passed to `pip-audit` via `--ignore-vuln`, so the release gate honours documented exceptions. The rendered `SECURITY.md` §12 mirrors the same list with full context (package, date, reason, expected resolution).
    * `_check-requirements.sh`: drift-detection no longer short-circuits subsequent gate checks. The `set -euo pipefail` interaction with the diff display pipeline previously caused the script to exit immediately on drift, before CVE / hash / OSV / provenance checks could run. The doc-claim "all five checks fire independently" is now true.
    * `SECURITY.md.template` §10 (SBOM) extended to surface both release assets, document the in-repo per-function evidence paths (`**/requirements.cdx.json`, `**/requirements.provenance.json`), and explain union semantics for components that may appear at multiple versions in the aggregate.
    * `SECURITY.md.template` §5 gains a new §5.1 "Verifiability decomposition" — a four-way breakdown of which guarantees are independently verifiable today (hash integrity, per-function SBOM determinism) and which become so in follow-up releases (Sigstore signing for substitution-in-transit; `# uv-compiled-at:` reproducibility for gate-derivation; SLSA L1 in-toto provenance for gate-execution attestation).
    * No customer action required. `./init` and `./deploy-all` workflows are unchanged.

## v3.0.0
    * BREAKING: coordinated with SOAR v3.0.0 which drops OpenAI direct integration. `AIProvider` in `apps/soar/parameters.toml` must be `BEDROCK` or `NONE` before upgrading; `OPENAI` is no longer accepted.
    * Removed 4 ChatGPT entries from `apps.example/soar/parameters.toml` (`ChatGPTOrganizationIdParameterPath`, `ChatGPTAPIKeyParameterPath`, `ChatGPTDefaultModel`, `ChatGPTFallbackModel`).
    * Customer-side Python deps installed by `./init` (`boto3`, `toml`, `yq`, plus all transitives) are now version-pinned and **SHA-256-hash-verified** at install time. The Installer's pyenv-managed Python 3.12.2 receives a deterministic, supply-chain-verified set of packages from a committed `requirements.txt`. Tampering or PyPI substitution is caught by `pip --require-hashes` before any byte is installed.
    * Added `SECURITY.md` at the Installer's root, documenting the supply-chain posture, governance model, vulnerability-reporting channel, and CVE response SLA.
    * GitHub Releases now include a CycloneDX SBOM as a downloadable asset (`Installer-<VERSION>-sbom.cdx.json`). Customers and intake reviewers can verify the dependency tree without cloning.
    * **Action required**: In your local `apps/soar/parameters.toml`, delete the same 4 `ChatGPT*` entries. If `AIProvider = "OPENAI"`, switch to `"BEDROCK"` (and configure `BedrockRegion` / `BedrockModel`) or `"NONE"` before deploying SOAR v3.0.0. If you're upgrading from before v2.8.0, also apply the `apps/` file updates documented in v2.8.0 and v2.7.0 below.

## v2.8.0
    * `protect-infra-immutable.json`: Extended `infra:immutable` tag protection to EC2, S3, Lambda, DynamoDB, SQS, SSM, Elastic Load Balancing, and CloudWatch Logs. Previously, tag removal and resource modification were only blocked for a subset of services.
    * `protect-foundations.json`: Added `DenyFederationProviderMutation` statement blocking OIDC and SAML provider creation and modification by non-admin principals. SecurityAdministratorAccess is exempted.
    * `NetworkAdministratorAccess.yaml`: Narrowed `iam:*` to the specific IAM actions required for network administration.
    * `developer-permission-boundary-policy.yaml`: Added athena, batch, cloudshell, glue, quicksight, sagemaker, and securityhub to match the DeveloperAccess permission set.
    * **Action required**: Copy the following files from `apps.example/` to `apps/` and redeploy:
        - `foundation/SCPs/protect-infra-immutable.json`
        - `foundation/SCPs/protect-foundations.json`
        - `foundation/sso-config/sso_permission_sets/NetworkAdministratorAccess.yaml`
        - `foundation/BoundaryPolicies/developer-permission-boundary-policy.yaml`

## v2.7.0
    * Fixed additional edge-case privilege escalation vulnerabilities in permissions boundary enforcement.
    * `require-boundary-permissions.json`: Added `PutRolePermissionsBoundary` to per-SSO-role statements, added universal catch-all for non-SSO principals, separated boundary deletion into its own statement.
    * `protect-foundations.json`: Added `ProtectAdminRoleTrustPolicies` statement to prevent trust policy modification on admin-exempted roles. Expanded `PreventUserMutations` to cover credential management (`CreateAccessKey`, `CreateLoginProfile`, etc.) and group operations.
    * **Action required**: Copy the following files from `apps.example/` to `apps/` and redeploy:
        - `foundation/SCPs/require-boundary-permissions.json`
        - `foundation/SCPs/protect-foundations.json`

## v2.6.1
    * Added protection for switching boundary permissions using SCP.

## v2.6.0
    * Added IAM user management permissions to SecurityAdministratorAccess role in protect-foundations.json SCP.
    * Added backup:* and backup-storage:* permissions to DeveloperAccess SSO permission set and permission boundary.

## v2.5.5
    * Added vpce:AllowMultiRegion to the NetworkAdministratorAccess SSO Permission Set.

## v2.5.4
    * Updated ARCHITECTURE.md.

## v2.5.3
    * Fixed zsh comments.

## v2.5.2
    * Fixed deploy script for Foundation-security-services-setup. Distributed to all repos.
    * Added ARCHITECTURE.md, describing the operation of the OpenSecOps Installer and its scripts.
    * Added header doc strings to all scripts under scripts/.

## v2.5.1
    * Fixed script execution to properly pass --verbose flag to component scripts when using verbose mode.

## v2.5.0
    * Added Foundation-security-services-setup component to automate AWS security services configuration (GuardDuty, Security Hub, IAM Access Analyzer, AWS Config, Detective, and Inspector delegation and setup across the organization), including updates to apps.example configuration files.

## v2.4.0
    * Added data/ML services (Athena, Batch, CloudShell, Glue, QuickSight, SageMaker) to DeveloperAccess permission sets.

## v2.3.0
    * Added `ReclassifyAWSHealthIncidents` parameter to SOAR configuration to support AWS Health incident reclassification feature introduced in SOAR v2.2.0, reducing false positives.

## v2.2.0
    * Added the developer SSO group.

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
