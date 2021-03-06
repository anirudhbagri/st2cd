#!/bin/bash
set -e

# This script is run during the StackStorm release process:
#  - if missing, create a branch named ${BRANCH} (i.e., "vX.Y") in ${PROJECT}.
#  - update the Makefile on this branch to reference $ST2_VERSION (i.e., "X.Y.Z").

PROJECT=$1
ST2_VERSION=$2
ORG=$3
BRANCH=$4
LOCAL_REPO=$5

GIT_REPO="git@github.com:${ORG}/${PROJECT}.git"
CWD=`pwd`

cleanup() {
    echo "Cleaning up droppings"
    cd ${CWD}
    rm -rf ${LOCAL_REPO}
}

if [[ -z ${LOCAL_REPO} ]]; then
    CURRENT_TIMESTAMP=`date +'%s'`
    RANDOM_NUMBER=`awk -v min=100 -v max=999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`
    LOCAL_REPO=${PROJECT}_${CURRENT_TIMESTAMP}_${RANDOM_NUMBER}
fi

if [ -d "${LOCAL_REPO}" ]; then
    echo "Deleting ${LOCAL_REPO}"
    rm -rf ${LOCAL_REPO}
fi

echo "Cloning ${GIT_REPO} to ${LOCAL_REPO}"
git clone ${GIT_REPO} ${LOCAL_REPO}

cd ${LOCAL_REPO}
echo "Currently at directory `pwd`..."

echo "Checking existence of branch ${BRANCH}"
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ -z "${BRANCH_EXISTS}" ]]; then
    echo "Creating branch ${BRANCH}"
    git branch ${BRANCH}
fi

echo "Checking out ${BRANCH}"
git checkout ${BRANCH}

echo "Updating Makefile"
# Replace line in Makefile beginning "ST2_VERSION ?=" with "ST2_VERSION ?= ${ST2_VERSION}"
rc=0
sed -i "/^ST2_VERSION.*/cST2_VERSION ?= ${ST2_VERSION}" Makefile || rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo "ERROR: Unable to update the st2 version in Makefile"
    cleanup
    exit $rc
fi

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    echo "Committing and pushing changes to Makefile"
    git add -A
    git commit -qm "Update version info for release - ${ST2_VERSION}"
    git push -u origin ${BRANCH} -q
fi

cleanup
