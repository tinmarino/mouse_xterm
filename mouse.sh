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
END_DOC

# Keystrokes <string>: usually output by the terminal
g_key=''
# Mouse track status <int>: 1 tracking; 0 Not tracking
g_mouse_track_status=0
# Binding <dict>: seq -> bash function
declare -A g_binding=(
  ["<63;"]="mouse_track_cb_scroll_down"
  ["<64;"]="mouse_track_cb_scroll_up"
  ## Click (0) Begining of line + X click cb
  ["<0;"]="mouse_track_cb_click"
  # Dichotomically found (xterm, 67, 68 maybe too)
  ["32;"]="mouse_track_cb_click"
  ["35;"]="mouse_track_cb_click"
)
# Cursor position <string>: 50;1 (x;y) if click on line 1, column 50: starting at 1;1
g_cursor_pos='1;1'

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
  # Out: $g_key
  mouse_track_log "--------------- Reading keys"
  g_key=""
  # TODO ugly 0.001 sec timeout
  while read -rt 0.001 -n 1 c; do
    mouse_track_log "reading $c"
    g_key="$g_key$c"
    [[ $c == 'M' || $c == 'm' || $c == 'R' || $c == '' ]] && break
  done
  mouse_track_log "g_key = $g_key"
}

mouse_track_read_cursor_pos() {
  # Read $cursor_pos <- xterm <- readline
  # Out: 50;1 (x;y) if click on line 1, column 50: starting at 1;1

  # Clean stdin
  mouse_track_read_keys_remaining

  # Ask cursor pos
  printf "%b" "$s_echo_get_cursor_pos"

  # Read it
  read -srdR g_cursor_pos
  g_cursor_pos=${g_cursor_pos#*[}
  mouse_track_log "cursor_pos returns:  $g_cursor_pos"
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
  local x0 y0 x1 y1 col readline_point

  # Read rest
  mouse_track_read_keys_remaining
  mouse_track_log "---------------- Mouse click with $g_key"

  # Log readline pre value
  mouse_track_log "$(echo "Readline pre: $READLINE_POINT, $READLINE_LINE, $READLINE_MARK" | xxd)"

  # Only work for M
  local mode=${g_key: -1}
  [[ "$mode" == m ]] && {
    mouse_track_log "Release ignored"
    return 0
  }

  # Get click (x1, y1)
  local xy=${g_key:0:-1}
  local x1=${xy%%;*}
  local y1=${xy##*;}

  # Get Cursor position (x0, y0)
  mouse_track_read_cursor_pos
  (( x0=${g_cursor_pos##*;} ))
  (( y0=${g_cursor_pos%%;*} ))
  mouse_track_log "x0 = $x0 && y0 = $y0 && g_cursor_pos = $g_cursor_pos"
  mouse_track_log "x1 = $x1 && y1 = $y1"

  # Calculate line position
  (( col = y1 - y0 ))
  (( col < 0 )) && (( col = 0 ))
  readarray -t a_line <<< "$READLINE_LINE"
  for i in "${a_line[@]}"
  do
      mouse_track_log "Array line: $i"
  done
  (( readline_point = x1 - x0 - 2 + col * COLUMNS ))
  mouse_track_log "col = $col && readline_point = $readline_point"
  # TODO if too low, put on last line

  # Move cursor
  export READLINE_POINT=$readline_point

  # Log readline post value
  mouse_track_log "Readline post: $READLINE_POINT, $READLINE_LINE, $READLINE_MARK"
}


mouse_track_cb_void() {
  # Callback : clean xterm and disable mouse escape
  mouse_track_read_keys_remaining
  mouse_track_log "Cb: Void with: $g_key"
  #mouse_track_stop
}


mouse_track_cb_scroll_up() {
  mouse_track_read_keys_remaining
  mouse_track_log "Cb: Scroll Up with: $g_key"

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
  #printf "%b" "$s_echo_enable$s_bindx_3$g_key"
}

mouse_track_cb_scroll_down() {
  mouse_track_log 'Cb: Scroll Down'
  mouse_track_read_keys_remaining
  #printf "%b" "$s_echo_enable$s_bindx_4$g_key"
}


mouse_track_set_bindings() {
  mouse_track_log 'Set bindings'
  for s_keyseq in "${!g_binding[@]}"; do
    local s_fct=${g_binding[$s_keyseq]}
    bind -x "\"\033[$s_keyseq\":$s_fct"
  done
}


mouse_track_unset_bindings() {
  # Unset mouse event callback binding
  mouse_track_log 'Unset bindings'
  for s_keyseq in "${!g_binding[@]}"; do
    local s_fct=${g_binding[s_keyseq]}
    bind -r "$s_keyseq"
  done
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
  # Finish : Disable mouse tracking
  # Disable mouse tracking
  mouse_track_echo_disable

  # Unset binding
  mouse_track_unset_bindings
}
