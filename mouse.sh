#!/usr/bin/env bash
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
    Copyright 2019 Tinmarino <tinmarino@gmail.com>
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
END_DOC

source $(dirname $)/variable.sh

# Mouse track status : 1 tracking; 0 Not tracking
mouse_track_status=0


function mouse_track_log {
  # Log for debug
  :
  # echo $1 >> /tmp/xterm_monitor
}


function mouse_track_echo_enable {
  # Enable (high)
  echo -ne $s_echo_enable
  mouse_track_status=1
}


function mouse_track_echo_disable {
  # Disable (low)
  echo -ne $s_echo_disable
  mouse_track_status=0
}


function mouse_track_read_keys_remaining {
  # Read $keys <- Stdin (until 'm')
  mouse_track_log "---------------"
  keys=""
  # TODO ugly 0.001 sec timeout
  while read -t 0.001 -n 1 c; do
    mouse_track_log "reading $c"
    keys="$keys$c"
    [[ $c == 'M' || $c == 'm' || $c == 'R' || $c == '' ]] && break
  done
  mouse_track_log "keys = $keys"
}


function mouse_track_read_cursor_pos {
  # Read $cursor_pos <- xterm <- readline

  # Clean stdin
  mouse_track_read_keys_remaining

  # Ask cursor pos
  echo -en $s_echo_get_cursor_pos

  # Read it
  read -sdR cursor_pos
  cursor_pos=${cursor_pos#*[}
  mouse_track_log "cursor_pos $cursor_pos"
}


function mouse_track_trap_disable_mouse {
  # Leave if mouse disabled yet
  [[ $mouse_track_status == 0 ]] && return

  # Callback : traped to debug : Disable XTERM escape
  mouse_track_log "trap : for : $BASH_COMMAND"

  # Leave for some commands
  [ -n "$COMP_LINE" ] && return  # do nothing if completing
  [ "$BASH_COMMAND" = "$PROMPT_COMMAND" ] && return # don't cause a preexec for $PROMPT_COMMAND

  # Disable mouse as callback
  mouse_track_log "trap : Stoping mouse tracking"
  mouse_track_stop
}


function mouse_track_0_cb {
  # Callback for mouse button 0 click/release
  local x0 y0 x1 y1 xy col line_pos

  # Read rest
  mouse_track_read_keys_remaining
  mouse_track_log "Mouse click with $keys"

  # Get click X,y
  xy=${keys:0:-1}
  let x1=${xy%%;*}
  let y1=${xy##*;}
  mouse_track_log "x1 = $x1 && y1 = $y1"

  # Get mouse position (bol)
  mouse_track_read_cursor_pos
  x0=${cursor_pos##*;}
  y0=${cursor_pos%%;*}
  mouse_track_log "x0 = $x0 && y0 = $y0 && cursor_pos = $cursor_pos"

  # Calculate line position
  let col=$y1-$y0
  [[ col -lt 0 ]] && let col=0
  let col=$col*$COLUMNS
  let line_pos="$x1 - $x0 - 2 + $col"
  mouse_track_log "col = $col && line_pos = line_pos"
  # TODO if too low, put on last line

  # Move cursor
  READLINE_POINT=$line_pos

  # Enable listen for next click
  mouse_track_echo_enable
}


function mouse_track_void_cb {
  # Callback : clean xterm and disable mouse escape
  mouse_track_read_keys_remaining
  mouse_track_stop
}


function mouse_track_bindings {
  # Binds 
  i=($s_bind_1 $s_bind_2 $s_bind_3 $s_bind_4)
  j=($s_macro_1 $s_macro_2 $s_macro_3 $s_macro_4)
  for (( k=0; k<${#i[@]}; k++ )) ; do
    mouse_track_log "binding ${i[k]} -> ${j[k]}"
    bind \"${i[k]}\":${j[k]}
  done

  # Bind -X
  i=($s_bindx_1 $s_bindx_2 $s_bindx_3 $s_bindx_4)
  j=($s_macrox_1 $s_macrox_2 $s_macrox_3 $s_macrox_4)
  for (( k=0; k<${#i[@]}; k++ )) ; do
    mouse_track_log "binding -x ${i[k]} -> ${j[k]}"
    bind -x \"${i[k]}\":${j[k]}
  done
}


function mouse_track_start {
  # Init : Enable mouse tracking
  mouse_track_bindings

  # Disable mouse tracking before each command
  trap 'mouse_track_trap_disable_mouse' DEBUG

  # Enable mouse tracking after command return
  export PROMPT_COMMAND+='mouse_track_echo_enable;'

  # Enable now anyway
  mouse_track_echo_enable
}


function mouse_track_stop {
  # Stop : Disable mouse tracking
  mouse_track_echo_disable

  # TODO remove my bindings is the clean way
  # So I need to separe data and function
}
