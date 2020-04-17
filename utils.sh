#!/bin/bash

startsection() {
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' -{1..80})"
  printf '\n%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" "$1" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}


endsection() {
  termwidth="$(tput cols)"
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' -{1..80})"
  printf '%*.*s%*.*s\n' 0 "$(((termwidth-${#1})/2))" "$padding" 0 "$(((termwidth-${#1})/2))" "$padding"
}

printprop() {
  indented=$(printf '%-20s' "$1")
  indented=${indented// /.}
  printf "%s ${2:-"<undefined>"}\n" "$indented"
}