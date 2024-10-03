#compdef crystal

_crystal() {

_crystal_commands() {
  local -a commands
  commands=(
    "init:generate new crystal project"
    "build:build an executable"
    "clear_cache:clear the compiler cache"
    "docs:generate documentation"
    "env:print Crystal environment information"
    "eval:eval code from args or standard input"
    "play:starts playground server"
    "run:build and run program"
    "spec:build and run specs (in spec directory)"
    "tool:run a tool"
    "help:show help"
    "version:show version"
  )
  _describe -t commands 'Crystal command' commands
}

local -a help_args; help_args=(
  '(-h --help)'{-h,--help}'[show help]'
)

local -a version_args; version_args=(
  '(-v --version)'{-v,--version}'[show version]' \
)

local -a no_color_args; no_color_args=(
  '(--no-color)--no-color[disable colored output]'
)

local -a prelude_args; prelude_args=(
  '(--prelude)--prelude[use given file as prelude]'
)

local -a exec_args; exec_args=(
  '(\*)'{-D+,--define=}'[define a compile-time flag]:' \
  '(--error-trace)--error-trace[show full error trace]' \
  '(-s --stats)'{-s,--stats}'[enable statistics output]' \
  '(-t --time)'{-t,--time}'[enable execution time output]' \
  '(-p --progress)'{-p,--progress}'[enable progress output]'
)

local -a format_args; format_args=(
  '(-f --format)'{-f,--format}'[output format text (default) or json]:'
)

local -a debug_args; debug_args=(
  '(-d --debug)'{-d,--debug}'[add full symbolic debug info]' \
  '(--no-debug)--no-debug[skip any symbolic debug info]'
)

local -a release_args; release_args=(
  '(--release)--release[compile in release mode]'
)

local -a cursor_args; cursor_args=(
  '(-c --cursor)'{-c,--cursor}'[cursor location with LOC as path/to/file.cr:line:column]:LOC'
)

local -a include_exclude_args; include_exclude_args=(
  '(-i --include)'{-i,--include}'[Include path in output]' \
  '(-i --exclude)'{-i,--exclude}'[Exclude path in output]'
)

local -a stdin_filename_args; stdin_filename_args=(
  '(--stdin-filename)--stdin-filename[source file name to be read from STDIN]'
)

local -a programfile; programfile='*:Crystal File:_files -g "*.cr(.)"'

# TODO make 'emit' allow completion with more than one
local -a shared_run_build; shared_run_build=(
  $programfile \
  $help_args \
  $no_color_args \
  $prelude_args \
  $format_args \
  $exec_args \
  $debug_args \
  $release_args \
  '(--emit)--emit[comma separated list of types of output for the compiler to emit]:foo:(asm llvm-bc llvm-ir obj)' \
  "(--ll)--ll[dump ll to Crystal's cache directory ]" \
  '(--link-flags)--link-flags[additional flags to pass to the linker]:' \
  '(--mcpu)--mcpu[target specific cpu type]:' \
  '(--mattr)--mattr[target specific features]:' \
  "(--no-codegen)--no-codegen[don't do code generation]" \
  '(-o --output)'{-o,--output}'[output filename]:' \
  '(--single-module)--single-module[generate a single llvm module]' \
  '(--threads)--threads[maximum number of threads to use]' \
  '(--verbose)--verbose[display executed commands]' \
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
    '(--target)--target[target triple]:' \
    && ret=0
}

_crystal-env() {
  _arguments \
    '(--help)--help[prints help]' \
    '1:type:(CRYSTAL_CACHE_DIR CRYSTAL_PATH CRYSTAL_VERSION CRYSTAL_OPTS)' \
    && ret=0
}

_crystal-eval() {
  _arguments \
    $help_args \
    $no_color_args \
    $exec_args \
    $debug_args \
    $release_args \
    && ret=0
}

_crystal-play() {
  _arguments \
    $programfile \
    '(--port)--port[PORT]:' \
    '(--binding)--binding[HOST]:' \
    '(--verbose)--verbose[display detailed information of executed code]' \
    '(-h --help)'{-h,--help}'[show help]' \
    && ret=0
}

_crystal-run() {
  _arguments \
    $shared_run_build \
    && ret=0
}

_crystal-spec() {
  _arguments \
    $programfile \
    $help_args \
    $no_color_args \
    $exec_args \
    $debug_args \
    $release_args \
    && ret=0
}

_crystal-tool() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments -C \
    ':command:->command' \
    '*::options:->options'

  case $state in
    (command)
      local -a commands

      commands=(
        "context:show context for given location"
        "dependencies:show tree of required source files"
        "expand:show macro expansion for given location"
        "flags:print all macro 'flag?' values"
        "format:format project, directories and/or files"
        "hierarchy:show type hierarchy"
        "implementations:show implementations for given call in location"
        "macro_code_coverage:generate a macro code coverage report"
        "types:show type of main variables"
        "unreachable:show methods that are never called"
      )

      _describe -t commands 'Crystal tool command' commands

      _arguments $help_args
    ;;

    (options)
      case $line[1] in
        (context)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            $format_args \
            $prelude_args \
            $stdin_filename_args \
            $cursor_args
        ;;

        (dependencies)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            '(-f --format)'{-f,--format}'[output format 'tree' (default), 'flat', 'dot', or 'mermaid']:' \
            $prelude_args \
            $stdin_filename_args \
            $include_exclude_args
        ;;

        (expand)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            $format_args \
            $prelude_args \
            $stdin_filename_args \
            $cursor_args
        ;;

        (flags)
          _arguments \
            $programfile \
            $no_color_args \
            $help_args
        ;;

        (format)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $include_exclude_args \
            '(--check)--check[checks that formatting code produces no changes]' \
            '(--show-backtrace)--show-backtrace[show backtrace on a bug (used only for debugging)]'
        ;;

        (hierarchy)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            $format_args \
            $prelude_args \
            $stdin_filename_args \
            '(-e)-e[filter types by NAME regex]:'
        ;;

        (implementations)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            $format_args \
            $prelude_args \
            $cursor_args \
            $stdin_filename_args
        ;;

        (unreachable)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            $include_exclude_args \
            '(-f --format)'{-f,--format}'[output format: text (default), json, csv, codecov]:' \
            $prelude_args \
            '(--check)--check[exits with error if there is any unreachable code]' \
            '(--tallies)--tallies[print reachable methods and their call counts as well]' \
            $stdin_filename_args
        ;;

        (macro_code_coverage)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            $include_exclude_args \
            '(-f --format)'{-f,--format}'[output format: codecov (default)]:' \
            $prelude_args \
            $stdin_filename_args
        ;;

        (types)
          _arguments \
            $programfile \
            $help_args \
            $no_color_args \
            $exec_args \
            $format_args \
            $prelude_args \
            $stdin_filename_args
        ;;
      esac
    ;;
  esac
}

local curcontext=$curcontext ret=1
declare -A opt_args
_arguments -C \
  $help_args \
  $version_args \
  '1:sub-command: _alternative "subcommands:sub command:_crystal_commands" "files:file:_files -g \*.cr\(-.\)"' \
  '*::arg:->cmd' && ret=0
case $state in
  (cmd)
    if (( $CURRENT == 1 )); then
    else
      curcontext="${curcontext%:*:*}:crystal-$words[1]:"
      if ! _call_function ret _crystal-$words[1] ; then
          _default && ret=0
      fi
      return ret
    fi
    ;;
esac
}
_crystal
