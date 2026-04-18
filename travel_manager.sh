#!/bin/bash

# ============================================================
#  Travel Spot Management System
#  Student: SHIMANTO SHIRSHO (2204009)
#  Course : Operating Systems (CSE)
#  Roles  : Admin | HotelManager | User
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
# INIT
# hotels.txt schema:
#   HotelID|SpotID|HotelName|Address|PricePerNight|TotalRooms|AvailableRooms|ManagerUsername
# pending_hotels.txt schema:
#   HotelID|SpotID|HotelName|Address|PricePerNight|TotalRooms|SubmittedBy
# bookings.txt schema:
#   BookingID|Username|HotelID|HotelName|SpotID|Nights|Status|Timestamp
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
        echo "BookingID|Username|HotelID|HotelName|SpotID|Nights|Status|Timestamp" > "$BOOKINGS_FILE"
        echo -e "${GREEN}[INFO] bookings.txt created.${RESET}"
    fi

    if [ ! -f "$AUDIT_LOG" ]; then
        echo "Timestamp|Actor|Action|TargetID" > "$AUDIT_LOG"
        echo -e "${GREEN}[INFO] audit_log.txt created.${RESET}"
    fi
}

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
# SANITIZE
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

# Safe in-place field update using awk — avoids sed breaking on special chars
update_field() {
    # update_field <file> <id_to_match_col1> <column_number> <new_value>
    local file="$1" match_id="$2" col="$3" new_val="$4"
    awk -F'|' -v id="$match_id" -v c="$col" -v val="$new_val" \
        'BEGIN{OFS="|"} $1==id{$c=val} {print}' "$file" > "${file}.tmp" \
        && mv "${file}.tmp" "$file"
}

# ============================================================
# AUTHENTICATION
# ============================================================
do_signup() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Create New Account ===${RESET}"

    local username
    while true; do
        read -p "  Choose a username  : " username
        username=$(sanitize "$username")
        [ -z "$username" ] && echo -e "${RED}  ✘ Username cannot be empty.${RESET}" && continue
        if grep -q "^[^|]*|${username}|" "$USERS_FILE"; then
            echo -e "${RED}  ✘ Username '${username}' is already taken.${RESET}"
        else
            break
        fi
    done

    local password password2
    while true; do
        read -s -p "  Password (hidden)  : " password; echo ""
        [ -z "$password" ] && echo -e "${RED}  ✘ Password cannot be empty.${RESET}" && continue
        read -s -p "  Confirm password   : " password2; echo ""
        [ "$password" = "$password2" ] && break
        echo -e "${RED}  ✘ Passwords do not match.${RESET}"
    done

    echo ""
    echo -e "  Select account type:"
    echo -e "  ${BOLD}1)${RESET} Regular User"
    echo -e "  ${BOLD}2)${RESET} Hotel Manager"
    local role_choice role
    while true; do
        read -p "  Choose (1/2): " role_choice
        case "$role_choice" in
            1) role="User"; break ;;
            2) role="HotelManager"; break ;;
            *) echo -e "${RED}  ✘ Choose 1 or 2.${RESET}" ;;
        esac
    done

    local new_id hash
    new_id=$(next_id "$USERS_FILE")
    hash=$(hash_password "$password")
    echo "${new_id}|${username}|${hash}|${role}" >> "$USERS_FILE"
    log_action "system" "SIGNUP" "UserID:${new_id}(${username}),Role:${role}"
    echo -e "${GREEN}  ✔ Account created as ${role}! You can now log in.${RESET}"
}

do_login() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Login ===${RESET}"
    read -p "  Username : " username
    read -s -p "  Password : " password; echo ""

    local hash user_line
    hash=$(hash_password "$password")
    user_line=$(grep -m1 "^[^|]*|${username}|${hash}|" "$USERS_FILE")

    if [ -z "$user_line" ]; then
        echo -e "${RED}  ✘ Invalid username or password.${RESET}"
        return 1
    fi

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
# SPLASH SCREEN
# ============================================================
splash_screen() {
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║     🌍  Travel Spot Management System            ║${RESET}"
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
# SHARED FEATURES (all roles)
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

search_by_season() {
    echo ""
    read -p "  Enter season (Winter/Summer/Spring/Monsoon/Any): " season_query
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
    list_spots
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

list_hotels_for_spot() {
    echo ""
    list_spots
    read -p "  Enter Spot ID: " spot_id
    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' not found.${RESET}"; return
    fi
    local spot_name
    spot_name=$(get_spot_name "$spot_id")
    echo -e "${CYAN}${BOLD}=== Hotels near ${spot_name} ===${RESET}"
    local count=0
    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "  🏨 ${BOLD}[${hid}] ${hotel_name}${RESET}"
            echo -e "       Address : ${address}"
            echo -e "       Price   : ৳${price}/night"
            echo -e "       Rooms   : ${avail_rooms}/${total_rooms} available"
            echo -e "       Manager : ${manager}"
            echo ""
            ((count++))
        fi
    done < "$HOTELS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No hotels for this spot.${RESET}"
}

show_full_summary() {
    echo ""
    list_spots
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

    echo -e "  ${CYAN}🏨 Hotels:${RESET}"
    local h_count=0 min_p=0 max_p=0
    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "     - ${BOLD}${hotel_name}${RESET} — ৳${price}/night  (${avail_rooms}/${total_rooms} rooms available)"
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
            END { if (count > 0) printf "%.1f %d", sum/count, count; else printf "N/A 0" }
        ' "$RATINGS_FILE")
        local avg count_r
        avg=$(echo "$result" | awk '{print $1}')
        count_r=$(echo "$result" | awk '{print $2}')
        printf "  %-5s | %-22s | %-12s | %s\n" "$id" "$name" "  ${avg}" "$count_r"
    done < "$SPOTS_FILE"
    echo ""
}

top_rated_spots() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Top Rated Spots ===${RESET}"
    echo ""
    local tmp_file
    tmp_file=$(mktemp)
    while IFS='|' read -r id name city country description season; do
        [ "$id" = "SpotID" ] && continue
        local result
        result=$(awk -F'|' -v sid="$id" '
            NR==1 { next }
            $1 == sid { sum += $3; count++ }
            END { if (count > 0) printf "%.2f %d", sum/count, count; else printf "0.00 0" }
        ' "$RATINGS_FILE")
        local avg count_r
        avg=$(echo "$result" | awk '{print $1}')
        count_r=$(echo "$result" | awk '{print $2}')
        echo "${avg}|${id}|${name}|${city}|${count_r}" >> "$tmp_file"
    done < "$SPOTS_FILE"

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
        echo "  TRAVEL SPOT MANAGEMENT SYSTEM — SUMMARY REPORT"
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
            echo "  [ HOTELS ]"
            local hc=0
            while IFS='|' read -r hid sid hname addr price total_rooms avail_rooms manager; do
                [ "$hid" = "HotelID" ] && continue
                if [ "$sid" = "$id" ]; then
                    echo "    [${hid}] ${hname}  |  ${addr}  |  BDT ${price}/night  |  ${avail_rooms}/${total_rooms} rooms  |  Manager: ${manager}"
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
# USER FEATURES
# ============================================================

user_submit_spot() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Submit New Travel Spot (Pending Admin Approval) ===${RESET}"
    local name city country description season
    while true; do
        read -p "  Spot name   : " name; name=$(sanitize "$name")
        [ -n "$name" ] && break; echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  City        : " city; city=$(sanitize "$city")
        [ -n "$city" ] && break; echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Country     : " country; country=$(sanitize "$country")
        [ -n "$country" ] && break; echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Description : " description; description=$(sanitize "$description")
        [ -n "$description" ] && break; echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Best Season (Winter/Summer/Spring/Monsoon/Any): " season
        season=$(sanitize "$season")
        [ -n "$season" ] && break; echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    local new_id
    new_id=$(next_id "$PENDING_SPOTS_FILE")
    echo "${new_id}|${name}|${city}|${country}|${description}|${season}|${CURRENT_USER}" >> "$PENDING_SPOTS_FILE"
    log_action "$CURRENT_USER" "SUBMIT_SPOT" "PendingID:${new_id}(${name})"
    echo -e "${GREEN}  ✔ Spot submitted! Waiting for admin approval. (Pending ID: ${new_id})${RESET}"
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

# View available rooms per hotel for a chosen spot
user_view_available_seats() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Available Rooms ===${RESET}"
    list_spots
    read -p "  Enter Spot ID: " spot_id
    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' not found.${RESET}"; return
    fi
    local spot_name
    spot_name=$(get_spot_name "$spot_id")
    echo ""
    echo -e "  ${CYAN}Room availability near ${spot_name}:${RESET}"
    echo ""
    local count=0
    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            # Build a simple visual bar
            local bar="" filled=0 empty=10
            [ "$total_rooms" -gt 0 ] && filled=$((avail_rooms * 10 / total_rooms))
            empty=$((10 - filled))
            for ((i=0; i<filled; i++)); do bar+="█"; done
            for ((i=0; i<empty; i++)); do bar+="░"; done
            echo -e "  🏨 ${BOLD}[${hid}] ${hotel_name}${RESET}"
            echo -e "       [${GREEN}${bar}${RESET}]  ${avail_rooms}/${total_rooms} rooms  —  ৳${price}/night"
            echo ""
            ((count++))
        fi
    done < "$HOTELS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No hotels for this spot yet.${RESET}"
}

# User books a hotel — request goes to bookings.txt as Pending
user_book_hotel() {
    echo ""
    echo -e "${CYAN}${BOLD}=== 🛎  Book a Hotel ===${RESET}"
    list_spots

    local spot_id
    while true; do
        read -p "  Select Spot ID: " spot_id
        spot_exists "$spot_id" && break
        echo -e "${RED}  ✘ Spot does not exist.${RESET}"
    done

    local spot_name
    spot_name=$(get_spot_name "$spot_id")

    echo ""
    echo -e "  ${CYAN}Hotels near ${spot_name}:${RESET}"
    local h_count=0
    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            if [ "$avail_rooms" -gt 0 ]; then
                echo -e "  ${BOLD}[${hid}]${RESET}  ${hotel_name}  —  ৳${price}/night  —  ${GREEN}${avail_rooms} rooms available${RESET}"
            else
                echo -e "  ${BOLD}[${hid}]${RESET}  ${hotel_name}  —  ৳${price}/night  —  ${RED}Fully booked${RESET}"
            fi
            ((h_count++))
        fi
    done < "$HOTELS_FILE"

    if [ "$h_count" -eq 0 ]; then
        echo -e "${YELLOW}  No hotels available for this spot yet.${RESET}"; return
    fi

    local hotel_id hotel_line selected_name selected_price avail_rooms
    while true; do
        read -p "  Select Hotel ID: " hotel_id
        hotel_line=$(grep "^${hotel_id}|${spot_id}|" "$HOTELS_FILE")
        if [ -z "$hotel_line" ]; then
            echo -e "${RED}  ✘ Invalid Hotel ID for this spot.${RESET}"; continue
        fi
        IFS='|' read -r hid sid selected_name address selected_price total_rooms avail_rooms manager <<< "$hotel_line"
        if [ "$avail_rooms" -le 0 ]; then
            echo -e "${RED}  ✘ This hotel is fully booked. Choose another.${RESET}"; continue
        fi
        break
    done

    local nights
    while true; do
        read -p "  Number of nights: " nights
        if [[ "$nights" =~ ^[0-9]+$ ]] && [ "$nights" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive number.${RESET}"
    done

    local total timestamp new_id
    total=$(awk "BEGIN { print $selected_price * $nights }")
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    new_id=$(next_id "$BOOKINGS_FILE")

    echo "${new_id}|${CURRENT_USER}|${hotel_id}|${selected_name}|${spot_id}|${nights}|Pending|${timestamp}" >> "$BOOKINGS_FILE"

    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}              🛎  Booking Request Sent              ${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
    echo -e "  📍 Destination  : ${spot_name}"
    echo -e "  🏨 Hotel        : ${selected_name}"
    echo -e "  📅 Nights       : ${nights}"
    echo -e "  💵 Rate         : ৳${selected_price}/night"
    echo -e "  ${BOLD}💰 Total Cost   : ৳${total}${RESET}"
    echo -e "  📋 Status       : ${YELLOW}Pending Manager Approval${RESET}"
    echo -e "  🔖 Booking ID   : #${new_id}"
    echo ""
    log_action "$CURRENT_USER" "BOOK_HOTEL" "BookingID:${new_id},HotelID:${hotel_id}(${selected_name}),Nights:${nights}"
}

# User views their own bookings history
user_my_bookings() {
    echo ""
    echo -e "${CYAN}${BOLD}=== My Bookings ===${RESET}"
    local count=0
    while IFS='|' read -r bid username hotel_id hotel_name spot_id nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        if [ "$username" = "$CURRENT_USER" ]; then
            local spot_name status_color
            spot_name=$(get_spot_name "$spot_id")
            case "$status" in
                Approved) status_color="${GREEN}" ;;
                Rejected) status_color="${RED}" ;;
                *)        status_color="${YELLOW}" ;;
            esac
            echo -e "  ${BOLD}[#${bid}]${RESET}  ${hotel_name}  →  ${spot_name}"
            echo -e "        Nights : ${nights}  |  Status: ${status_color}${status}${RESET}"
            echo -e "        Booked : ${timestamp}"
            echo ""
            ((count++))
        fi
    done < "$BOOKINGS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  You have no bookings yet.${RESET}"
}

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
    echo ""
    echo -e "  ${CYAN}Hotels near ${spot_name}:${RESET}"
    local h_count=0
    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "    ${BOLD}${hid})${RESET}  ${hotel_name}  —  ৳${price}/night  (${avail_rooms} rooms available)"
            ((h_count++))
        fi
    done < "$HOTELS_FILE"

    if [ "$h_count" -eq 0 ]; then
        echo -e "${YELLOW}  No hotels for this spot yet.${RESET}"; return
    fi

    local hotel_id hotel_line selected_name selected_price
    while true; do
        read -p "  Select Hotel ID: " hotel_id
        hotel_line=$(grep "^${hotel_id}|${spot_id}|" "$HOTELS_FILE")
        if [ -n "$hotel_line" ]; then
            IFS='|' read -r hid sid selected_name address selected_price total_rooms avail_rooms manager <<< "$hotel_line"
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

    local total
    total=$(awk "BEGIN { print $selected_price * $days }")
    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}              💰  Trip Cost Summary                 ${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
    echo -e "  📍 Destination : ${spot_name}"
    echo -e "  🏨 Hotel       : ${selected_name}"
    echo -e "  📅 Nights      : ${days}"
    echo -e "  💵 Rate        : ৳${selected_price}/night"
    echo -e "  ${BOLD}💰 Total Cost  : ৳${total}${RESET}"
    echo ""
    log_action "$CURRENT_USER" "COST_CALC" "Spot:${spot_id},Hotel:${hotel_id},Nights:${days},Total:${total}"
}

# ============================================================
# HOTEL MANAGER FEATURES
# ============================================================

# Hotel Manager submits hotel — goes to pending for admin approval
hm_add_hotel() {
    echo ""
    echo -e "${BLUE}${BOLD}=== Add New Hotel (Pending Admin Approval) ===${RESET}"
    list_spots

    local spot_id
    while true; do
        read -p "  Spot ID to attach hotel to: " spot_id
        spot_exists "$spot_id" && break
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist.${RESET}"
    done

    local hotel_name address price total_rooms
    while true; do
        read -p "  Hotel name   : " hotel_name; hotel_name=$(sanitize "$hotel_name")
        [ -n "$hotel_name" ] && break; echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Address      : " address; address=$(sanitize "$address")
        [ -n "$address" ] && break; echo -e "${RED}  ✘ Cannot be empty.${RESET}"
    done
    while true; do
        read -p "  Price/night (BDT): " price
        if [[ "$price" =~ ^[0-9]+$ ]] && [ "$price" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive whole number.${RESET}"
    done
    while true; do
        read -p "  Total rooms  : " total_rooms
        if [[ "$total_rooms" =~ ^[0-9]+$ ]] && [ "$total_rooms" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive whole number.${RESET}"
    done

    local new_id
    new_id=$(next_id "$PENDING_HOTELS_FILE")
    echo "${new_id}|${spot_id}|${hotel_name}|${address}|${price}|${total_rooms}|${CURRENT_USER}" >> "$PENDING_HOTELS_FILE"
    log_action "$CURRENT_USER" "SUBMIT_HOTEL" "PendingID:${new_id}(${hotel_name}),SpotID:${spot_id}"
    echo -e "${GREEN}  ✔ Hotel submitted for admin approval! (Pending ID: ${new_id})${RESET}"
}

# Hotel Manager views only hotels they manage
hm_my_hotels() {
    echo ""
    echo -e "${BLUE}${BOLD}=== My Hotels ===${RESET}"
    local count=0
    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$manager" = "$CURRENT_USER" ]; then
            local spot_name
            spot_name=$(get_spot_name "$sid")
            echo -e "  🏨 ${BOLD}[${hid}] ${hotel_name}${RESET}  —  near ${spot_name}"
            echo -e "       Address : ${address}"
            echo -e "       Price   : ৳${price}/night"
            echo -e "       Rooms   : ${avail_rooms}/${total_rooms} available"
            echo ""
            ((count++))
        fi
    done < "$HOTELS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  You have no approved hotels yet.${RESET}"
}

# Hotel Manager views room availability for their hotels
hm_view_seats() {
    echo ""
    echo -e "${BLUE}${BOLD}=== Available Seats — My Hotels ===${RESET}"
    echo ""
    local count=0
    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        if [ "$manager" = "$CURRENT_USER" ]; then
            local bar="" filled=0 empty=10
            [ "$total_rooms" -gt 0 ] && filled=$((avail_rooms * 10 / total_rooms))
            empty=$((10 - filled))
            for ((i=0; i<filled; i++)); do bar+="█"; done
            for ((i=0; i<empty; i++)); do bar+="░"; done
            echo -e "  🏨 ${BOLD}[${hid}] ${hotel_name}${RESET}"
            echo -e "       [${GREEN}${bar}${RESET}]  ${avail_rooms}/${total_rooms} rooms available"
            echo ""
            ((count++))
        fi
    done < "$HOTELS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No approved hotels found for your account.${RESET}"
}

# Hotel Manager views all booking requests for their hotels
hm_booking_requests() {
    echo ""
    echo -e "${BLUE}${BOLD}=== Booking Requests — My Hotels ===${RESET}"
    local count=0
    while IFS='|' read -r bid username hotel_id hotel_name spot_id nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        local manager
        manager=$(get_hotel_manager "$hotel_id")
        if [ "$manager" = "$CURRENT_USER" ]; then
            local spot_name status_color
            spot_name=$(get_spot_name "$spot_id")
            case "$status" in
                Approved) status_color="${GREEN}" ;;
                Rejected) status_color="${RED}" ;;
                *)        status_color="${YELLOW}" ;;
            esac
            echo -e "  ${BOLD}[Booking #${bid}]${RESET}"
            echo -e "    Guest  : ${BOLD}${username}${RESET}"
            echo -e "    Hotel  : ${hotel_name}  (ID: ${hotel_id})"
            echo -e "    Spot   : ${spot_name}"
            echo -e "    Nights : ${nights}"
            echo -e "    Status : ${status_color}${status}${RESET}"
            echo -e "    Time   : ${timestamp}"
            echo ""
            ((count++))
        fi
    done < "$BOOKINGS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No booking requests for your hotels.${RESET}"
}

# Hotel Manager approves or rejects a pending booking
hm_approve_booking() {
    echo ""
    echo -e "${BLUE}${BOLD}=== Approve / Reject a Booking ===${RESET}"

    # Show only pending bookings for this manager's hotels
    local count=0
    while IFS='|' read -r bid username hotel_id hotel_name spot_id nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        [ "$status" != "Pending" ] && continue
        local manager
        manager=$(get_hotel_manager "$hotel_id")
        if [ "$manager" = "$CURRENT_USER" ]; then
            echo -e "  ${BOLD}[#${bid}]${RESET}  ${BOLD}${username}${RESET}  →  ${hotel_name}  —  ${nights} night(s)"
            ((count++))
        fi
    done < "$BOOKINGS_FILE"

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  No pending booking requests.${RESET}"; return
    fi

    read -p "  Enter Booking ID: " booking_id

    local booking_line
    booking_line=$(grep "^${booking_id}|" "$BOOKINGS_FILE")
    if [ -z "$booking_line" ]; then
        echo -e "${RED}  ✘ Booking ID '${booking_id}' not found.${RESET}"; return
    fi

    IFS='|' read -r bid b_username hotel_id hotel_name spot_id nights status timestamp <<< "$booking_line"

    # Security check: verify this hotel belongs to the current manager
    local manager
    manager=$(get_hotel_manager "$hotel_id")
    if [ "$manager" != "$CURRENT_USER" ]; then
        echo -e "${RED}  ✘ This booking does not belong to your hotel.${RESET}"; return
    fi

    if [ "$status" != "Pending" ]; then
        echo -e "${RED}  ✘ This booking is already ${status}.${RESET}"; return
    fi

    echo ""
    echo -e "  Guest  : ${BOLD}${b_username}${RESET}"
    echo -e "  Hotel  : ${hotel_name}"
    echo -e "  Nights : ${nights}"
    echo ""
    echo -e "  ${BOLD}A)${RESET} Approve  |  ${BOLD}R)${RESET} Reject  |  ${BOLD}0)${RESET} Cancel"
    read -p "  Choose (A/R/0): " action

    case "${action^^}" in
        A)
            local avail_rooms
            avail_rooms=$(get_available_rooms "$hotel_id")
            if [ "$avail_rooms" -le 0 ]; then
                echo -e "${RED}  ✘ No rooms available. Cannot approve.${RESET}"; return
            fi
            # Update booking status field (column 7) to Approved
            update_field "$BOOKINGS_FILE" "$booking_id" 7 "Approved"
            # Decrease available rooms (column 7) in hotels.txt by 1
            local new_avail=$((avail_rooms - 1))
            update_field "$HOTELS_FILE" "$hotel_id" 7 "$new_avail"
            log_action "$CURRENT_USER" "APPROVE_BOOKING" "BookingID:${booking_id},Guest:${b_username},HotelID:${hotel_id}"
            echo -e "${GREEN}  ✔ Booking #${booking_id} approved. Room assigned to ${b_username}.${RESET}"
            ;;
        R)
            read -p "  Confirm rejection? (yes/no): " confirm
            if [ "${confirm,,}" = "yes" ]; then
                update_field "$BOOKINGS_FILE" "$booking_id" 7 "Rejected"
                log_action "$CURRENT_USER" "REJECT_BOOKING" "BookingID:${booking_id},Guest:${b_username},HotelID:${hotel_id}"
                echo -e "${GREEN}  ✔ Booking #${booking_id} rejected.${RESET}"
            else
                echo -e "${YELLOW}  Cancelled.${RESET}"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}  ✘ Invalid choice.${RESET}" ;;
    esac
}

# ============================================================
# ADMIN FEATURES
# ============================================================

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
    echo -e "  ${BOLD}A)${RESET} Approve  |  ${BOLD}D)${RESET} Disapprove  |  ${BOLD}0)${RESET} Cancel"
    read -p "  Choose action (A/D/0): " action

    case "${action^^}" in
        A)
            read -p "  Enter Pending ID to APPROVE: " pending_id
            local spot_line
            spot_line=$(grep "^${pending_id}|" "$PENDING_SPOTS_FILE")
            [ -z "$spot_line" ] && echo -e "${RED}  ✘ Not found.${RESET}" && return
            IFS='|' read -r pid name city country description season submitted_by <<< "$spot_line"
            local new_id
            new_id=$(next_id "$SPOTS_FILE")
            echo "${new_id}|${name}|${city}|${country}|${description}|${season}" >> "$SPOTS_FILE"
            if grep -q "^${new_id}|" "$SPOTS_FILE"; then
                sed -i "/^${pending_id}|/d" "$PENDING_SPOTS_FILE"
                log_action "$CURRENT_USER" "APPROVE_SPOT" "NewID:${new_id}(${name}),By:${submitted_by}"
                echo -e "${GREEN}  ✔ '${name}' approved as Spot ID ${new_id}.${RESET}"
            else
                echo -e "${RED}  ✘ Write failed. Aborted safely.${RESET}"
            fi
            ;;
        D)
            read -p "  Enter Pending ID to DISAPPROVE: " pending_id
            local spot_line
            spot_line=$(grep "^${pending_id}|" "$PENDING_SPOTS_FILE")
            [ -z "$spot_line" ] && echo -e "${RED}  ✘ Not found.${RESET}" && return
            IFS='|' read -r pid name city country description season submitted_by <<< "$spot_line"
            echo -e "${YELLOW}  Spot: ${name}  (${city}, ${country})  — by ${submitted_by}${RESET}"
            read -p "  Confirm disapprove? (yes/no): " confirm
            if [ "${confirm,,}" = "yes" ]; then
                sed -i "/^${pending_id}|/d" "$PENDING_SPOTS_FILE"
                log_action "$CURRENT_USER" "DISAPPROVE_SPOT" "PendingID:${pending_id}(${name}),By:${submitted_by}"
                echo -e "${GREEN}  ✔ Spot '${name}' dismissed.${RESET}"
            else
                echo -e "${YELLOW}  Cancelled.${RESET}"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}  ✘ Invalid choice.${RESET}" ;;
    esac
}

# Pending hotels now submitted by Hotel Managers
admin_approve_hotels() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== Pending Hotels — Approve or Disapprove ===${RESET}"
    echo -e "  ${YELLOW}(Submissions from Hotel Managers)${RESET}"
    echo ""

    local count=0
    while IFS='|' read -r id spot_id hotel_name address price total_rooms submitted_by; do
        [ "$id" = "HotelID" ] && continue
        if spot_exists "$spot_id"; then
            local sname
            sname=$(get_spot_name "$spot_id")
            echo -e "  ${BOLD}[${id}]${RESET}  ${hotel_name}  near ${sname}  —  ৳${price}/night  —  ${total_rooms} rooms  — by ${YELLOW}${submitted_by}${RESET}"
        else
            echo -e "  ${BOLD}[${id}]${RESET}  ${hotel_name}  ${RED}⚠ SpotID:${spot_id} no longer exists${RESET}  — by ${YELLOW}${submitted_by}${RESET}"
        fi
        ((count++))
    done < "$PENDING_HOTELS_FILE"

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  No pending hotels.${RESET}"; return
    fi

    echo ""
    echo -e "  ${BOLD}A)${RESET} Approve  |  ${BOLD}D)${RESET} Disapprove  |  ${BOLD}0)${RESET} Cancel"
    read -p "  Choose action (A/D/0): " action

    case "${action^^}" in
        A)
            read -p "  Enter Pending ID to APPROVE: " pending_id
            local hotel_line
            hotel_line=$(grep "^${pending_id}|" "$PENDING_HOTELS_FILE")
            [ -z "$hotel_line" ] && echo -e "${RED}  ✘ Not found.${RESET}" && return
            IFS='|' read -r pid spot_id hotel_name address price total_rooms submitted_by <<< "$hotel_line"

            if ! spot_exists "$spot_id"; then
                echo -e "${RED}  ✘ Cannot approve: Spot no longer exists. Use Disapprove to clean up.${RESET}"; return
            fi

            local new_id
            new_id=$(next_id "$HOTELS_FILE")
            # AvailableRooms starts equal to TotalRooms; ManagerUsername = submitted_by
            echo "${new_id}|${spot_id}|${hotel_name}|${address}|${price}|${total_rooms}|${total_rooms}|${submitted_by}" >> "$HOTELS_FILE"

            if grep -q "^${new_id}|" "$HOTELS_FILE"; then
                sed -i "/^${pending_id}|/d" "$PENDING_HOTELS_FILE"
                log_action "$CURRENT_USER" "APPROVE_HOTEL" "NewID:${new_id}(${hotel_name}),Manager:${submitted_by}"
                echo -e "${GREEN}  ✔ '${hotel_name}' approved as Hotel ID ${new_id}. Manager: ${submitted_by}${RESET}"
            else
                echo -e "${RED}  ✘ Write failed. Aborted safely.${RESET}"
            fi
            ;;
        D)
            read -p "  Enter Pending ID to DISAPPROVE: " pending_id
            local hotel_line
            hotel_line=$(grep "^${pending_id}|" "$PENDING_HOTELS_FILE")
            [ -z "$hotel_line" ] && echo -e "${RED}  ✘ Not found.${RESET}" && return
            IFS='|' read -r pid spot_id hotel_name address price total_rooms submitted_by <<< "$hotel_line"
            echo -e "${YELLOW}  Hotel: ${hotel_name}  —  ৳${price}/night  —  ${total_rooms} rooms  — by ${submitted_by}${RESET}"
            read -p "  Confirm disapprove? (yes/no): " confirm
            if [ "${confirm,,}" = "yes" ]; then
                sed -i "/^${pending_id}|/d" "$PENDING_HOTELS_FILE"
                log_action "$CURRENT_USER" "DISAPPROVE_HOTEL" "PendingID:${pending_id}(${hotel_name}),By:${submitted_by}"
                echo -e "${GREEN}  ✔ Hotel '${hotel_name}' dismissed.${RESET}"
            else
                echo -e "${YELLOW}  Cancelled.${RESET}"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}  ✘ Invalid choice.${RESET}" ;;
    esac
}

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
    echo -e "${RED}  ⚠  WARNING: Permanently deletes:${RESET}"
    echo -e "${RED}     • Spot: ${spot_name}${RESET}"
    echo -e "${RED}     • All live hotels for this spot${RESET}"
    echo -e "${RED}     • All ratings for this spot${RESET}"
    echo -e "${RED}     • All bookings for this spot${RESET}"
    echo -e "${RED}     • All pending hotel submissions for this spot${RESET}"
    echo ""
    read -p "  Type 'YES' to confirm: " confirm
    [ "$confirm" != "YES" ] && echo -e "${YELLOW}  Cancelled.${RESET}" && return

    sed -i "/^${spot_id}|/d" "$SPOTS_FILE"
    sed -i "/^[^|]*|${spot_id}|/d" "$HOTELS_FILE"
    sed -i "/^${spot_id}|/d" "$RATINGS_FILE"
    sed -i "/^[^|]*|${spot_id}|/d" "$PENDING_HOTELS_FILE"
    # Remove bookings where SpotID (col 5) matches
    awk -F'|' -v sid="$spot_id" '$5 != sid || NR==1' "$BOOKINGS_FILE" > "${BOOKINGS_FILE}.tmp" \
        && mv "${BOOKINGS_FILE}.tmp" "$BOOKINGS_FILE"

    log_action "$CURRENT_USER" "CASCADE_DELETE" "SpotID:${spot_id}(${spot_name})"
    echo -e "${GREEN}  ✔ Spot '${spot_name}' and all linked data permanently deleted.${RESET}"
}

admin_view_users() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== All Registered Users ===${RESET}"
    echo ""
    printf "  ${BOLD}%-6s | %-20s | %-14s${RESET}\n" "ID" "Username" "Role"
    echo "  -------+---------------------+---------------"
    while IFS='|' read -r uid username hash role; do
        [ "$uid" = "UserID" ] && continue
        printf "  %-6s | %-20s | %-14s\n" "$uid" "$username" "$role"
    done < "$USERS_FILE"
    echo ""
}

admin_view_audit_log() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== System Audit Log ===${RESET}"
    echo ""
    printf "  ${BOLD}%-20s | %-16s | %-26s | %s${RESET}\n" "Timestamp" "Actor" "Action" "Target"
    echo "  ---------------------+-----------------+---------------------------+------------------"
    tail -n +2 "$AUDIT_LOG" | while IFS='|' read -r ts actor action target; do
        printf "  %-20s | %-16s | %-26s | %s\n" "$ts" "$actor" "$action" "$target"
    done
    echo ""
}

admin_view_all_bookings() {
    echo ""
    echo -e "${MAGENTA}${BOLD}=== All Bookings ===${RESET}"
    local count=0
    while IFS='|' read -r bid username hotel_id hotel_name spot_id nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        local spot_name manager status_color
        spot_name=$(get_spot_name "$spot_id")
        manager=$(get_hotel_manager "$hotel_id")
        case "$status" in
            Approved) status_color="${GREEN}" ;;
            Rejected) status_color="${RED}" ;;
            *)        status_color="${YELLOW}" ;;
        esac
        echo -e "  ${BOLD}[#${bid}]${RESET}  ${username}  →  ${hotel_name}  (${spot_name})"
        echo -e "        Nights  : ${nights}  |  Manager: ${manager}  |  Status: ${status_color}${status}${RESET}"
        echo -e "        Time    : ${timestamp}"
        echo ""
        ((count++))
    done < "$BOOKINGS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No bookings yet.${RESET}"
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
        echo -e "  ${BOLD} 5)${RESET}  Submit a new spot"
        echo -e "  ${BOLD} 6)${RESET}  Add rating for a spot"
        echo -e "  ${BOLD} 7)${RESET}  List ratings for a spot"
        echo -e "  ${BOLD} 8)${RESET}  Show full summary for a spot"
        echo -e "  ${BOLD} 9)${RESET}  View available rooms  🛏"
        echo -e "  ${BOLD}10)${RESET}  Book a hotel  🛎"
        echo -e "  ${BOLD}11)${RESET}  My bookings"
        echo -e "  ${BOLD}12)${RESET}  Top rated spots  🏆"
        echo -e "  ${BOLD}13)${RESET}  Travel cost calculator  💰"
        echo -e "  ${BOLD}14)${RESET}  Logout"
        echo ""
        read -p "  Choose (1-14): " choice
        case "$choice" in
            1)  list_spots ;;
            2)  search_by_city ;;
            3)  search_by_country ;;
            4)  search_by_season ;;
            5)  user_submit_spot ;;
            6)  user_add_rating ;;
            7)  list_ratings_for_spot ;;
            8)  show_full_summary ;;
            9)  user_view_available_seats ;;
            10) user_book_hotel ;;
            11) user_my_bookings ;;
            12) top_rated_spots ;;
            13) travel_cost_calculator ;;
            14) do_logout; return ;;
            *)  echo -e "${RED}  ✘ Invalid option. Choose 1–14.${RESET}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

hotel_manager_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${RESET}"
        printf  "${BOLD}${BLUE}   🏨  Hotel Manager — %-28s${RESET}\n" "${CURRENT_USER}"
        echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${RESET}"
        echo -e "  ${BOLD} 1)${RESET}  List all spots"
        echo -e "  ${BOLD} 2)${RESET}  Search by city"
        echo -e "  ${BOLD} 3)${RESET}  Search by country"
        echo -e "  ${BOLD} 4)${RESET}  List ratings for a spot"
        echo -e "  ${BOLD} 5)${RESET}  List hotels for a spot"
        echo -e "  ${BOLD} 6)${RESET}  Add new hotel  (pending admin approval)"
        echo -e "  ${BOLD} 7)${RESET}  My hotels"
        echo -e "  ${BOLD} 8)${RESET}  Available seats — my hotels  🛏"
        echo -e "  ${BOLD} 9)${RESET}  Booking requests  📋"
        echo -e "  ${BOLD}10)${RESET}  Approve / Reject a booking  ✅"
        echo -e "  ${BOLD}11)${RESET}  Logout"
        echo ""
        read -p "  Choose (1-11): " choice
        case "$choice" in
            1)  list_spots ;;
            2)  search_by_city ;;
            3)  search_by_country ;;
            4)  list_ratings_for_spot ;;
            5)  list_hotels_for_spot ;;
            6)  hm_add_hotel ;;
            7)  hm_my_hotels ;;
            8)  hm_view_seats ;;
            9)  hm_booking_requests ;;
            10) hm_approve_booking ;;
            11) do_logout; return ;;
            *)  echo -e "${RED}  ✘ Invalid option. Choose 1–11.${RESET}" ;;
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
        echo -e "  ${BOLD}10)${RESET}  View all bookings"
        echo -e "  ${BOLD}11)${RESET}  Export summary report"
        echo -e "  ${BOLD}12)${RESET}  Logout"
        echo ""
        read -p "  Choose (1-12): " choice
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
            10) admin_view_all_bookings ;;
            11) export_summary_report ;;
            12) do_logout; return ;;
            *)  echo -e "${RED}  ✘ Invalid option. Choose 1–12.${RESET}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

# ============================================================
# ENTRY POINT
# ============================================================
init_files

while true; do
    splash_screen
    case "$CURRENT_ROLE" in
        Admin)        admin_menu ;;
        HotelManager) hotel_manager_menu ;;
        *)            user_menu ;;
    esac
done
