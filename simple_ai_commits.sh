#!/usr/bin/zsh

# ai generated commits
VERBOSE=0
NUMBER=5
PRINTONLY=1

# gather user arguments
for arg in "$@"; do
    case "$arg" in
        -v | --verbose)
            VERBOSE=1
            shift 2
            ;;
        -n | --number)
            NUMBER="$2"
            shift 2
            ;;
        -p | --print-only)
            PRINTONLY=1
            shift 2
            ;;
    esac
done

# get the diff
diff=$(git --no-pager diff --cached --no-color --minimal)
if [[ -z $diff ]]
then
    echo "Empty diff: $diff"
    return
fi
if [[ $VERBOSE == 1 ]]
then
    echo "diff $diff"
fi

# get ai suggested commit message
system_prompt="You are given the output of 'git diff --cached'. You must reply $NUMBER commit messages suggestions that follow convention commits.
Your message format should be: '<type>(scope): <description>'
Do not forget newline, they will be used to parse your suggestions.

Examples:
fix(authentication): add password regex pattern
feat(storage): add new test cases
perf(init): add caching to file loaders
"
suggestions=$(llm -s $system_prompt -m $diff | grep -v ^$ | sort)

# split one suggestion by line
arr=()
while IFS= read -r line; do
    arr+=("$line")
    if [[ $VERBOSE == 1 ]]
        then
            echo "Suggestion: $line"
    fi
done <<< "$suggestions"

# select
select choice in $arr
break
# dialog
# choice=$(dialog --stdout --no-items --menu "Choose git commit" 100 100 5 $arr)

if [[ $VERBOSE == 1 ]]
then
    echo "You chose $choice"
fi

if [[ $PRINTONLY == 1 ]]
then
    print -z "git commit -m '$choice'" || echo "git commit -m '$choice'"
else
    git commit -m "$choice"
fi

