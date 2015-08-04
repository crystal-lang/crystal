#compdef crystal
_crystal() {

_crystal_commands() {
  local -a commands
  commands=(
    "init:generate new crystal project"
    "build:compile program file"
    "browser:open an http server to browse program file"
    "deps:install project dependencies"
    "docs:generate documentation"
    "eval:eval code"
    "hierarchy:show type hierarchy"
    "run:compile and run program file"
    "spec:compile and run specs (in spec directory)"
    "types:show type of main variables"
    {-h,--help}":show help"
    {-v,--version}":show version"
  )
  # mabye make last thing "$@" instead? from _play
_describe -t commands 'Crystal command' commands
}

# TODO maybe you can have more than one -D?
local -a common_args; common_args=(
  '(-D --define)'{-D,--define}'[Define a compile-time flag]:' \
  '(-h --help)'{-h,--help}'[Show help]' \
  '(--no-color)--no-color[Disable colored output]' \
  '(--prelude)--prelude[Use given file as prelude]')

# TODO make 'emit' allow completion with more than one
local -a shared_run_build; shared_run_build=(
    '*:Crystal File:_files -g "*.cr(.)"' \
    $common_args \
    '(--ll)-ll[Dump ll to .crystal directory]' \
    '(--link-flags)--link-flags[Additional flags to pass to the linker]:' \
    '(--mcpu)--mcpu[Target specific cpu type]:' \
    '(--no-build)--no-build[Disable build output]' \
    '(-o)-o[Output filename]:' \
    '(--prelude)--prelude[Use given file as prelude]:' \
    '(--release)--release[Compile in release mode]' \
    '(-s --stats)'{-s,--stats}'[Enable statistics output]' \
    '(--single-module)--single-module[Generate a single LLVM module]' \
    '(--threads)--threads[Maximum number of threads to use]:' \
    '(--verbose)--verbose[Display executed commands]' \
    '(--emit)--emit[Comma separated list of types of output for the compiler to emit]:foo:(asm llvm-bc llvm-ir obj)'
    )


# TODO add help text for name and dir
_crystal-init() {
  _arguments \
    '1:type:(lib app)' \
    && ret=0
}

_crystal-build() {
  _arguments \
    $shared_run_build \
    '(--cross-compile)--cross-compile[cross-compile FLAGS]:' \
    '(--target)--target[Target triple]:' \
    && ret=0
}

_crystal-browser() {
  _arguments \
    $common_args \
    && ret=0
}

_crystal-hierarchy() {
  _arguments \
    $common_args \
    && ret=0
}

_crystal-run() {
  _arguments \
    $shared_run_build \
    && ret=0
}

_crystal-types() {
  _arguments \
    $common_args \
    && ret=0
}


local curcontext=$curcontext ret=1
local context state line
declare -A opt_args
_arguments -C   '*::arg:->cmd' && return
case $state in
  (cmd)
    if (( $CURRENT == 1 )); then
      _crystal_commands
    else
      curcontext="${curcontext%:*:*}:crystal-$words[1]:"
      _call_function ret _crystal-$words[1]
    fi
    ;;
esac

}
_crystal

