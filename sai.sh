#!/usr/bin/zsh


function log() {
    if [[ $VERBOSE == 1 ]]
    then
        echo "$1"
    fi
}

# ai generated commits
VERBOSE=0
NUMBER=5
OUT="commit"
MODEL="gpt-4o-mini"
UI="fzf"
EXTRA=""
PATCH="1"
PREV_COMMIT="0"

usage="--verbose for more info on what's going on

--patch=0 or 1 to select the diff using 'git add --patch'

--number number of prompts to generate

--include_previous=0 or 1   to include or not the name of the last 5 previous commits for context. Default 1

--output=print populate your next prompt with the git message
--output=commit instead will directly commit

--model default to gpt-4o-mini

--UI 'fzf'     can be 'fzf', 'select' or 'dialog'

--extra any additional info you want to give to the llm
"

system_prompt="You are my best developper. Your task is: given an output of 'git diff', you must reply $NUMBER suggestions of commit messages that follow the conventionnal commits format.
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
        -n | --number)
            NUMBER="${arg#*=}"
            ;;
        -o | --output)
            OUT="${arg#*=}"
            ;;
        -m | --model)
            MODEL="${arg#*=}"
            ;;
        -u | --ui)
            UI="${arg#*=}"
            ;;
        -e | --extra)
            EXTRA="${arg#*=}"
            ;;
        -p | --patch)
            PATCH="${arg#*=}"
            ;;
        --include_previous)
            PREV_COMMIT="${arg#*=}"
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
    prev_commits="## NAMES OF PREVIOUS COMMITS ##\n$(git --no-pager log -n 5 --no-color --pretty=format:\"%s\")\n## END OF NAMES OF PREVIOUS COMMITS ##\n\n"
else
    prev_commits=""
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

# get ai suggested commit message
echo "Asking $model..."
# via openai (faster)
# version 0.28.1
# answer=$(openai api chat_completions.create -g system "$system_prompt" -g user "$prompt" -m $MODEL -t 0)
# version >=1.2.3
# answer=$(openai api chat.completions.create -g system "$system_prompt" -g user "$prompt" -m $MODEL -t 0)
# via llm (slower but very extensible)
answer=$(llm -m $MODEL -s "$system_prompt" "$prompt" -o temperature 0)
echo "API call finished"

thinking=$(awk '
    BEGIN { RS="</thinking>"; FS="<thinking>" }
    NF>1 { gsub(/^[ \\t]*\\n/, "", $2); gsub(/\\n[ \\t]*$/, "", $2); print $2 }
' <<< "$answer" | awk NF)
echo "\n\n## Reasonning of $model ##:\n$thinking\n\n"

answer=$(awk '
    BEGIN { RS="</answer>"; FS="<answer>" }
    NF>1 { gsub(/^[ \\t]*\\n/, "", $2); gsub(/\\n[ \\t]*$/, "", $2); print $2 }
' <<< "$answer" | awk NF)
suggestions=$answer

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
    choice=$(echo $suggestions | fzf --height=50% --layout=reverse --border)
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


# end
if [[ $OUT == "print" ]]
then
    log "Not committed but shown"
    print -z "git commit -m '$choice'" || echo "git commit -m '$choice'"
elif [[ $OUT == "commit" ]]
then
    log "Making commit"
    git commit -m "$choice"
else
    echo "Invalid --output $OUT"
    exit
fi

