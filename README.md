# Mouse support on readline

The following code enables clicks to move cursor in bash/readline on terminal emulators.

1. Enable xterm mouse tracking reporting   
2. Set readline bindings to consume the escape sequence generated by clicks    

Tested on xterm and: alacritty, kitty, gnome-terminal

## Quickstart

In a bash shell, source [mouse.sh](./mouse.sh).

```bash
eval "$(curl -X GET https://raw.githubusercontent.com/tinmarino/mouse_xterm/master/mouse.sh)" && mouse_track_start
```

Or permanently
  
```bash
git clone --depth=1 https://github.com/tinmarino/mouse_xterm Mouse && cd Mouse
source mouse.sh && mouse_track_start  # This can be in your bashrc
```

## TODO

* Get log with call depth
* If at after last character of a line, put cursor at lat char of this line <= and not the next line as calculated now
* Avoid terminal  blinking when trigger readline
* Clearify arithmetic
* Create a tmux bind-key to MouseDown1Pane (currently it is select-pane)
* Take care of other buttons: 2 and 3 that are entering escpe sequeence in terminal
* Pressing Escape and mouse is escaping the mouse and then do not get the readline binding

## Xterm

Xterm have a mouse tracking feature

```bash
printf '\e[?1000;1006;1015h' # Enable tracking
printf '\e[?1000;1006;1015l' # Disable tracking
read  # Read and prrint stdin full escape sequences, escape look like ^[, click like ^[[<0;36;26M
man console_codes  # Some of them
vim /usr/share/doc/xterm/ctlseqs.txt.gz  # ctlseqs local documentation
```

* Mouse click looks like `\e[<0;3;21M` and a release `\e[<0;3;21`. Where `2` is x (from left) and `22` is y (from top)  
* Mouse whell up : `\e[<64;3;21M`
* Mouse whell down : `\e[<65;3;21M`
* Press `C-v` after enabling the mouse tracking to see that

## Bash, Readline

Multiple lines: press `<C-v><C-j>` for line continuation (or just `<C-J>`, if `bind '"\n": self-insert'`)

Readline can trigger a bash callback

```bash
bind -x '"\e[<64;": mouse_void_cb' # Cannot be put in .inputrc
bind    '"\C-h"   : "$(date) \e\C-e\ef\ef\ef\ef\ef"' #Can be put in .inputrc
```

Readline can call multiple functions

```bash
# Mouse cursor to begining-of-line before calling click callback
bind    '"\C-98" : beginning-of-line'
bind -x '"\C-99" : mouse_0_cb'
bind    '"\e[<0;": "\C-98\C-99"'
```

Readline callback can change cursor (point) position with `READLINE_POINT` environment variable

```bash
bind -x '"\C-h"  : xterm_test'
function xterm_test {
  printf "%s" "line is $READLINE_LINE and point $READLINE_POINT and mark $READLINE_LINE"
  READLINE_POINT=24    # The cursor position (0 for begining of command)
  READLINE_LINE='coco' # The command line current content
}
```


## Perl (reply)

TODO no comment yet, I could not invoke a readline command or I would have lost $term->{point}

## Python (ipython)

Ipython supports mouse. See [Ipython/terminal/shortcuts](https://github.com/ipython/ipython/blob/master/IPython/terminal/shortcuts.py) -> [Prompt-toolkit/bingin.mouse](https://github.com/prompt-toolkit/python-prompt-toolkit/blob/master/prompt_toolkit/key_binding/bindings/mouse.py)

	ipython --TerminalInteractiveShell.mouse_support=True

Or to enable at startup write in `.ipython/profile_default/ipython_config.py`

	c = get_config()
	c.TerminalInteractiveShell.mouse_support

## Limitations

* OK : bash, ipython3, tmux
* NO : python, reply
* DISABLED : vim

## Changelog

* Fix: sleep at read cursor if keep cmouse click
* Add date to log

## Links

* [Xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
* [Ctrl keys as used in vim source](https://github.com/vim/vim/blob/master/src/libvterm/doc/seqs.txt)
* [zsh script for mouse tracking](https://github.com/stephane-chazelas/misc-scripts/blob/master/mouse.zsh) : the same but in zsh (not bash)
* [term-mouse](https://github.com/CoderPuppy/term-mouse): the same but in Js
* [so: how to expand PS1](https://stackoverflow.com/questions/3451993/how-to-expand-ps1)
* [so: how to get cursor position](https://unix.stackexchange.com/questions/88296/get-vertical-cursor-position)
* [doc: dec_ansi_parser with drawing](https://vt100.net/emu/dec_ansi_parser)
* [doc: A Prompt the Width of Your Term](https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x869.html)
* [doc: list of ANSI ctlseq](https://www.aivosto.com/articles/control-characters.html)
