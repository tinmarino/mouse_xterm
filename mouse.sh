#!/usr/bin/env bash
: <<'END_DOC'
    Mouse click to move cursor

  DESCRIPTION:
    Your readline cursor should move on mouse click

  USAGE:
    source mouse.sh && mouse_track_start
    `ctrl+l` to renable track (automatically disable when you want to scrool)

  DEPENDS:
    xterm, readline

  CODE:
    1. mouse_track_start binds the mouse strokes and enables xterm mouse reports
      - The gd_binding dictionary declare the keystrokes and binding
    2. mouse_track_cb_click is called at each mouse click
    3. mouse_track_work_null is setting the READLINE_POINT apropriately
      - Its stdin is redirected to /dev/null to avoid late surprises
  
  LICENSE:
    Copyright 2019-2023 Tinmarino <tinmarino@gmail.com>
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
END_DOC

#set -u

# Escape sequences
declare -g gs_echo_enable=$'\033[?1000;1002;1006;1015h'
declare -g gs_echo_disable=$'\033[?1000;1002;1006;1015l'
declare -g gs_echo_get_cursor_pos=$'\033[6n'

# Binding <dict>: seq -> bash function
declare -gA gd_binding=(
  [<64;]=mouse_track_cb_scroll_up
  [<65;]=mouse_track_cb_scroll_down
  ## Click (0) Begining of line + X click cb
  [<0;]=mouse_track_cb_click
  [<1;]=mouse_track_cb_click2
  [<2;]=mouse_track_cb_click3
  [<32;]=mouse_track_cb_drag1
  [<33;]=mouse_track_cb_void  # middle
  [<34;]=mouse_track_cb_void  # right
  # Dichotomically found (xterm, 67, 68 maybe too)
  [32;]=mouse_track_cb_click
  [33;]=mouse_track_cb_click2
  [34;]=mouse_track_cb_click3
)
declare -g gs_prompt_command='mouse_track_prompt_command;'
mouse_track_cb_scroll_up(){ mouse_track_tmux_proxy 'tmux copy-mode -e \; send-keys -X -N 5 scroll-up'; }
mouse_track_cb_scroll_down(){ mouse_track_tmux_proxy ''; }
mouse_track_cb_click2(){ mouse_track_tmux_proxy 'tmux paste-buffer'; }
mouse_track_cb_click3(){ mouse_track_tmux_proxy "
  tmux display-menu -T '#[align=centre]#{pane_index} (#{pane_id})' \
    'Horizontal Split'  'h' 'split-window -h' \
    'Vertical Split'    'v' 'split-window -v' \
    'Swap Up'           'u' 'swap-pane -U' \
    'Swap Down'         'd' 'swap-pane -D' \
    '#{?pane_marked_set,,-}Swap Marked' 's' 'swap-pane' \
    'Kill'              'X' 'kill-pane' \
    'Respawn'           'R' 'respawn-pane -k' \
    '#{?pane_marked,Unmark,Mark}' 'm' 'select-pane -m'\
    '#{?window_zoomed_flag,Unzoom,Zoom}' 'z' 'resize-pane -Z'
  "; }
mouse_track_cb_drag1(){ mouse_track_tmux_proxy 'tmux copy-mode -e \; send-keys -X begin-selection'; }
mouse_track_cb_drag2(){ mouse_track_tmux_proxy 'tmux copy-mode -e \; send-keys -X begin-selection'; }
mouse_track_cb_drag3(){ mouse_track_tmux_proxy 'tmux copy-mode -e \; send-keys -X begin-selection'; }


# Cursor position <string>: 50;1 (x;y) if click on line 1, column 50: starting at 1;1
declare -gi gi_cursor_x=0
declare -gi gi_cursor_y=0

# Readline begining of line, used to resure the PS1 size (especially x)
declare -gi gi_bol_x=0
declare -gi gi_bol_y=0

# Keystrokes <string>: usually output by the terminal
declare -g g_key=''
declare -g gs_ps=''

# Mouse track status <bool>: 1 tracking; 0 Not tracking
declare -gi gb_mouse_track_status=0

# Tmux command to launch
declare -g g_tmux_cmd=''

declare -g gs_logfile="${TMPDIR:-/tmp}/xterm_monitor.log"

mouse_track_version(){
  : 'Print current MouseTrack version
    Used to report issues
  '
  printf '0.02'
}


mouse_track_verify_ps1(){
  : 'Used to report issues
    Depends: xxd command
    See: https://stackoverflow.com/questions/3451993/how-to-expand-ps1
  '
  >&2 echo -e "\nP0: Printinf Raw PS1"
  local ps=$PS1
  echo -n "$ps" | xxd >&2

  >&2 echo -e "\nP1: Expanding (require bash 4.4)"
  ps=${ps@P}
  echo -n "$ps" | xxd >&2

  >&2 echo -e "\nP2: Removing everything 01 and 02"
  shopt -s extglob
  ps=${ps//$'\x01'*([^$'\x02'])$'\x02'}
  echo -n "$ps" | xxd >&2

  >&2 echo -e "\nP3: Checking warnings"
  if [[ "$ps" =~ [\x07\x1b\x9c] ]]; then
    # Check if escape inside
    # 07 => BEL
    # 1b => ESC
    # 9C => ST
    >&2 echo 'Warning: There is an escape code in your PS1 which is not betwwen \[ \]'
    >&2 echo "Tip: put \[ \] around your escape codes (ctlseqs + associated parameters)"
    echo -n "$ps" | xxd >&2
  # Check printable characters <= 20 .. 7e, and newline
  # -- Remove the trailing 0x0a (BEL)
  elif [[ "$ps" =~ [^[:graph:][:space:]] ]]; then
    >&2 echo 'Warning: There is a non printable character in PS1 which is not between \[ \]'
    >&2 echo "Tip: put \[ \] around your escape codes (ctlseqs + associated parameters)"
    echo "$ps"
    echo -n "$ps" | xxd >&2
  fi

  # Echo result
  >&2 echo -e "\nP4: Printing PS1 display lenght"
  echo "${#ps}"
}


mouse_track_report(){
  : 'Main function to report an issue'
  mouse_track_run(){
    echo -e "\n\e[34m----------------------------------------------------------"
    echo -e "MouseTrack run: $*\e[0m"
    "$@"
  }
  mouse_track_run mouse_track_verify_ps1
  mouse_track_run pstree -sp $$
  mouse_track_run uname -a
  mouse_track_run echo "$PROMPT_COMMAND"
  mouse_track_run tail -n 500 "$gs_logfile"
  unset -f mouse_track_run
}


mouse_track_log(){
  : 'Log for debug'
  local s_pad_template=--------------------------------------------
  local pad="${s_pad_template:0:$(( (${#FUNCNAME[@]} - 1) * 2 ))}"
  { printf '%(%T)T: %s %b\n' -1 "$pad" "$*" &>> "$gs_logfile"; } &> /dev/null
}


mouse_track_echo_enable(){
  : 'Enable xterm mouse reporting (high)'
  printf '%b' "$gs_echo_enable"
  gb_mouse_track_status=1
}


mouse_track_echo_disable(){
  : 'Disable xterm mouse reporting (low)'
  printf '%b' "$gs_echo_disable"
  gb_mouse_track_status=0
}


mouse_track_read_keys_remaining(){
  : 'Read the keys left from stdin
    In: Stdin (until m)
    :arg1: timout in second
  '
  local timeout=${1:-0.001}
  # Out: $g_key
  g_key=''
  while read -r -n 1 -t "$timeout" c; do
    g_key="$g_key$c"
    # M and m for click, R for get_cursor_pos
    [[ $c == M || $c == m || $c == R || $c == '' ]] && break
  done

  mouse_track_log "Read: '$g_key'"
}


mouse_track_consume_keys(){
  local s_consumed=''
  while read -r -n 1 -t 0.001 c; do
    s_consumed="$s_consumed$c"
  done

  mouse_track_log "Consumed: '$s_consumed'"
}


mouse_track_read_cursor_pos(){
  : 'Read cursor_pos <- xterm <- readline
    Out: 50;1 (x;y) if click on line 1, column 50: starting at 1;1
    See: https://unix.stackexchange.com/questions/88296/get-vertical-cursor-position
  '
  local -i i_row=0 i_col=0  # Cannot be declared as integer. read command would fail
  local row_read


  # Read it
  {
    # Clean stdin
    mouse_track_consume_keys

    # Set echo style (no echo)
    local oldstty; oldstty=$(stty -g)
    stty raw -echo min 0

    # Ask cursor pos
    IFS=';' read -r -dR -p "$gs_echo_get_cursor_pos" row_read i_col

    # Reset echo style (display keystrokes)
    stty "$oldstty"
  } </dev/tty
  i_row=${row_read#*[}

  mouse_track_log "Pos: x=$i_col, $i_row"

  # Parse it
  if (( $# > 0 )); then
    (( gi_bol_x = i_col ))
    (( gi_bol_y = i_row ))
    mouse_track_log "Bol: x=$gi_bol_x, y=$gi_bol_y, POINT=$READLINE_POINT"
  else
    (( gi_cursor_x = i_col ))
    (( gi_cursor_y = i_row ))
    mouse_track_log "Cursor: x=$gi_cursor_x, y=$gi_cursor_y"
  fi
}


mouse_track_read_bol(){
  : 'Move the cursor to Begining of realine line'
  bind '"\za": beginning-of-line'  # C-a
  bind '"\ea": end-of-line'  # C-e
  bind '"\eb": set-mark'  # C-space

  # Move cursor to BOL
  printf '%b' 'za' > /dev/tty
  echo -e "\e[12H"

  READLINE_POINT=100

  mouse_track_read_cursor_pos bol

  mouse_track_log "TEMP: $gi_bol_x, $gi_bol_y"
}


mouse_track_trap_debug(){
  : 'Trap for stopping track at command spawn (like vim)
    Callback : traped to debug : Disable XTERM escape
  '

  # Log
  mouse_track_log "trap ($gb_mouse_track_status) for: $BASH_COMMAND"

  # Clause: mouse track disabled yet
  (( gb_mouse_track_status == 0 )) \
    && { mouse_track_log "trap to disable disregarded (already disabled)"; return; }

  # Clause: bash is completing
  [[ -v COMP_LINE && -n "$COMP_LINE" ]] \
    && { mouse_track_log "trap to disable disregarded (completing)"; return; }

  # Clause: don't cause a preexec for $PROMPT_COMMAND
  [[ "$BASH_COMMAND" == "$PROMPT_COMMAND" ]] \
    && { mouse_track_log "trap to disable disregarded (prompt command)"; return; }

  # Clause: bound from myself for example at scroll
  [[ "$BASH_COMMAND" =~ ^mouse_track* ]] \
    && { mouse_track_log "trap to disable disregarded (self call)"; return; }

  # Log
  mouse_track_log "trap to disable passed clause. Stoping mouse tracking..."

  # Disable mouse as callback
  mouse_track_echo_disable
}


mouse_track_work_null(){
  : 'Work in null'
  local -i i_row_offset=0 i_readline_point=0

  mouse_track_log
  mouse_track_log
  mouse_track_log "---------------- Mouse click with $g_key"
  
  # Clause: g_key defined: I need coordinates
  [[ -z "$g_key" ]] && {
    mouse_track_log "WARNING: a click without coordinate associated"
    return 0
  }

  # Clause: Only work for M
  local mode=${g_key: -1}
  [[ "$mode" == m ]] && {
    mouse_track_log "Release ignored"
    return 0
  }

  # # Log readline pre value
  # mouse_track_log "Readline point, line, mark..."
  # mouse_track_log "$(echo "$READLINE_POINT, $READLINE_LINE, $READLINE_MARK" | xxd)"

  # Get click (x1, y1)
  local xy=${g_key:0:-1}
  local -i i_click_x=${xy%%;*}
  local -i i_click_y=${xy##*;}
  mouse_track_log "Click: x=$i_click_x, y=$i_click_y"

  # Get Cursor position (x0, y0)
  mouse_track_read_cursor_pos

  # Calculate PS1 len
  local -i i_ps1; i_ps1=$(mouse_track_ps1_len)

  # Calculate line position
  (( i_row_offset = i_click_y - gi_cursor_y ))
  (( i_row_offset < 0 )) && (( i_row_offset = 0 ))

  # Retrieve lines
  readarray -t a_line <<< "$READLINE_LINE"
  # Log line
  local s_line
  local -i i_line_log=1
  for s_line in "${a_line[@]}"; do
    mouse_track_log "Array line: $((i_line_log++)): $s_line"
  done

  # Add y <= Parse preceding rows
  local -i i_current_row=0
  local -i i_current_sub_row=0  # Wrap
  local -i i_visual_row=0  # sum
  while (( i_current_row + i_current_sub_row <= i_row_offset )); do
    # Search wrap
    local i_max_len=$COLUMNS
    (( i_current_row == 0 && i_current_sub_row == 0 )) && (( i_max_len -= i_ps1 ))
    local s_line=${a_line[$i_current_row]}
    local i_line=${#s_line}

    (( i_visual_row == 0  )) \
      && (( i_current_sub_row > 0 )) \
      && (( i_line -= i_ps1 ))

    # If in wrap second line: Remove the already parsed lines
    (( i_current_sub_row > 0 )) \
      && (( i_line -= COLUMNS * i_current_sub_row ))

    mouse_track_log "Line: $i_current_row + $i_current_sub_row = $i_visual_row, point0=$i_readline_point, max: ${#READLINE_LINE}"

    # Clause: Do not append the last line len
    # -- So clicking below will position cursor on last line
    # Todo, this does no take long wrap into account, and break too fast
    if (( i_visual_row == i_row_offset )); then
        # && (( i_line < i_max_len )); then
      mouse_track_log "Arith41: break"
      break
    fi

    local -i i_to_add_line=0
    if (( i_line > i_max_len )); then
      mouse_track_log "Arith0: line:$i_line, max:$i_max_len, col=$COLUMNS, sub=$i_current_sub_row"
      # Wrap
      (( i_current_sub_row += 1 ))
      (( i_to_add_line = i_max_len ))
    else
      mouse_track_log "Arith1: line:$i_line, max:$i_max_len, col=$COLUMNS, sub=$i_current_sub_row"
      (( i_current_row += 1 )); (( i_current_sub_row = 0 ))
      (( i_to_add_line = i_line + 1 ))
    fi

    # Clause: Stop if last line
    if (( i_readline_point + i_to_add_line >= ${#READLINE_LINE} )); then
      mouse_track_log "Arith42: break"
      break
    fi

    (( i_readline_point += i_to_add_line ))
    (( i_visual_row +=1 ))
  done

  # Add x
  #if (( i_visual_row == i_row_offset )); then
    local -i i_last_add=$(( i_click_x - gi_cursor_x ))
    mouse_track_log "R1: $i_readline_point, Line: $i_line, Add: $i_last_add"
    # -- Feature: if click after the line last character, stay on this line
    (( i_visual_row == 0 )) && (( i_last_add -= i_ps1 ))
    # ---- TODO: restore from above 
    (( i_last_add > i_line )) && (( i_last_add = i_line ))
    (( i_readline_point += i_last_add ))
    mouse_track_log "R2: $i_readline_point"
    mouse_track_log "i_row_offset=$i_row_offset, i_visual_row=$i_visual_row, i_readline_point=$i_readline_point"
  #fi

  # Move cursor
  export READLINE_POINT=$i_readline_point

  # Log readline post value
  mouse_track_log "Readline post: $READLINE_POINT, $READLINE_LINE, $READLINE_MARK"

  # TODO
  # Restore ssty
  #stty "$s_oldstty"
}


mouse_track_cb_click(){
  : 'Callback for mouse button 0 click/release'

  # Disable mouse to avoid an other click during the call
  mouse_track_echo_disable
  trap mouse_track_echo_enable RETURN

  mouse_track_read_keys_remaining 0.001

  # Redraw to avoid long blink (still have a short one)  # redraw-current-line
  echo -ne "\e[0n"

  # Do not accept input while processing
  mouse_track_work_null < /dev/null

  # Redraw to avoid waiting for user action   # redraw-current-line
  echo -ne "\e[0n"
}

mouse_track_ps1_len(){
  : 'Get display lenght of PS1
    Ref1: https://stackoverflow.com/questions/3451993/how-to-expand-ps1
  '
  gs_ps=$PS1
  local -i res=${#PS1}

  # Expand: Warning, need bash 4.4
  gs_ps=${gs_ps@P}

  # Just consider last line
  gs_ps=${gs_ps##*$'\n'}

  # Remove everything 01 and 02"
  shopt -s extglob
  gs_ps=${gs_ps//$'\x01'*([^$'\x02'])$'\x02'}

  # Sanitize, in case
  gs_ps=$(LC_ALL=C sed '
    # Safety
    s/\x01\|\x02//g;

    # Safety Remove OSC https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands
    # 20 .. 7e => printable characters
    # 07 => BEL
    # 9C => ST
    # 1b 5C => ESC + BS
    s/\x1b\][0-9;]*[\x20-\x7e]*\([\x07\x9C]\|\x1b\\\)//g;

    # Safety: Remove all escape sequences https://superuser.com/questions/380772/removing-ansi-color-codes-from-text-stream
    s/\x1b\[[0-9;]*[a-zA-Z]//g;
  ' <<< "$gs_ps")

  # Bye
  res=${#gs_ps}
  mouse_track_log "PS1 (calculated): len=$res, content='$gs_ps'"
  #mouse_track_log "$(echo -n "$gs_ps" | xxd)"

  # Return
  echo "$res"
}

mouse_track_cb_void(){
  : 'Callback : clean xterm and disable mouse escape'
  mouse_track_read_keys_remaining 0.001
  mouse_track_log "Cb: Void with: $g_key"
}

mouse_track_tmux_get_command(){
  : 'Get the tmux command to rebind'
  g_tmux_cmd="$(tmux list-keys -T root "$1" | sed "s/^[^W]*$1 /tmux /")"
  #g_tmux_cmd="$(echo 'if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= \"#{pane_in_mode}\" \"send-keys -M\" \"copy-mode -et=\""')"
}


mouse_track_tmux_proxy(){
  local s_tmux_cmd="$1"
  mouse_track_read_keys_remaining 0.001
  mouse_track_log "Cb: tmux proxy cmd: $s_tmux_cmd, keys remaining: $g_key"

  # Tmux case
  if command -v tmux &> /dev/null \
      && [[ -n "$TMUX" ]] \
      ; then
    # Launch mux scroll:
    # In job so that realine binding returns before => I can see the current line
    # In subshell to avoid job control stderr
    mouse_track_log "Cb: tmux proxy2 start job $s_tmux_cmd"
    ( {
      sleep 0.01
      #mouse_track_tmux_get_command "$s_tmux_cmd"
      # shellcheck disable=SC2046,SC2086  # Quote this to prevent wor
      eval "$s_tmux_cmd"
      #tmux if-shell -F -t = "#{||:#{mouse_any_flag},#{pane_in_mode}}" "select-pane -t=; send-keys -M" "display-menu -t= -xM -yM -T \"#[align=centre]#{pane_index} (#{pane_id})\"  '#{?mouse_word,Search For #[underscore]#{=/9/...:mouse_word},}' 'C-r' {copy-mode -t=; send -Xt= search-backward \"#{q:mouse_word}\"} '#{?mouse_word,Type #[underscore]#{=/9/...:mouse_word},}' 'C-y' {send-keys -l -- \"#{q:mouse_word}\"} '#{?mouse_word,Copy #[underscore]#{=/9/...:mouse_word},}' 'c' {set-buffer -- \"#{q:mouse_word}\"} '#{?mouse_line,Copy Line,}' 'l' {set-buffer -- \"#{q:mouse_line}\"} '' 'Horizontal Split' 'h' {split-window -h} 'Vertical Split' 'v' {split-window -v} '' 'Swap Up' 'u' {swap-pane -U} 'Swap Down' 'd' {swap-pane -D} '#{?pane_marked_set,,-}Swap Marked' 's' {swap-pane} '' 'Kill' 'X' {kill-pane} 'Respawn' 'R' {respawn-pane -k} '#{?pane_marked,Unmark,Mark}' 'm' {select-pane -m} '#{?window_zoomed_flag,Unzoom,Zoom}' 'z' {resize-pane -Z}"
      mouse_track_log "Cb: Button 2, tmux async finish $s_tmux_cmd -> $g_tmux_cmd"
      mouse_track_log "tmux $g_tmux_cmd"
    } & )
    return 0
  fi

  mouse_track_cb_void
}


mouse_track_cb_scroll_down(){
  mouse_track_log 'Cb: Scroll Down'
  mouse_track_read_keys_remaining 0.001
}


mouse_track_set_bindings(){
  : 'Set all global bindings (mouse event callbacks)'
  local s_keyseq=''
  mouse_track_log 'Set bindings'
  for s_keyseq in "${!gd_binding[@]}"; do
    mouse_track_log "Bind: $s_keyseq => ${gd_binding[$s_keyseq]}"
    local s_fct=${gd_binding[$s_keyseq]}
    bind -x "\"\033[$s_keyseq\":$s_fct"
  done
}


mouse_track_unset_bindings(){
  : 'Unset all global bindings (mouse event callbacks)'
  local s_keyseq=''
  mouse_track_log 'Unset bindings'
  for s_keyseq in "${!gd_binding[@]}"; do
    mouse_track_log "Unbind: $s_keyseq => ${gd_binding[$s_keyseq]}"
    local s_fct=${gd_binding[$s_keyseq]}
    bind -r "\033[$s_keyseq"
  done
}


mouse_track_prompt_command(){
  : 'Disable mouse tracking'
  command -v mouse_track_echo_enable &> /dev/null \
    && mouse_track_echo_enable
}


mouse_track_start(){
  : 'Init : Enable mouse tracking'
  mouse_track_set_bindings

  # Disable mouse tracking before each command
  trap mouse_track_trap_debug DEBUG

  # Enable mouse tracking after command return
  if [[ ! "$PROMPT_COMMAND" =~ $gs_prompt_command ]]; then
    # Append ";" in case PROMPT_COMMAND is already defined
    [[ -v PROMPT_COMMAND ]] && [[ -n "$PROMPT_COMMAND" ]] && [[ "${PROMPT_COMMAND: -1}" != ";" ]] && PROMPT_COMMAND+="; "
    export PROMPT_COMMAND+=$gs_prompt_command
  fi

  # Enable now anyway
  mouse_track_echo_enable
}


mouse_track_stop(){
  : 'Finish : Disable mouse tracking
  '
  mouse_track_echo_disable

  ## Remove echo_enable from PROMPT_COMMAND
  if [[ ! "$PROMPT_COMMAND" =~ $gs_prompt_command ]]; then
    export PROMPT_COMMAND=${PROMPT_COMMAND//$gs_prompt_command/}
  fi

  # Unset binding
  mouse_track_unset_bindings
}


# The fonction must be exported in case a bash subshell is entered
export -f mouse_track_prompt_command
