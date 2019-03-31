#!/usr/bin/bash
<<'END_DOC'
    Mouse click to move cursor

  DESCRIPTION :
    Your readline cursor should move on mouse click

  USAGE :
    source mouse.sh && mouse_track
    `ctrl+l` to renable track (automatically disable when you want to scrool)

  DEPENDS :
    xterm, readline

  LICENSE :
    Copyright © 2019 Tinmarino <tinmarino@gmail.com>
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
END_DOC

# Embed all in a scope hiddder
function mouse_track_scope_hidder {
# Mouse track status : 1 tracking; 0 Not tracking
mouse_track_status=0


function log_mouse_track {
  # Log for debug
  :
  # echo $1 >> /tmp/xterm_monitor
}

function echo_mouse_track_enable {
  # Enable (high)
  echo -ne "\e[?1000;1006;1015h"
  mouse_track_status=1
}

function echo_mouse_track_disable {
  # Disable (low)
  echo -ne "\e[?1000;1006;1015l"
  mouse_track_status=0
}

function read_mouse_keys_remaining {
  # Read $keys <- Stdin (until 'm')
  log_mouse_track "---------------"
  keys=""
  while  read -n 1 c; do
    keys="$keys$c"
    [[ $c == 'M' || $c == 'm' ]] && break
  done
  log_mouse_track "keys = $keys"
}

function read_cursor_pos {
  # Read $cursor_pos <- xterm <- readline
  echo -en "\E[6n"
  read -sdR cursor_pos
  cursor_pos=${cursor_pos#*[}
  log_mouse_track "cursor_pos $cursor_pos"
}

function trap_disable_mouse {
  # Leave if mouse disabled yet
  [[ $mouse_track_status == 0 ]] && return

  # Callback : traped to debug : Disable XTERM escape
  log_mouse_track "trap : for : $BASH_COMMAND"

  # Leave for some commands
  [ -n "$COMP_LINE" ] && return  # do nothing if completing
  [ "$BASH_COMMAND" = "$PROMPT_COMMAND" ] && return # don't cause a preexec for $PROMPT_COMMAND
  [[ "$BASH_COMMAND" =~ \s*ipy.* ]] && return # ipython : can keep bindings

  # Disable mouse as callback
  log_mouse_track "trap : Disabling mouse"
  echo_mouse_track_disable
}

function mouse_0_cb {
  local x0 y0 x1 y1 xy col line_pos
  # Callback for mouse button 0 click/release
  # Read rest
  read_mouse_keys_remaining
  xy=${keys:0:-1}
  let x1=${xy%%;*}
  let y1=${xy##*;}

  # Get mouse position (bol)
  read_cursor_pos
  x0=${cursor_pos##*;}
  y0=${cursor_pos%%;*}

  # Calculate line position
  let col=$y1-$y0
  [[ col -lt 0 ]] && let col=0
  let col=$col*$COLUMNS
  let line_pos="$x1 - $x0 - 2 + $col"
  log_mouse_track "x1 = $x1 && y1 = $y1 && line_pos = $line_pos"
  log_mouse_track "x0 = $x0 && y0 = $y0 && cursor_pos = $cursor_pos"
  log_mouse_track "col = $col"
  # TODO if too low, put on last line

  # Move cursor
  READLINE_POINT=$line_pos

  # Enable listen for next click
  echo_mouse_track_enable
}

function mouse_void_cb {
  # Callback : clean xterm and disable mouse escape
  read_mouse_keys_remaining
  echo_mouse_track_disable
}

function mouse_track_start_hidden {
  # Init : Enable mouse tracking
  # Utils
  bind    '"\C-91": clear-screen'
  bind -x '"\C-92": printf "\e[?1000;1006;1015h"'
  bind -x '"\C-91": printf "\e[?1000;1006;1015l"'
  bind    '"\C-98": beginning-of-line'
  bind -x '"\C-99": mouse_0_cb'

  # Bind Click
  bind '"\e[<0;": "\C-98\C-99"'
  bind -x '"\e[<64;": mouse_void_cb'
  bind -x '"\e[<65;": mouse_void_cb'

  # Bind C-l to reenable mouse
  bind '"\C-l": "\C-91\C-92"'

  # Disable mouse tracking before each command
  trap 'trap_disable_mouse' DEBUG

  # Enable mouse tracking after command return
  export PROMPT_COMMAND+='echo_mouse_track_enable;'
}

function mouse_track_stop_hidden {
  # Stop : Disable mouse tracking
  echo_mouse_track_disable
}

[[ $1 == 1 ]] && mouse_track_start_hidden
[[ $1 == 0 ]] && mouse_track_stop_hidden
} # End of scope_hidder


# Exports
function mouse_track_start {
  mouse_track_scope_hidder 1
}

function mouse_track_stop {
  mouse_track_scope_hidder 0
}
