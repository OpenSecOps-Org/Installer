# OpenSecOps Installer Architecture

This document describes the operation of the OpenSecOps Installer and its scripts, providing a comprehensive overview of how the deployment system works across Foundation components.

## Overview

The OpenSecOps Installer is a deployment orchestration system that manages the automated deployment of Foundation components across AWS Organizations. It provides a unified deployment interface while supporting multiple deployment patterns (SAM, CloudFormation, Scripts) and handling complex parameter resolution and cross-account operations.

## Core Architecture

### Repository Structure

```
Installer/
├── ARCHITECTURE.md              # This documentation
├── apps/                        # Application configurations
│   ├── accounts.toml            # Account definitions and SSO profiles
│   └── foundation/              # Foundation application parameters
│       └── parameters.toml      # Global parameters for all Foundation components
├── scripts/                     # Core deployment scripts
│   ├── deploy.py               # Main deployment orchestration script
│   ├── refresh.zsh             # Script distribution mechanism
│   └── publish.zsh             # Publication workflow script
└── deploy-all                   # Master deployment script for all Foundation components
```

### Component Integration

Each Foundation component follows a standardized structure:

```
Foundation-component-name/
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

The central `deploy.py` script (`Installer/scripts/deploy.py`) is distributed to all Foundation components via the refresh mechanism. It provides:

1. **Unified Deployment Interface**: Single entry point for all deployment patterns
2. **Parameter Resolution**: Complex parameter substitution and cross-referencing
3. **Cross-Account Operations**: Automated role assumption and multi-account deployments
4. **Multiple Deployment Patterns**: Support for SAM, CloudFormation, and custom scripts

### Parameter System

#### Global Parameters (`Installer/apps/foundation/parameters.toml`)

Defines organization-wide configuration:

```toml
# Global parameters (used across repos)
org-id = 'o-example12345'
root-ou = 'r-example12345'
main-region = 'us-east-1'
other-regions = ['us-west-2', 'eu-west-1']
cross-account-role = "AWSControlTowerExecution"

# Component-specific parameters
[Foundation-component-name.script-name]
parameter1 = 'value1'
parameter2 = '{admin-account}'  # Cross-reference
```

#### Parameter Resolution

The parameter system supports:

1. **Direct Values**: Static strings, numbers, lists
2. **Cross-References**: `{parameter-name}` syntax for referencing other parameters
3. **Account References**: `{admin-account}` resolves to account IDs from `accounts.toml`
4. **Computed Values**: `{all-regions}` dynamically computed from `main-region` + `other-regions`

#### Parameter Processing Flow

```
1. Load global parameters from parameters.toml
2. For each component deployment:
   a. Load component-specific config-deploy.toml
   b. Extract component parameters using script_parameters_to_dictionary()
   c. Resolve all {references} using dereference() function
   d. Pass resolved parameters to deployment mechanism
```

## Deployment Patterns

### 1. SAM Deployments

For serverless applications using AWS SAM:

```toml
[SAM]
profile = "admin-account"
regions = "{all-regions}"
stack-name = "component-stack"
capabilities = "CAPABILITY_IAM"

[SAM.parameters]
Parameter1 = "{org-id}"
Parameter2 = "static-value"
```

**Process:**
1. Build SAM application (`sam build`)
2. Deploy to each specified region
3. Pass resolved parameters as SAM parameter overrides

### 2. CloudFormation Deployments

For infrastructure-as-code using CloudFormation:

```toml
[[CloudFormation]]
name = "stack-name"
template = "template.yaml"
account = "{admin-account}"
regions = "{all-regions}"
capabilities = "CAPABILITY_IAM"

[CloudFormation.stack-name]
Parameter1 = "{org-id}"
Parameter2 = "static-value"
```

**Process:**
1. Read CloudFormation template
2. Create/update stacks or stacksets
3. Monitor deployment progress
4. Handle cross-account operations

### 3. Script Deployments

For custom automation scripts:

```toml
[[Script]]
name = 'setup-security-services'
args = [['--aws-config', '{AWSConfigEnabled}'],
        ['--regions', '{all-regions}'],
        ['--admin-account', '{admin-account}']]

[Script.setup-security-services]
AWSConfigEnabled = 'Yes'
admin-account = '{admin-account}'
all-regions = '{all-regions}'
```

**Process:**
1. Resolve script-specific parameters
2. Build command with resolved arguments
3. Execute script with proper flags (--dry-run, --verbose)

## Key Functions and Algorithms

### Parameter Resolution (`dereference()`)

```python
def dereference(value, params):
    # Handle computed values
    if value == '{all-regions}':
        main_region = params.get('main-region', '')
        other_regions = params.get('other-regions', [])
        return [main_region] + other_regions
    
    # Handle parameter references
    if "{" in value and "}" in value:
        # Substitute {param} with actual values
        return substitute_parameters(value, params)
    
    return value
```

### Script Parameter Processing

```python
def script_parameters_to_dictionary(script_name, params, repo_name):
    section = params[repo_name][script_name]
    result = {}
    for k, v in section.items():
        v = dereference(v, params)
        result[k] = v
    return result
```

### Command Building for Scripts

```python
# Optimized parameter resolution to avoid double-dereference
param_key = v.strip('{}') if v.startswith('{') and v.endswith('}') else None
if param_key and param_key in our_params:
    # Use already-resolved value
    result = our_params[param_key]
else:
    # Fall back to dereference for unresolved parameters
    result = dereference(v, our_params)

# Convert lists to comma-separated strings for script arguments
if isinstance(result, list):
    cmd.append(','.join(result))
else:
    cmd.append(result)
```

## Cross-Account Operations

### Account Management

The `accounts.toml` file defines:

```toml
[admin-account]
id = "111111111111"
profile = "AdminProfile"

[security-account]
id = "222222222222"
profile = "SecurityProfile"
```

### Role Assumption

The deployment system automatically assumes roles for cross-account operations:

```python
def get_client(client_type, account_id, region, role):
    other_session = STS_CLIENT.assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{role}",
        RoleSessionName=f"deploy_{account_id}"
    )
    # Return configured client with assumed role credentials
```

## Script Distribution (`refresh`)

The refresh mechanism ensures all Foundation components have the latest deployment scripts:

1. **Source**: `Installer/scripts/` contains master versions
2. **Distribution**: `refresh` script copies to all Foundation components
3. **Consistency**: Ensures unified deployment behavior across components

### Refresh Process

```bash
# In each Foundation component
./scripts/refresh.zsh
```

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

```bash
./deploy --verbose
```

Provides detailed output:
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

```bash
# Check parameter resolution
./deploy --verbose --dry-run

# Verify AWS access
aws sts get-caller-identity

# Test specific component
cd Foundation-component-name && ./deploy --dry-run
```

This architecture enables the OpenSecOps system to maintain consistency across deployments while providing flexibility for different component requirements and deployment patterns.