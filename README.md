
# Plaintext Spaced-Repetition CLI

## What is this?

SM-2 is a spaced-repetition algorithm for facilitating active recall. It is used
in the SuperMemo implementation (among other places).

This project is a super simple, low/no-dependency, plain-text/unix-focused CLI
tool for maintaining a set of spaced-repetition flash cards.

The source cards for this project are _any plain-text file on your system_.
Simply symlink files to the `/cards` directory here, and they'll be
tracked in the SM-2 algorithm. **That's all you have to do**. Alternatively, you
can create files here directly, or copy them from elsewhere - as long as there's
a UNIX-`cat`-able file in `/cards`, it'll enter the system.

The benefit of symlinking cards is that the source content gets to stay in the
single place where it belongs and is maintained - whether its a markdown note in
a Zettelkasten directory, a text file in a journaling system, a document in a work
project, source code, etc. - while still being a candidate for active recall.

# Caveats!

- **This project is still very much an experiment!**. I'm a bash-scripting novice.
This is the most complicated bash script i've created. I can't guarantee the
safety of your data - but the source code here is quite small so you can check
it all out for yourself.
- I created this mainly for myself in order to fulfil a narrowly-focused desire 
  of mine. I'm sure XYZ spaced-repetition algorithm is superior or [this-and-that]
  active recall paradigm has replaced this or `AmazingApp.py` does this better
  already. Thanks for the suggestions, but I'm having fun here :)
- I may continue to develop and maintain this, or I may abandon it altogether.
  No promises
- This is a super-alpha version (or something. and I don't mean "super-alpha" in
the very-potent-male sense). Much - or everything - may change.

# Installing

- [REQUIRED] You likely already have `jq` available if you're the type of person
who is interested in this project (try `$which jq`)... But it if not, [install jq](https://stedolan.github.io/jq/download/)
- [REQUIRED] Set `SM2DIR` environment variable to _this directory_ in your Bash profile
- Maybe add `spaced.sh` to your path. 

# Initial Setup and Usage

- Create, symlink or copy files into `/cards`.
- Run `spaced.sh`.

The `settings.json` file is this app's entire database for now. This keeps
dependencies low and all the data user-visible.

### Flash card option

If a source file / card has three or more dashes (`---`) on a line, it will be
considered a **flash card**. That is, the first half will be shown and the user
will be prompted before seeing the second half.

Like this:

```example-card.md

Who was the first president of the USA?

----

George Washington

```

Otherwise, the entire file will be displayed at once. Either way, you'll be
asked if you recalled it:

### Prompts and interaction

- You'll be shown cards according to your prior performance.
- For each card, you'll be asked if you recalled it or not (`y/n`).
- Either way, you'll be prompted for how _well_ (or not) you recalled it
(`1-3`).
- At the end of the review, you'll be re-prompted for any cards you were shaky
  on, until you're solid on all of them (this is the SM-2 way).
- Based on your performance this time, the cards' metadata will be updated
  according to SM-2 and scheduled for future review.
- Run it again tomorrow!

# Contributing

This script is sort of a big mess. Sorry about that.

The one nice thing (for contributors) is you can run it with a `YYYY-MM-DD`
argument to enter a `debug` mode, which overrides the "last reviewed" date in
order to spoof the system and test out the algorithm.  
Like this: `./spaced.sh 2019-04-01`

Any and all refactoring, improvements, features, fixes, or requests will be
happily entertained.

The `Todo / Ideas` list below might be a good starting point.

# Todo / Ideas

- [ ] Arrive at a good name (for the project and the main script)
- [ ] Exit if `SM2DIR` isn't set
- [ ] Check if file is `cat`-able before adding to settings
- [ ] Rename lots of things (like `files: []` in the settings file)
- [ ] Generally improve user-input control flow
- [ ] Find a better approach for presenting the card internals (borders around
    the content or something)
- [ ] Provide other utility commands for reporting on cards
- [ ] Provide other standard options during run (like `spaced --help`)
- [ ] Archive cards?
- [ ] \* **Allow _portion_ of a file to be used** (Something like
    `card-file.md[[15-20]]` for lines 15-20 of `card-file.md`. In this way, when
    the file is symlinked, the filename will be used to denote the subset lines)

# References:

- https://en.wikipedia.org/wiki/SuperMemo#Description_of_SM-2_algorithm

