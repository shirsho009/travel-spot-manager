#!/bin/bash

# ============================================================
#  Travel Spot Management System v2.0
#  Student: SHIMANTO SHIRSHO (2204009)
#  Course : Operating Systems (CSE)
#  Features: RBAC, Auth, Approval Workflow, Audit Log
# ============================================================

# ---------- File paths ----------
USERS_FILE="users.txt"
SPOTS_FILE="spots.txt"
PENDING_SPOTS_FILE="pending_spots.txt"
HOTELS_FILE="hotels.txt"
PENDING_HOTELS_FILE="pending_hotels.txt"
RATINGS_FILE="ratings.txt"
AUDIT_LOG="audit_log.txt"
EXPORT_FILE="summary_report.txt"

# ---------- Terminal colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- Session variables ----------
CURRENT_USER=""
CURRENT_ROLE=""
CURRENT_USERID=""

# ============================================================
# TRAP — Handle Ctrl+C gracefully (no corrupted files)
# ============================================================
trap 'echo -e "\n${YELLOW}  [!] Interrupted. Logging out safely...${RESET}"
      log_action "${CURRENT_USER:-system}" "FORCE_EXIT" "SIGINT"
      CURRENT_USER=""; CURRENT_ROLE=""; CURRENT_USERID=""
      echo -e "${GREEN}  Goodbye!${RESET}"; exit 0' SIGINT

# ============================================================
# INIT — Auto-create all DB files with headers + sample data
# ============================================================
init_files() {
    # users.txt — default admin: admin / admin123
    if [ ! -f "$USERS_FILE" ]; then
        echo "UserID|Username|PasswordHash|Role" > "$USERS_FILE"
        local admin_hash
        admin_hash=$(echo -n "admin123" | sha256sum | awk '{print $1}')
        echo "1|admin|${admin_hash}|Admin" >> "$USERS_FILE"
        echo -e "${GREEN}[INFO] users.txt created.  Default login → admin / admin123${RESET}"
    fi

    # spots.txt — new schema includes BestSeason
    if [ ! -f "$SPOTS_FILE" ]; then
        echo "SpotID|Name|City|Country|Description|BestSeason" > "$SPOTS_FILE"
        echo "1|Cox's Bazar|Cox's Bazar|Bangladesh|Longest natural sea beach in the world. 120km of golden sand.|Winter" >> "$SPOTS_FILE"
        echo "2|Sajek Valley|Rangamati|Bangladesh|Beautiful hill-top valley with panoramic views of green hills.|Spring" >> "$SPOTS_FILE"
        echo "3|Sundarbans|Khulna|Bangladesh|UNESCO World Heritage mangrove forest. Home to Royal Bengal Tiger.|Winter" >> "$SPOTS_FILE"
        echo "4|Kuakata|Barisal|Bangladesh|Sunrise and sunset beach on the same spot.|Winter" >> "$SPOTS_FILE"
        echo -e "${GREEN}[INFO] spots.txt created with sample data.${RESET}"
    fi

    # pending_spots.txt — submissions waiting for admin approval
    if [ ! -f "$PENDING_SPOTS_FILE" ]; then
        echo "SpotID|Name|City|Country|Description|BestSeason|SubmittedBy" > "$PENDING_SPOTS_FILE"
    fi

    # hotels.txt — new schema includes HotelID as first column
    if [ ! -f "$HOTELS_FILE" ]; then
        echo "HotelID|SpotID|HotelName|Address|PricePerNight" > "$HOTELS_FILE"
        echo "1|1|Sea View Resort|Near Beach Road, Cox's Bazar|5000" >> "$HOTELS_FILE"
        echo "2|1|Beach Paradise Hotel|Main Beach Area, Cox's Bazar|6500" >> "$HOTELS_FILE"
        echo "3|2|Hill View Inn|Top of Sajek Hill, Rangamati|6000" >> "$HOTELS_FILE"
        echo "4|3|Sundarban Eco Lodge|Near Jetty Area, Khulna|4000" >> "$HOTELS_FILE"
        echo "5|4|Kuakata Sea Pearl Resort|Beachfront, Kuakata|4500" >> "$HOTELS_FILE"
        echo -e "${GREEN}[INFO] hotels.txt created with sample data.${RESET}"
    fi

    # pending_hotels.txt
    if [ ! -f "$PENDING_HOTELS_FILE" ]; then
        echo "HotelID|SpotID|HotelName|Address|PricePerNight|SubmittedBy" > "$PENDING_HOTELS_FILE"
    fi

    # ratings.txt
    if [ ! -f "$RATINGS_FILE" ]; then
        echo "SpotID|Username|Rating|Comment" > "$RATINGS_FILE"
        echo "1|shimanto|4|Beautiful, but crowded during holidays" >> "$RATINGS_FILE"
        echo "1|anika|5|Very clean and scenic. Perfect family trip!" >> "$RATINGS_FILE"
        echo "2|tahmid|3|Need better roads to reach the top" >> "$RATINGS_FILE"
        echo "2|farha|4|Amazing views, cold weather perfect" >> "$RATINGS_FILE"
        echo "3|rafi|5|Wildlife boat safari was unforgettable" >> "$RATINGS_FILE"
        echo -e "${GREEN}[INFO] ratings.txt created with sample data.${RESET}"
    fi

    # audit_log.txt
    if [ ! -f "$AUDIT_LOG" ]; then
        echo "Timestamp|Actor|Action|TargetID" > "$AUDIT_LOG"
        echo -e "${GREEN}[INFO] audit_log.txt created.${RESET}"
    fi
}

# ============================================================
# AUDIT LOGGER — every important action is recorded
# ============================================================
log_action() {
    local actor="$1"
    local action="$2"
    local target="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp}|${actor}|${action}|${target}" >> "$AUDIT_LOG"
}

# ============================================================
# INPUT SANITIZATION — strip pipe chars to prevent DB injection
# ============================================================
sanitize() {
    # Remove all | characters from input
    echo "$1" | tr -d '|'
}

# ============================================================
# HELPERS
# ============================================================

# Returns 0 (true) if a Spot ID exists in the live spots file
spot_exists() {
    grep -q "^${1}|" "$SPOTS_FILE"
}

# Returns the Name of a spot by its ID
get_spot_name() {
    grep "^${1}|" "$SPOTS_FILE" | cut -d'|' -f2
}

# Returns next available integer ID for a given file
next_id() {
    local file="$1"
    local max_id
    max_id=$(tail -n +2 "$file" | cut -d'|' -f1 | sort -n | tail -1)
    [ -z "$max_id" ] && echo 1 || echo $((max_id + 1))
}

# ============================================================
# AUTHENTICATION
# ============================================================

hash_password() {
    # sha256sum hashes the password; awk strips the trailing filename "-"
    echo -n "$1" | sha256sum | awk '{print $1}'
}

do_signup() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Create New Account ===${RESET}"

    # Username — must be unique and non-empty
    local username
    while true; do
        read -p "  Choose a username : " username
        username=$(sanitize "$username")
        if [ -z "$username" ]; then
            echo -e "${RED}  ✘ Username cannot be empty.${RESET}"; continue
        fi
        # grep pattern: any UserID, then |username|
        if grep -q "^[^|]*|${username}|" "$USERS_FILE"; then
            echo -e "${RED}  ✘ Username '${username}' is already taken.${RESET}"
        else
            break
        fi
    done

    # Password — hidden input, must match twice
    local password password2
    while true; do
        read -s -p "  Password (hidden) : " password; echo ""
        [ -z "$password" ] && echo -e "${RED}  ✘ Password cannot be empty.${RESET}" && continue
        read -s -p "  Confirm password  : " password2; echo ""
        [ "$password" = "$password2" ] && break
        echo -e "${RED}  ✘ Passwords do not match. Try again.${RESET}"
    done

    local new_id hash
    new_id=$(next_id "$USERS_FILE")
    hash=$(hash_password "$password")

    # New accounts are always "User" role; only DB-level edits can make an Admin
    echo "${new_id}|${username}|${hash}|User" >> "$USERS_FILE"
    log_action "system" "SIGNUP" "UserID:${new_id}(${username})"
    echo -e "${GREEN}  ✔ Account created! You can now log in as '${username}'.${RESET}"
}

do_login() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Login ===${RESET}"

    read -p "  Username : " username
    read -s -p "  Password : " password; echo ""

    local hash user_line
    hash=$(hash_password "$password")

    # Look for a line matching UserID|username|hash|Role
    user_line=$(grep -m1 "^[^|]*|${username}|${hash}|" "$USERS_FILE")

    if [ -z "$user_line" ]; then
        echo -e "${RED}  ✘ Invalid username or password.${RESET}"
        return 1
    fi

    # Populate session variables
    IFS='|' read -r uid uname uhash urole <<< "$user_line"
    CURRENT_USERID="$uid"
    CURRENT_USER="$uname"
    CURRENT_ROLE="$urole"

    log_action "$CURRENT_USER" "LOGIN" "Role:${CURRENT_ROLE}"
    echo -e "${GREEN}  ✔ Welcome, ${CURRENT_USER}!  (Role: ${CURRENT_ROLE})${RESET}"
    return 0
}

do_logout() {
    log_action "$CURRENT_USER" "LOGOUT" "-"
    echo -e "${YELLOW}  Logged out. Goodbye, ${CURRENT_USER}!${RESET}"
    CURRENT_USER=""; CURRENT_ROLE=""; CURRENT_USERID=""
}

# ============================================================
# SPLASH SCREEN — displayed when no user is logged in
# ============================================================
splash_screen() {
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║     🌍  Travel Spot Management System  v2.0      ║${RESET}"
        echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════╣${RESET}"
        echo -e "${BOLD}${CYAN}║         1) Login    2) Sign Up    3) Exit         ║${RESET}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
        echo ""
        read -p "  Choose: " splash_choice

        case "$splash_choice" in
            1) do_login && return 0 ;;
            2) do_signup ;;
            3) echo -e "${GREEN}  Goodbye!${RESET}"; exit 0 ;;
            *) echo -e "${RED}  ✘ Invalid choice.${RESET}" ;;
        esac
    done
}

# ============================================================
# SHARED FEATURES — available to both User and Admin
# ============================================================

list_spots() {
    echo ""
    echo -e "${CYAN}${BOLD}=== All Travel Spots ===${RESET}"
    local count=0
    while IFS='|' read -r id name city country description season; do
        [ "$id" = "SpotID" ] && continue
        echo -e "  ${BOLD}${id}.${RESET} ${name}  (${city}, ${country})  📅 ${season}"
        ((count++))
    done < "$SPOTS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No spots in database.${RESET}"
}

search_by_city() {
    echo ""
    read -p "  Enter city to search: " city_query
    city_query=$(sanitize "$city_query")
    echo -e "${CYAN}${BOLD}=== Spots matching city '${city_query}' ===${RESET}"
    local count=0
    while IFS='|' read -r id name city country description season; do
        [ "$id" = "SpotID" ] && continue
        if echo "$city" | grep -qi "$city_query"; then
            echo -e "  ${BOLD}${id}.${RESET} ${name}  (${city}, ${country})"
            ((count++))
        fi
    done < "$SPOTS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No matches found.${RESET}"
}

search_by_country() {
    echo ""
    read -p "  Enter country to search: " country_query
    country_query=$(sanitize "$country_query")
    echo -e "${CYAN}${BOLD}=== Spots matching country '${country_query}' ===${RESET}"
    local count=0
    while IFS='|' read -r id name city country description season; do
        [ "$id" = "SpotID" ] && continue
        if echo "$country" | grep -qi "$country_query"; then
            echo -e "  ${BOLD}${id}.${RESET} ${name}  (${city}, ${country})"
            ((count++))
        fi
    done < "$SPOTS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No matches found.${RESET}"
}

# Seasonal recommender — matches BestSeason column
search_by_season() {
    echo ""
    read -p "  Enter season (Winter / Summer / Spring / Monsoon / Any): " season_query
    season_query=$(sanitize "$season_query")
    echo -e "${CYAN}${BOLD}=== Spots best in '${season_query}' ===${RESET}"
    local count=0
    while IFS='|' read -r id name city country description season; do
        [ "$id" = "SpotID" ] && continue
        if echo "$season" | grep -qi "$season_query"; then
            echo -e "  ${BOLD}${id}.${RESET} ${name}  (${city}, ${country})  📅 Best: ${season}"
            ((count++))
        fi
    done < "$SPOTS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No spots found for '${season_query}'.${RESET}"
}

list_ratings_for_spot() {
    echo ""
    read -p "  Enter Spot ID: " spot_id
    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' not found.${RESET}"; return
    fi
    local spot_name
    spot_name=$(get_spot_name "$spot_id")
    echo -e "${CYAN}${BOLD}=== Ratings for ${spot_name} (ID: ${spot_id}) ===${RESET}"
    local count=0
    while IFS='|' read -r sid username rating comment; do
        [ "$sid" = "SpotID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "  👤 ${BOLD}${username}${RESET}: ${rating}/5 — ${comment}"
            ((count++))
        fi
    done < "$RATINGS_FILE"
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  No ratings yet.${RESET}"
    else
        echo -e "  ${BOLD}Total: ${count} rating(s)${RESET}"
    fi
}

show_full_summary() {
    echo ""
    read -p "  Enter Spot ID: " spot_id
    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' not found.${RESET}"; return
    fi

    local spot_line
    spot_line=$(grep "^${spot_id}|" "$SPOTS_FILE")
    IFS='|' read -r id name city country description season <<< "$spot_line"

    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
    printf  "${BOLD}${CYAN}    Summary: %-38s${RESET}\n" "${name}  (ID:${id})"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
    echo -e "  📍 ${BOLD}Location   :${RESET} ${city}, ${country}"
    echo -e "  📅 ${BOLD}Best Season:${RESET} ${season}"
    echo -e "  📝 ${BOLD}Description:${RESET} ${description}"
    echo ""

    # --- Ratings ---
    echo -e "  ${YELLOW}⭐ Ratings:${RESET}"
    local r_count=0 r_sum=0
    while IFS='|' read -r sid username rating comment; do
        [ "$sid" = "SpotID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "     - ${BOLD}${username}${RESET}: ${rating}/5 — ${comment}"
            ((r_count++)); r_sum=$((r_sum + rating))
        fi
    done < "$RATINGS_FILE"

    if [ "$r_count" -gt 0 ]; then
        local avg
        avg=$(awk "BEGIN { printf \"%.1f\", $r_sum / $r_count }")
        echo -e "  ${YELLOW}  ➤ Average: ${avg} ⭐  (${r_count} rating(s))${RESET}"
    else
        echo -e "  ${YELLOW}  No ratings yet.${RESET}"
    fi
    echo ""

    # --- Hotels ---
    echo -e "  ${CYAN}🏨 Hotels:${RESET}"
    local h_count=0 min_p=0 max_p=0
    while IFS='|' read -r hid sid hotel_name address price; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "     - ${BOLD}${hotel_name}${RESET} — ${address}  (৳${price}/night)"
            ((h_count++))
            if [ "$min_p" -eq 0 ] || [ "$price" -lt "$min_p" ]; then min_p=$price; fi
            [ "$price" -gt "$max_p" ] && max_p=$price
        fi
    done < "$HOTELS_FILE"

    if [ "$h_count" -gt 0 ]; then
        echo -e "  ${CYAN}  ➤ ${h_count} hotel(s)  (৳${min_p} – ৳${max_p}/night)${RESET}"
    else
        echo -e "  ${CYAN}  No hotels listed yet.${RESET}"
    fi
    echo ""
}

average_ratings_all() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Average Ratings — All Spots ===${RESET}"
    echo ""
    printf "  ${BOLD}%-5s | %-22s | %-12s | %s${RESET}\n" "ID" "Name" "Avg Rating" "# Ratings"
    echo "  ------+-----------------------+--------------+-----------"
    while IFS='|' read -r id name city country description season; do
        [ "$id" = "SpotID" ] && continue
        local result
        result=$(awk -F'|' -v sid="$id" '
            NR==1 { next }
            $1 == sid { sum += $3; count++ }
            END {
                if (count > 0) printf "%.1f %d", sum/count, count
                else printf "N/A 0"
            }
        ' "$RATINGS_FILE")
        local avg count_r
        avg=$(echo "$result" | awk '{print $1}')
        count_r=$(echo "$result" | awk '{print $2}')
        printf "  %-5s | %-22s | %-12s | %s\n" "$id" "$name" "  ${avg}" "$count_r"
    done < "$SPOTS_FILE"
    echo ""
}

# Social analytics — sorted by average rating (highest first)
top_rated_spots() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Top Rated Spots ===${RESET}"
    echo ""

    # Build temp file: avg|id|name|city|count
    local tmp_file
    tmp_file=$(mktemp)

    while IFS='|' read -r id name city country description season; do
        [ "$id" = "SpotID" ] && continue
        local result
        result=$(awk -F'|' -v sid="$id" '
            NR==1 { next }
            $1 == sid { sum += $3; count++ }
            END {
                if (count > 0) printf "%.2f %d", sum/count, count
                else printf "0.00 0"
            }
        ' "$RATINGS_FILE")
        local avg count_r
        avg=$(echo "$result" | awk '{print $1}')
        count_r=$(echo "$result" | awk '{print $2}')
        echo "${avg}|${id}|${name}|${city}|${count_r}" >> "$tmp_file"
    done < "$SPOTS_FILE"

    # sort -t'|' -k1 -rn : sort by first field (avg) numerically in reverse
    local rank=1
    sort -t'|' -k1 -rn "$tmp_file" | while IFS='|' read -r avg id name city count_r; do
        if [ "$count_r" -eq 0 ] 2>/dev/null; then
            echo -e "  ${BOLD}#${rank}${RESET}  ${name}  (${city})  —  No ratings yet"
        else
            echo -e "  ${BOLD}#${rank}${RESET}  ${name}  (${city})  —  ${YELLOW}${avg} ⭐${RESET}  (${count_r} ratings)"
        fi
        ((rank++))
    done

    rm -f "$tmp_file"
}

export_summary_report() {
    echo ""
    echo -e "${CYAN}Generating full summary report...${RESET}"
    {
        echo "============================================================"
        echo "  TRAVEL SPOT MANAGEMENT SYSTEM v2.0 — SUMMARY REPORT"
        echo "  Student  : SHIMANTO SHIRSHO (2204009)"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  By       : ${CURRENT_USER}"
        echo "============================================================"
        echo ""

        while IFS='|' read -r id name city country description season; do
            [ "$id" = "SpotID" ] && continue
            echo "------------------------------------------------------------"
            echo "  SPOT #${id}: ${name}"
            echo "  Location  : ${city}, ${country}"
            echo "  Season    : ${season}"
            echo "  About     : ${description}"
            echo ""

            # Ratings sub-block
            echo "  [ RATINGS ]"
            local rc=0 rs=0
            while IFS='|' read -r sid username rating comment; do
                [ "$sid" = "SpotID" ] && continue
                if [ "$sid" = "$id" ]; then
                    echo "    ${username}: ${rating}/5 — ${comment}"
                    ((rc++)); rs=$((rs + rating))
                fi
            done < "$RATINGS_FILE"
            if [ "$rc" -gt 0 ]; then
                local avg
                avg=$(awk "BEGIN { printf \"%.1f\", $rs / $rc }")
                echo "    Average: ${avg}/5  (${rc} rating(s))"
            else
                echo "    No ratings yet."
            fi
            echo ""

            # Hotels sub-block
            echo "  [ HOTELS ]"
            local hc=0
            while IFS='|' read -r hid sid hname addr price; do
                [ "$hid" = "HotelID" ] && continue
                if [ "$sid" = "$id" ]; then
                    echo "    ${hname}  |  ${addr}  |  BDT ${price}/night"
                    ((hc++))
                fi
            done < "$HOTELS_FILE"
            [ "$hc" -eq 0 ] && echo "    No hotels listed."
            echo ""
        done < "$SPOTS_FILE"

        echo "============================================================"
        echo "                      END OF REPORT"
        echo "============================================================"
    } > "$EXPORT_FILE"

    log_action "$CURRENT_USER" "EXPORT_REPORT" "$EXPORT_FILE"
    echo -e "${GREEN}  ✔ Report saved to '${EXPORT_FILE}'${RESET}"
}

# ============================================================
# USER-ONLY FEATURES
# ============================================================

# Submits spot to pending_spots.txt — NOT directly to spots.txt
user_submit_spot() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Submit New Travel Spot (Pending Admin Approval) ===${RESET}"

    local name city country description season
    while true; do
        read -p "  Spot name   : " name; name=$(sanitize "$name")
        [ -n "$name" ] && break
        echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  City        : " city; city=$(sanitize "$city")
        [ -n "$city" ] && break
        echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Country     : " country; country=$(sanitize "$country")
        [ -n "$country" ] && break
        echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Description : " description; description=$(sanitize "$description")
        [ -n "$description" ] && break
        echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Best Season (Winter/Summer/Spring/Monsoon/Any): " season
        season=$(sanitize "$season")
        [ -n "$season" ] && break
        echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done

    local new_id
    new_id=$(next_id "$PENDING_SPOTS_FILE")
    echo "${new_id}|${name}|${city}|${country}|${description}|${season}|${CURRENT_USER}" >> "$PENDING_SPOTS_FILE"
    log_action "$CURRENT_USER" "SUBMIT_SPOT" "PendingID:${new_id}(${name})"
    echo -e "${GREEN}  ✔ Spot submitted! Waiting for admin approval. (Pending ID: ${new_id})${RESET}"
}

# Submits hotel to pending_hotels.txt — NOT directly to hotels.txt
user_submit_hotel() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Submit New Hotel (Pending Admin Approval) ===${RESET}"
    list_spots

    local spot_id
    while true; do
        read -p "  Spot ID to attach hotel to: " spot_id
        spot_exists "$spot_id" && break
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist.${RESET}"
    done

    local hotel_name address price
    while true; do
        read -p "  Hotel name  : " hotel_name; hotel_name=$(sanitize "$hotel_name")
        [ -n "$hotel_name" ] && break
        echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Address     : " address; address=$(sanitize "$address")
        [ -n "$address" ] && break
        echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Price/night (BDT): " price
        if [[ "$price" =~ ^[0-9]+$ ]] && [ "$price" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive whole number.${RESET}"
    done

    local new_id
    new_id=$(next_id "$PENDING_HOTELS_FILE")
    echo "${new_id}|${spot_id}|${hotel_name}|${address}|${price}|${CURRENT_USER}" >> "$PENDING_HOTELS_FILE"
    log_action "$CURRENT_USER" "SUBMIT_HOTEL" "PendingID:${new_id}(${hotel_name})"
    echo -e "${GREEN}  ✔ Hotel submitted! Waiting for admin approval. (Pending ID: ${new_id})${RESET}"
}

user_add_rating() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Add Rating for a Spot ===${RESET}"
    list_spots

    local spot_id rating comment
    while true; do
        read -p "  Enter Spot ID: " spot_id
        spot_exists "$spot_id" && break
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist.${RESET}"
    done
    while true; do
        read -p "  Rating (1-5): " rating
        [[ "$rating" =~ ^[1-5]$ ]] && break
        echo -e "${RED}  ✘ Must be a number 1 to 5.${RESET}"
    done
    read -p "  Comment     : " comment
    comment=$(sanitize "$comment")

    echo "${spot_id}|${CURRENT_USER}|${rating}|${comment}" >> "$RATINGS_FILE"
    log_action "$CURRENT_USER" "ADD_RATING" "SpotID:${spot_id}(${rating}/5)"
    echo -e "${GREEN}  ✔ Rating added successfully!${RESET}"
}

# Travel cost calculator — Price × Days with hotel picker
travel_cost_calculator() {
    echo ""
    echo -e "${CYAN}${BOLD}=== 💰 Travel Cost Calculator ===${RESET}"
    list_spots

    local spot_id
    while true; do
        read -p "  Select Spot ID: " spot_id
        spot_exists "$spot_id" && break
        echo -e "${RED}  ✘ Spot does not exist.${RESET}"
    done

    local spot_name
    spot_name=$(get_spot_name "$spot_id")

    # Show hotels for this spot
    echo ""
    echo -e "  ${CYAN}Available hotels near ${spot_name}:${RESET}"
    local h_count=0
    while IFS='|' read -r hid sid hotel_name address price; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "    ${BOLD}${hid})${RESET}  ${hotel_name}  —  ৳${price}/night  (${address})"
            ((h_count++))
        fi
    done < "$HOTELS_FILE"

    if [ "$h_count" -eq 0 ]; then
        echo -e "${YELLOW}  No hotels available for this spot yet.${RESET}"; return
    fi

    # Pick hotel — validate it belongs to this spot
    local hotel_id selected_name selected_price hotel_line
    while true; do
        read -p "  Select Hotel ID: " hotel_id
        # Pattern: HotelID|SpotID| — ensures hotel belongs to the chosen spot
        hotel_line=$(grep "^${hotel_id}|${spot_id}|" "$HOTELS_FILE")
        if [ -n "$hotel_line" ]; then
            IFS='|' read -r hid sid selected_name address selected_price <<< "$hotel_line"
            break
        fi
        echo -e "${RED}  ✘ Invalid Hotel ID for this spot.${RESET}"
    done

    local days
    while true; do
        read -p "  Number of nights: " days
        if [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive number.${RESET}"
    done

    # awk handles the multiplication cleanly
    local total
    total=$(awk "BEGIN { print $selected_price * $days }")

    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}            💰  Trip Cost Summary            ${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${RESET}"
    echo -e "  📍 Destination : ${spot_name}"
    echo -e "  🏨 Hotel       : ${selected_name}"
    echo -e "  📅 Nights      : ${days}"
    echo -e "  💵 Rate        : ৳${selected_price} / night"
    echo -e "  ${BOLD}💰 Total Cost  : ৳${total}${RESET}"
    echo ""
    log_action "$CURRENT_USER" "COST_CALC" "Spot:${spot_id},Hotel:${hotel_id},Nights:${days},Total:${total}"
}

# ============================================================
# ADMIN-ONLY FEATURES
# ============================================================

# Approval: move spot from pending_spots.txt → spots.txt atomically
admin_approve_spots() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== Pending Spots — Approve or Disapprove ===${RESET}"

    local count=0
    while IFS='|' read -r id name city country description season submitted_by; do
        [ "$id" = "SpotID" ] && continue
        echo -e "  ${BOLD}[${id}]${RESET}  ${name}  (${city}, ${country})  📅 ${season}  — by ${YELLOW}${submitted_by}${RESET}"
        ((count++))
    done < "$PENDING_SPOTS_FILE"

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  No pending spots.${RESET}"; return
    fi

    echo ""
    echo -e "  ${BOLD}A)${RESET} Approve a spot"
    echo -e "  ${BOLD}D)${RESET} Disapprove (dismiss) a spot"
    echo -e "  ${BOLD}0)${RESET} Cancel"
    echo ""
    read -p "  Choose action (A/D/0): " action

    case "${action^^}" in

        A)  read -p "  Enter Pending ID to APPROVE: " pending_id

            local spot_line
            spot_line=$(grep "^${pending_id}|" "$PENDING_SPOTS_FILE")
            if [ -z "$spot_line" ]; then
                echo -e "${RED}  ✘ Pending ID '${pending_id}' not found.${RESET}"; return
            fi

            IFS='|' read -r pid name city country description season submitted_by <<< "$spot_line"

            local new_id
            new_id=$(next_id "$SPOTS_FILE")
            local new_entry="${new_id}|${name}|${city}|${country}|${description}|${season}"

            echo "$new_entry" >> "$SPOTS_FILE"

            if grep -q "^${new_id}|" "$SPOTS_FILE"; then
                sed -i "/^${pending_id}|/d" "$PENDING_SPOTS_FILE"
                log_action "$CURRENT_USER" "APPROVE_SPOT" \
                    "NewID:${new_id}(${name}),By:${submitted_by}"
                echo -e "${GREEN}  ✔ '${name}' approved and added as Spot ID ${new_id}.${RESET}"
            else
                echo -e "${RED}  ✘ Write verification failed. Approval aborted safely.${RESET}"
            fi
            ;;

        D)  read -p "  Enter Pending ID to DISAPPROVE: " pending_id

            local spot_line
            spot_line=$(grep "^${pending_id}|" "$PENDING_SPOTS_FILE")
            if [ -z "$spot_line" ]; then
                echo -e "${RED}  ✘ Pending ID '${pending_id}' not found.${RESET}"; return
            fi

            IFS='|' read -r pid name city country description season submitted_by <<< "$spot_line"

            echo ""
            echo -e "${YELLOW}  Spot     : ${name}  (${city}, ${country})${RESET}"
            echo -e "${YELLOW}  Season   : ${season}${RESET}"
            echo -e "${YELLOW}  Submitted by: ${submitted_by}${RESET}"
            echo ""
            read -p "  Confirm disapprove? (yes/no): " confirm

            if [ "${confirm,,}" = "yes" ]; then
                sed -i "/^${pending_id}|/d" "$PENDING_SPOTS_FILE"
                log_action "$CURRENT_USER" "DISAPPROVE_SPOT" \
                    "PendingID:${pending_id}(${name}),By:${submitted_by}"
                echo -e "${GREEN}  ✔ Pending spot '${name}' dismissed and removed.${RESET}"
            else
                echo -e "${YELLOW}  Cancelled.${RESET}"
            fi
            ;;

        0)  return ;;
        *)  echo -e "${RED}  ✘ Invalid choice.${RESET}" ;;
    esac
}

# Approval: move hotel from pending_hotels.txt → hotels.txt atomically
admin_approve_hotels() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== Pending Hotels — Approve or Disapprove ===${RESET}"

    # Check if the spot the hotel belongs to still exists
    # and warn if it doesn't (shouldn't happen now, but good safety net)
    local count=0
    while IFS='|' read -r id spot_id hotel_name address price submitted_by; do
        [ "$id" = "HotelID" ] && continue
        local sname
        if spot_exists "$spot_id"; then
            sname=$(get_spot_name "$spot_id")
            echo -e "  ${BOLD}[${id}]${RESET}  ${hotel_name}  near ${sname} (SpotID:${spot_id})  ৳${price}/night  — by ${YELLOW}${submitted_by}${RESET}"
        else
            # Spot was deleted but pending entry survived (edge case guard)
            echo -e "  ${BOLD}[${id}]${RESET}  ${hotel_name}  ${RED}⚠ SpotID:${spot_id} no longer exists${RESET}  — by ${YELLOW}${submitted_by}${RESET}"
        fi
        ((count++))
    done < "$PENDING_HOTELS_FILE"

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  No pending hotels.${RESET}"; return
    fi

    echo ""
    echo -e "  ${BOLD}A)${RESET} Approve a hotel"
    echo -e "  ${BOLD}D)${RESET} Disapprove (dismiss) a hotel"
    echo -e "  ${BOLD}0)${RESET} Cancel"
    echo ""
    read -p "  Choose action (A/D/0): " action

    case "${action^^}" in   # ^^ converts input to uppercase

        A)  # ── APPROVE ──────────────────────────────────────────
            read -p "  Enter Pending ID to APPROVE: " pending_id

            local hotel_line
            hotel_line=$(grep "^${pending_id}|" "$PENDING_HOTELS_FILE")
            if [ -z "$hotel_line" ]; then
                echo -e "${RED}  ✘ Pending ID '${pending_id}' not found.${RESET}"; return
            fi

            IFS='|' read -r pid spot_id hotel_name address price submitted_by <<< "$hotel_line"

            # Guard: make sure the spot still exists before approving
            if ! spot_exists "$spot_id"; then
                echo -e "${RED}  ✘ Cannot approve: SpotID '${spot_id}' no longer exists.${RESET}"
                echo -e "${YELLOW}  Tip: Use Disapprove to clean up this orphaned entry.${RESET}"
                return
            fi

            local new_id
            new_id=$(next_id "$HOTELS_FILE")
            local new_entry="${new_id}|${spot_id}|${hotel_name}|${address}|${price}"

            # Atomic write: append first, verify, then delete from pending
            echo "$new_entry" >> "$HOTELS_FILE"

            if grep -q "^${new_id}|" "$HOTELS_FILE"; then
                sed -i "/^${pending_id}|/d" "$PENDING_HOTELS_FILE"
                log_action "$CURRENT_USER" "APPROVE_HOTEL" \
                    "NewID:${new_id}(${hotel_name}),SpotID:${spot_id},By:${submitted_by}"
                echo -e "${GREEN}  ✔ '${hotel_name}' approved and added as Hotel ID ${new_id}.${RESET}"
            else
                echo -e "${RED}  ✘ Write verification failed. Approval aborted safely.${RESET}"
            fi
            ;;

        D)  # ── DISAPPROVE ──────────────────────────────────────
            read -p "  Enter Pending ID to DISAPPROVE: " pending_id

            local hotel_line
            hotel_line=$(grep "^${pending_id}|" "$PENDING_HOTELS_FILE")
            if [ -z "$hotel_line" ]; then
                echo -e "${RED}  ✘ Pending ID '${pending_id}' not found.${RESET}"; return
            fi

            IFS='|' read -r pid spot_id hotel_name address price submitted_by <<< "$hotel_line"

            echo ""
            echo -e "${YELLOW}  Hotel    : ${hotel_name}${RESET}"
            echo -e "${YELLOW}  SpotID   : ${spot_id}${RESET}"
            echo -e "${YELLOW}  Price    : ৳${price}/night${RESET}"
            echo -e "${YELLOW}  Submitted by: ${submitted_by}${RESET}"
            echo ""
            read -p "  Confirm disapprove? (yes/no): " confirm

            if [ "${confirm,,}" = "yes" ]; then    # ,, converts to lowercase
                sed -i "/^${pending_id}|/d" "$PENDING_HOTELS_FILE"
                log_action "$CURRENT_USER" "DISAPPROVE_HOTEL" \
                    "PendingID:${pending_id}(${hotel_name}),SpotID:${spot_id},By:${submitted_by}"
                echo -e "${GREEN}  ✔ Pending hotel '${hotel_name}' dismissed and removed.${RESET}"
            else
                echo -e "${YELLOW}  Cancelled.${RESET}"
            fi
            ;;

        0)  return ;;
        *)  echo -e "${RED}  ✘ Invalid choice.${RESET}" ;;
    esac
}

# Cascade delete: removes a spot AND all its linked hotels + ratings
admin_delete_spot() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== Delete a Spot (Cascade) ===${RESET}"
    list_spots

    local spot_id
    read -p "  Enter Spot ID to DELETE: " spot_id
    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' not found.${RESET}"; return
    fi

    local spot_name
    spot_name=$(get_spot_name "$spot_id")
    echo ""
    echo -e "${RED}  ⚠  WARNING: This will permanently delete:${RESET}"
    echo -e "${RED}     • Spot: ${spot_name}${RESET}"
    echo -e "${RED}     • ALL hotels linked to this spot${RESET}"
    echo -e "${RED}     • ALL ratings linked to this spot${RESET}"
    echo ""
    read -p "  Type 'YES' to confirm permanent deletion: " confirm
    [ "$confirm" != "YES" ] && echo -e "${YELLOW}  Cancelled.${RESET}" && return

    # CASCADE DELETE using sed -i (in-place deletion)
    # 1. Delete the spot row
    sed -i "/^${spot_id}|/d" "$SPOTS_FILE"

    # 2. Delete all live hotels for this spot
    sed -i "/^[^|]*|${spot_id}|/d" "$HOTELS_FILE"

    # 3. Delete all ratings for this spot
    sed -i "/^${spot_id}|/d" "$RATINGS_FILE"

    # 4. Delete all PENDING hotels for this spot
    #    Prevents orphaned pending entries attaching to a future recycled SpotID
    local pending_hotel_count
    pending_hotel_count=$(grep -c "^[^|]*|${spot_id}|" "$PENDING_HOTELS_FILE" 2>/dev/null || echo 0)
    sed -i "/^[^|]*|${spot_id}|/d" "$PENDING_HOTELS_FILE"

    log_action "$CURRENT_USER" "CASCADE_DELETE" "SpotID:${spot_id}(${spot_name}),PendingHotelsRemoved:${pending_hotel_count}"
    echo -e "${GREEN}  ✔ Spot '${spot_name}' and all linked data permanently deleted.${RESET}"
    [ "$pending_hotel_count" -gt 0 ] && \
        echo -e "${YELLOW}  ⚠  Also removed ${pending_hotel_count} pending hotel submission(s) for this spot.${RESET}"
}

# View all registered users (passwords hidden — only hashes stored)
admin_view_users() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== All Registered Users ===${RESET}"
    echo ""
    printf "  ${BOLD}%-6s | %-20s | %-8s${RESET}\n" "ID" "Username" "Role"
    echo "  -------+---------------------+---------"
    while IFS='|' read -r uid username hash role; do
        [ "$uid" = "UserID" ] && continue
        printf "  %-6s | %-20s | %-8s\n" "$uid" "$username" "$role"
    done < "$USERS_FILE"
    echo ""
}

# View the full audit trail
admin_view_audit_log() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== System Audit Log ===${RESET}"
    echo ""
    printf "  ${BOLD}%-20s | %-14s | %-26s | %s${RESET}\n" "Timestamp" "Actor" "Action" "Target"
    echo "  ---------------------+---------------+---------------------------+------------------"
    tail -n +2 "$AUDIT_LOG" | while IFS='|' read -r ts actor action target; do
        printf "  %-20s | %-14s | %-26s | %s\n" "$ts" "$actor" "$action" "$target"
    done
    echo ""
}

# ============================================================
# ROLE-BASED MENUS
# ============================================================

user_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
        printf  "${BOLD}${GREEN}   👤  User Panel — %-30s${RESET}\n" "${CURRENT_USER}"
        echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
        echo -e "  ${BOLD} 1)${RESET}  List all spots"
        echo -e "  ${BOLD} 2)${RESET}  Search by city"
        echo -e "  ${BOLD} 3)${RESET}  Search by country"
        echo -e "  ${BOLD} 4)${RESET}  Search by best season  🌤"
        echo -e "  ${BOLD} 5)${RESET}  Submit a new spot  (pending approval)"
        echo -e "  ${BOLD} 6)${RESET}  Submit a new hotel (pending approval)"
        echo -e "  ${BOLD} 7)${RESET}  Add rating for a spot"
        echo -e "  ${BOLD} 8)${RESET}  List ratings for a spot"
        echo -e "  ${BOLD} 9)${RESET}  Show full summary for a spot"
        echo -e "  ${BOLD}10)${RESET}  Top rated spots  🏆"
        echo -e "  ${BOLD}11)${RESET}  Travel cost calculator  💰"
        echo -e "  ${BOLD}12)${RESET}  Logout"
        echo ""
        read -p "  Choose (1-12): " choice

        case "$choice" in
            1)  list_spots ;;
            2)  search_by_city ;;
            3)  search_by_country ;;
            4)  search_by_season ;;
            5)  user_submit_spot ;;
            6)  user_submit_hotel ;;
            7)  user_add_rating ;;
            8)  list_ratings_for_spot ;;
            9)  show_full_summary ;;
            10) top_rated_spots ;;
            11) travel_cost_calculator ;;
            12) do_logout; return ;;
            *)  echo -e "${RED}  ✘ Invalid option. Choose 1–12.${RESET}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

admin_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}${MAGENTA}╔══════════════════════════════════════════════════╗${RESET}"
        printf  "${BOLD}${MAGENTA}   🛠  Admin Panel — %-30s${RESET}\n" "${CURRENT_USER}"
        echo -e "${BOLD}${MAGENTA}╚══════════════════════════════════════════════════╝${RESET}"
        echo -e "  ${BOLD} 1)${RESET}  List all spots"
        echo -e "  ${BOLD} 2)${RESET}  Approve pending spots  ✅"
        echo -e "  ${BOLD} 3)${RESET}  Approve pending hotels ✅"
        echo -e "  ${BOLD} 4)${RESET}  Delete a spot (cascade) 🗑"
        echo -e "  ${BOLD} 5)${RESET}  View all registered users"
        echo -e "  ${BOLD} 6)${RESET}  View audit log  📋"
        echo -e "  ${BOLD} 7)${RESET}  Average ratings for all spots"
        echo -e "  ${BOLD} 8)${RESET}  Show full summary for a spot"
        echo -e "  ${BOLD} 9)${RESET}  Top rated spots  🏆"
        echo -e "  ${BOLD}10)${RESET}  Export summary report"
        echo -e "  ${BOLD}11)${RESET}  Logout"
        echo ""
        read -p "  Choose (1-11): " choice

        case "$choice" in
            1)  list_spots ;;
            2)  admin_approve_spots ;;
            3)  admin_approve_hotels ;;
            4)  admin_delete_spot ;;
            5)  admin_view_users ;;
            6)  admin_view_audit_log ;;
            7)  average_ratings_all ;;
            8)  show_full_summary ;;
            9)  top_rated_spots ;;
            10) export_summary_report ;;
            11) do_logout; return ;;
            *)  echo -e "${RED}  ✘ Invalid option. Choose 1–11.${RESET}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

# ============================================================
# ENTRY POINT
# ============================================================
init_files

# Outer loop: keeps returning to splash screen after logout
while true; do
    splash_screen
    # Route to correct menu based on role
    if [ "$CURRENT_ROLE" = "Admin" ]; then
        admin_menu
    else
        user_menu
    fi
done
