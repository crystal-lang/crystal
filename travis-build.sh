#!/bin/bash

set -e

rev=$(git rev-parse --short HEAD)

bundle exec rake docs docs:tidy

git config --global user.email "bcardiff@manas.com.ar"
git config --global user.name "Travis on behalf Brian J. Cardiff"

git remote add upstream "https://$GH_TOKEN@github.com/manastech/crystal"
git fetch upstream
git reset upstream/gh-pages

git add -A docs/
git commit -m "rebuild docs at ${rev} [ci skip]" || true
git push -q upstream HEAD:gh-pages
