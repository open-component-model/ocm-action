# Open Component Model action

[![REUSE status](https://api.reuse.software/badge/github.com/open-component-model/ocm-action)](https://api.reuse.software/info/github.com/open-component-model/ocm-action)


This action installs a dedicated version of the OCM tool and executes the
operation specified with the `action` input.
All paths are evaluated relative to the workdir.

## Inputs

### `tool-version`

**Optional** The tool verson to install. Default `"v0.1.0-alpha.1"`.

### `tool-repo`

**Optional** The tool repository to install from. Default `"gardener/component-cli"`.

### `action`

**Required** The action to execute.

Possible actions are

|Action|Meaning|Inputs|
|------|-------|------|
|`create_component`|create a component folder with component descriptor| `directory`, `component`, `version`, `descriptor` |
|`add_resources`|add resources to an already existing or new component| `directory`, `component`, `version`, `descriptor`, `resources` |
|`add_component`|add a component to an extisting or new transport archive| `directory`, `ctf` |
|`push_ctf`|push the transport archive. If it does not exist, yet, or a component directory is given, the actual component will be used to create the transport archive.| `directory`, `ctf`, `comprepo_url`, `comprepo_user`, `comprepo_password` |

### `directory`

**Optional** Will be defaulted by `gen/ocm/component`, if input is required by action.

The directory to generate the component information

### `descriptor`

**Optional** The inital component descriptor to use.

If not specified it checks for a file `ocm/component-descriptor.yaml`.

### `component`

**Optional** The component name.

If a descriptor is specified the component name can be specified there.
If not given the repository based component identity is used.

### `version`

**Optional** The component version.

If not given the `version_cmd` input is checked for a command to execute to derive
the version. Otherwise the actual tag is checked. If not present the `version_file`
file ic checked and appended by the commit id.

### `version_file`

**Optional** The filename used to lookup the actual version. Default `VERSION`.

### `version_cmd`

**Optional** A command called to determine the version of the component to create.

### `resources`

**Optional** The resource specification file describing the resources to add.
If not specified it checks for `gen/ocm/resources.yaml` and `ocm/resources.yaml`.

### `ctf`

**Optional** The file path of a generated transport archive. Default: `gen/ocm/transport.ctf`.

### `comprepo_url`

**Required for** `push_ctf`. The base URL for the used component repository.
For example `https://ghcr.io/mandelsoft/cnudie`.

### `comprepo_user`

**Required for** `push_ctf`. The username used to access the component repository.

### `comprepo_password`

**Required for** `push_ctf`. The password used to access the component repository.

## Outputs

### `component-name`

The (optional) effective component name.

### `component-version`

The (optional) effective component version.

### `component-path`

The (optional) workspace relative path of the generated component directory.

### `transport-archive`

The (optional) workspace relative path of the generated transport archive

## Example usage

```
uses: open-component-model/ocm-action@main
with:
  tool-version: v0.1.0-alpha.1
  action: add_resources
```

## Licensing

Copyright 2022 SAP SE or an SAP affiliate company and Open Component Model contributors.
Please see our [LICENSE](LICENSE) for copyright and license information.
Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/open-component-model/ocm-action).
