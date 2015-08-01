# Troubleshooting

## Yosemite (10.10)

If you are using yosemite with homebrew you can run in some issues.

### `Error: No available formula for llvm36`

To solve it you have to make sure that you have all the right versions for homebrew with:
```
$ brew tap homebrew/versions
```

### `ld: library not found for -lgmp`

Please make sure that you have the newest version of GCC as there were some issues with yosemite:

```
$ brew install gcc
```