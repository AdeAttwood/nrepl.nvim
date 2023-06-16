# NREPL NVIM

A super simple Clojure nrepl plugin for neovim. Just enough to evaluate your
code quickly from nvim buffer.

## Why? There are other plugins that to this.

Yea but they also do *a lot* more. Most notably conjure, the plugin this is
inspired by supports multiple languages and provides a lot of the same
functionality of the LSP.

This plugin aims to take the Unix philosophy and only focuses on the execution
of code on the repl. It leaves the language intelligence to specialized tools.

This plugin also does not handle the management of your repl process. It will
only connect if there is a `.nrepl-port` file in the current directory. You
will need to spawn the repl in another terminal.

## Quick start

Start up your repl in another terminal.

```sh
clojure -Sdeps '{:deps {nrepl/nrepl {:mvn/version "LATEST"}}}' -M -m nrepl.cmdline --interactive
```

Open a clojure file in nvim and connect to the running repl.

```
:NreplConnect
```

There are two key bindings to evaluate you code. You can evaluate the buffer
or expression.

| Key Binding | Description                     |
| ----------- | ------------------------------- |
| <leader>ee  | Evaluate the current expression |
| <leader>eb  | Evaluate the current buffer     |

## The log buffer

The output from your last execution will be printed as virtual text at the
current point. All the rest will be added to a buffer called `ReplLog`. This is
a normal buffer, and you can open it however you want. For example, you can use
`vsplit`

```
:vsplit ReplLog
```
