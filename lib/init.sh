#!/bin/bash

# ============================================================
#  lib/init.sh — Global variables, helpers, DB initializer
# ============================================================

# ---------- File paths ----------
USERS_FILE="users.txt"
SPOTS_FILE="spots.txt"
PENDING_SPOTS_FILE="pending_spots.txt"
HOTELS_FILE="hotels.txt"
PENDING_HOTELS_FILE="pending_hotels.txt"
RATINGS_FILE="ratings.txt"
BOOKINGS_FILE="bookings.txt"
AUDIT_LOG="audit_log.txt"
EXPORT_FILE="summary_report.txt"

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- Session ----------
CURRENT_USER=""
CURRENT_ROLE=""
CURRENT_USERID=""

# ---------- Trap ----------
trap 'echo -e "\n${YELLOW}  [!] Interrupted. Logging out safely...${RESET}"
      log_action "${CURRENT_USER:-system}" "FORCE_EXIT" "SIGINT"
      CURRENT_USER=""; CURRENT_ROLE=""; CURRENT_USERID=""
      echo -e "${GREEN}  Goodbye!${RESET}"; exit 0' SIGINT

# ============================================================
# AUDIT LOGGER
# ============================================================
log_action() {
    local actor="$1" action="$2" target="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp}|${actor}|${action}|${target}" >> "$AUDIT_LOG"
}

# ============================================================
# SANITIZE — strip pipe character to prevent delimiter injection
# ============================================================
sanitize() {
    echo "$1" | tr -d '|'
}

# ============================================================
# HELPERS
# ============================================================
spot_exists() {
    grep -q "^${1}|" "$SPOTS_FILE"
}

get_spot_name() {
    grep "^${1}|" "$SPOTS_FILE" | cut -d'|' -f2
}

hotel_exists() {
    grep -q "^${1}|" "$HOTELS_FILE"
}

get_hotel_manager() {
    grep "^${1}|" "$HOTELS_FILE" | cut -d'|' -f8
}

get_hotel_price() {
    grep "^${1}|" "$HOTELS_FILE" | cut -d'|' -f5
}

get_available_rooms() {
    grep "^${1}|" "$HOTELS_FILE" | cut -d'|' -f7
}

next_id() {
    local file="$1"
    local max_id
    max_id=$(tail -n +2 "$file" | cut -d'|' -f1 | sort -n | tail -1)
    [ -z "$max_id" ] && echo 1 || echo $((max_id + 1))
}

hash_password() {
    echo -n "$1" | sha256sum | awk '{print $1}'
}

# Safe in-place single field update using awk
# Usage: update_field <file> <id_col1_value> <col_number> <new_value>
update_field() {
    local file="$1" match_id="$2" col="$3" new_val="$4"
    awk -F'|' -v id="$match_id" -v c="$col" -v val="$new_val" \
        'BEGIN{OFS="|"} $1==id{$c=val} {print}' \
        "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# ============================================================
# INIT — creates all DB files with headers + sample data
# Bookings schema:
#   BookingID|Username|HotelID|HotelName|SpotID|Rooms|Nights|Status|Timestamp
# Hotels schema:
#   HotelID|SpotID|HotelName|Address|PricePerNight|TotalRooms|AvailableRooms|ManagerUsername
# ============================================================
init_files() {
    if [ ! -f "$USERS_FILE" ]; then
        echo "UserID|Username|PasswordHash|Role" > "$USERS_FILE"
        local admin_hash
        admin_hash=$(echo -n "admin123" | sha256sum | awk '{print $1}')
        echo "1|admin|${admin_hash}|Admin" >> "$USERS_FILE"
        echo -e "${GREEN}[INFO] users.txt created.  Default login → admin / admin123${RESET}"
    fi

    if [ ! -f "$SPOTS_FILE" ]; then
        echo "SpotID|Name|City|Country|Description|BestSeason" > "$SPOTS_FILE"
        echo "1|Cox's Bazar|Cox's Bazar|Bangladesh|Longest natural sea beach in the world.|Winter" >> "$SPOTS_FILE"
        echo "2|Sajek Valley|Rangamati|Bangladesh|Beautiful hill-top valley with panoramic views.|Spring" >> "$SPOTS_FILE"
        echo "3|Sundarbans|Khulna|Bangladesh|UNESCO World Heritage mangrove forest.|Winter" >> "$SPOTS_FILE"
        echo "4|Kuakata|Barisal|Bangladesh|Sunrise and sunset beach on the same spot.|Winter" >> "$SPOTS_FILE"
        echo -e "${GREEN}[INFO] spots.txt created with sample data.${RESET}"
    fi

    if [ ! -f "$PENDING_SPOTS_FILE" ]; then
        echo "SpotID|Name|City|Country|Description|BestSeason|SubmittedBy" > "$PENDING_SPOTS_FILE"
    fi

    if [ ! -f "$HOTELS_FILE" ]; then
        echo "HotelID|SpotID|HotelName|Address|PricePerNight|TotalRooms|AvailableRooms|ManagerUsername" > "$HOTELS_FILE"
        echo "1|1|Sea View Resort|Near Beach Road Cox's Bazar|5000|20|20|admin" >> "$HOTELS_FILE"
        echo "2|1|Beach Paradise Hotel|Main Beach Area Cox's Bazar|6500|15|15|admin" >> "$HOTELS_FILE"
        echo "3|2|Hill View Inn|Top of Sajek Hill Rangamati|6000|10|10|admin" >> "$HOTELS_FILE"
        echo "4|3|Sundarban Eco Lodge|Near Jetty Area Khulna|4000|12|12|admin" >> "$HOTELS_FILE"
        echo "5|4|Kuakata Sea Pearl Resort|Beachfront Kuakata|4500|18|18|admin" >> "$HOTELS_FILE"
        echo -e "${GREEN}[INFO] hotels.txt created with sample data.${RESET}"
    fi

    if [ ! -f "$PENDING_HOTELS_FILE" ]; then
        echo "HotelID|SpotID|HotelName|Address|PricePerNight|TotalRooms|SubmittedBy" > "$PENDING_HOTELS_FILE"
    fi

    if [ ! -f "$RATINGS_FILE" ]; then
        echo "SpotID|Username|Rating|Comment" > "$RATINGS_FILE"
        echo "1|shimanto|4|Beautiful, but crowded during holidays" >> "$RATINGS_FILE"
        echo "1|anika|5|Very clean and scenic. Perfect family trip!" >> "$RATINGS_FILE"
        echo "2|tahmid|3|Need better roads to reach the top" >> "$RATINGS_FILE"
        echo "2|farha|4|Amazing views, cold weather perfect" >> "$RATINGS_FILE"
        echo "3|rafi|5|Wildlife boat safari was unforgettable" >> "$RATINGS_FILE"
        echo -e "${GREEN}[INFO] ratings.txt created with sample data.${RESET}"
    fi

    if [ ! -f "$BOOKINGS_FILE" ]; then
        echo "BookingID|Username|HotelID|HotelName|SpotID|Rooms|Nights|Status|Timestamp" > "$BOOKINGS_FILE"
        echo -e "${GREEN}[INFO] bookings.txt created.${RESET}"
    fi

    if [ ! -f "$AUDIT_LOG" ]; then
        echo "Timestamp|Actor|Action|TargetID" > "$AUDIT_LOG"
        echo -e "${GREEN}[INFO] audit_log.txt created.${RESET}"
    fi
}
