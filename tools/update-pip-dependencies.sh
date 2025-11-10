#!/bin/bash
#######################################################################################
# Copyright ETSI Contributors and Others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#######################################################################################

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Usage $0 <repo> <branch> <user> [<do_push>]"
    echo "Example: $0 all master garciadeblas"
    echo "Example: $0 NBI v18.0 garciadeblas false"
    exit 1
fi

set -e -o pipefail

BRANCH="$2"
USER="$3"
DO_PUSH="${4:-true}"

modules="common IM NBI N2VC LCM MON PLA POL NG-SA RO osmclient tests"
list=""
for i in $modules; do
    if [ "$1" == "$i" -o "$1" == "all" ]; then
        list="$1"
        break
    fi
done

[ "$1" == "all" ] && list=$modules

if [ -z "$list" ]; then
    echo "Repo must be one of these: $modules all"
    exit 1
fi

# Create a temporary folder
TMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TMP_DIR"

echo "Updating pip dependencies"
for i in $list; do
    echo "Updating pip dependencies for $i"
    REPO_DIR="$TMP_DIR/$i"
    if [ ! -d "$REPO_DIR" ]; then
        git clone ssh://$USER@osm.etsi.org:29418/osm/$i "$REPO_DIR" && (cd "$REPO_DIR" && curl https://osm.etsi.org/gerrit/tools/hooks/commit-msg > .git/hooks/commit-msg ; chmod +x .git/hooks/commit-msg)
    fi
    pushd "$REPO_DIR"
    git checkout $BRANCH
    git pull --rebase
    tox -e pip-compile
    git add -u
    git commit -s -m "Update pip dependencies"
    git show HEAD --stat
    git diff HEAD^ > "$TMP_DIR/$i.diff"
    echo "===================" | tee -a "$TMP_DIR/all.diff"
    echo "Showing diff for $i" | tee -a "$TMP_DIR/all.diff"
    echo "===================" | tee -a "$TMP_DIR/all.diff"
    git diff HEAD^ | tee -a "$TMP_DIR/all.diff"
    if [ "$DO_PUSH" == "true" ]; then
        echo "Pushing changes for $i"
        git push origin $BRANCH
    fi
    popd
done
echo "All diffs saved in $TMP_DIR/all.diff"

exit 0
