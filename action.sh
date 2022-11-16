#!/bin/bash -e

WORKSPACE="${GITHUB_WORKSPACE:=/usr/local}"
WORKSPACE="/usr/local"
TOOLVERSION=${tool_version:=v0.1.0-alpha.1}
TOOLREPO=${tool_repo:=open-component-model/ocm}
URL=https://github.com/$TOOLREPO/releases/download
PLATFORM=linux-amd64
if [ "$REPO" != "gardener/component-cli" ]; then
  ARCHIVESUFFIX=.tgz
  ARCHIVEFILE="ocm-$PLATFORM$ARCHIVESUFFIX"
else
  ARCHIVESUFFIX=.gz
  ARCHIVEFILE="componentcli-$PLATFORM$ARCHIVESUFFIX"
fi
FILE="$(basename "$ARCHIVEFILE" $ARCHIVESUFFIX)"


FILE="$(basename "$ARCHIVEFILE" .gz)"
OCM="/tmp/$FILE"
AUTH=/tmp/config

VERSIONFILE=${ocm_versionfile:=VERSION}
REPO="$(git config --get remote.origin.url)"
REPO="${REPO#https://}"

error()
{
  echo Error: "$@" >&2
  exit 1
}

install()
{( 
  cd /tmp
  echo "Install Open Component Model Tool version $VERSION"
  rm -f "$ARCHIVEFILE"
  wget -q "$URL/$TOOLVERSION/$ARCHIVEFILE"
  if [ "$ARCHIVESUFFIX" = .tgz ]; then
    tar -xzf "$ARCHIVEFILE"
  else
    gunzip -f "$ARCHIVEFILE"
  fi
)}

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
            echo "taking component version from $VERSIONFILE file"
            ocm_componentversion="$(cat "$VERSIONFILE")-snapshot-$(git rev-parse --short HEAD)"
          fi
        fi
      fi
    fi
  fi
  if [ -z "$ocm_componentversion" ]; then
    error no component version found
  fi
}

createAuth()
{
  if [ -z "$ocm_comprepo" ]; then
    error "component repository required"
  fi
  if [ -z "$ocm_comprepouser" ]; then
    error "component repository user required"
  fi
  if [ -z "$ocm_comprepopassword" ]; then
    error "component repository password required"
  fi
  comprepourl="${ocm_comprepo#*//}"
  comprepourl="${ocm_comprepo%$comprepourl}${comprepourl%%/*}"

  cat >$AUTH <<EOF
{
        "auths": {
                "$comprepourl": {
                        "auth": "$(base64 <<<"$ocm_comprepouser:$ocm_comprepopassword")"
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/18.06.1-ce (linux)"
        }
}
EOF
}

echo "REPO:          $(git config --get remote.origin.url)"
echo "ACTION:        $1"
echo "COMPONENT_DIR: $ocm_componentdir"
echo "COMPONENT:     $ocm_component"
echo "DESCRIPTOR:    $ocm_descriptor"
echo "VERSION_CMD:   $ocm_versioncmd"
echo "RESOURCES:     $ocm_resources"
echo "CTF:           $ocm_ctf"
echo "COMPREPO:      $ocm_comprepo"
echo "COMPREPO_USER: $ocm_comprepouser"
if [ -n "$ocm_comprepopassword" ]; then
  echo "::add-mask::$ocm_comprepopassword"
fi
echo "COMPREPO_PASS: $ocm_comprepopassword"

install
echo "OCM:           $OCM"

if [ -z "$ocm_ctf" ]; then
  ocm_ctf="gen/ocm/transport.ctf"
fi

createComponent()
{
  if [ -z "$ocm_componentdir" ]; then
    ocm_componentdir=gen/ocm/component
  fi
  mkdir -p "$ocm_componentdir"
  getVersion
  if [ -z "$ocm_descriptor" -a -f ocm/component-descriptor.yaml ]; then
    ocm_descriptor=ocm/component-descriptor.yaml
  fi
  if [ -n "$ocm_descriptor" ]; then
    echo "Using predefined component descriptor $ocm_descriptor"
    cp "$ocm_descriptor" "$ocm_component_dir/component-descriptor.yaml"
    opts=
    if [ -n "$ocm_component" ]; then
      echo "  setting component name $ocm_component"
      opts="--component-name $ocm_component"
    fi
    echo "  setting component version $ocm_componentversion"
    $OCM ca set "$ocm_componentdir" $opts --component-version $ocm_componentversion
  else
    if [ -z "$ocm_component" ]; then
      ocm_component="$REPO"
    fi
    echo "Creating component descriptor for $ocm_componentn version $ocm_componentversion"
    $OCM ca create "$ocm_componentdir" --component-name $ocm_component --component-version $ocm_componentversion   
  fi
  ocm_component=$($OCM ca get "$ocm_componentdir" --property name)

  cat >/tmp/sources <<EOF
name: 'project'
type: 'git'
access:
  type: "git"
  repository: $REPO
  version: $GITHUB_SHA
version: $ocm_componentversion
EOF
  $OCM ca sources add "$ocm_componentdir" /tmp/sources
}

printDescriptor()
{
  echo "Component Descriptor:"
  cat "$ocm_componentdir/component-descriptor.yaml"
  echo "Component name $ocm_component"
  echo "::set-output name=component-name::$ocm_component"
  echo "::set-output name=component-version::$ocm_componentversion"
  echo "::set-output name=component-path::$ocm_componentdir"
}

addResources()
{
  createComponent
  if [ -z "$ocm_resources" ]; then
    if [ -f "gen/ocm/resources.yaml" ]; then
      ocm_resources=gen/ocm/resources.yaml
    else
      if [ -f "ocm/resources.yaml" ]; then
        ocm_resources=ocm/resources.yaml
      fi
    fi
  fi
  if [ -z "$ocm_resources" ]; then
    error "no resources.yaml found"
  fi
  if [ ! -f "$ocm_resources" ]; then
    error "$ocm_resources not found"
  fi
  $OCM ca resource add "$ocm_componenetdir" COMPONENT_VERSION="$ocm_componentversion" COMPONENT_NAME="$ocm_component" "$ocm_resources"
}

addComponent()
{
  if [ -z "$ocm_componentdir" ]; then
    ocm_componentdir=gen/ocm/component
  fi
  mkdir -p "$(dirname "$ocm_ctf")"
  $OCM ctf add "$ocm_ctf" "$ocm_componentdir"
  echo "Transport Archive is $ocm_ctf"
  echo "::set-output name=transport-archive::$ocm_ctf"
}

pushCTF()
{
  createAuth
  if [ ! -f "$ocm_ctf" -o -n "$ocm_componentdir" ]; then
    addCTF
  fi
  $OCM ctf push --registry-config "$AUTH" "$ocm_ctf" --repo-ctx "$ocm_comprepo" 
  echo "Transport Archive is $ocm_ctf"
  echo "::set-output name=transport-archive::$ocm_ctf"
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
