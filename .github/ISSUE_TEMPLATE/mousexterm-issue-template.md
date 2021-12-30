---
name: MouseXterm issue template
about: In order to retrieve nice info from users
title: ''
labels: ''
assignees: ''

---

* [ ] I run MouseXterm with the command below <paste output below>
* [ ] I get <TOFILL>
* [ ] I would expect <TOFILL>

```bash
eval "$(curl -X GET https://raw.githubusercontent.com/tinmarino/mouse_xterm/master/mouse.sh)" && mouse_track_start
mouse_track_verify_ps1
pstree -sp $$
uname -a
echo $PROMPT_COMMAND
# Play with mouse clicks and
cat /tmp/xterm_monitor
```
