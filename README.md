# Open Component Model action

[![REUSE status](https://api.reuse.software/badge/github.com/open-component-model/ocm-action)](https://api.reuse.software/info/github.com/open-component-model/ocm-action)


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
|`add_resources`|add resources/references to an already existing or new component| `directory`, `component`, `version`, `provider`, `resources`, `references`, `templater`, `settings`, `var_values` |
|`add_component`|add component(s) to an extisting or new transport archive| `directory`, `ctf`, `components`, `templater`, `settings`, `var_values` |
|`push_ctf`|push the transport archive. If it does not exist and a component directory is given, the actual component will be used to create the transport archive.| `directory`, `ctf`, `comprepo_url`, `comprepo_user`, `comprepo_password` |

### `gen` (default `gen/ocm`)

The generation folder to use. The folder is created if not present. THis folder is used for all commands.

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

### `components`

**Optional** The component specification file describing the compoenents to add.
If not specified it checks for `gen/ocm/components.yaml` and `ocm/components.yaml`.
With this a previous build step can create this file under the `gen` folder or
the sources provide a static file.

### `ctf`

**Optional** The file path of a generated transport archive. Default: `gen/ocm/transport.ctf`.

### `comprepo_url`

**Optional for** `push_ctf`. The base URL for the used component repository.
For example `ghcr.io/mandelsoft/ocm`. The default is the sub repo `ocm` of
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

### `provider`

The optional provider of the component. Required for create action otherwise ignored

### `templater`

Templater engine used to expand components, resources and references (spiff, go or subst) optional

### `settings`

Path to a file containing the variable values when expanding template variables. yaml file
with syntax:

```yaml
MY_VAR: my_value
MY_OTHER_VAR: my_value_2
```

Use eiher `settings` or `var_values`.

### `var_values`

variable values when expanding template variables (optional yaml syntax).
Use eiher `settings` or `var_values`.

Example:

```
...
- name: add OCM resources
  uses: open-component-model/ocm-action
  with:
    action: add_resources
    var_values: |
      MULTI: true
      IMAGE: ghcr.io/acme/simpleserver:${{ env.VERSION }}
      PLATFORMS: "linux/amd64 linux/arm64"
    ...
```

## Commands

### `create_component`

This commands creates a component archive, which can be enriched later by resources or references.
Alternatively, components can be completely described by a component specifivarion file (`components`)
and added directly to a transport archive with `add_components`.

### `add_resources`

This command can be used to add resources and/or references to a component archive.
The component version composed this way can then be added to a transport archive with `add_component`.
Alternatively, components can be completely described by a component specifivarion file (`components`)
and added directly to a transport archive with `add_components`.

It uses a resources specification file (`resources`) and a references specification file (`references`).
If no such option is given it looks for standard specification files (`ocm/resources.yaml`, `gen/ocm/resources.yaml`,
`ocm/references.yaml` and `gen/ocm/references.yaml`). 
If no component archive is specified (`directory`), it tries to use the default (`gen/ocm/component`),
if this is not present, also, it tries to create it with `create_component`.

An optional templater (`templater`) can be used to process the specification files prior to evaluation.
In this case the value settings are used ( `settings`or `var_values`).

Standard values always provided:
- **`VERSION`**: the specified or calculated version 
- **`NAME`**: the specified or calculated component name. The default name is derived from the source repository. 

### `add_component`

This command can be used to create a transport archive and to add component versions. This could 
either be a previously created component archive (`directory`) or the components are taken from
a description file (`components`).

If no source is specified it looks for defaulr descriptions in `gen/ocm/components.yaml` or `ocm/components.yaml`. 
If no such description is found. It tries to use `add_resources`.

An optional templater (`tenmplater`) can be used to process the specification file prior to evaluation.
In this case the value settings are used ( `settings`or `var_values`).

### `push_ctf`

This command can be used to push the generated transport archive to an OCM repository. The default repoitory
is the github OCI repository with the package name `<github org>/ocm`.

## Example usage

The following example assumes a project with a dockerfile building images for two different platforms.
It uses the `buildx` plugin and the `ocm-action` plugin to create and upload a component-version and
attach the common-tansport-archive as build artifact.

```
name: build-and-ocm
# trigger manually
run-name: Build image and create component version
on:
  workflow_dispatch:
env:
  VERSION: "1.0.0"
  COMP_NAME: acme.org/simpleserver
  PROVIDER: github.com/acme
jobs:
  build-and-create-ocm:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repo
        uses: actions/checkout@v3
      - name: setup OCM
        uses: open-component-model/ocm-setup-action@main
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v2
      - name: Set up Docker Context for Buildx
        id: buildx-context
        run: |
          docker context create builders
      - name: Set up Docker Buildx
        timeout-minutes: 5
        uses: docker/setup-buildx-action@v2
        with:
          version: latest
      - name: Build amd64
        id: build_amd64
        uses: docker/build-push-action@v3
        with:
          push: false
          load: true
          platforms: linux/amd64
          tags: ghcr.io/acme/simpleserver:${{ env.VERSION }}-linux-amd64
      - name: Build arm64
        id: build_arm64
        uses: docker/build-push-action@v3
        with:
          push: false
          load: true
          platforms: linux/arm64
          tags: ghcr.io/acme/simpleserver:${{ env.VERSION }}-linux-arm64
      - name: create OCM component version
        uses: open-component-model/ocm-action@main
        with:
          action: create_component
          component: ${{ env.COMP_NAME }}
          provider: ${{ env.PROVIDER }}
          version: ${{ env.VERSION }}
      - name: add OCM resources
        uses: open-component-model/ocm-action@main
        with:
          action: add_resources
          component: ${{ env.COMP_NAME }}
          resources: resources.yaml
          templater: spiff
          version: ${{ env.VERSION }}
          var_values: |
            MULTI: true
            IMAGE: ghcr.io/acme/simpleserver:${{ env.VERSION }}
            PLATFORMS: "linux/amd64 linux/arm64"
      - name: create OCM transport archive
        uses: open-component-model/ocm-action@main
        with:
          action: add_component
          ctf: gen/ctf
      - name: Upload transport archive
        uses: actions/upload-artifact@v3
        with:
          name: ocm-simpleserver-ctf.zip
          path: |
            gen/ctf

```

## Licensing

Copyright 2022 SAP SE or an SAP affiliate company and Open Component Model contributors.
Please see our [LICENSE](LICENSE) for copyright and license information.
Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/open-component-model/ocm-action).
