#! /usr/bin/env sh

git tag --list | \
grep -v -E '0\.1?[0-9]\.' | \
grep '^[0-9]' | \
sort -rV | \
awk '
  BEGIN {
    print "{"
    print "  \"versions\": ["
    printf "    {\"name\": \"nightly\", \"url\": \"/api/master/\", \"released\": false}"
  }

  {
    printf ",\n    {\"name\": \"" $1 "\", \"url\": \"/api/" $1 "/\"}"
  }

  END {
    print "\n  ]"
    print "}"
  }
'
