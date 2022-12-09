# Open Component Model action

This action installs a dedicated version of the OCM tool and executes the
operation specified with the `action` input.
All paths are evaluated relative to the workdir.

## Prerequisites

The `ocm`command line tool must be installed.
This can be done with the action [`open-component-model/ocm-setup-action`](https://github.com/open-component-model/ocm-setup-action).

## Inputs

### `action`

**Required** The action to execute.

Possible actions are

|Action|Meaning|Inputs|
|------|-------|------|
|`create_component`|create a component folder with component descriptor| `directory`, `component`, `version`, `provider` |
|`add_resources`|add resources/references to an already existing or new component| `directory`, `component`, `version`, `provider`, `resources`, `references`, `settigs` |
|`add_component`|add a component to an extisting or new transport archive| `directory`, `ctf` |
|`push_ctf`|push the transport archive. If it does not exist and a component directory is given, the actual component will be used to create the transport archive.| `directory`, `ctf`, `comprepo_url`, `comprepo_user`, `comprepo_password` |

### `directory`

**Optional** Will be defaulted to `gen/ocm/component`, if input is required by action.

The directory to generate the component information

### `component`

**Optional** The component name. If not given the component name is derived from
the source repository.

### `version`

**Optional** The component version.

If not given the `version_cmd` input is checked for a command to execute to derive 
the version. Otherwise the actual tag is checked. If not present the `version_file`
file is checked and appended by the commit id.

### `version_file`

**Optional** The filename used to lookup the actual version. Default `VERSION`.

### `version_cmd`

**Optional** A command called to determine the version of the component to create.

### `provider`

**Required for** `create_component` The provider name.

### `resources`

**Optional** The resource specification file describing the resources to add.
If not specified it checks for `gen/ocm/resources.yaml` and `ocm/resources.yaml`.
With this a previous build step can create this file under the `gen` folder or
the sources provide a static file.

### `references`

**Optional** The reference specification file describing the references to add.
If not specified it checks for `gen/ocm/references.yaml` and `ocm/references.yaml`.
With this a previous build step can create this file under the `gen` folder or
the sources provide a static file.

### `ctf`

**Optional** The file path of a generated transport archive. Default: `gen/ocm/transport.ctf`.

### `comprepo_url`

**Optional for** `push_ctf`. The base URL for the used component repository.
For example `https://ghcr.io/mandelsoft/cnudie`. The default is the sub repo `ocm` of
the organization of the built repository.

### `comprepo_user`

**Optional for** `push_ctf`. The username used to access the component repository.
The default is the owner of the actually built repository.

### `comprepo_password`

**Required for** `push_ctf`. The password used to access the component repository.
The default is the GITHUB_TOKEN environment variable of the actually built repository.
It requires packages write permission.

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
  action: add_resources
```
