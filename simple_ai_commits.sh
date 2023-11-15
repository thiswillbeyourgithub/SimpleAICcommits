#!/usr/bin/zsh

# ai generated commits
VERBOSE=0
NUMBER=5
OUT="commit"
MODEL="gpt-3.5-turbo-1106"
UI="select"
CONTEXT=""

usage="--verbose for more info on what's going on
--number number of prompts to generate
--output=print populate your next prompt with the git message
--output=commit instead will directly commit
--model default to gpt-3.5-turbo-1106
--UI default to 'select', can be 'dialog'
--context any additional context you want to give to the llm
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
        -c | --context)
            CONTEXT="$2"
            shift
            ;;
        -h | --help)
            echo $usage
            return
            ;;
    esac
done

# get the diff
diff=$(git --no-pager diff --cached --no-color --minimal)
if [[ -z $diff ]]
then
    echo "Empty diff: $diff"
    return
else
    diff="DIFF:\n'''\n$diff\n'''"
fi

if [[ $VERBOSE == 1 ]]
then
    echo "diff $diff"
fi
if [[ $CONTEXT != "" ]]
then
    diff="USER: The high level context of this change is \"$CONTEXT\"\n\n$diff"
    CONTEXT="\nIf the user adds context to the diff, take it into account."
fi

# get ai suggested commit message
system_prompt="You are given the output of 'git diff --cached'. You must reply $NUMBER commit messages suggestions that follow convention commits.
Your message format should be: '<type>(scope): <description>'
Do not forget newline, they will be used to parse your suggestions.$CONTEXT

Examples:
fix(authentication): add password regex pattern
feat(storage): add new test cases
perf(init): add caching to file loaders
"
suggestions=$(llm -m $MODEL -s "$system_prompt" "$diff" | grep -v ^$ | sort)

# split one suggestion by line
arr=()
while IFS= read -r line; do
    arr+=("$line")
    if [[ $VERBOSE == 1 ]]
        then
            echo "Suggestion: $line"
    fi
done <<< "$suggestions"

if [[ $UI == "select" ]]
then
    select choice in $arr
    break
elif [[ $UI == "dialog" ]]
then
    choice=$(dialog --stdout --no-items --menu "Choose git commit" 100 100 5 $arr)
else
    echo "Invalid --ui $UI"
    return
fi

if [[ $VERBOSE == 1 ]]
then
    echo "You chose '$choice'"
fi

if [[ $OUT == "print" ]]
then
    if [[ $VERBOSE == 1 ]]
    then
        echo "Not committed but shown"
    fi
    print -z "git commit -m '$choice'" || echo "git commit -m '$choice'"
elif [[ $OUT == "commit" ]]
then
    if [[ $VERBOSE == 1 ]]
    then
        echo "Commited"
    fi
    git commit -m "$choice"
else
    echo "Invalid --output $OUT"
    exit
fi

