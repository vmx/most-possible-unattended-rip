#!/usr/bin/env bash
# automatisches rippen einer audio-cd
# https://github.com/JoeLametta/whipper
# Vorbereitung morituri:
# # rip offset find
# # rip drive analyze

LOG_DIR="$HOME/logs/audio-rip"
OUTPUT_DIR="$HOME/rip"

# ============

get_cover_art() {
    local RELEASES=$(tr '\015' "\n" < "${LOG_FILE}" | grep "Release")

    local COUNTER=0
    # From https://www.linuxquestions.org/questions/programming-9/multi-line-return-from-grep-into-an-array-333576/#post1694951
    # (2018-02-09)
    local IFS=$'\n'
    # There might be more than one disk that matches, get the cover art
    # from all of them
    for RELEASE in ${RELEASES}; do
        # remove the search pattern
        local MBID=${RELEASE/Release : /}

        if [ "${COUNTER}" -eq "0" ]; then
            wget -O cover.jpg "https://coverartarchive.org/release/${MBID}/front"
        else
            wget -O cover.${COUNTER}.jpg "https://coverartarchive.org/release/${MBID}/front"
        fi

        COUNTER=$((${COUNTER} + 1))
    done
}

LOG_FILE="$LOG_DIR/rip-$(date +%Y-%m-%dT%H-%M-%S).log"

# end previous shutdown if one is active
sudo shutdown -c

# marker file for skipping the automated ripping
CONFIG_FILE="${HOME}/.config/auto-rip.cfg"

# include config file
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# optionally omit the process by config setting
if [ "$DISABLED" = 1 ]; then
    echo "# omitting auto rip due to config setting" | tee -a "$LOG_FILE"
    exit 0
fi

echo "# auto rip started" | tee -a "$LOG_FILE"

# PYTHONIOENCODING: workaround for an issue: https://github.com/JoeLametta/whipper/issues/43
nice -n 19 ionice -c 3  whipper cd rip --output-directory="$OUTPUT_DIR" -U true >>"$LOG_FILE" 2>&1
SC=$?
echo "# auto rip finished" | tee -a "$LOG_FILE"

# grab the cover art
if [ $SC == 0 ]; then
    get_cover_art
    echo "# result: success with getting cover art" | tee -a "$LOG_FILE"
else
    echo "# result: no success with whipper/morituri: status code = ${SC}" | tee -a "$LOG_FILE"
    
    # if you have abcde then use it as fallback
    if type abcde >/dev/null 2>&1; then
        echo "# trying abcde" | tee -a "$LOG_FILE"
        abcde | tee -a "$LOG_FILE"
        SC=$?
        
        if [ $SC == 0 ]; then
            echo "# result: success with abcde" | tee -a "$LOG_FILE"
            eject
        else
            echo "# result: no success with abcde: status code = ${SC}" | tee -a "$LOG_FILE"
        fi
    fi
fi

# reread the config file to include a late shutdown decision
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# optionally shutdown after a short delay
if [ "$SHUTDOWN" = 1 ]; then
    echo "# shutting down the system" | tee -a "$LOG_FILE"
    if ! [[ $SHUTDOWN_TIMEOUT =~ ^[0-9]+$ ]]; then SHUTDOWN_TIMEOUT=3; fi
    sudo shutdown -h $SHUTDOWN_TIMEOUT | tee -a "$LOG_FILE"
fi
