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

## Add Commands

To add a new command to the cli, place an executable, e.g. `one.sh`, in
the `{{INSTALL_PATH}}/commands/` directory, the `{{INSTALL_PATH}}` is the
directory where `cli.sh` resides (i.e root directory of the repo):

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

## Global Configuration

If you use the provided `cli.sh`, you can configure the cli with different
environments by adding one or multiple `.env.<ENVIRONMENT>` files in the root
directory of this repo. The commands will all be able to read the variables set
in these files and you can use the `-e <ENVIRONMENT>` flag to choose which file
to use.
