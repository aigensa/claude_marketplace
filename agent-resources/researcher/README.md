# researcher agent resources

Support files for `agents/researcher.md`. Install to `~/.claude/researcher/`
(the agent reads `$HOME/.claude/researcher/bin/*`):

    mkdir -p ~/.claude && cp -R agent-resources/researcher ~/.claude/researcher

Bash for the agent is restricted by `bin/hook-pretool-bash.sh` to `bin/validate.sh [dir]` only.
Requires: uv, jq.
