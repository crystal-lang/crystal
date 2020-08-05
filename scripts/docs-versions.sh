#! /usr/bin/env sh

git tag --list | \
grep -v -E '0\.1?[0-9]\.' | \
grep '^[0-9]' | \
tac | \
awk '
  BEGIN {
    print "{"
    print "  \"versions\": ["
    getline current_version < "src/VERSION"
    printf "    {\"name\": \"" current_version "\", \"url\": \"/api/master/\", \"released\": false}"
  }

  {
    printf ",\n    {\"name\": \"" $1 "\", \"url\": \"/api/" $1 "/\"}"
  }

  END {
    print "\n  ]"
    print "}"
  }
'
