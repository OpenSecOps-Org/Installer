# OpenSecOps Installer Architecture

This document describes the operation of the OpenSecOps Installer and its scripts, providing a comprehensive overview of how the deployment system works across OpenSecOps component repositories.

## Overview

The OpenSecOps Installer is a deployment orchestration system that manages the automated deployment of OpenSecOps component repositories across AWS Organizations. It provides a unified deployment interface while supporting multiple deployment patterns (SAM, CloudFormation, Scripts) and handling complex parameter resolution and cross-account operations.

## Core Architecture

### Repository Structure

```
Installer/
├── ARCHITECTURE.md              # This documentation
├── apps/                        # Application configurations (not under source control)
│   ├── accounts.toml            # Account definitions and SSO profiles
│   ├── foundation/              # Foundation application parameters
│   │   ├── parameters.toml      # Global parameters for Foundation components
│   │   └── repos.toml           # Foundation repository definitions
│   └── soar/                    # SOAR application parameters
│       ├── parameters.toml      # Global parameters for SOAR components
│       └── repos.toml           # SOAR repository definitions
├── apps.example/                # Template configurations to copy and customize
├── scripts/                     # Core deployment scripts
│   ├── deploy.py               # Main deployment orchestration script
│   ├── refresh.zsh             # Script distribution mechanism
│   └── publish.zsh             # Publication workflow script
└── deploy-all                   # Master deployment script for all OpenSecOps components
```

### Configuration Setup

The `apps.example/` directory contains template configurations that should be copied to `apps/` and customized for your environment:

1. **Initial Setup**: Copy `apps.example/` to `apps/` and customize for your AWS Organization
2. **Version Control**: The `apps/` directory is excluded from source control but you should create a separate git repository for your configuration files
3. **Customization**: Tailor the copied files to match your account IDs, regions, and deployment requirements
4. **Organization**: Both Foundation and SOAR components have separate parameter and repository definition files

### Component Integration

Each OpenSecOps component repository follows a standardized structure:

```
OpenSecOps-component-name/
├── config-deploy.toml          # Deployment configuration
├── deploy -> scripts/deploy.py # Symlink to deployment script
├── scripts/                    # Distributed scripts (managed by refresh)
│   ├── deploy.py              # Copy of Installer/scripts/deploy.py
│   ├── setup.zsh              # Git setup utilities
│   └── publish.zsh            # Publishing workflow
└── [component-specific files]
```

## Deployment Orchestration

### The `deploy.py` Script

The central `deploy.py` script (`Installer/scripts/deploy.py`) is distributed to all OpenSecOps component repositories via the refresh mechanism. It provides:

1. **Unified Deployment Interface**: Single entry point for all deployment patterns
2. **Parameter Resolution**: Complex parameter substitution and cross-referencing
3. **Cross-Account Operations**: Automated role assumption and multi-account deployments
4. **Multiple Deployment Patterns**: Support for SAM, CloudFormation, and custom scripts

### Parameter System

#### Global Parameters (`Installer/apps/foundation/parameters.toml`)

Defines organization-wide configuration:

Organization-wide configuration includes global parameters and component-specific sections.

#### Parameter Resolution

The parameter system supports:

1. **Direct Values**: Static strings, numbers, lists
2. **Cross-References**: `{parameter-name}` syntax for referencing other parameters
3. **Account References**: `{admin-account}` resolves to account IDs from `accounts.toml`
4. **Computed Values**: `{all-regions}` dynamically computed from `main-region` + `other-regions`

#### Parameter Processing Flow

1. Load global parameters from parameters.toml
2. For each component deployment:
   - Load component-specific config-deploy.toml
   - Extract component parameters
   - Resolve all parameter references
   - Pass resolved parameters to deployment mechanism

## Deployment Patterns

### 1. SAM Deployments

For serverless applications using AWS SAM, the configuration includes profile, regions, stack name, and parameters.

**Process:**
1. Build SAM application (`sam build`)
2. Deploy to each specified region
3. Pass resolved parameters as SAM parameter overrides

### 2. CloudFormation Deployments

For infrastructure-as-code using CloudFormation, the configuration includes stack definitions, templates, target accounts, and parameters.

**Process:**
1. Read CloudFormation template
2. Create/update stacks or stacksets
3. Monitor deployment progress
4. Handle cross-account operations

### 3. Script Deployments

For custom automation scripts, the configuration includes script names, arguments, and script-specific parameters.

**Process:**
1. Resolve script-specific parameters
2. Build command with resolved arguments
3. Execute script with proper flags (--dry-run, --verbose)

## Key Functions and Algorithms

### Parameter Resolution

The parameter resolution system handles computed values, parameter references, and substitutions to provide dynamic configuration.

### Script Parameter Processing

Script parameters are extracted, resolved, and converted to dictionaries for use in deployment operations.

### Command Building for Scripts

Command building optimizes parameter resolution and formats arguments appropriately for script execution.

## Cross-Account Operations

### Account Management

The `accounts.toml` file defines account IDs and SSO profiles for cross-account operations.

### Role Assumption

The deployment system automatically assumes roles for cross-account operations using AWS STS.

## Script Distribution (`refresh`)

The refresh mechanism ensures all OpenSecOps component repositories have the latest deployment scripts:

1. **Source**: `Installer/scripts/` contains master versions
2. **Distribution**: `refresh` script copies to all OpenSecOps component repositories
3. **Consistency**: Ensures unified deployment behavior across components

### Refresh Process

The refresh process updates deployment scripts from the central Installer location.

This updates:
- `scripts/deploy.py` from `Installer/scripts/deploy.py`
- `scripts/setup.zsh` from `Installer/scripts/setup.zsh`
- `scripts/publish.zsh` from `Installer/scripts/publish.zsh`

## Error Handling and Safety

### Dry-Run Support

All deployment patterns support `--dry-run`:
- **SAM**: Uses `--no-execute-changeset`
- **CloudFormation**: Previews changes without execution
- **Scripts**: Passed through to script implementation

### Idempotency

Deployments are designed to be idempotent:
- CloudFormation change sets detect no-op operations
- Scripts implement proper state checking
- Safe to re-run after failures

### Validation

- Parameter validation before deployment
- Template validation for CloudFormation
- Cross-account role verification

## Security Considerations

### Authentication

- Uses AWS SSO for authentication
- Validates active session before deployment
- No stored credentials

### Authorization

- Cross-account access via predefined roles
- Least privilege principle
- Audit trail through CloudTrail

### Parameter Security

- No secrets in parameter files
- Account IDs and organization details only
- Parameters resolved at deployment time

## Monitoring and Debugging

### Verbose Mode

Verbose mode (`./deploy --verbose`) provides detailed output including:

- Parameter resolution details
- AWS API calls and responses  
- Command construction for scripts
- Stack/deployment progress

### Logging

- Colored output for different message types
- Progress indicators for long-running operations
- Error details with context

## Extension Points

### Adding New Components

1. Create component repository with `config-deploy.toml`
2. Add component parameters to `parameters.toml`
3. Run `refresh` to get deployment scripts
4. Test with `./deploy --dry-run`

### Custom Deployment Patterns

The deployment script can be extended to support additional patterns by:
1. Adding new sections to `config-deploy.toml`
2. Implementing processing functions in `deploy.py`
3. Distributing via refresh mechanism

## Best Practices

### Parameter Design

- Use descriptive parameter names
- Group related parameters under component sections
- Minimize cross-component dependencies
- Document parameter purposes

### Component Development

- Always implement `--dry-run` support
- Provide meaningful verbose output
- Ensure idempotent operations
- Handle errors gracefully

### Testing

- Test with both `--dry-run` and live deployment
- Verify cross-account operations
- Test parameter resolution edge cases
- Validate in multiple AWS regions

## Troubleshooting

### Common Issues

1. **Parameter Resolution Failures**
   - Check parameter exists in `parameters.toml`
   - Verify correct `{reference}` syntax
   - Use `--verbose` to see resolution details

2. **Cross-Account Access Denied**
   - Verify AWS SSO session active
   - Check role exists in target account
   - Confirm role trust relationship

3. **Script Execution Failures**
   - Ensure script has execute permissions
   - Check script parameter expectations
   - Verify component-specific requirements

### Debugging Commands

Common debugging commands include verbose dry-run deployment, AWS identity verification, and component-specific testing.

This architecture enables the OpenSecOps system to maintain consistency across deployments while providing flexibility for different component requirements and deployment patterns.