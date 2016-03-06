ensureline() {
  LINE="$1"
  FILE="$2"
  if [ ! -e "$FILE" ]; then
    touch "$FILE" || return 1
  fi
  egrep -q '^'"$LINE"'$' "$FILE" || echo "$LINE" >> "$FILE" || return 1
}

