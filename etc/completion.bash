# Bash completion for "crystal" command.
# Written by Sergey Potapov <blake131313@gmail.com>.

# Get list of crystal files or directories, that match $pattern
_crystal_compgen_files(){
    local pattern=$1
    compgen -f -o plusdirs -X '!*.cr' -- $pattern
}

_crystal()
{
    local program=${COMP_WORDS[0]}
    local cmd=${COMP_WORDS[1]}
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="init build deps docs eval play run spec tool help version --help --version"

    case "${cmd}" in
        init)
            if [[ "${prev}" == "init" ]] ; then
                COMPREPLY=( $(compgen -W "app lib" -- ${cur}) )
            else
                COMPREPLY=( $(compgen -f ${cur}) )
            fi
            ;;
        compile)
            if [[ ${cur} == -* ]] ; then
                local opts="--cross-compile --debug --emit --ll --link-flags --mcpu --no-color --no-codegen --prelude --release --single-module --threads --target --verbose --help"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            else
                COMPREPLY=($(_crystal_compgen_files $cur))
            fi
            ;;
        deps)
            if [[ ${cur} == -* ]] ; then
                local opts="--no-color --version --production"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            else
                if [[ "${prev}" == "deps" ]] ; then
                    local subcommands="check install list update"
                    COMPREPLY=( $(compgen -W "${subcommands}" -- ${cur}) )
                else
                    COMPREPLY=($(_crystal_compgen_files $cur))
                fi
            fi
            ;;
        run)
            if [[ ${cur} == -* ]] ; then
                local opts="--debug --define --emit --format --help --ll --link-flags --mcpu --no-color --no-codegen --prelude --release --stats --single-module --threads --verbose"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            else
                COMPREPLY=($(_crystal_compgen_files $cur))
            fi
            ;;
        tool)
            if [[ ${cur} == -* ]] ; then
                local opts="--no-color --prelude --define --format --cursor"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            else
                if [[ "${prev}" == "tool" ]] ; then
                    local subcommands="context format hierarchy implementations types"
                    COMPREPLY=( $(compgen -W "${subcommands}" -- ${cur}) )
                else
                    COMPREPLY=($(_crystal_compgen_files $cur))
                fi
            fi
            ;;
        play)
            if [[ ${cur} == -* ]] ; then
                local opts="--port --binding --verbose --help"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            else
                COMPREPLY=($(_crystal_compgen_files $cur))
            fi
            ;;
        docs|eval|spec|version|help)
            # These commands do not accept any options nor subcommands
            COMPREPLY=( $(compgen -f ${cur}) )
            ;;
        *)
            # When any of sumbcommands matches directly
            if [[ "${prev}" == "${program}" && $(compgen -W "${commands}" -- ${cur})  ]] ; then
                COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
            else
                COMPREPLY=($(_crystal_compgen_files $cur))
            fi
    esac
    return 0
}

complete -F _crystal -o filenames crystal
