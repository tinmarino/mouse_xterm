# Escape sequences
s_echo_enable="\e[?1000;1006;1015h"
s_echo_disable="\e[?1000;1006;1015l"
s_echo_get_cursor_pos="\E[6n"

# Bindins
## 91 Clear
s_bind_1="\C-91"
s_macro_1="clear-screen"

## 93 Beginning of line
s_bind_2="\C-93"
s_macro_2="beginning-of-line"

## 92 Disable (X)
s_bindx_1="\C-92"
s_macrox_1='mouse_track_echo_disable'

## 94 Click (X)
s_bindx_2="\C-94"
s_macrox_2="mouse_track_0_cb"


## Click (0) Begining of line + X click cb
## TODO remove beginning of line
s_bind_3="\e[<0;"
s_macro_3="\"\C-93\C-94\""

## Scrool up
s_bindx_3="\e[<64;"
s_macrox_3="mouse_track_void_cb"

## Scrool down
s_bindx_4="\e[<65;"
s_macrox_4="mouse_track_void_cb"

## C-l -> reenable the mouse
s_bind_4="\C-l"
s_macro_4="\"\C-91\C-92\""
