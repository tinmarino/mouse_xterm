#!/usr/bin/env bash
: <<'END_DOC'
    Mouse click to move cursor

  DESCRIPTION:
    Your readline cursor should move on mouse click

  USAGE:
    source mouse.sh && mousetrack_start
    `ctrl+l` to renable track (automatically disable when you want to scrool)

  DEPENDS:
    xterm, readline

  CODE:
    1. mousetrack_start binds the mouse strokes and enables xterm mouse reports
      - The g_mousetrack_d_binding dictionary declare the keystrokes and binding
    2. mousetrack_cb_click is called at each mouse click
    3. mousetrack_work_null is setting the READLINE_POINT apropriately
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
declare -g g_mousetrack_echo_enable=$'\033[?1000;1002;1006;1015h'
declare -g g_mousetrack_echo_disable=$'\033[?1000;1002;1006;1015l'
declare -g g_mousetrack_echo_get_cursor_pos=$'\033[6n'

# Binding <dict>: seq -> bash function
# -- Prefixed by \033[
declare -gA g_mousetrack_d_binding=(
  [<64;]=mousetrack_cb_scroll_up
  [<65;]=mousetrack_cb_scroll_down
  # Click (0) Begining of line + X click cb
  # -- ^[[<0;29;18M
  [<0;]=mousetrack_cb_click
  [<1;]=mousetrack_cb_click2
  [<2;]=mousetrack_cb_click3
  [<32;]=mousetrack_cb_drag1
  [<33;]=mousetrack_cb_void  # middle
  [<34;]=mousetrack_cb_void  # right
  # Dichotomically found (xterm, 67, 68 maybe too)
  [32;]=mousetrack_cb_click
  [33;]=mousetrack_cb_click2
  [34;]=mousetrack_cb_click3
)
declare -g g_mousetrack_prompt_command='mousetrack_prompt_command;'
mousetrack_cb_scroll_up(){ mousetrack_tmux_proxy 'tmux copy-mode -e \; send-keys -X -N 5 scroll-up'; }
mousetrack_cb_scroll_down(){ mousetrack_tmux_proxy ''; }
mousetrack_cb_click2(){ mousetrack_tmux_proxy 'tmux paste-buffer'; }
mousetrack_cb_click3(){ mousetrack_tmux_proxy "
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
mousetrack_cb_drag1(){ mousetrack_tmux_proxy 'tmux copy-mode -e \; send-keys -X begin-selection'; }
mousetrack_cb_drag2(){ mousetrack_tmux_proxy 'tmux copy-mode -e \; send-keys -X begin-selection'; }
mousetrack_cb_drag3(){ mousetrack_tmux_proxy 'tmux copy-mode -e \; send-keys -X begin-selection'; }


# Cursor position <string>: 50;1 (x;y) if click on line 1, column 50: starting at 1;1
declare -gi g_mousetrack_i_cursor_x=0
declare -gi g_mousetrack_i_cursor_y=0

# Readline begining of line, used to resure the PS1 size (especially x)
declare -gi g_mousetrack_i_bol_x=0
declare -gi g_mousetrack_i_bol_y=0

# Keystrokes <string>: usually output by the terminal
declare -g g_mousetrack_key=''
declare -g g_mousetrack_ps=''

# Mouse track status <bool>: 1 tracking; 0 Not tracking
declare -gi g_mousetrack_b_status=0

# Tmux command to launch
declare -g g_mousetrack_tmux_cmd=''

declare -g g_mousetrack_logfile="${TMPDIR:-/tmp}/xterm_monitor.log"

mousetrack_version(){
  : 'Print current MouseTrack version
    Used to report issues
  '
  printf '0.02'
}


mousetrack_verify_ps1(){
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


mousetrack_report(){
  : 'Main function to report an issue'
  mousetrack_run(){
    echo -e "\n\e[34m----------------------------------------------------------"
    echo -e "MouseTrack run: $*\e[0m"
    "$@"
  }
  mousetrack_run mousetrack_verify_ps1
  mousetrack_run pstree -sp $$
  mousetrack_run uname -a
  mousetrack_run echo "$PROMPT_COMMAND"
  mousetrack_run tail -n 500 "$g_mousetrack_logfile"
  unset -f mousetrack_run
}


mousetrack_log(){
  : 'Log for debug'
  local s_pad_template=--------------------------------------------
  local pad="${s_pad_template:0:$(( (${#FUNCNAME[@]} - 1) * 2 ))}"
  { printf '%(%T)T: %s %b\n' -1 "$pad" "$*" &>> "$g_mousetrack_logfile"; } &> /dev/null
}


mousetrack_echo_enable(){
  : 'Enable xterm mouse reporting (high)'
  printf '%b' "$g_mousetrack_echo_enable"
  g_mousetrack_b_status=1
}


mousetrack_echo_disable(){
  : 'Disable xterm mouse reporting (low)'
  printf '%b' "$g_mousetrack_echo_disable"
  g_mousetrack_b_status=0
}


mousetrack_read_keys_remaining(){
  : 'Read the keys left from stdin
    In: Stdin (until m)
    Out: g_mousetrack_key
    :arg1: timout in second
  '
  local timeout=${1:-0.001}
  g_mousetrack_key=''
  while read -r -n 1 -t "$timeout" c; do
    g_mousetrack_key="$g_mousetrack_key$c"
    # M and m for click, R for get_cursor_pos
    [[ $c == M || $c == m || $c == R || $c == '' ]] && break
  done

  mousetrack_log "Read remaining: '$g_mousetrack_key'"
}


mousetrack_consume_keys(){
  local s_consumed=''
  while read -r -n 1 -t 0 c; do
    s_consumed="$s_consumed$c"
  done

  mousetrack_log "Consumed: '$s_consumed'"
}


mousetrack_read_cursor_pos(){
  : 'Read cursor_pos <- xterm <- readline
    Out:
      gi_cursor_{x,y} 50;1 (x;y) if click on line 1, column 50: starting at 1;1
    See: https://unix.stackexchange.com/questions/88296/get-vertical-cursor-position
  '
  local -i i_row=0 i_col=0  # Cannot be declared as integer. read command would fail
  local row_read


  # Read it
  {
    # Clean stdin
    mousetrack_consume_keys

    # Set echo style (no echo)
    local oldstty; oldstty=$(stty -g)
    stty raw -echo min 0

    # Ask cursor pos
    IFS=';' read -r -dR -p "$g_mousetrack_echo_get_cursor_pos" row_read i_col

    # Reset echo style (display keystrokes)
    stty "$oldstty"
  } </dev/tty
  i_row=${row_read#*[}

  mousetrack_log "Pos: x=$i_col, $i_row"

  # Parse it
  if (( $# > 0 )); then
    (( g_mousetrack_i_bol_x = i_col ))
    (( g_mousetrack_i_bol_y = i_row ))
    mousetrack_log "Bol: x=$g_mousetrack_i_bol_x, y=$g_mousetrack_i_bol_y, POINT=$READLINE_POINT"
  else
    (( g_mousetrack_i_cursor_x = i_col ))
    (( g_mousetrack_i_cursor_y = i_row ))
    mousetrack_log "Cursor: x=$g_mousetrack_i_cursor_x, y=$g_mousetrack_i_cursor_y"
  fi
}


mousetrack_read_bol(){
  : 'Move the cursor to Begining of realine line'
  bind '"\za": beginning-of-line'  # C-a
  bind '"\ea": end-of-line'  # C-e
  bind '"\eb": set-mark'  # C-space

  # Move cursor to BOL
  printf '%b' 'za' > /dev/tty
  echo -e "\e[12H"

  READLINE_POINT=100

  mousetrack_read_cursor_pos bol

  mousetrack_log "TEMP: $g_mousetrack_i_bol_x, $g_mousetrack_i_bol_y"
}


mousetrack_trap_debug(){
  : 'Trap for stopping track at command spawn (like vim)
    Callback : traped to debug : Disable XTERM escape
  '

  # Log
  mousetrack_log "trap ($g_mousetrack_b_status) for: $BASH_COMMAND"

  # Clause: mouse track disabled yet
  (( g_mousetrack_b_status == 0 )) \
    && { mousetrack_log "trap to disable disregarded (already disabled)"; return; }

  # Clause: bash is completing
  [[ -v COMP_LINE && -n "$COMP_LINE" ]] \
    && { mousetrack_log "trap to disable disregarded (completing)"; return; }

  # Clause: don't cause a preexec for $PROMPT_COMMAND
  [[ "$BASH_COMMAND" == "$PROMPT_COMMAND" ]] \
    && { mousetrack_log "trap to disable disregarded (prompt command)"; return; }

  # Clause: bound from myself for example at scroll
  [[ "$BASH_COMMAND" =~ ^mousetrack* ]] \
    && { mousetrack_log "trap to disable disregarded (self call)"; return; }

  # Log
  mousetrack_log "trap to disable passed clause. Stoping mouse tracking..."

  # Disable mouse as callback
  mousetrack_echo_disable
}


mousetrack_work_null(){
  : 'Core arithmetic, redirecting stdin < null'
  local -i i_row_offset=0 i_readline_point=0

  mousetrack_log
  mousetrack_log
  mousetrack_log "---------------- Mouse click with $g_mousetrack_key"

  # Clause: g_mousetrack_key defined: I need coordinates
  [[ -z "$g_mousetrack_key" ]] && {
    mousetrack_log "WARNING: a click without coordinate associated"
    return 0
  }

  # Clause: Only work for M
  local mode=${g_mousetrack_key: -1}
  [[ "$mode" == m ]] && {
    mousetrack_log "Release ignored"
    return 0
  }

  # # Log readline pre value
  # mousetrack_log "Readline point, line, mark..."
  # mousetrack_log "$(echo "$READLINE_POINT, $READLINE_LINE, $READLINE_MARK" | xxd)"

  # Get click (x1, y1)
  local xy=${g_mousetrack_key:0:-1}
  local -i i_click_x=${xy%%;*}
  local -i i_click_y=${xy##*;}
  mousetrack_log "Click: x=$i_click_x, y=$i_click_y"

  # Get Cursor position (x0, y0)
  # -- This creates flinkering
  # mousetrack_read_cursor_pos

  # Calculate PS1 len
  local -i i_ps1; i_ps1=$(mousetrack_ps1_len)

  # Calculate line position
  (( i_row_offset = i_click_y - g_mousetrack_i_cursor_y ))
  (( i_row_offset < 0 )) && (( i_row_offset = 0 ))

  # Retrieve lines
  readarray -t a_line <<< "$READLINE_LINE"
  # Log line
  local s_line
  local -i i_line_log=1
  for s_line in "${a_line[@]}"; do
    mousetrack_log "Array line: $((i_line_log++)): $s_line"
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

    mousetrack_log "Line: $i_current_row + $i_current_sub_row = $i_visual_row, point0=$i_readline_point, max: ${#READLINE_LINE}"

    # Clause: Do not append the last line len
    # -- So clicking below will position cursor on last line
    # Todo, this does no take long wrap into account, and break too fast
    if (( i_visual_row == i_row_offset )); then
        # && (( i_line < i_max_len )); then
      mousetrack_log "Arith41: break"
      break
    fi

    local -i i_to_add_line=0
    if (( i_line > i_max_len )); then
      mousetrack_log "Arith0: line:$i_line, max:$i_max_len, col=$COLUMNS, sub=$i_current_sub_row"
      # Wrap
      (( i_current_sub_row += 1 ))
      (( i_to_add_line = i_max_len ))
    else
      mousetrack_log "Arith1: line:$i_line, max:$i_max_len, col=$COLUMNS, sub=$i_current_sub_row"
      (( i_current_row += 1 )); (( i_current_sub_row = 0 ))
      (( i_to_add_line = i_line + 1 ))
    fi

    # Clause: Stop if last line
    if (( i_readline_point + i_to_add_line >= ${#READLINE_LINE} )); then
      mousetrack_log "Arith42: break"
      break
    fi

    (( i_readline_point += i_to_add_line ))
    (( i_visual_row +=1 ))
  done

  # Add x
  #if (( i_visual_row == i_row_offset )); then
    local -i i_last_add=$(( i_click_x - g_mousetrack_i_cursor_x ))
    mousetrack_log "R1: $i_readline_point, Line: $i_line, Add: $i_last_add"
    # -- Feature: if click after the line last character, stay on this line
    (( i_visual_row == 0 )) && (( i_last_add -= i_ps1 ))
    # ---- TODO: restore from above
    (( i_last_add > i_line )) && (( i_last_add = i_line ))
    (( i_readline_point += i_last_add ))
    mousetrack_log "R2: $i_readline_point"
    mousetrack_log "i_row_offset=$i_row_offset, i_visual_row=$i_visual_row, i_readline_point=$i_readline_point"
  #fi

  # Move cursor
  export READLINE_POINT=$i_readline_point

  # Log readline post value
  mousetrack_log "Readline post: $READLINE_POINT, $READLINE_LINE, $READLINE_MARK"
}


mousetrack_cb_click(){
  : 'Callback for mouse button 0 click/release'
  # Hi
  mousetrack_log ''
  mousetrack_log "==> Click start at $(date +"%T.%6N")"

  # Disable mouse to avoid an other click during the call
  mousetrack_echo_disable
  trap mousetrack_echo_enable RETURN

  mousetrack_read_keys_remaining 0.001

  # Do not accept input while processing
  mousetrack_work_null < /dev/null

  # Redraw to avoid long blink (still have a short one)  # redraw-current-line
  #printf '\e[0n'

  # Bye
  mousetrack_log "<== Click end at $(date +"%T.%6N")"
  mousetrack_log ''

  return 0
}

mousetrack_ps1_len(){
  : 'Get display lenght of PS1
    Ref1: https://stackoverflow.com/questions/3451993/how-to-expand-ps1
  '
  g_mousetrack_ps=$PS1
  local -i res=${#PS1}

  # Expand: Warning, need bash 4.4
  g_mousetrack_ps=${g_mousetrack_ps@P}

  # Just consider last line
  g_mousetrack_ps=${g_mousetrack_ps##*$'\n'}

  # Remove everything 01 and 02
  shopt -s extglob
  g_mousetrack_ps=${g_mousetrack_ps//$'\x01'*([^$'\x02'])$'\x02'}

  # Sanitize, in case
  g_mousetrack_ps=$(LC_ALL=C sed '
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
  ' <<< "$g_mousetrack_ps")

  # Bye
  res=${#g_mousetrack_ps}
  mousetrack_log "PS1 (calculated): len=$res, content='$g_mousetrack_ps'"
  #mousetrack_log "$(echo -n "$g_mousetrack_ps" | xxd)"

  # Return
  echo "$res"
}

mousetrack_cb_void(){
  : 'Callback : clean xterm and disable mouse escape'
  mousetrack_read_keys_remaining 0.001
  mousetrack_log "Cb: Void with: $g_mousetrack_key"
}

mousetrack_tmux_get_command(){
  : 'Get the tmux command to rebind'
  g_mousetrack_tmux_cmd="$(tmux list-keys -T root "$1" | sed "s/^[^W]*$1 /tmux /")"
  #g_mousetrack_tmux_cmd="$(echo 'if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= \"#{pane_in_mode}\" \"send-keys -M\" \"copy-mode -et=\""')"
}


mousetrack_tmux_proxy(){
  local s_tmux_cmd="$1"
  mousetrack_read_keys_remaining 0.001
  mousetrack_log "Cb: tmux proxy cmd: $s_tmux_cmd, keys remaining: $g_mousetrack_key"

  # Tmux case
  if command -v tmux &> /dev/null \
      && [[ -n "$TMUX" ]] \
      ; then
    # Launch mux scroll:
    # In job so that realine binding returns before => I can see the current line
    # In subshell to avoid job control stderr
    mousetrack_log "Cb: tmux proxy2 start job $s_tmux_cmd"
    ( {
      sleep 0.01
      #mousetrack_tmux_get_command "$s_tmux_cmd"
      # shellcheck disable=SC2046,SC2086  # Quote this to prevent wor
      eval "$s_tmux_cmd"
      #tmux if-shell -F -t = "#{||:#{mouse_any_flag},#{pane_in_mode}}" "select-pane -t=; send-keys -M" "display-menu -t= -xM -yM -T \"#[align=centre]#{pane_index} (#{pane_id})\"  '#{?mouse_word,Search For #[underscore]#{=/9/...:mouse_word},}' 'C-r' {copy-mode -t=; send -Xt= search-backward \"#{q:mouse_word}\"} '#{?mouse_word,Type #[underscore]#{=/9/...:mouse_word},}' 'C-y' {send-keys -l -- \"#{q:mouse_word}\"} '#{?mouse_word,Copy #[underscore]#{=/9/...:mouse_word},}' 'c' {set-buffer -- \"#{q:mouse_word}\"} '#{?mouse_line,Copy Line,}' 'l' {set-buffer -- \"#{q:mouse_line}\"} '' 'Horizontal Split' 'h' {split-window -h} 'Vertical Split' 'v' {split-window -v} '' 'Swap Up' 'u' {swap-pane -U} 'Swap Down' 'd' {swap-pane -D} '#{?pane_marked_set,,-}Swap Marked' 's' {swap-pane} '' 'Kill' 'X' {kill-pane} 'Respawn' 'R' {respawn-pane -k} '#{?pane_marked,Unmark,Mark}' 'm' {select-pane -m} '#{?window_zoomed_flag,Unzoom,Zoom}' 'z' {resize-pane -Z}"
      mousetrack_log "Cb: Button 2, tmux async finish $s_tmux_cmd -> $g_mousetrack_tmux_cmd"
      mousetrack_log "tmux $g_mousetrack_tmux_cmd"
    } & )
    return 0
  fi

  mousetrack_cb_void
}


mousetrack_cb_scroll_down(){
  mousetrack_log 'Cb: Scroll Down'
  mousetrack_read_keys_remaining 0.001
}


mousetrack_set_bindings(){
  : 'Set all global bindings (mouse event callbacks)'
  local s_keyseq=''
  mousetrack_log 'Set bindings'
  for s_keyseq in "${!g_mousetrack_d_binding[@]}"; do
    mousetrack_log "Bind: $s_keyseq => ${g_mousetrack_d_binding[$s_keyseq]}"
    local s_fct=${g_mousetrack_d_binding[$s_keyseq]}
    bind -x "\"\033[$s_keyseq\":$s_fct"
  done
}


mousetrack_unset_bindings(){
  : 'Unset all global bindings (mouse event callbacks)'
  local s_keyseq=''
  mousetrack_log 'Unset bindings'
  for s_keyseq in "${!g_mousetrack_d_binding[@]}"; do
    mousetrack_log "Unbind: $s_keyseq => ${g_mousetrack_d_binding[$s_keyseq]}"
    local s_fct=${g_mousetrack_d_binding[$s_keyseq]}
    bind -r "\033[$s_keyseq"
  done
}


mousetrack_prompt_command(){
  : 'Disable mouse tracking'
  command -v mousetrack_echo_enable &> /dev/null \
    && mousetrack_echo_enable
}


mousetrack_start(){
  : 'Init : Enable mouse tracking'
  mousetrack_set_bindings

  # Disable mouse tracking before each command
  trap mousetrack_trap_debug DEBUG

  # Enable mouse tracking after command return
  if [[ ! "$PROMPT_COMMAND" =~ $g_mousetrack_prompt_command ]]; then
    # Append ";" in case PROMPT_COMMAND is already defined
    [[ -v PROMPT_COMMAND ]] && [[ -n "$PROMPT_COMMAND" ]] && [[ "${PROMPT_COMMAND: -1}" != ";" ]] && PROMPT_COMMAND+="; "
    export PROMPT_COMMAND+=$g_mousetrack_prompt_command
  fi

  # Enable now anyway
  mousetrack_echo_enable
}


mousetrack_stop(){
  : 'Finish : Disable mouse tracking
  '
  mousetrack_echo_disable

  # Remove echo_enable from PROMPT_COMMAND
  if [[ ! "$PROMPT_COMMAND" =~ $g_mousetrack_prompt_command ]]; then
    export PROMPT_COMMAND=${PROMPT_COMMAND//$g_mousetrack_prompt_command/}
  fi

  # Unset binding
  mousetrack_unset_bindings
}


# The fonction must be exported in case a bash subshell is entered
export -f mousetrack_prompt_command
