#!/bin/bash -e

WORKSPACE="${GITHUB_WORKSPACE:=/usr/local}"
GEN="${ocm_gen:=gen/ocm}"
AUTH=/tmp/config

VERSIONFILE=${ocm_versionfile:=VERSION}
REPO="$(git config --get remote.origin.url)"
REPO="${REPO#https://}"
REPO="${REPO#git@}"
REPO="${REPO%.git}"
REPO="${REPO/://}"

if [ -z "$GITHUB_OUTPUT" ]; then
  GITHUB_OUTPUT=".out"
fi

error()
{
  echo Error: "$@" >&2
  exit 1
}

if [ -x bin/ocm ]; then
  OCM=bin/ocm
else
  if [ -x "/usr/local/bin/ocm" ]; then
    OCM="/usr/local/bin/ocm"
  else
    if ! which ocm >/dev/null; then
      error ocm cli not found
    fi
    OCM=ocm
  fi
fi

execute()
{
  echo "executing: $@"
  "$@"
}

setOutput()
{
  echo "$1=$@" >> $GITHUB_OUTPUT
}

if [ -n "$ocm_versioncmd" ]; then
  echo "determining component version with version command: $ocm_versioncmd"
  ocm_componentversion="$($ocm_versioncmd)"
  def_componentversion=" (from version command)"
else
  if [ -n "$ocm_componentversion" -a -f "$ocm_componentversion"  ]; then
    VERSIONFILE="$ocm_componentversion"
    ocm_componentversion=
  fi
  if [ -z "$ocm_componentversion" ]; then
    if [ -x hack/component_version ]; then
      echo "determining component version with version command: hack/component_version"
      ocm_componentversion="$(hack/component_version)"
      def_componentversion=" (from command hack/component_version)"
    else
      versions=( $(git tag --points-at HEAD) )
      echo found tags ${versions[@]}
      if [ ${#versions} -gt 0 ]; then
        echo "determining component version using git tags"
        ocm_componentversion="${versions[0]}"
        def_componentversion=" (defaulted by git tag)"
      else
        if [ -f "$VERSIONFILE" ]; then
          echo "using component version from $VERSIONFILE file"
          ocm_componentversion="$(cat "$VERSIONFILE")-$(git rev-parse --short HEAD)"
          def_componentversion=" (from version file $VERSIONFILE)"
        fi
      fi
    fi
  fi
fi

creds=( )
createAuth()
{
  echo "createAuth()"
  if [ -z "$ocm_comprepo" ]; then
    ocm_comprepo="ghcr.io/$GITHUB_REPOSITORY_OWNER/ocm"
  fi
  if [ -z "$ocm_comprepouser" ]; then
    if [ "${ocm_comprepo#ghcr.io/}" = "$ocm_comprepouser" ]; then
      error "component repository user required"
    fi
    ocm_comprepouser=$GITHUB_REPOSITORY_OWNER
  fi
  if [ -z "$ocm_comprepopassword" ]; then
    if [ "${ocm_comprepo#ghcr.io/}" = "$ocm_comprepouser" ]; then
      error "component repository password required"
    fi
    ocm_comprepopassword="$GITHUB_TOKEN"
  fi
  comprepourl="${ocm_comprepo#*//}"
  repohost="${comprepourl%%/*}"
  comprepourl="${ocm_comprepo%$comprepourl}${comprepourl%%/*}"
  echo "Credential args repohost: $repohost, username: $username"
  creds=( --cred :type=OCIRegistry --cred ":hostname=$repohost" --cred "username=$ocm_comprepouser" --cred "password=$ocm_comprepopassword" )
}

def_ctf=
def_componentdir=
def_component=
if [ -z "$ocm_ctf" ]; then
  ocm_ctf="$GEN/transport.ctf"
  def_ctf=" (defaulted)"
fi
if [ -z "$ocm_componentdir" ]; then
  ocm_componentdir="$GEN/component"
  def_componentdir=" (defaulted)"
fi
if [ -z "$ocm_component" ]; then
  ocm_component="$REPO"
  def_component=" (defaulted from repository)"
fi

echo "WORKSPACE:     $WORKSPACE"
echo "REPO:          $REPO"
echo "ACTION:        $1"
echo "GENDIR:        $GEN"
echo "COMPONENT:     $ocm_component$def_component"
echo "PROVIDER:      $ocm_provider"
echo "DESCRIPTOR:    $ocm_descriptor"
echo "VERSION_CMD:   $ocm_versioncmd"
echo "VERSION:       $ocm_componentversion$def_componentversion"
echo "TEMPLATER:     $ocm_templater"
echo "RESOURCES:     $ocm_resources"
echo "COMPONENTS:    $ocm_components"
echo "TEMPLATER:     $ocm_templater"
echo "COMPONENT_DIR: $ocm_componentdir$def_componentdir"
echo "CTF:           $ocm_ctf$def_ctf"
echo "COMPREPO:      $ocm_comprepo"
echo "COMPREPO_USER: $ocm_comprepouser"
if [ -n "$ocm_comprepopassword" ]; then
  echo "::add-mask::$ocm_comprepopassword"
fi
echo "COMPREPO_PASS: $ocm_comprepopassword"

createComponent()
{
  if [ -z "$ocm_provider" ]; then
    error provider required
  fi
  if [ -z "$ocm_componentversion" ]; then
    error no component version found
  fi
  mkdir -p "$(dirname "$ocm_componentdir")"
  echo "Creating component archive for $ocm_component version $ocm_componentversion"
  execute $OCM create ca --file "$ocm_componentdir" "$ocm_component" $ocm_componentversion --provider "$ocm_provider"

  cat >/tmp/sources <<EOF
name: 'project'
type: 'filesystem'
access:
  type: "gitHub"
  repoUrl: $REPO
  commit: $(git rev-parse HEAD)
version: $ocm_componentversion
EOF
  execute $OCM add sources "$ocm_componentdir" /tmp/sources
}

printDescriptor()
{
  echo "Component Descriptor:"
  cat "$ocm_componentdir/component-descriptor.yaml"
  echo "Component name $ocm_component"
  setOutput component-name "$ocm_component"
  setOutput component-version "$ocm_componentversion"
  setOutput component-path "$ocm_componentdir"
}

prepareSettings()
{
  if [ -z "$ocm_settings" ]; then
    if [ -f "$GEN/settings.yaml" ]; then
      ocm_settings="$GEN/settings.yaml"
    else
      if [ -f "ocm/settings.yaml" ]; then
        ocm_settings=ocm/settings.yaml
      fi
    fi
  fi
  settings=( VERSION="$ocm_componentversion" NAME="$ocm_component" )
  if [ -n "$ocm_var_values" ]; then
    if [ -n "$ocm_settings" ]; then
      error "Use either settings or ocm_values but not both"
    fi
    echo "${ocm_var_values}" > "$GEN/settings.yaml"
    settings=( --settings "$GEN/settings.yaml" )
    echo "Variables used for templating:"
    cat "$GEN/settings.yaml"
  else
    if [ -n "$ocm_settings" ]; then
      if [ ! -f "$ocm_settings" ]; then
        error settings file "$ocm_settings" not found
      fi
      settings=( --settings "$ocm_settings" )
    fi
  fi

  templater=( )
  if [ -n "$ocm_templater" ]; then
    templater=( --templater "$ocm_templater" )
  fi
}

addResources()
{
  if [ ! -e "$ocm_componentdir" ]; then
    echo "Dir $ocm_componentdir not found creating component"
    createComponent
  fi
  if [ -z "$ocm_resources" ]; then
    if [ -f "$GEN/resources.yaml" ]; then
      ocm_resources="$GEN/resources.yaml"
    else
      if [ -f "ocm/resources.yaml" ]; then
        ocm_resources=ocm/resources.yaml
      fi
    fi
  fi
  if [ -z "$ocm_references" ]; then
    if [ -f "$GEN/references.yaml" ]; then
      ocm_references="$GEN/references.yaml"
    else
      if [ -f "ocm/resources.yaml" ]; then
        ocm_references=ocm/references.yaml
      fi
    fi
  fi
  prepareSettings
  if [ -z "$ocm_resources" -a -z "$ocm_references" ]; then
    error "no resources.yaml or references.yaml found"
  fi
  if [ -n "$ocm_resources" ]; then
    if [ ! -f "$ocm_resources" ]; then
      error "$ocm_resources not found"
    fi
    execute $OCM add resources "$ocm_componentdir" "${settings[@]}"  "${templater[@]}" "$ocm_resources"
  fi
  if [ -n "$ocm_references" ]; then
    if [ ! -f "$ocm_references" ]; then
      error "$ocm_references not found"
    fi
    execute $OCM add references "$ocm_componentdir" "${settings[@]}" "${templater[@]}" "$ocm_references"
  fi
}

addComponent()
{
  if [ -z "$ocm_components"  -a ! -d "$ocm_componentdir" ]; then
    # check for implicit components.yaml
    if [ -f "$GEN/components.yaml" ]; then
      ocm_components="$GEN/components.yaml"
    else
      if [ -f "ocm/components.yaml" ]; then
        ocm_components=ocm/components.yaml
      fi
    fi
  fi

  if [ -z "$ocm_components" ]; then
    echo "No component specification found: adding component by component archive $ocm_componentdir"
    # if no component specifications are found try to use component archive
    if [ ! -d "$ocm_componentdir" ]; then
      echo "Dir $ocm_componentdir not found: adding resources"
      addResources
    fi
    echo "Transfer CA to CTF"
    mkdir -p "$(dirname "$ocm_ctf")"
    execute $OCM transfer ca "$ocm_componentdir" "$ocm_ctf"
    echo "Transport Archive is $ocm_ctf"
  else
    echo "Adding component versions from $ocm_components" to CTF
    prepareSettings
    if [ ! -f "$ocm_components" ]; then
      error "$ocm_components not found"
    fi
    flags=""
    if [ -n "$ocm_cleanup" ]; then
      flags="f"
    fi
    if [ ! -e "$ocm_ctf" ]; then
      flags="c"
    fi
    if [ -n "$flags" ]; then
      flags="-$flags"
    fi
    mkdir -p "$(dirname "$ocm_ctf")"
    execute $OCM add components $flags --file "$ocm_ctf" "${settings[@]}"  "${templater[@]}" "$ocm_components"
  fi
  setOutput transport-archive "$ocm_ctf"
}

pushCTF()
{
  echo "pushCTF with ocm_ctf: ${ocm_ctf} and ${ocm_componentdir}"
  createAuth
  if [ ! -d "$ocm_ctf" ]; then
    addComponent
  fi
  echo "Transport Archive is $ocm_ctf"
  echo "Component Repository is $ocm_comprepo"
  execute $OCM "${creds[@]}" transfer ctf "$ocm_ctf" "$ocm_comprepo"
  setOutput transport-archive "$ocm_ctf"
}

case "$1" in
  create_component)
      createComponent
      printDescriptor;;
  add_resources)
      addResources
      printDescriptor;;
  add_component)
     addComponent;;
  push_ctf)
      pushCTF;;
  *)  error "invalid command $1";;
esac
