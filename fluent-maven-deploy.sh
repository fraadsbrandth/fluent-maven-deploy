#!/bin/bash

SCRIPT_NAME=$0
COMMIT_PREFIX="[#deploy] -> "
echo "[START] ${SCRIPT_NAME} starting"

function finalize() {
    if [ "0" == "${1}" ]; then
        RESULT="executed successfully"
    else
        RESULT="executed with error"
    fi
    echo "[END] ${SCRIPT_NAME} ${RESULT}"
    exit $1
}

function ensureRequiredPrograms() {
    if [[ $(which git) ]]; then
        echo "[INFO] Git installed."
    else
        echo "[ERROR] Install git to run script."
        finalize 1
    fi
    if [[ $(which mvn) ]]; then
        echo "[INFO] Maven installed."
    else
        echo "[ERROR] Install maven to run script."
        finalize 1
    fi
}
ensureRequiredPrograms

function ensureMasterBranch() {
  local branch=$(git symbolic-ref --short -q HEAD)
  if [[ (${branch} == "master") ]]; then
    echo "[INFO] Currently on master branch."
  else
    echo "[ERROR] Deployment can only be done on master branch."
    finalize 1
  fi
}
ensureMasterBranch

function ensureNoUntrackedChanges() {
    if [[ -n $(git status -s) ]]; then
        echo "[ERROR] Untracked changes"
        echo " - There exists untracked changes in the repository"
        echo " - Commit changes and run script again"
        echo " - Changes exists in following files;"
        git status -s
        finalize 1
    fi

}
ensureNoUntrackedChanges

function getSemverUpdateFromLatestGitCommitMessage() {
    local latest_git_commit=$(git log -1 --pretty=%B)
    local latest_git_commit_upper_case=${latest_git_commit^^}
    if [[ (${latest_git_commit_upper_case} = *"#PATCH"*) ]]; then
        echo "patch"
    elif [[ (${latest_git_commit_upper_case} = *"#MINOR"*) ]]; then
        echo "minor"
    elif [[ (${latest_git_commit_upper_case} = *"#MAJOR"*) ]]; then
        echo "major"
    elif [[ (${latest_git_commit} = *"${COMMIT_PREFIX}"*) ]]; then
        echo "no_change"
    else
        echo "skip"
    fi
}

SEMVER_UPDATE=$(getSemverUpdateFromLatestGitCommitMessage)
if [ ${SEMVER_UPDATE} == "skip" ]; then
    echo "[INFO] No deploy needed"
    echo " - Latest git commit message does not contain #patch, #minor or #major (case insensitive)"
    finalize 0
elif [ ${SEMVER_UPDATE} == "no_change" ]; then
    echo "[INFO] No deploy needed"
    echo " - No changes since last deploy."
    finalize 0
fi

# Arguments
for i in "$@"
do
case ${i} in
    --goal=*)
    GOAL="${i#*=}"
    shift
    ;;
    --options=*)
    OPTIONS="${i#*=}"
    shift
    ;;
    *)
    # unknown option
    ;;
esac
# Default values
if [ -z ${GOAL+x} ]; then
  GOAL="deploy"
fi
done

echo "[INFO] Resolved arguments"
echo "- GOAL=${GOAL}"
echo "- OPTIONS=${OPTIONS}"

CURRENT_VERSION=$(mvn -q \
    -Dexec.executable="echo" \
    -Dexec.args='${project.version}' \
    --non-recursive \
    org.codehaus.mojo:exec-maven-plugin:1.6.0:exec)

CURRENT_VERSION_ARRAY=(${CURRENT_VERSION//./ })
CURRENT_VERSION_ARRAY_LENGTH=${#CURRENT_VERSION_ARRAY[@]}

GIT_SHORT_HASH=$(git rev-parse --short HEAD)

echo "[INFO] Resolved variables"
echo "- CURRENT_VERSION=${CURRENT_VERSION}"
echo "- GIT_SHORT_HASH=${GIT_SHORT_HASH}"

# Verifying current version
if [ ${CURRENT_VERSION_ARRAY_LENGTH} == 3 ]; then # SEMVER
    echo "[INFO] Version type"
    echo " - Current version on semver format."
elif [ ${CURRENT_VERSION_ARRAY_LENGTH} == 4 ]; then # POSSIBLY SEMVER WITH GIT HASH SUFFIX
    POSSIBLE_SHORT_GIT_HASH=${CURRENT_VERSION_ARRAY[3]}
    echo "[INFO] Version type"
    echo " - Current version on semver format with possible short git hash suffix (${POSSIBLE_SHORT_GIT_HASH})."
    if [ ${GIT_SHORT_HASH} == ${POSSIBLE_SHORT_GIT_HASH} ]; then
        echo "[INFO] Revision already deployed"
        echo " - Revision ${GIT_SHORT_HASH} is already deployed."
        finalize 0
    fi
else
    echo "[ERROR] Invalid version"
    echo " - Version ${CURRENT_VERSION} is on an invalid format. Deploy denied."
    echo " - Version has to have 3 or 4 part divided by dots (.)"
    finalize 1
fi

# Verify semver part of version
function ensureNumber() {
    local regex='^[0-9]+$'
    if ! [[ $1 =~ $regex ]] ; then
       echo "[ERROR] Not a number"
       echo " - ${1} is not a number"
       finalize 1
    fi
}

echo "[INFO] Verifying current semver version"
ensureNumber ${CURRENT_VERSION_ARRAY[0]}
ensureNumber ${CURRENT_VERSION_ARRAY[1]}
ensureNumber ${CURRENT_VERSION_ARRAY[2]}
echo " - Current semver version is properly formatted"

# Checking for SNAPSHOT
if grep -r --include="*pom.xml" "\-SNAPSHOT" "."; then
    echo "[ERROR] Deploy failed"
    echo " - Project contains SNAPSHOT version/dependencies. Deploy denied."
    echo " - Remove the SNAPSHOT occurrences in the files listed above to perform deploy."
    echo " - Note that deploy will be denied for any occurrences of 'SNAPSHOT' in any pom.xml (also commented out)."
    finalize 1
fi

# Get new version function
function getBumpedSemverVersion() {
    local semver_array=(${1//./ })
    local semver_update=$2
    if [ ${semver_update} == "patch" ]; then
        echo ${semver_array[0]}.${semver_array[1]}.$((${semver_array[2]} + 1))
    elif [ ${semver_update} == "minor" ]; then
        echo ${semver_array[0]}.$((${semver_array[1]} + 1)).0
    else
        echo $((${semver_array[0]} + 1)).0.0
    fi
}

# Setting new version
CURRENT_SEMVER_VERSION=${CURRENT_VERSION_ARRAY[0]}.${CURRENT_VERSION_ARRAY[1]}.${CURRENT_VERSION_ARRAY[2]}
NEW_SEMVER_VERSION=$(getBumpedSemverVersion ${CURRENT_VERSION} ${SEMVER_UPDATE})
NEW_VERSION=${NEW_SEMVER_VERSION}.${GIT_SHORT_HASH}

echo "[INFO] Version info"
echo " - Current semver version is ${CURRENT_SEMVER_VERSION}"
echo " - New semver version is ${NEW_SEMVER_VERSION}"
echo " - New version is ${NEW_VERSION}"
echo " - Updating version"
mvn versions:set -DnewVersion=${NEW_VERSION}

if [[ ${GOAL^^} == "DEPLOY" ]]; then
  echo "[INFO] Updating repository"
  git add "./*pom.xml"
  GIT_COMMIT_MESSAGE="${COMMIT_PREFIX}${SEMVER_UPDATE} update from ${CURRENT_VERSION} to ${NEW_VERSION}"
  git commit -m "${GIT_COMMIT_MESSAGE}"
  git push origin master
else
  echo "[INFO] Skipping update of repostory since maven goal ${GOAL} != deploy."
fi

echo "[INFO] Performing maven ${GOAL}"
eval mvn clean ${GOAL} -U ${OPTIONS}
