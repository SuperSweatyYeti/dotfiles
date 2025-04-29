#!/bin/sh
PREFERENCES_FILE="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"

# Check if the "vertical_tabs_enabled" is set to true
VERTICAL_TABS=$(jq '.brave.tabs.vertical_tabs_enabled' "$PREFERENCES_FILE" )

# If it's set to false, set it to true
if [ "$VERTICAL_TABS" == "false" ]; then
  jq '.brave.tabs.vertical_tabs_enabled = true' "$PREFERENCES_FILE" > "$PREFERENCES_FILE.tmp" && mv "$PREFERENCES_FILE.tmp" "$PREFERENCES_FILE"
  echo "Updated vertical_tabs_enabled to true."
  exit 0
elif [ "$VERTICAL_TABS" == "true" ]; then
  echo "vertical_tabs_enabled is already true."
  exit 0
else
  echo "[ERROR] The 'vertical_tabs_enabled' option could not be found in the Brave Browser Preferences file at:"
  echo "$PREFERENCES_FILE"
  exit 1
fi

