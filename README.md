# SimpleAICcommits
Simple shell script to use an LLM to write your commit messages

# Features
* Gets your diff either using `git add --patch` or directly from your `--staged` diff
* Conventional commit format
- Customizable number of commit message suggestions
- Option to include previous commit messages for context
- Flexible output modes: print or directly commit
- Selectable AI models (e.g., GPT-3.5-turbo, GPT-4)
- User interface options: select or dialog
- Ability to add extra context to AI prompt
- Displays AI's reasoning process

## How to
1. `git clone https://github.com/thiswillbeyourgithub/SimpleAICcommits`.
2. make sure you have either `openai` installed and keys setup (you can also use [llm](https://github.com/simonw/llm) by uncommenting one line).
3. `./sai.sh --help`
