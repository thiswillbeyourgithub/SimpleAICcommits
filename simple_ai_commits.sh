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
UI="select"
EXTRA=""
PATCH="1"

usage="--verbose for more info on what's going on
--patch=0 or 1 to select the diff using 'git add --patch'
--number number of prompts to generate
--output=print populate your next prompt with the git message
--output=commit instead will directly commit
--model default to gpt-3.5-turbo-2501
--UI default to 'select', can be 'dialog'
--extra any additional info you want to give to the llm
"

# gather user arguments
for arg in "$@"; do
    case "$arg" in
        -v | --verbose)
            VERBOSE=1
            shift
            ;;
        -n | --number)
            NUMBER="$2"
            shift 2
            ;;
        -o | --output)
            OUT="$2"
            shift
            ;;
        -m | --model)
            MODEL="$2"
            shift
            ;;
        -u | --ui)
            UI="$2"
            shift
            ;;
        -e | --extra)
            EXTRA="$2"
            shift
            ;;
        -p | --patch)
            PATCH="$2"
            shift
            ;;
        -h | --help)
            echo $usage
            exit 1
            ;;
    esac
done


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
    diff="GIT DIFF:\n```\n$diff\n```\n\n"
    log "$diff"
fi

if [[ $EXTRA != "" ]]
then
    diff="EXTRA USER INFORMATION: \"$EXTRA\"\n\n$diff"
    EXTRA="\nTake into account any extra information given by the user."
fi

# get ai suggested commit message
system_prompt="You are given the output of 'git diff --cached'. You must reply $NUMBER commit messages suggestions that follow convention commits.
Your message format should be: '<type>(scope): <description>'
Do not forget newline, they will be used to parse your suggestions.$EXTRA

Examples:
fix(authentication): add password regex pattern
feat(storage): add new test cases
perf(init): add caching to file loaders
"
log "System prompt: $system_prompt"

log "Asking LLM..."
# via openai (faster)
# version 0.28.1
suggestions=$(openai api chat_completions.create -g system "$system_prompt" -g user "$diff" -m $MODEL -t 0 | grep -v ^$ | sort)
# version >=1.2.3
# suggestions=$(openai api chat.completions.create -g system "$system_prompt" -g user "$diff" -m $MODEL -t 0 | grep -v ^$ | sort)
# via llm (slower but very extensible)
#suggestions=$(llm -m $MODEL -s "$system_prompt" "$diff" -o temperature 0 | grep -v ^$ | sort)
log "Done!"

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
elif [[ $UI == "dialog" ]]
then
    choice=$(dialog --stdout --no-items --menu "Choose git commit" 100 100 5 $arr)
else
    echo "Invalid --ui $UI"
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

