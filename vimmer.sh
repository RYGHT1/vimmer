#!/sbin/bash
# shellcheck disable=2090,2154,1091,1090

list_modules=false
list_projects=true
term=false
debug_mode=false

main() {

#     pids=$(pgrep -f 'zsh -i')
#     for pid in $pids; do
#         if [ "$!" != "$pid" ]; then
#             echo "killing $pid"
#             kill -KILL "$pid"
#         fi
#     done

    if [ ! -e "$HOME/.cache/vimmer/modules.env" ] || [ ! -e "$HOME/.cache/vimmer/projects.env" ]; then
        init_cache
    fi

    modules_env="$HOME/.cache/vimmer/modules.env"
    source "$modules_env"

    projects_env="$HOME/.cache/vimmer/projects.env"
    source "$projects_env"



    if [ $# -eq 0 ]; then
        findProject
    fi

    while [ "$1" != "" ]; do
        case $1 in
            --add|-a|add)
                shift
                add "$@"
                exit 0
                ;;
            --add-project|-ap|add-project)
                shift
                add_project "$@"
                exit 0
                ;;
            --remove|-r|remove)
                shift
                remove "$@"
                exit 0
                ;;
            --remove-project|-rp|remove-project)
                shift
                remove-project "$@"
                exit 0
                ;;
            --list|-l|list)
                list
                exit 0
                ;;
            --help|-h|help)
                help
                exit 0
                ;;
            --modules|-m|modules)
                list_modules=true
                if [ "$2" != "" ]; then
                    if [[ "$2" = "false" ]]; then
                        list_modules=false
                        list_projects=true
                        shift
                    elif [[ "$2" = "true" ]]; then
                        list_modules=true
                        shift
                    else
                        echo -e "\e[91mInvalid argument:\e[0m $2 (should be 'true' or 'false')"
                        exit 1
                    fi
                fi
                shift
                ;;
            --projects|-p|projects)
                list_projects=true
                if [ "$2" != "" ]; then
                    if [[ "$2" = "false" ]]; then
                        list_projects=false
                        list_modules=true
                        shift
                    elif [[ "$2" = "true" ]]; then
                        list_projects=true
                        shift
                    else
                        echo -e "\e[91mInvalid argument:\e[0m $2 (should be 'true' or 'false')"
                        exit 1
                    fi
                fi
                shift
                ;;
            --term|-t|term)
                term=true
                shift
                ;;
            --debug)
                debug_mode=true
                shift
                ;;
            *)
                echo -e "\e[91mInvalid argument:\e[0m $1"
                help
                exit 1
                ;;
        esac
    done

    if [ $list_projects = "false" ] && [ $list_modules = "false" ]; then
        echo -e "\e[91mInvalid arguments:\e[0m --list-modules and --list-parents cannot both be false"
        exit 1
    fi
    findProject
}

init_cache() { 
    # create ~/.cache
    if [ ! -e "$HOME/.cache" ]; then
        mkdir "$HOME/.cache"
    fi

    # create ~/.cache/vimmer
    if [ ! -e "$HOME/.cache/vimmer" ]; then
        mkdir "$HOME/.cache/vimmer"
    fi

    # create ~/.cache/vimmer/modules.env
    if [ ! -e "$HOME/.cache/vimmer/modules.env" ]; then
        touch "$HOME/.cache/vimmer/modules.env"
        echo "modules=(" > "$HOME/.cache/vimmer/modules.env"
        echo ")" >> "$HOME/.cache/vimmer/modules.env"
    fi

    # create ~/.cache/vimmer/projects.env
    if [ ! -e "$HOME/.cache/vimmer/projects.env" ]; then
        touch "$HOME/.cache/vimmer/projects.env"
        echo "projects=(" > "$HOME/.cache/vimmer/projects.env"
        echo ")" >> "$HOME/.cache/vimmer/projects.env"
    fi

    if [ ! -e "$HOME/.cache/vimmer/modules.env" ]; then
        echo -e "\e[31mError:\e[0m Failed to create ~/.cache/vimmer/modules.env"
        exit 1
    fi
}


debug() {
    # shellcheck disable=2317
    if [ "$debug_mode" = "true" ]; then
        echo "$1"
    fi
}

findProject() {
    findables=()

    # shellcheck disable=2154
    if [ "${#modules[@]}" -eq 0 ]; then
        echo -e "\e[31mError:\e[0m No modules/projects defined in vimmer"
        echo "Use 'add|-a|--add' <directory> to add a directory as a module"
        exit 1
    fi

    for project in "${modules[@]}"; do
        if [ ! -e "$project" ]; then
            sed -i "\|${project}|d" "$modules_env"
        else
            findables+=("$project")
        fi
    done 

    #selected_path=$(find "${findables[@]}" -maxdepth 1 | fzf --preview "if [ -d {} ]; then tree -C -I 'node_modules' {}; else bat --style=plain,changes,grid --color always {}; fi" --bind "ctrl-u:preview-page-up,ctrl-d:preview-page-down")

    # shellcheck disable=2089
    command="fzf --preview \"if [ -d {} ]; then tree -C -I 'node_modules' {}; else bat --style=plain,changes,grid --color always {}; fi\" --bind \"ctrl-u:preview-page-up,ctrl-d:preview-page-down\""
    found=$(find "${findables[@]}" -maxdepth 1)

    if [ $list_modules = "false" ]; then
        found=$(grep -vxF -f <(printf "%s\n" "${findables[@]}") <(printf "%s\n" "${found[@]}"))
    fi

    for project in "${projects[@]}"; do
        if [ ! -e "$project" ]; then
            sed -i "\|${project}|d" "$projects_env"
        else
            found+=$'\n'"$project"
        fi
    done

    found=$(printf '%s\n' "${found[@]}" | sort -u)

    debug "found: ${found[*]}"

    if [ $list_projects = "false" ]; then
        selected_path=$(for project in "${findables[@]}"; do
        echo "$project"
    done | eval "$command")
else
    selected_path=$(echo "${found[@]}" | eval "$command")
    fi

    debug "selected_path: $selected_path"

    if [[ -n "$selected_path" ]]; then
        echo "Opening $selected_path"
        if [ -d "$selected_path" ]; then
            cd "$selected_path" || exit
        else
            cd "$(dirname "$selected_path")" || exit
        fi
        if [ $term = "false" ]; then
            nvim "$selected_path"
        fi
        /bin/zsh -c 'cd "$selected_path" && exec /bin/zsh'
    else
        debug "failed the last if"
        fi
        debug "exiting"
        exit 0
    }

    add_project() {
        directory=$(readlink -f "$1") # or just a file
        if [ ! -e "$directory" ]; then
            echo -e "\e[31mError:\e[0m '$directory' is not a directory or does not exist"
        fi

        for project in "${projects[@]}"; do
            if [ "$project" = "$directory" ]; then
                echo -e "\e[31mError:\e[0m '$directory' already exists in vimmer"
                exit 1
            fi
        done

        echo -e "\e[32mAdded\e[0m directory $directory to vimmer"
        sed -i "/projects=(/a '$directory'" "$projects_env"
    }

    # add module
    add() {
        directory=$(readlink -f "$1")

        if [ ! -d "$directory" ]; then
            echo -e "\e[31mError:\e[0m '$directory' is not a directory or does not exist"
        fi

        for project in "${modules[@]}"; do
            if [ "$project" = "$directory" ]; then
                echo -e "\e[31mError:\e[0m '$directory' already exists in vimmer"
                exit 1
            fi
        done 

        echo -e "\e[32mAdded\e[0m directory $directory to vimmer"
        sed -i "/modules=(/a '$directory'" "$modules_env"
    }

    remove() { # MAKE no arg version with fzf selection
        directory=$(readlink -f "$1")

        if [ ! -d "$directory" ]; then
            echo -e "\e[31mError:\e[0m '$directory' is not a directory or does not exist"
            exit 1
        fi

        if [ "$(grep -cE "'$directory'" "$modules_env")" -gt 0 ]; then
            sed -i "\|'${directory}'|d" "$modules_env"
            echo -e "\e[91mRemoved\e[0m directory $directory from modules"
        else
            echo -e "\e[31mError:\e[0m '$directory' is not a part of vimmer"
        fi
    }

    remove-project() {

    directory=$(readlink -f "$1")    

    if [ ! -d "$directory" ]; then
        echo -e "\e[31mError:\e[0m '$directory' is not a directory or does not exist"
        exit 1
    fi

    if [ "$(grep -cE "'$directory'" "$projects_env")" -gt 0 ]; then
        sed -i "\|'${project}'|d" "$projects_env"
        echo -e "\e[91mRemoved\e[0m directory $directory from projects"
    else
        echo -e "\e[31mError:\e[0m '$directory' is not a part of vimmer"
    fi
}

list() {
    echo -e "\e[34m---MODULES---\e[0m"
    for project in "${modules[@]}"; do
        echo "$project"
    done
    echo ""
    echo -e "\e[34m---PROJECTS---\e[0m"
    for project in "${projects[@]}"; do
        echo "$project"
    done
}

help() {
    echo -e "\t\e[32m _   _ _                               " 
    echo -e "\t| | | (_)                              " 
    echo -e "\t| | | |_ _ __ ___  _ __ ___   ___ _ __ " 
    echo -e "\t| | | | | '_ \` _ \| '_ \` _ \ / _ \ '__|" 
    echo -e "\t\ \_/ / | | | | | | | | | | |  __/ |   " 
    echo -e "\t \___/|_|_| |_| |_|_| |_| |_|\___|_|   \e[0m" 
    echo ""
    echo -e " \e[34mMODULES:\e[0m"
    echo -e " \tModules are directories that can be added to vimmer."
    echo -e " \tVimmer will then be able search for those modules' directories and files"
    echo -e " \tfor example you 'vimmer add ~/dir' and you can search for files in that directory"
    echo ""   
    echo -e " \e[34mPROJECTS:\e[0m"
    echo -e " \tProjects are standalone directories that can be added to vimmer."
    echo -e " \tExample: 'vimmer add-project ~/project' and only the directory ~/project will show up"
    echo ""   
    echo -e " \e[34mCOMMANDS:\e[0m"
    echo -e " \t\e[33mNo arguments:                                              opens up the search interface\e[0m"
    echo -e " \t[--add|-a|add] <directory>                                 Adds a directory to the modules list"
    echo -e " \t[--add-project|-ap|add-project] <directory>                Adds a directory to the projects list"
    echo ""   
    echo -e " \t[--remove|-r|remove] <directory>                           Removes a directory from the modules list"
    echo -e " \t[--remove-project|-rp|remove-project] <directory>          Removes a directory from the projects list"
    echo ""   
    echo -e " \t[--list|-l|list]                                           Lists all modules and projects"
    echo -e " \t[--help|-h|help]                                           Shows this help"
    echo ""   
    echo -e " \e[34mFILTERS:\e[0m"
    echo -e " \t[--term|-t|term]                                           Will not open vim at the end"
    echo -e " \t[--modules|-m|modules] <true*|false>                       Shows/hides modules (vimmer has this off)"
    echo -e " \t                                                           if no argument is given defaults to true"
    echo -e " \t[--projects|-p|projects] <true*|false>                     Shows/hides projects (vimmer has this on)"
    echo -e " \t                                                           if no argument is given defaults to true"
}

main "$@"
