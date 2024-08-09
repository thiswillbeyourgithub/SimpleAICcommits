#!/usr/bin/zsh


function log() {
    if [[ $VERBOSE == 1 ]]
    then
        echo "$1"
    fi
}

# default parameter value
VERBOSE=0
NUMBER=10
OUT="commit"
MODEL="gpt-4o-mini"
UI="fzf"
EXTRA=""
PATCH="1"
DO_RESET="1"
PREV_COMMIT="1"
PREFIX="SAIC: "
VERSION="2.2"
BACKEND="openai"

# hardcoded value
MAX_STRING_LENGTH=100000

usage="

--patch=1                   1 to use 'git add --patch' to get the diff, 0 to get the diff directly

--do-reset=1                1 to do a 'git reset' at the start, allowing you to restart 'git add --patch' for example. 0 to disable.

--number=10                 number of suggestions to ask for

--prefix='SAIC: '            prefix of the commit, helps SAIC knows which previous commit it did.

--include_previous=1        1 to include or not the name of the last 10 previous commits for context. 0 to disable. Default 1

--output='commit'           'print' to populate your next prompt with the git message or 'commit' to commit directly.

--model='gpt-4o-mini'

--backend='openai'          either 'openai' (faster) or 'llm' (more extensible, supports any provider)

--UI='fzf'                  can be 'fzf', 'select' or 'dialog'

--extra                     any additional context you want to give to the llm

--version                   display version number

--verbose                   for more info on what's going on
"

system_prompt="You are SAIC (Simple AI Commit), my best developper. Your task is: given an output of 'git diff', you must reply $NUMBER suggestions of commit messages that follow the conventionnal commits format.
Your message format should be: '<type>(scope): <description>'
BEFORE answering, you can use a <thinking> tag for yourself, THEN take a deep breath, THEN finally answer wrapping all your suggestions in a single <answer> tag that ends with </answer>.
Do not forget to separate each suggestion by a newline, they will be used to parse your suggestions.$EXTRA

Examples of appropriate suggestion format:
<thinking>
This is an example of your reasonning.
</thinking>
<answer>
fix(authentication): add password regex pattern
feat(storage): add new test cases
perf(init): add caching to file loaders
</answer>
"

# gather user arguments
for arg in "$@"; do
    case "${arg%%=*}" in
        -v | --verbose)
            VERBOSE=1
            ;;
        --version)
            echo "$VERSION"
            exit 0
            ;;
        -n | --number)
            NUMBER="${arg#*=}"
            if [[ $NUMBER -gt 0 ]]
            then
                echo "Invalid --number value (must be a positive int)"
                exit 1
            fi
            ;;
        -o | --output)
            OUT="${arg#*=}"
            if [[ "$OUT" != "commit" && "$OUT" != "print" ]]
            then
                echo "Invalid --output value (must be commit or print)"
                exit 1
            fi
            ;;
        --backend)
            BACKEND="${arg#*=}"
            if [[ "$BACKEND" != "openai" && "$BACKEND" != "llm" ]]
            then
                echo "Invalid --backend value (must be openai or llm)"
                exit 1
            fi
            ;;
        -m | --model)
            MODEL="${arg#*=}"
            ;;
        -u | --ui)
            UI="${arg#*=}"
            if [[ "$UI" != "fzf" && "$UI" != "dialog" && "$UI" != "select" ]]
            then
                echo "Invalid --ui value (must be fzf, dilog or select)"
                exit 1
            fi
            ;;
        --prefix)
            PREFIX="${arg#*=}"
            ;;
        -e | --extra)
            EXTRA="${arg#*=}"
            ;;
        -p | --patch)
            PATCH="${arg#*=}"
            if [[ "$PATCH" != "0" && "$PATCH" != "1" ]]
            then
                echo "Invalid --patch value (must be 0 or 1)"
                exit 1
            fi
            ;;
        --do-reset)
            DO_RESET="${arg#*=}"
            if [[ "$DO_RESET" != "0" && "$DO_RESET" != "1" ]]
            then
                echo "Invalid --do-reset value (must be 0 or 1)"
                exit 1
            fi
            ;;
        --include_previous)
            PREV_COMMIT="${arg#*=}"
            if [[ "$PREV_COMMIT" != "0" && "$PREV_COMMIT" != "1" ]]
            then
                echo "Invalid --prev-commit value (must be 0 or 1)"
                exit 1
            fi
            ;;
        -h | --help)
            echo "$usage"
            exit 1
            ;;
        *)
            echo "Error: Unexpected argument '${arg%%=*}'"
            echo "$usage"
            exit 1
            ;;
    esac
done

# get the previous git commits
if [[ "$PREV_COMMIT" != "0" ]]
then
    prev_commits="## NAMES OF PREVIOUS COMMITS ##\n$(git --no-pager log -n 10 --no-color --pretty=format:\"%s\")\n## END OF NAMES OF PREVIOUS COMMITS ##\n\n"
else
    prev_commits=""
fi

if [[ "$DO_RESET" != "0" ]]
then
    echo "git reset"
    git reset
fi

# get the git diff
diff_cached=$(git --no-pager diff --cached --no-color --minimal)

if [[ "$PATCH" == "1" ]]
then
    if [[ -z "$diff_cached" ]]
    then
        git add --patch
        diff_cached=$(git --no-pager diff --cached --no-color --minimal)
    else
        echo "Not doing 'git add --patch' because there's already a diff --cached"
    fi
fi

if [[ -z "$diff_cached" ]]
then
    diff_noncached=$(git --no-pager diff --no-color --minimal)
    diff=$diff_cached
else
    diff=$diff_cached
fi
if [[ -z "$diff" ]]
then
    echo "Empty git diff (--cached or not)"
    exit 1
else
    diff="## BEGINNING OF GIT DIFF ##\n$diff\n## END OF GIT DIFF ##\n\n"
    log "$diff"
fi


if [[ "$EXTRA" != "" ]]
then
    EXTRA="\nADDITIONAL INFORMATION:\n```\n$EXTRA\n```"
fi

prompt="$prev_commits$diff"

lengthp=${#prompt}
lengths=${#system_prompt}
length=$lengthp+$lengths
if [[ $length -gt $MAX_STRING_LENGTH ]]
then
    echo "Prompt we were about to send to the LLM is suspiciously large, it's number of character is $length which is above $MAX_STRING_LENGTH"
    exit 1
fi

# get ai suggested commit message
echo "Asking $MODEL via $BACKEND..."
if [[ "$BACKEND" == "openai" ]]
then
    answer=$(openai api chat.completions.create -g system "$system_prompt" -g user "$prompt" -m $MODEL -t 0)
elif [[ "$BACKEND" == "llm" ]]
then
    answer=$(llm -m $MODEL -s "$system_prompt" "$prompt" -o temperature 0)
fi
echo "API call finished"

thinking=$(awk '
    BEGIN { RS="</thinking>"; FS="<thinking>" }
    NF>1 { gsub(/^[ \\t]*\\n/, "", $2); gsub(/\\n[ \\t]*$/, "", $2); print $2 }
' <<< "$answer" | awk NF)
echo "\n\n## Reasonning of $MODEL ##:\n$thinking\n\n"

answer=$(awk '
    BEGIN { RS="</answer>"; FS="<answer>" }
    NF>1 { gsub(/^[ \\t]*\\n/, "", $2); gsub(/\\n[ \\t]*$/, "", $2); print $2 }
' <<< "$answer" | awk NF)
suggestions=$answer

suggestions=$(echo $suggestions | sort)

# split one suggestion by line
arr=()
while IFS= read -r line; do
    arr+=("$line")
    log "Suggestion: $line"
done <<< "$suggestions"

# UI
if [[ $UI == "select" ]]
then
    select choice in $arr
    break
elif [[ $UI == "fzf" ]]
then
    choice=$(echo $suggestions | fzf \
        --header="Choose commmit name (e to edit)" \
        --layout=reverse \
        --border \
        --preview 'echo {}' \
        --preview-window down:wrap \
        --bind 'e:execute(echo EDIT{})' \
        --expect 'e'
    )
    key=$(echo "$choice" | head -1)
    choice=$(echo "$choice" | tail -1)
    if [[ $key == "e" ]]
    then
        OUT="print"
        choice=${choice#EDIT}
    fi
elif [[ $UI == "dialog" ]]
then
    choice=$(dialog --stdout --no-items --menu "Choose git commit" 100 100 5 $arr)
else
    echo "Invalid --ui $UI"
    exit 1
fi
if [[ -z "$choice" ]]
then
    echo "Invalid choice: '$choice'"
    exit 1
fi

log "You chose '$choice'"

choice=$PREFIX$choice

# end
if [[ $OUT == "print" ]]
then
    log "Not committed but shown"
    BUFFER="git commit -m '$choice'"
    vared -c BUFFER
    eval $BUFFER

elif [[ $OUT == "commit" ]]
then
    log "Making commit"
    git commit -m "$choice"

else
    echo "Invalid --output $OUT"
    exit
fi

