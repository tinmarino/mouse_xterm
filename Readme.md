# Mouse support on readline


## Code

Xterm have a mouse tracking feature

	echo -e "\e[?1000;1006;1015h" # Enable tracking
	echo -e "\e[?1000;1006;1015l" # Disable tracking

* Mouse click looks like `\e[<0;3;21M` and a release `\e[<0;3;21`. Where `2` is x (from left) and `22` is y (from top)  
* Mouse whell up : `\e[<64;3;21M`
* Mouse whell down : `\e[<65;3;21M`
* Press `C-v` after enabling the mouse tracking to see that

Readline can trigger a bash callback

	bind -x '"\e[<64;": mouse_void_cb' # Cannot be put in .inputrc
	bind    '"\C-h"   : "$(date) \e\C-e\ef\ef\ef\ef\ef"' #Can be put in .inputrc

Readline can call multiple functions

	# Mouse cursor to begining-of-line before calling click callback
	bind    '"\C-98" : beginning-of-line'
	bind -x '"\C-99" : mouse_0_cb'
	bind    '"\e[<0;": "\C-98\C-99"'

Readline callback can change cursor (point) position with environment variable

	READLINE_POINT=24    # The cursor position (0 for begining of command)
	READLINE_LINE='coco' # The command line current content

## Limitations

* OK bash ipython3
* NO python, reply
* DISABLED vim

## Links

* [Xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
* [Ctrl keys as used in vim source](https://github.com/vim/vim/blob/master/src/libvterm/doc/seqs.txt)
* [zsh script for mouse tracking](https://github.com/stephane-chazelas/misc-scripts/blob/master/mouse.zsh) : the same but in zsh (not bash)