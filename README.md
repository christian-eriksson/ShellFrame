# Shell Script CLI

Simple framework for a CLI with multiple commands written in Bash. The commands
could be written in anylanguage as long as one can call them through bash using
an executable in the 'commands' directory. Extend the functionality with new
commands by adding `<command_name>.sh` in the `commands/` directory and making
it executable. The script needs to provide some mandatory functionallity, see
the ['add commands'-section](#add-commands).

## Installation

Install the cli by soft linking the 'cli.sh' to some directory in
your path:

```sh
ln -s {{INSTALL_PATH}}/cli.sh ~/.local/bin/{{CLI_NAME}}
```

Assuming that `~/.local/bin` is in your `$PATH`. You can then call the cli with
`{{CLI_NAME}}`. Use `-h` flag to show the help for the cli and the supported
commands.

If you want completions for the cli source the completion script:

```sh
CLI_NAME={{CLI_NAME}} . {{INSTALL_PATH}}/cli-completion.bash
```

You can add this line to your `~/.bashrc`, `~/.profile`, or some other file
which is loaded when a shell opens.

## Add Commands

To add a new command to the cli, place an executable, e.g. `one.sh`, in
the `{{INSTALL_PATH}}/commands/` directory, the `{{INSTALL_PATH}}` is the
directory where `cli.sh` and `cli-completions.bash` resides (i.e root directory
of the repo):

```txt
cli.sh
commands/
  |-- one.sh
```

The command script needs to accept the `-h` flag and display a help text for the
command then exit (with `0` status) if provided. It must also accept the `-v`
flag, for verbose output, and execute normally if it is provided (with some
extra logs if verbose logging is implemented). When `cli.sh -h` is called it
will call the executables in `commands` to compile the help text for the cli.
Similarly, the `-v` flag is passed to any executable in `commands` if
`cli.sh -v <command>` is invoked.

> **NOTE:** only commands directly in the `commands` directory needs to adhere
> to this interface. Any behavior of any potential sub-command is an
> implementation detail left to the executables in the `commands` directory.

Given that you installed the cli using `cli` as the `{{CLI_NAME}}`, you can now
call the new command with:

```sh
cli one
```

To add sub commands to the `one` command and have them be automatically detected
by the completion script. Add the executables in the `commands/one-commands/`
directory:

```txt
cli.sh
commands/
  |-- one.sh
  |-- one-commands/
  |     |-- two.js
  |     |-- three.py
```

The sub commands `two` and `three` are then suggested if you write:

```sh
cli one {tab}{tab}
# three  two
```

The `{tab}{tab}` just means pressing the tab-key twice. The `one.sh` script is
responsible for executing the chosen command, and thus need to be able to find
the sub-command script files relative to its location. If `cli one two` is
executed, the `cli.sh` script will call `commands/one.sh two`, so `one.sh` needs
to know what to do with `two`.

### Completion files

If the sub-commands are not external executables or the executables live in some
other location, you can provide the completion hints manually by creating a
completion file:

```txt
cli.sh
commands/
  |-- one.sh
  |-- one-commands/
  |     |-- two.js
  |     |-- three.py
  |-- two
  |-- two-completions.txt
```

Here the `two-completions.txt` is a regular text file with the following
content:

```txt
three
four
```

So the command `cli two` has two subcommands resulting in the following:

```sh
cli two {tab}{tab}
# three  four
```

Again, when calling the command `cli two four` the `cli.sh` script will call
make the following call `commands/two four`. Meaning that the executable `two`
needs to know how to handle the input `four`.

> **NOTE:** file names, excluding extensions, need to be unique within a
> directory as this is also the command name. However, they do not need to be
> unique to the whole directory structure.

You can also create chains of completion file and trees of sub-commands. Let's
say that `three.py` has a couple of sub-commands, `five` and `six`, and that
`two four` has two sub-commands, `seven` and `eight`. The file tree would then
look like:

```txt
cli.sh
commands/
  |-- one.sh
  |-- one-commands/
  |     |-- two.js
  |     |-- three.py
  |     |-- three-commands/
  |     |     |-- five.sh
  |     |     |-- six.sh
  |-- two
  |-- two-completions.txt
  |-- two-four-completions.txt
```

Where `two-four-completions.txt` looks like:

```txt
seven
eight
```

You would then get the following completions:

```sh
cli one three {tab}{tab}
# five  sixe
cli two four {tab}{tab}
# seven eight
```

And calling `cli one three five` would mean that the `cli.sh` script calls
`commands/one.sh three five`, where `one.sh` is responsible for making sure that
`five.sh` is called correctly (with or without calling `three.py` that is an
implementation detail left to `one.sh`). Likewise, calling `cli two four eight`
means that `cli.sh` calls `commands/two four eight`, where the `two` executable
is responsible for the implementation.

A command can have both a completions file and a commands directory. The
commands directory takes precedence while searching for completion hints, which
can make some completions files unreachable if not placed in the correct
location. In the example below this is the context of the completions files:

```txt
# one-completions.txt
two

# one-two-completions.txt
five

# three-completions.txt
six
```

and the following file structure:

```txt
cli.sh
commands/
  |-- one.sh
  |-- one-completions.txt
  |-- one-two-completions.txt <-- is never found
  |-- one-commands/
  |     |-- three.sh
  |     |-- three-completions.txt
  |     |-- three-commands/
  |     |     |-- seven.sh
  |     |-- two-commands/
  |     |     |-- four.sh
```

then you would get the following completions:

```sh
cli one {tab}{tab}
# three  two
cli one three {tab}{tab}
# seven  six
cli one two {tab}{tab}
# four   <-- MISSING: 'five' from 'one-two-completions.txt'
```

So `one-two-completions.txt` is never found because `one-commands/two-commands/`
takes precedence in the search, and since the `two-commands` directory exists
the search doesn't backtrack to look for `one-two-completions.txt`. So the
completion script steps into that directory in search for a completion file. If
you still want a completions file for `one two` you can rearrange the file tree
like so:

```txt
cli.sh
commands/
  |-- one.sh
  |-- one-completions.txt
  |-- one-commands/
  |     |-- three.sh
  |     |-- three-completions.txt
  |     |-- three-commands/
  |     |     |-- seven.sh
  |     |-- two-completions.txt <-- move completions file here!
  |     |-- two-commands/
  |     |     |-- four.sh
```

Now the search will find the `one-commands/two-completions.txt` file and also
look for the `two-commands` directory. So now you would get this completion for
`two`:

```sh
cli one two {tab}{tab}
# five  four
```

### Flag completions

You can add flags to the completions by adding flag completion files, they work
similarly to completions files. These files are named `{command}-flags.txt` and
follow the same discovery rules as `{command}-completions.txt`. If `one.sh`
accepts the flags `-q` and `-w` you should create `one-flags.txt` with the
following content:

```txt
-q
-w
```

and put it next to the `one.sh` command:

```txt
cli.sh
commands/
  |-- one.sh
  |-- one-completions.txt
  |-- one-flags.txt
```

If the `one-completions.txt` has the following content:

```txt
two
three
```

You will get the following completions:

```sh
cli one {tab}{tab}
# -q   three  two    -w
cli one -{tab}{tab}
# -q  -w
cli one -q {tab}{tab}
# three  two    -w
```

If you have flags that takes arguments you should make this known in the flag
completion file. You do this by adding a space and a hint to the flags line in
the completions file. To add a flags `-n` and `-t` that both take an argument
to the example above we update the `one-flags.txt` file:

```txt
-n <NUM>
-q
-t type of number
-w
```

The hint can be any string but it is recommended to keep it pretty short, as a
long string risks messing up the formatting. The above will result in the
following completions:

```sh
cli one {tab}{tab}
# -n     -q     three  two    -t     -w
cli one -{tab}{tab}
# -n  -q  -w
cli one -n {tab}{tab}
#        <NUM>
cli one -t {tab}{tab}
#                 type of number
cli one -t integer {tab}{tab}
# -n     -q     three  two    -w
```

### Completions for base command

If you need flag or command completions from a completions file for the base
command you need to create a `cli-completions.txt` and/or `cli-flags.txt` in the
root directory:

```txt
cli.sh
cli-completions.txt
cli-flags.txt
commands/
```

These files should have the same name as the script file, `cli.sh` in this
example, not the `{{CLI_NAME}}` used when installing the cli.

This feature could be useful if you are only using the `cli-completion.bash` for
your cli completion, but bing your own `cli.sh` script.

## Global Configuration

If you use the provided `cli.sh`, you can configure the cli with different
environments by adding one or multiple `.env.<ENVIRONMENT>` files in the root
directory of this repo. The commands will all be able to read the variables set
in these files and you can use the `-e <ENVIRONMENT>` flag to choose which file
to use.
