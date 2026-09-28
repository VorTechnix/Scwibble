#!/usr/bin/bash

# A script based util to sync KDE Plasma wallpaper with KScreenLocker and LightDM.
# Copyright (C) 2026  VorTechnix

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


### === WELCOME === ###
function welcome {
    cat <<EOF
Welcome to Swibble!
Version 0.0.1

Enter h for help or q to quit.

EOF
}

### === VARIABLES === ###

DIVIDER="--------------------------------------------------------------------"

### === HELPS === ###

function clihelp {
    cat <<EOF
Usage: scwibble [OPTIONS] [FILE]
$DIVIDER

Starts in interactive mode if called without arguments. If called with without options assumes --setsync.

Options:
  -h,   --help              Show this help text
  -s,   --sync              Sync the active wallpaper to lockscreen and lightdm
  -b,   --setsync <FILE>    Set FILE as wallpaper and sync

EOF
}

function ihelp {
    cat <<EOF
Scwibble Commands:
$DIVIDER
h H         Show this help
q Q         Exit Scwibble

set <FILE>  Set FILE as desktop background

EOF
}

### === HELPER FUNCTIONS === ###

function make_shared {
    SRC="$1"
    SRC_NAME=$(basename -- "$SRC")
    SRC_EXT="${SRC_NAME##*.}"
    SHARED_DIR="/usr/local/shared/backgrounds"
    IMG="$SHARED_DIR/$(id -u).$SRC_EXT"

    if [[ ! -d "$SHARED_DIR" ]]; then
        mkdir -p "$SHARED_DIR"
        chmod a+x "$SHARED_DIR"
    fi

    # Copy image to shared background folder
    cp -Tf "$SRC" "$IMG"

    # Print new image path
    echo "$IMG"
}

function is_image() {
    if [[ ! -e "$1" ]]; then
        return 1
    fi

    file --mime-type "$1" | grep -q 'image/'
}

function get_image {
    TEST_PATH="${1#file://}"
    
    if is_image "$TEST_PATH"; then
        echo $TEST_PATH
        return 0
    fi
    
    if [[ -d "$TEST_PATH" ]]; then
        while IFS= read -r file; do
            [[ -f "$file" ]] || continue

            if is_image "$file"; then
                echo "$file"
                return 0
            fi
        # Feeding fd/eza output directly into the loop safely
        done < <(fd -tf . "$TEST_PATH" -X eza -1rs size)
    fi
    
    echo "Error: Could not resolve asset location for '$TEST_PATH'." >&2
    exit 1
}

function get_paper {
    CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    # Parse out the Image= line from the desktop configuration
    # TODO: this should use grep
    RAW_VALUE=$(awk -F= '/^Image=/ {print $2; exit}' "$CONFIG_FILE")

    # Exit if no image string is found
    if [ -z "$RAW_VALUE" ]; then
        echo "Error: Could not find active desktop wallpaper path."
        exit 1
    fi

    # Resolve the target path based on whether it's a file path or a theme name
    # TODO: Redo this stepwise so it makes sure FINAL_PATH is an image
    if [[ "$RAW_VALUE" == file://* ]]; then
        # It's already a full file URL path (Custom User Wallpaper)
        FINAL_PATH="$RAW_VALUE"
    elif [[ "$RAW_VALUE" == /* ]]; then
        # It's an absolute path but missing the 'file://' scheme
        FINAL_PATH="file://$RAW_VALUE"
    else
        # It's a shorthand package name (System Default Wallpaper e.g. "Altai")
        # Resolve it directly to the default global directory
        GLOBAL_DIR="/usr/share/wallpapers/$RAW_VALUE/contents/images"
        
        if [[ -d "$GLOBAL_DIR" ]]; then
            # Find the highest resolution image asset available in the folder
            BEST_IMAGE=$(get_image "$GLOBAL_DIR")
            FINAL_PATH="file://$BEST_IMAGE"
        else
            # Fallback check for user-local wallpaper packages
            LOCAL_DIR="$HOME/.local/share/wallpapers/$RAW_VALUE/contents/images"
            if [[ -d "$LOCAL_DIR" ]]; then
                # Get best image
                FINAL_PATH=$(get_image "$LOCAL_DIR")
            else
                echo "Error: Could not resolve asset location for '$TEST_PATH'." >&2
                exit 1
            fi
        fi
    fi
    
    echo "$FINAL_PATH"
}

### === MAIN FUNCTIONS === ###
function ldm_sync {
    # lightdm doesn't take file:///... URIs
    PLAIN_PATH=$(get_image "$1")
    IMG_DIR="${PLAIN_PATH%/*}"

    # Check if lightdm can access the folder containing image
    PERMS=$(namei -l "$IMG_DIR" |\
        awk '{print $1}' |\
        grep -m 1 '^d.*-$')

    # If not prompt to make shared
    if [[ -n $PERMS ]]; then
        echo "WARNING: LightDM cannot read file at '$IMG_DIR'"
        read -p "Copy to local shared backgrounds? [y/n]> " ret
        if [[ $ret != 'y' ]]; then
            echo "LightDM sync aborted."
            return 0
        fi
        PLAIN_PATH=$(make_shared "$PLAIN_PATH")
    fi

    # Tell AccountsService to update LightDM's background property
    # Stored in "/var/lib/AccountsService/users/$(id -u)"
    dbus-send --system --print-reply \
              --dest=org.freedesktop.Accounts \
              /org/freedesktop/Accounts/User$(id -u) \
              org.freedesktop.DBus.Properties.Set \
              string:"org.freedesktop.DisplayManager.AccountsService" \
              string:"BackgroundFile" \
              variant:string:"$PLAIN_PATH"
}

function sync {
    LOCK_CONFIG="$HOME/.config/kscreenlockerrc"
    
    # 1. Get wallpaper path
    IMAGE_PATH="$(get_paper)"
    
    # 2. Write the exact string into the lockscreen configuration
    # (Swap 'kwriteconfig6' to 'kwriteconfig5' if you are running an older Plasma 5 stack)
    kwriteconfig6 --file "$LOCK_CONFIG" \
                  --group "Greeter" \
                  --group "Wallpaper" \
                  --group "org.kde.image" \
                  --group "General" \
                  --key "Image" "$IMAGE_PATH"
    
    # 3. Tell AccountsService to update LightDM's background property
    ldm_sync "$IMAGE_PATH"
}

function wallpaper {
    if is_image "$1"; then
        plasma-apply-wallpaperimage $1
        sync
    else
        echo "ERROR: Not a valid image: $1"
        echo "Operation aborted."
    fi
}

function main {
    echo "What would you like to do? (h for help)"
    read -rp "> " user_choice
    
    # Shell split user input
    mapfile -d '' input < <(xargs printf '%s\0' <<< "$user_choice")
    
    
}

### === RUNNERS === ###

# Fallback Logic: If $1 doesn't start with '-', assume it's a file for --setsync
if [ -n "$1" ] && [[ "$1" != -* ]]; then
    # Rewrite the arguments to include the flag automatically
    set -- "--setsync" "$@"
fi

# Parse options using GNU getopt
PARSED=$(getopt -o hsb: --long help,sync,setsync: --name "$0" -- "$@")
if [ $? -ne 0 ]; then
    # getopt will automatically print an error if an unknown flag is passed
    exit 1
fi

# Re-read the output of getopt into the script positional parameters
eval set -- "$PARSED"

case "$1" in
    -h|--help)
        clihelp
        exit 0
        ;;
    -s|--sync)
        echo "Action: Syncing the active wallpaper to lockscreen and lightdm..."
        sync
        ;;
    -b|--setsync)
        WALLPAPER_FILE="$2"
        echo "Action: Setting '$WALLPAPER_FILE' as wallpaper and syncing..."
        wallpaper "$WALLPAPER_FILE"
        ;;
    --)
        welcome
        # while true; do
        #     exit 0
        #     # main
        # done
        ;;
    *)
        echo "Internal programming error."
        exit 1
        ;;
esac
