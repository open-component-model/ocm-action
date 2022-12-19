#!/bin/bash -e

WORKSPACE="${GITHUB_WORKSPACE:=/usr/local}"
AUTH=/tmp/config

VERSIONFILE=${ocm_versionfile:=VERSION}
REPO="$(git config --get remote.origin.url)"
REPO="${REPO#https://}"

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
  fi
  if ! which ocm >/dev/null; then
    error ocm cli not found
  fi
fi

setOutput()
{
  echo "$1=$@" >> $GITHUB_OUTPUT
}

getVersion()
{
  if [ -n "$ocm_versioncmd" ]; then
    echo "determining component version with version command: $ocm_versioncmd"
    ocm_componentversion="$($ocm_versioncmd)"
  else
    if [ -n "$ocm_componentversion" -a -f "$ocm_componentversion"  ]; then
      VERSIONFILE="$ocm_componentversion"
      ocm_componentversion=
    fi
    if [ -z "$ocm_componentversion" ]; then
      if [ -x hack/component_version ]; then
        echo "determining component version with version command: hack/component_version"
        ocm_componentversion="$(hack/component_version)"
      else
        versions=( $(git tag --points-at HEAD) )
        echo found tags ${versions[@]}
        if [ ${#versions} -gt 0 ]; then
          echo "determining component version using git tags"
          ocm_componentversion="${versions[0]}"
        else
          if [ -f "$VERSIONFILE" ]; then
            echo "using component version from $VERSIONFILE file"
            ocm_componentversion="$(cat "$VERSIONFILE")-$(git rev-parse --short HEAD)"
          fi
        fi
      fi
    fi
  fi
  if [ -z "$ocm_componentversion" ]; then
    error no component version found
  fi
}

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

if [ -z "$ocm_ctf" ]; then
  ocm_ctf="gen/ocm/transport.ctf"
fi
if [ -z "$ocm_componentdir" ]; then
  ocm_componentdir="gen/ocm/component"
fi

echo "WORKSPACE:     $WORKSPACE"
echo "REPO:          $REPO"
echo "ACTION:        $1"
echo "COMPONENT_DIR: $ocm_componentdir"
echo "COMPONENT:     $ocm_component"
echo "PROVIDER:      $ocm_provider"
echo "DESCRIPTOR:    $ocm_descriptor"
echo "VERSION_CMD:   $ocm_versioncmd"
echo "VERSION:       $ocm_componentversion"
echo "TEMPLATER:     $ocm_templater"
echo "RESOURCES:     $ocm_resources"
echo "CTF:           $ocm_ctf"
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
  if [ -z "$ocm_component" ]; then
    ocm_component="$REPO"
  fi
  mkdir -p "$(dirname "$ocm_componentdir")"
  getVersion
  if [ -z "$ocm_component" ]; then
    ocm_component="$REPO"
  fi
  echo "Creating component archive for $ocm_component version $ocm_componentversion"
  echo "$OCM create ca --file $ocm_componentdir $ocm_component $ocm_componentversion --provider $ocm_provider"
  $OCM create ca --file "$ocm_componentdir" "$ocm_component" $ocm_componentversion --provider "$ocm_provider"

  cat >/tmp/sources <<EOF
name: 'project'
type: 'filesystem'
access:
  type: "gitHub"
  repoUrl: $REPO
  commit: $(git rev-parse HEAD)
version: $ocm_componentversion
EOF
  $OCM add sources "$ocm_componentdir" /tmp/sources
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

addResources()
{
  if [ ! -e "$ocm_componentdir" ]; then
    echo "Dir $ocm_componentdir not found creating component"
    createComponent
  fi
  if [ -z "$ocm_resources" ]; then
    if [ -f "gen/ocm/resources.yaml" ]; then
      ocm_resources=gen/ocm/resources.yaml
    else
      if [ -f "ocm/resources.yaml" ]; then
        ocm_resources=ocm/resources.yaml
      fi
    fi
  fi
  if [ -z "$ocm_references" ]; then
    if [ -f "gen/ocm/references.yaml" ]; then
      ocm_references=gen/ocm/references.yaml
    else
      if [ -f "ocm/resources.yaml" ]; then
        ocm_references=ocm/references.yaml
      fi
    fi
  fi
  if [ -z "$ocm_settings" ]; then
    if [ -f gen/ocm/settings.yaml ]; then
      ocm_settings=gen/ocm/settings.yaml
    else
      if [ -f "ocm/settings.yaml" ]; then
        ocm_settings=ocm/settings.yaml
      fi
    fi
  fi
  settings=( )
  if [ -n "$ocm_var_values" ]; then
    if [ -n "$ocm_settings" ]; then
      error "Use either settings or ocm_values but not both"
    fi
    echo "${ocm_var_values}" > gen/ocm/settings.yaml
    settings=( --settings "gen/ocm/settings.yaml" )
    echo "Variables used for templating:"
    cat gen/ocm/settings.yaml
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
  if [ -z "$ocm_resources" -a -z "$ocm_references" ]; then
    error "no resources.yaml or references.yaml found"
  fi
  if [ -n "$ocm_resources" ]; then
    if [ ! -f "$ocm_resources" ]; then
      error "$ocm_resources not found"
    fi
    echo $OCM add resources "$ocm_componentdir" "${settings[@]}" "${templater[@]}" VERSION="$ocm_componentversion" NAME="$ocm_component" "$ocm_resources"
    $OCM add resources "$ocm_componentdir" "${settings[@]}"  "${templater[@]}" VERSION="$ocm_componentversion" NAME="$ocm_component" "$ocm_resources"
  fi
  if [ -n "$ocm_references" ]; then
    if [ ! -f "$ocm_references" ]; then
      error "$ocm_references not found"
    fi
    echo $OCM add references "$ocm_componentdir" "${settings[@]}" "${templater[@]}" VERSION="$ocm_componentversion" NAME="$ocm_component" "$ocm_references"
    $OCM add references "$ocm_componentdir" "${settings[@]}" "${templater[@]}" VERSION="$ocm_componentversion" NAME="$ocm_component" "$ocm_references"
  fi
}

addComponent()
{
  if [ ! -d "$ocm_componentdir" ]; then
    echo "Dir $ocm_componentdir not found adding resources"
    addResources
  fi
  echo "Transfer CA to CTF"
  mkdir -p "$(dirname "$ocm_ctf")"
  $OCM transfer ca "$ocm_componentdir" "$ocm_ctf"
  echo "Transport Archive is $ocm_ctf"
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
  echo $OCM "${creds[@]}" transfer ctf "$ocm_ctf" "$ocm_comprepo"
  $OCM "${creds[@]}" transfer ctf "$ocm_ctf" "$ocm_comprepo"
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
