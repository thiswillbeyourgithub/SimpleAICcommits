# saic.sh (SimpleAICcommits)
Dead simple zsh script to use an LLM to write your commit messages

# Features
- Gets your diff either using `git add --patch` or directly from your `--staged` diff
- Conventional commit format
- Specify a prefix to the commit message to identify the commits made using saic.sh
- Customizable number of commit message suggestions
- Option to include previous commit messages for context (this makes the LLM adapt to your habits!)
- Flexible output modes: print or directly commit
- Selectable AI models (e.g., GPT-3.5-turbo, GPT-4)
- User interface options: fzf, select or dialog
- Ability to add extra context to AI prompt
- Displays AI's reasoning process
- Failsafe: automatically crash if has more than 100_000 characters
- Multiple backend: call either using openai (faster) or using [llm](https://github.com/simonw/llm/) (more extensible and supports many providers)

## How to
1. `git clone https://github.com/thiswillbeyourgithub/SimpleAICcommits`.
2. make sure you have either `openai` installed and keys setup (you can also use [llm](https://github.com/simonw/llm) by uncommenting one line).
3. `./saic.sh --help`
