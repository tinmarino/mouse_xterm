#!/usr/bin/env bash
: <<'END_DOC'
    Mouse click to move cursor

  DESCRIPTION :
    Your readline cursor should move on mouse click

  USAGE :
    source mouse.sh && mouse_track
    `ctrl+l` to renable track (automatically disable when you want to scrool)

  DEPENDS :
    xterm, readline

  LICENSE :
    Copyright 2019-2021 Tinmarino <tinmarino@gmail.com>
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
  TODO
    remove beginning of line
    Avoid blocking realine if scroll up: I do not see the line
END_DOC

# Keys (usually output by the terminal)
g_keys=''
# Mouse track status : 1 tracking; 0 Not tracking
g_mouse_track_status=0


# Escape sequences
s_echo_enable='\033[?1000;1006;1015h'
s_echo_disable='\033[?1000;1006;1015l'
s_echo_get_cursor_pos='\033[6n'

mouse_track_log() {
  # Log for debug
  :
  printf "%b\n" "$*"  >> /tmp/xterm_monitor
}


mouse_track_echo_enable() {
  # Enable (high)
  printf "%b" "$s_echo_enable"
  g_mouse_track_status=1
}


mouse_track_echo_disable() {
  # Disable (low)
  printf "%b" "$s_echo_disable"
  g_mouse_track_status=0
}


mouse_track_read_keys_remaining() {
  # In: Stdin (until 'm')
  # Out: $g_keys
  mouse_track_log "--------------- Reading keys"
  g_keys=""
  # TODO ugly 0.001 sec timeout
  while read -rt 0.001 -n 1 c; do
    mouse_track_log "reading $c"
    g_keys="$g_keys$c"
    [[ $c == 'M' || $c == 'm' || $c == 'R' || $c == '' ]] && break
  done
  mouse_track_log "g_keys = $g_keys"
}

mouse_track_read_cursor_pos() {
  # Read $cursor_pos <- xterm <- readline

  # Clean stdin
  mouse_track_read_keys_remaining

  # Ask cursor pos
  printf "%b" "$s_echo_get_cursor_pos"

  # Read it
  read -srdR cursor_pos
  cursor_pos=${cursor_pos#*[}
  mouse_track_log "cursor_pos $cursor_pos"
}


mouse_track_trap_disable_mouse() {
  # Trap for stopping track at command spawn (like vim)
  # Callback : traped to debug : Disable XTERM escape

  # log
  mouse_track_log "trap ($g_mouse_track_status) for : $BASH_COMMAND"

  # Clauses: leave if ...
  # -- mouse track disabled yet
  [[ $g_mouse_track_status == 0 ]] \
      || [[ -n "$COMP_LINE" ]] \
      || [[ "$BASH_COMMAND" == "$PROMPT_COMMAND" ]] \
      || [[ "$BASH_COMMAND" =~ ^mouse_track* ]] \
      && { mouse_track_log "trap disregarded (clause)"; return; }
      # -- bash is completing
      # -- don't cause a preexec for $PROMPT_COMMAND
      # -- bind from myself for example at scroll

  # Disable mouse as callback
  mouse_track_log "trap : Stoping mouse tracking"
  mouse_track_stop
}


mouse_track_cb_click() {
  # Callback for mouse button 0 click/release
  local x0 y0 x1 y1 col line_pos

  # Read rest
  mouse_track_read_keys_remaining
  mouse_track_log "Mouse click with $g_keys"

  # Only work for M
  local mode=${g_keys: -1}
  [[ "$mode" == m ]] && {
    mouse_track_log "Release ignored"
    return 0
  }

  # Get click X,y
  local xy=${g_keys:0:-1}
  local x1=${xy%%;*}
  local y1=${xy##*;}
  mouse_track_log "x1 = $x1 && y1 = $y1"

  # Get mouse position (bol)
  mouse_track_read_cursor_pos
  (( x0=${cursor_pos##*;} ))
  (( y0=${cursor_pos%%;*} ))
  mouse_track_log "x0 = $x0 && y0 = $y0 && cursor_pos = $cursor_pos"

  # Calculate line position
  (( col = y1 - y0 ))
  (( col < 0 )) && (( col = 0 ))
  (( col = col * COLUMNS ))
  (( line_pos = x1 - x0 - 2 + col ))
  mouse_track_log "col = $col && line_pos = $line_pos"
  # TODO if too low, put on last line

  # Move cursor
  export READLINE_POINT=$line_pos
}


mouse_track_cb_void() {
  # Callback : clean xterm and disable mouse escape
  mouse_track_read_keys_remaining
  mouse_track_log "Cb: Void with: $g_keys"
  #mouse_track_stop
}


mouse_track_cb_scroll_up() {
  mouse_track_read_keys_remaining
  mouse_track_log "Cb: Scroll Up with: $g_keys"

  # Tmux case
  if command -v tmux &> /dev/null \
      && [[ -n "$TMUX" ]] \
      ; then
    # Launch mux scroll:
    # In job so that realine binding returns before => I can see the current line
    # In subshell to avoid job control stderr
    mouse_track_log 'Cb: Scroll Up -> Tmux, lauching job in subshell'
    ( {
      sleep 0.01
      mouse_track_log 'Cb: Scroll Up, tmux async start'
      tmux copy-mode -e
      tmux select-pane
      tmux send-keys -X -N 5 scroll-up
      mouse_track_log 'Cb: Scroll Up, tmux async finish'
    } & )
    mouse_track_log 'Cb: Scroll Up, tmux returning'
    return 0
  fi

  mouse_track_cb_void
  #printf "%b" "$s_echo_enable$s_bindx_3$g_keys"
}

mouse_track_cb_scroll_down() {
  mouse_track_log 'Cb: Scroll Down'
  mouse_track_read_keys_remaining
  #printf "%b" "$s_echo_enable$s_bindx_4$g_keys"
}


mouse_track_set_bindings() {
  # Set Bindings
  ## TODO remove beginning of line

  mouse_track_log "binding: 93 -> Beginning of line (Readline)"
  local s_bind_to_bol='\C-93'
  bind "\"$s_bind_to_bol\":begining-of-line"

  mouse_track_log "binding: 94 -> Click (eXecute)"
  local s_bindx_to_click='\C-94'
  bind -x "\"$s_bindx_to_click\":mouse_track_cb_click"

  mouse_track_log 'binding: Scrool up (eXecute)'
  bind -x "\"\033[<64\":mouse_track_cb_scroll_up"

  mouse_track_log 'binding: Scrool down (eXecute)'
  bind -x "\"\033[<65;\":mouse_track_cb_scroll_down"

  mouse_track_log 'binding: Click -> 93 + 94 (Readline)'
  ## Click (0) Begining of line + X click cb
  bind "\"\033[<0;\":\"$s_bindx_to_click\""
  # Dichotomically foun
  bind "\"\033[32;\":\"$s_bindx_to_click\""
  bind "\"\033[35;\":\"$s_bindx_to_click\""
}


mouse_track_start() {
  # Init : Enable mouse tracking
  mouse_track_set_bindings

  # Disable mouse tracking before each command
  trap 'mouse_track_trap_disable_mouse' DEBUG

  # Enable mouse tracking after command return
  export PROMPT_COMMAND+='mouse_track_echo_enable;'

  # Enable now anyway
  mouse_track_echo_enable
}


mouse_track_stop() {
  # Stop : Disable mouse tracking
  mouse_track_echo_disable

  # TODO remove my bindings is the clean way
  # So I need to separe data and function
}
