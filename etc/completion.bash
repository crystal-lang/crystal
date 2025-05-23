# Bash completion for "crystal" command.
# Written by Sergey Potapov <blake131313@gmail.com>.

# Return list of options, that match $pattern
_crystal_compgen_options(){
    local IFS=$' \n'
    local options=$1
    local pattern=$2
    COMPREPLY=( $(compgen -W "${options}" -- "${pattern}") )
}

# Return list of crystal sources or directories, that match $pattern
_crystal_compgen_sources(){
    local IFS=$'\n'
    local pattern=$1
    type compopt &> /dev/null && compopt -o filenames
    COMPREPLY=( $(compgen -f -o plusdirs -X '!*.cr' -- "${pattern}") )
}

# Return list of files or directories, that match $pattern (the default action)
_crystal_compgen_files(){
    local IFS=$'\n'
    local pattern=$1
    type compopt &> /dev/null && compopt -o filenames
    COMPREPLY=( $(compgen -o default -- "${pattern}") )
}

_crystal()
{
    local IFS=$' \n'
    local program=${COMP_WORDS[0]}
    local cmd=${COMP_WORDS[1]}
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="init build clear_cache docs eval play run spec tool help version --help --version"

    case "${cmd}" in
        init)
            if [[ "${prev}" == "init" ]] ; then
                local opts="app lib"
                _crystal_compgen_options "${opts}" "${cur}"
            else
                _crystal_compgen_files "${cur}"
            fi
            ;;
        build)
            if [[ "${cur}" == -* ]] ; then
                local opts="--cross-compile --debug --emit --error-on-warnings --exclude-warnings --ll --link-flags --mcpu --no-color --no-codegen --output --prelude --release --single-module --threads --target --verbose --warnings --help"
                _crystal_compgen_options "${opts}" "${cur}"
            else
                _crystal_compgen_sources "${cur}"
            fi
            ;;
        run)
            if [[ "${cur}" == -* ]] ; then
                local opts="--debug --define --emit --error-on-warnings --exclude-warnings --format --help --ll --link-flags --mcpu --no-color --no-codegen --output --prelude --release --stats --single-module --threads --verbose --warnings"
                _crystal_compgen_options "${opts}" "${cur}"
            else
                _crystal_compgen_sources "${cur}"
            fi
            ;;
        tool)
            if [[ "${cur}" == -* ]] ; then
                local opts="--no-color --prelude --define --format --cursor"
                _crystal_compgen_options "${opts}" "${cur}"
            else
                if [[ "${prev}" == "tool" ]] ; then
                    local subcommands="context dependencies expand flags format hierarchy implementations macro_code_coverage types unreachable"
                    _crystal_compgen_options "${subcommands}" "${cur}"
                else
                    _crystal_compgen_sources "${cur}"
                fi
            fi
            ;;
        play)
            if [[ ${cur} == -* ]] ; then
                local opts="--port --binding --verbose --help"
                _crystal_compgen_options "${opts}" "${cur}"
            else
                _crystal_compgen_sources "${cur}"
            fi
            ;;
        clear_cache|docs|eval|spec|version|help)
            # These commands do not accept any options nor subcommands
            _crystal_compgen_files "${cur}"
            ;;
        *)
            # When any of subcommands matches directly
            if [[ "${prev}" == "${program}" && $(compgen -W "${commands}" -- "${cur}") ]] ; then
                _crystal_compgen_options "${commands}" "${cur}"
            else
                _crystal_compgen_sources "${cur}"
            fi
    esac
    return 0
}

complete -F _crystal crystal
