
# Evaluate compression libs

This is only really relevant for claude since its expensive and eats tokens.

My preference is one that is good at handling compressing things like html/web pages as well as the other regular code stuff.

Here are some project to evaluate:

Ideally they are active, easy to install across agents.

# batteries included
https://github.com/rtk-ai/rtk   - try this first
https://github.com/chopratejas/headroom

# specific tasks
https://github.com/xelektron/token-enhancer
https://github.com/mksglu/context-mode

## tunable
https://github.com/zdk/lowfat
https://github.com/yvgude/lean-ctx


# Skills

I could either copy them into these dirs and include a ref to the original for updates. Or I can write a single skill (skill-sync) that will pull down the list of skills I like/need into my current agent.

example install: npx skills add https://github.com/mattpocock/skills --skill grill-with-docs

> npx skills add -g ./my-local-skills

## code review

find a good one. architecture, and security too.

there are a bunch of them. but some are plugins. some are model specific. and some are multi agent - do I really need that?

## TDD

find a good one

## grillme

https://github.com/mattpocock/skills @ grill-with-docs


## updating docs (my custom one)

/update-docs

create my skill that will updated docs in my project. it should have these files.

The goal is to updated the docs according to the source of truth - the code itself.

For example the list of features in the README may have changed. Maybe one was removed from the code, or there are new ones worth mentioning.

I need to figure out a cadence for running this. Maybe when/after merging to main. That would help with the changelog too.


CLAUDE.md : @/AGENTS.md

AGENTS.md
    this should always be kept minimal. preferably under 20 lines. and maitain a basic index to other docs for discovery as needed.

README.md
    This is primarilly for users where they can learn how to run it, and what features it has. however it should also be usable by LLMs and point to other relevant docs as well.

docs/development.md

doc/changelog ????

docs/architecture.md       ← system design, components, data flow

docs/data-model.md          ← key entities, not entire schema since that can get out of date

docs/gotchas.md   


# Memory

This is complex since there are different memory systems and each agent has their own.

Could be a useful way to remember coding conventions and tooling across systems? Like use flox, bun, nix, etc. Use tabs, etc.

