# Open Component Model action

[![REUSE status](https://api.reuse.software/badge/github.com/open-component-model/ocm-action)](https://api.reuse.software/info/github.com/open-component-model/ocm-action)


This action installs the OCM tool and executes the operation specified with the `action` input. All paths are evaluated relative to the workdir.

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
|`push_ctf`|push the transport archive. If it does not exist and a component directory is given, the actual component will be used to create the transport archive.| `directory`, `ctf`, `comprepo_url`, `force_push`, `comprepo_user`, `comprepo_password` |

### `gen` (default `gen/ocm`)

The generation folder to use. The folder is created if not present. This folder is used for all commands.

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

### `force_push`

**Optional for** `push_ctf`. Set to `true` to allow overwriting existing versions. If not set and
the component exists the transfer will be skipped. Use this option carefully (mostly during
development).

### `comprepo_password`

**Required for** `push_ctf`. The password used to access the component repository.
For publishing to the github packages of the org of the current repository set this to
`${{ secrets.GITHUB_TOKEN }}`. It requires packages write permission.

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

Template engine used to expand components, resources and references (spiff, go or subst) optional

### `settings`

Path to a file containing the variable values when expanding template variables (yaml syntax). Use eiher `settings` or `var_values`.

Example:

```yaml
MY_VAR: my_value
MY_OTHER_VAR: my_value_2
```

### `var_values`

variable values when expanding template variables (optional yaml syntax).
Use eiher `settings` or `var_values`.

Example:

```yaml
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

This commands creates a component archive, which can be enriched later by resources and references.
Alternatively, components can be completely described by a component specification file (`components`)
and added directly to a transport archive with `add_components`.

### `add_resources`

This command can be used to add resources and/or references to a component archive.
The component version composed this way can then be added to a transport archive with `add_component`.
Alternatively, components can be completely described by a component specification file (`components`)
and added directly to a transport archive with `add_components`.

It uses a resources specification file (`resources`) and a references specification file (`references`).
If no such option is given it looks for standard specification files (`ocm/resources.yaml`, `gen/ocm/resources.yaml`,
`ocm/references.yaml` and `gen/ocm/references.yaml`).
If no component archive is specified (`directory`), it tries to use the default (`gen/ocm/component`),
if this is also not present it tries to create it with `create_component`.

An optional templater (`templater`) can be used to process the specification files prior to evaluation.
In this case the value settings are used (`settings` or `var_values`).

Standard values always provided:
- **`VERSION`**: the specified or calculated version
- **`NAME`**: the specified or calculated component name. The default name is derived from the source repository.

### `add_component`

This command can be used to create a transport archive and to add component versions. This could
either be a previously created component archive (`directory`) or the components are taken from
a description file (`components`).

If no source is specified it looks for default descriptions in `gen/ocm/components.yaml` or `ocm/components.yaml`.
If no such description is found. It tries to use `add_resources`.

An optional templater (`templater`) can be used to process the specification file prior to evaluation.
In this case the value settings are used (`settings` or `var_values`).

### `push_ctf`

This command can be used to push the generated transport archive to an OCM repository. The default repository
is the github OCI repository with the package name `<github org>/ocm`.

## Example usage

### Using resources.yaml

The following example assumes a project with a dockerfile building images for two different platforms. It uses the `buildx` plugin and the `ocm-action` plugin to create and upload a component-version and attach the common-tansport-archive as build artifact. The version number of the component is taken from a file named `VERSION`.

Note that docker is used two build single platform images and ocm is used to build and push a multi-platform image from the single-platform images. The `create-component` action will automatically add a `source` element to the component descriptor referring to the current github repository.

`resources.yaml`:

```yaml
---
name: chart
type: helmChart
input:
  type: helm
  path: helmchart
---
name: image
type: ociImage
version: ${VERSION}
input:
  type: "dockermulti"
  repository: ${IMAGE}
  variants: ${VARIANTS}
```

Github action:

```yaml
name: ocm-resources
run-name: Build component version using resources.yaml
  workflow_dispatch:
env:
  COMP_NAME: acme.org/simpleserver
  PROVIDER: github.com/acme
  CD_REPO: ghcr.io/acme/ocm
  OCI_URL: ghcr.io/acme
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
      - name: Get version from file
        run: |
          version=`cat VERSION`
          echo "VERSION=$version" >> $GITHUB_ENV
          echo "Using version: $version"
      - name: Build amd64
        id: build_amd64
        uses: docker/build-push-action@v3
        with:
          push: false
          load: true
          platforms: linux/amd64
          tags: ${{ env.OCI_URL }}/${{ env.COMP_NAME }}:${{ env.VERSION }}-linux-amd64
      - name: Build arm64
        id: build_arm64
        uses: docker/build-push-action@v3
        with:
          push: false
          load: true
          platforms: linux/arm64
          tags: ${{ env.OCI_URL }}/${{ env.COMP_NAME }}:${{ env.VERSION }}-linux-arm64
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
          version: ${{ env.VERSION }}
          # Note below that you have to use double quotes for the VARIANTS value.
          var_values: |
            IMAGE: ${{ env.OCI_URL }}/${{ env.COMP_NAME }}
            VARIANTS: "['${{ env.OCI_URL }}/${{ env.COMP_NAME }}:${{ env.VERSION }}-linux-amd64', '${{ env.OCI_URL }}/${{ env.COMP_NAME }}:${{ env.VERSION }}-linux-arm64']"
      - name: create OCM transport archive
        uses: open-component-model/ocm-action@main
        with:
          action: add_component
      - name: push OCM transport archive
        uses: open-component-model/ocm-action@main
        with:
          action: push_ctf
          # Warning: use force_push only for development (overwrites existing components)!
          force_push: true
          comprepo_password: ${{ secrets.GITHUB_TOKEN }}
          comprepo_url: ${{ env.CD_REPO }}
      - name: Upload transport archive
        uses: actions/upload-artifact@v3
        with:
          name: ocm-simpleserver-ctf.zip
          path: |
            gen/ocm/ctf
```

### Using components.yaml

The following example assumes a project with a dockerfile building images for two different platforms. It uses the `buildx` plugin build and push the image to an OCI registry. It uses the `ocm-action` plugin to create and upload a component-version and attach the common-tansport-archive as build artifact. The version number of the component is taken from a file named `VERSION`.

The file `component.yaml` contains all the information needed to create the component-descriptor. The `add_component` action will not automatically add a `source` element to the component descriptor. You have to provide the `source` element yourself if needed.

`components.yaml`:

```yaml
components:
- name: ${COMP_NAME}
  version: ${VERSION}
  provider:
    name: ${PROVIDER}
  sources:
  - name: source
    type: filesystem
    version: ${VERSION}
    access:
      type: gitHub
      repoUrl: ${REPO_URL}
      commit: ${COMMIT}
  resources:
  - name: chart
    type: helmChart
    input:
      type: helm
      path: helmchart
  - name: ocm-image
    type: ociImage
    version: ${VERSION}
    access:
      type: ociArtifact
      imageReference: ${IMAGE}:${VERSION}
```

Github action:

```yaml
name: ocm-components
run-name: Build component version using component.yaml
on:
  workflow_dispatch:
env:
  COMP_NAME: acme.org/simpleserver
  PROVIDER: github.com/acme
  CD_REPO: ghcr.io/acme/ocm
  OCI_URL: ghcr.io/acme
jobs:
  build-and-create-ocm:
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - name: Check out the repo
        uses: actions/checkout@v3
      # setup workflow to use the OCM github action:
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
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Get version from file
        run: |
          version=`cat VERSION`
          echo "VERSION=$version" >> $GITHUB_ENV
          echo "Using version: $version"
      - name: Build amd64 and arm64
        id: build_amd64
        uses: docker/build-push-action@v3
        with:
          push: true
          platforms: linux/amd64,linux/arm64
          tags: ${{ env.OCI_URL }}/${{ env.COMP_NAME }}:${{ env.VERSION }}
      # Create a common transport format (CTF) archive including the component descriptor:
      - name: create OCM CTF
        uses: open-component-model/ocm-action@main
        with:
          action: add_component
          components: components.yaml
          directory: .
          version: ${{ env.VERSION }}
          var_values: |
            COMMIT: ${{ github.sha }}
            COMP_NAME: ${{ env.COMP_NAME }}
            IMAGE: ${{ env.OCI_URL }}/${{ env.COMP_NAME }}
            PROVIDER: ${{ env.PROVIDER }}
            REPO_URL: ${{ github.server_url }}/${{ github.repository }}
            VERSION: ${{ env.VERSION}}
      # Optional: push the component to an OCI registry
      - name: push CTF
        uses: open-component-model/ocm-action@main
        with:
          action: push_ctf
          comprepo_url: ${{ env.CD_REPO}}
          # Warning: use force_push only for development (overwrites existing components)!
          force_push: true
          comprepo_password: ${{ secrets.GITHUB_TOKEN }}
      # Optional: attach the common transport format archive to the workflow run
      - name: Upload transport archive
        uses: actions/upload-artifact@v3
        with:
          name: ocm-simpleserver-ctf.zip
          path: |
            gen/ocm/ctf
```

## Licensing

Copyright 2022-2023 SAP SE or an SAP affiliate company and Open Component Model contributors.
Please see our [LICENSE](LICENSE) for copyright and license information.
Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/open-component-model/ocm-action).
