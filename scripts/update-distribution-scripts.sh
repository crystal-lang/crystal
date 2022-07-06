#!/usr/bin/env sh
#
# This helper updates the reference of [distribution-scripts](https://github.com/crystal-lang/distribution-scripts),
# pushes the change to GitHub and creates a pull request.
#
# Usage:
#
#    scripts/update-distribution_scripts.sh [REF]
#
# Requirements:
# * packages: git gh sed
# * Working directory should be in a checked out work tree of `crystal-lang/crystal`.
#
# * The default value for reference is the current HEAD of https://github.com/crystal-lang/distribution-scripts.

set -eu

DISTRIBUTION_SCRIPTS_WORK_DIR=${DISTRIBUTION_SCRIPTS_WORK_DIR:-../distribution-scripts/.git}
GIT_DS="git --git-dir=$DISTRIBUTION_SCRIPTS_WORK_DIR"

$GIT_DS fetch origin master

if [ -z "${1:-}"]; then
  reference=$($GIT_DS rev-list origin/master | head -1)
else
  reference=${1}
fi

branch="ci/update-distribution-scripts"

git switch -C "$branch" master

old_reference=$(sed -n "/distribution-scripts-version:/{n;n;n;p}" .circleci/config.yml | grep -o -P '(?<=default: ")[^"]+')
echo $old_reference..$reference

sed -i -E "/distribution-scripts-version:/{n;n;n;s/default: \".*\"/default: \"$reference\"/}" .circleci/config.yml

git add .circleci/config.yml

message="Updates \`distribution-scripts\` dependency to https://github.com/crystal-lang/distribution-scripts/commit/$reference"
log=$($GIT_DS log $old_reference..$reference --format="%s" | sed "s/.*(/\* crystal-lang\/distribution-scripts/;s/.$//")
message="$message\n\nThis includes the following changes:\n\n$log"

git commit -m "Update distribution-scripts" -m "$message"

git show

git push -u upstream "$branch"


# Create pull request
gh pr create -R crystal-lang/crystal --fill --label "topic:infrastructure" --assignee "@me"
