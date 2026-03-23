# Claude Skills

Custom skills for Claude Code that integrate TDD process with test craft, and provide a reviewer's checklist for catching test anti-patterns.

## Skills

| Skill | Description |
|-------|-------------|
| **writing-effective-tests** | Combines TDD process (RED-GREEN-REFACTOR) with test craft (type selection, mocking boundaries, naming, testability patterns). Covers unit, integration, and E2E testing with real-world anti-patterns from code reviews. |
| **reviewing-tests** | Reviewer-focused skill that inverts the writing perspective — teaches how to catch bad tests, overcome reviewer biases (Green Bar, Coverage Number, Volume, Mock Confidence), and systematically evaluate test suites. |

## Install

```bash
git clone https://github.com/upendradevsingh/claude-skills.git
cd claude-skills
chmod +x install.sh
./install.sh
```

This symlinks skills into `~/.claude/skills/` so Claude Code picks them up globally across all projects.

## Update

```bash
cd claude-skills
git pull
# Symlinks auto-update — no reinstall needed
```

## Uninstall

```bash
cd claude-skills
./uninstall.sh
```

## How It Works

The `install.sh` script creates symlinks from `~/.claude/skills/<skill-name>` to the corresponding directory in this repo. Because they're symlinks, `git pull` immediately updates all skills with no extra step.

```
~/.claude/skills/
    writing-effective-tests -> /path/to/claude-skills/skills/writing-effective-tests/
    reviewing-tests -> /path/to/claude-skills/skills/reviewing-tests/
```

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with frontmatter:
   ```yaml
   ---
   name: skill-name
   description: Use when [triggering conditions]
   ---
   ```
2. Run `./install.sh` to link it
3. Test with Claude Code in any project

## License

MIT
