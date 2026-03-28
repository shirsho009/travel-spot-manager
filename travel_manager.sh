#!/bin/bash

# ============================================================
#  Travel Spot Management System
#  Student: SHIMANTO SHIRSHO (2204009)
#  Course : Operating Systems (CSE)
# ============================================================

# ---------- File paths ----------
SPOTS_FILE="spots.txt"
RATINGS_FILE="ratings.txt"
HOTELS_FILE="hotels.txt"
EXPORT_FILE="summary_report.txt"

# ---------- Terminal colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
# INIT — Auto-create database files with headers + sample data
# ============================================================
init_files() {
    if [ ! -f "$SPOTS_FILE" ]; then
        echo "ID|Name|City|Country|Description" > "$SPOTS_FILE"
        echo "1|Cox's Bazar|Cox's Bazar|Bangladesh|Longest natural sea beach in the world. 120km stretch of golden sand." >> "$SPOTS_FILE"
        echo "2|Sajek Valley|Rangamati|Bangladesh|Beautiful hill-top valley with panoramic views of green hills." >> "$SPOTS_FILE"
        echo "3|Sundarbans|Khulna|Bangladesh|UNESCO World Heritage mangrove forest. Home to Royal Bengal Tiger." >> "$SPOTS_FILE"
        echo "4|Kuakata|Barisal|Bangladesh|Sunrise and sunset beach on the same spot." >> "$SPOTS_FILE"
        echo -e "${GREEN}[INFO] spots.txt created with sample data.${RESET}"
    fi

    if [ ! -f "$RATINGS_FILE" ]; then
        echo "SpotID|UserName|Rating|Comment" > "$RATINGS_FILE"
        echo "1|shimanto|4|Beautiful, but crowded during holidays" >> "$RATINGS_FILE"
        echo "1|anika|5|Very clean and scenic. Perfect family trip!" >> "$RATINGS_FILE"
        echo "2|tahmid|3|Need better roads to reach the top" >> "$RATINGS_FILE"
        echo "2|farha|4|Amazing views, cold weather perfect" >> "$RATINGS_FILE"
        echo "3|rafi|5|Wildlife boat safari was unforgettable" >> "$RATINGS_FILE"
        echo -e "${GREEN}[INFO] ratings.txt created with sample data.${RESET}"
    fi

    if [ ! -f "$HOTELS_FILE" ]; then
        echo "SpotID|HotelName|Address|PricePerNightBDT" > "$HOTELS_FILE"
        echo "1|Sea View Resort|Near Beach Road, Cox's Bazar|5000" >> "$HOTELS_FILE"
        echo "1|Beach Paradise Hotel|Main Beach Area, Cox's Bazar|6500" >> "$HOTELS_FILE"
        echo "2|Hill View Inn|Top of Sajek Hill, Rangamati|6000" >> "$HOTELS_FILE"
        echo "3|Sundarban Eco Lodge|Near Jetty Area, Khulna|4000" >> "$HOTELS_FILE"
        echo "4|Kuakata Sea Pearl Resort|Beachfront, Kuakata|4500" >> "$HOTELS_FILE"
        echo -e "${GREEN}[INFO] hotels.txt created with sample data.${RESET}"
    fi
}

# ============================================================
# HELPERS
# ============================================================

# Returns 0 (true) if a Spot ID exists in spots.txt
spot_exists() {
    local id="$1"
    grep -q "^${id}|" "$SPOTS_FILE"
}

# Prints the Name of a spot given its ID
get_spot_name() {
    local id="$1"
    grep "^${id}|" "$SPOTS_FILE" | cut -d'|' -f2
}

# Calculates the next available ID for a given file
next_id() {
    local file="$1"
    local max_id
    # Skip header (tail -n +2), extract column 1, sort numerically, get the last one
    max_id=$(tail -n +2 "$file" | cut -d'|' -f1 | sort -n | tail -1)
    if [ -z "$max_id" ]; then
        echo 1
    else
        echo $((max_id + 1))
    fi
}

# ============================================================
# FEATURE 1 — Add New Travel Spot
# ============================================================
add_spot() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Add New Travel Spot ===${RESET}"

    # Name (non-empty)
    while true; do
        read -p "  Spot name   : " name
        [ -n "$name" ] && break
        echo -e "${RED}  ✘ Name cannot be empty.${RESET}"
    done

    # City (non-empty)
    while true; do
        read -p "  City        : " city
        [ -n "$city" ] && break
        echo -e "${RED}  ✘ City cannot be empty.${RESET}"
    done

    # Country (non-empty)
    while true; do
        read -p "  Country     : " country
        [ -n "$country" ] && break
        echo -e "${RED}  ✘ Country cannot be empty.${RESET}"
    done

    # Description (non-empty)
    while true; do
        read -p "  Description : " description
        [ -n "$description" ] && break
        echo -e "${RED}  ✘ Description cannot be empty.${RESET}"
    done

    local new_id
    new_id=$(next_id "$SPOTS_FILE")

    # Append new row to spots.txt
    echo "${new_id}|${name}|${city}|${country}|${description}" >> "$SPOTS_FILE"

    echo -e "${GREEN}  ✔ Spot added successfully! New ID = ${new_id}${RESET}"
}

# ============================================================
# FEATURE 2 — List All Spots
# ============================================================
list_spots() {
    echo ""
    echo -e "${CYAN}${BOLD}=== All Travel Spots ===${RESET}"

    local count=0
    # IFS='|' splits each line on pipe when reading
    while IFS='|' read -r id name city country description; do
        [ "$id" = "ID" ] && continue          # skip header line
        echo -e "  ${BOLD}${id}.${RESET} ${name}  (${city}, ${country})"
        ((count++))
    done < "$SPOTS_FILE"

    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No spots found.${RESET}"
}

# ============================================================
# FEATURE 3 — Search Spots by City
# ============================================================
search_by_city() {
    echo ""
    read -p "  Enter city to search: " city_query
    echo -e "${CYAN}${BOLD}=== Spots in city matching '${city_query}' ===${RESET}"

    local count=0
    while IFS='|' read -r id name city country description; do
        [ "$id" = "ID" ] && continue
        # grep -qi = case-insensitive, quiet (just returns true/false)
        if echo "$city" | grep -qi "$city_query"; then
            echo -e "  ${BOLD}${id}.${RESET} ${name}  (${city}, ${country})"
            ((count++))
        fi
    done < "$SPOTS_FILE"

    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No spots found matching '${city_query}'.${RESET}"
}

# ============================================================
# FEATURE 4 — Search Spots by Country
# ============================================================
search_by_country() {
    echo ""
    read -p "  Enter country to search: " country_query
    echo -e "${CYAN}${BOLD}=== Spots in country matching '${country_query}' ===${RESET}"

    local count=0
    while IFS='|' read -r id name city country description; do
        [ "$id" = "ID" ] && continue
        if echo "$country" | grep -qi "$country_query"; then
            echo -e "  ${BOLD}${id}.${RESET} ${name}  (${city}, ${country})"
            ((count++))
        fi
    done < "$SPOTS_FILE"

    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No spots found matching '${country_query}'.${RESET}"
}

# ============================================================
# FEATURE 5 — Add Rating for a Spot
# ============================================================
add_rating() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Add Rating for a Spot ===${RESET}"
    list_spots

    # Validate Spot ID exists
    while true; do
        read -p "  Enter Spot ID: " spot_id
        spot_exists "$spot_id" && break
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist. Try again.${RESET}"
    done

    # Non-empty username
    while true; do
        read -p "  Username    : " username
        [ -n "$username" ] && break
        echo -e "${RED}  ✘ Username cannot be empty.${RESET}"
    done

    # Rating must be 1-5
    while true; do
        read -p "  Rating (1-5): " rating
        if [[ "$rating" =~ ^[1-5]$ ]]; then
            break
        fi
        echo -e "${RED}  ✘ Rating must be a number between 1 and 5.${RESET}"
    done

    read -p "  Comment     : " comment

    echo "${spot_id}|${username}|${rating}|${comment}" >> "$RATINGS_FILE"
    echo -e "${GREEN}  ✔ Rating added successfully!${RESET}"
}

# ============================================================
# FEATURE 6 — List Ratings for a Spot
# ============================================================
list_ratings() {
    echo ""
    read -p "  Enter Spot ID: " spot_id

    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist.${RESET}"
        return
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
        echo -e "${YELLOW}  No ratings yet for this spot.${RESET}"
    else
        echo -e "  ${BOLD}Total: ${count} rating(s)${RESET}"
    fi
}

# ============================================================
# FEATURE 7 — Add Hotel Near a Spot
# ============================================================
add_hotel() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Add Hotel Near a Spot ===${RESET}"
    list_spots

    # Validate Spot ID
    while true; do
        read -p "  Enter Spot ID: " spot_id
        spot_exists "$spot_id" && break
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist. Try again.${RESET}"
    done

    while true; do
        read -p "  Hotel name  : " hotel_name
        [ -n "$hotel_name" ] && break
        echo -e "${RED}  ✘ Hotel name cannot be empty.${RESET}"
    done

    while true; do
        read -p "  Address     : " address
        [ -n "$address" ] && break
        echo -e "${RED}  ✘ Address cannot be empty.${RESET}"
    done

    # Price must be a positive integer
    while true; do
        read -p "  Price/night (BDT): " price
        if [[ "$price" =~ ^[0-9]+$ ]] && [ "$price" -gt 0 ]; then
            break
        fi
        echo -e "${RED}  ✘ Price must be a positive whole number.${RESET}"
    done

    echo "${spot_id}|${hotel_name}|${address}|${price}" >> "$HOTELS_FILE"
    echo -e "${GREEN}  ✔ Hotel added successfully!${RESET}"
}

# ============================================================
# FEATURE 8 — List Hotels for a Spot
# ============================================================
list_hotels() {
    echo ""
    read -p "  Enter Spot ID: " spot_id

    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist.${RESET}"
        return
    fi

    local spot_name
    spot_name=$(get_spot_name "$spot_id")
    echo -e "${CYAN}${BOLD}=== Hotels near ${spot_name} (ID: ${spot_id}) ===${RESET}"

    local count=0
    while IFS='|' read -r sid hotel_name address price; do
        [ "$sid" = "SpotID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "  🏨 ${BOLD}${hotel_name}${RESET} — ${address}  (৳${price}/night)"
            ((count++))
        fi
    done < "$HOTELS_FILE"

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  No hotels listed for this spot yet.${RESET}"
    else
        echo -e "  ${BOLD}Total: ${count} hotel(s)${RESET}"
    fi
}

# ============================================================
# FEATURE 9 — Show Complete Summary for a Spot
# ============================================================
show_summary() {
    echo ""
    read -p "  Enter Spot ID: " spot_id

    if ! spot_exists "$spot_id"; then
        echo -e "${RED}  ✘ Spot ID '${spot_id}' does not exist.${RESET}"
        return
    fi

    # Read full spot line and split into variables
    local spot_line
    spot_line=$(grep "^${spot_id}|" "$SPOTS_FILE")
    IFS='|' read -r id name city country description <<< "$spot_line"

    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
    printf  "${BOLD}${CYAN}  %-50s${RESET}\n" "Summary for ${name}  (ID: ${id})"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
    echo -e "  📍 ${BOLD}Location   :${RESET} ${city}, ${country}"
    echo -e "  📝 ${BOLD}Description:${RESET} ${description}"
    echo ""

    # ------- Ratings section -------
    echo -e "  ${YELLOW}⭐ Ratings:${RESET}"
    local rating_count=0
    local rating_sum=0

    while IFS='|' read -r sid username rating comment; do
        [ "$sid" = "SpotID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "     - ${BOLD}${username}${RESET}: ${rating}/5 — ${comment}"
            ((rating_count++))
            rating_sum=$((rating_sum + rating))
        fi
    done < "$RATINGS_FILE"

    if [ "$rating_count" -gt 0 ]; then
        # awk handles floating-point division cleanly
        local avg
        avg=$(awk "BEGIN { printf \"%.1f\", $rating_sum / $rating_count }")
        echo -e "  ${YELLOW}  ➤ Average: ${avg} ⭐  (${rating_count} rating(s))${RESET}"
    else
        echo -e "  ${YELLOW}  No ratings yet.${RESET}"
    fi

    echo ""

    # ------- Hotels section -------
    echo -e "  ${CYAN}🏨 Hotels:${RESET}"
    local hotel_count=0
    local min_price=0
    local max_price=0

    while IFS='|' read -r sid hotel_name address price; do
        [ "$sid" = "SpotID" ] && continue
        if [ "$sid" = "$spot_id" ]; then
            echo -e "     - ${BOLD}${hotel_name}${RESET} — ${address}  (৳${price}/night)"
            ((hotel_count++))
            # Track min/max price for range display
            if [ "$min_price" -eq 0 ] || [ "$price" -lt "$min_price" ]; then
                min_price=$price
            fi
            [ "$price" -gt "$max_price" ] && max_price=$price
        fi
    done < "$HOTELS_FILE"

    if [ "$hotel_count" -gt 0 ]; then
        echo -e "  ${CYAN}  ➤ ${hotel_count} hotel(s) available  (৳${min_price} – ৳${max_price}/night)${RESET}"
    else
        echo -e "  ${CYAN}  No hotels listed yet.${RESET}"
    fi
    echo ""
}

# ============================================================
# FEATURE 10 — Average Ratings for ALL Spots
# ============================================================
average_ratings_all() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Average Ratings — All Spots ===${RESET}"
    echo ""
    printf "  ${BOLD}%-5s | %-24s | %-11s | %s${RESET}\n" \
           "ID" "Name" "Avg Rating" "# Ratings"
    echo "  ------+-------------------------+-------------+----------"

    while IFS='|' read -r id name city country description; do
        [ "$id" = "ID" ] && continue

        # awk reads ratings.txt, filters by spot ID, sums and counts
        local result
        result=$(awk -F'|' -v sid="$id" '
            NR==1 { next }
            $1 == sid { sum += $3; count++ }
            END {
                if (count > 0)
                    printf "%.1f %d", sum/count, count
                else
                    printf "N/A 0"
            }
        ' "$RATINGS_FILE")

        local avg count_r
        avg=$(echo "$result" | awk '{print $1}')
        count_r=$(echo "$result" | awk '{print $2}')

        if [ "$avg" = "N/A" ]; then
            printf "  %-5s | %-24s | %-11s | %s\n" \
                   "$id" "$name" "  N/A" "0"
        else
            printf "  %-5s | %-24s | %-11s | %s\n" \
                   "$id" "$name" "  ${avg} ⭐" "$count_r"
        fi
    done < "$SPOTS_FILE"
    echo ""
}

# ============================================================
# FEATURE 11 — Export Full Summary to summary_report.txt
# ============================================================
export_summary() {
    echo ""
    echo -e "${CYAN}Generating summary report...${RESET}"

    # Everything inside { } gets redirected to the report file
    {
        echo "============================================================"
        echo "       TRAVEL SPOT MANAGEMENT SYSTEM — SUMMARY REPORT"
        echo "       Student : SHIMANTO SHIRSHO (2204009)"
        echo "       Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "============================================================"
        echo ""

        while IFS='|' read -r id name city country description; do
            [ "$id" = "ID" ] && continue

            echo "------------------------------------------------------------"
            echo "  SPOT #${id}: ${name}"
            echo "  Location : ${city}, ${country}"
            echo "  About    : ${description}"
            echo ""

            # Ratings block
            echo "  [ RATINGS ]"
            local rating_count=0
            local rating_sum=0

            while IFS='|' read -r sid username rating comment; do
                [ "$sid" = "SpotID" ] && continue
                if [ "$sid" = "$id" ]; then
                    echo "    - ${username}: ${rating}/5 — ${comment}"
                    ((rating_count++))
                    rating_sum=$((rating_sum + rating))
                fi
            done < "$RATINGS_FILE"

            if [ "$rating_count" -gt 0 ]; then
                local avg
                avg=$(awk "BEGIN { printf \"%.1f\", $rating_sum / $rating_count }")
                echo "    Average : ${avg}/5  (${rating_count} rating(s))"
            else
                echo "    No ratings yet."
            fi
            echo ""

            # Hotels block
            echo "  [ HOTELS ]"
            local hotel_count=0

            while IFS='|' read -r sid hotel_name address price; do
                [ "$sid" = "SpotID" ] && continue
                if [ "$sid" = "$id" ]; then
                    echo "    - ${hotel_name} | ${address} | BDT ${price}/night"
                    ((hotel_count++))
                fi
            done < "$HOTELS_FILE"

            [ "$hotel_count" -eq 0 ] && echo "    No hotels listed."
            echo ""

        done < "$SPOTS_FILE"

        echo "============================================================"
        echo "                     END OF REPORT"
        echo "============================================================"

    } > "$EXPORT_FILE"    # <-- all output above written to this file

    echo -e "${GREEN}  ✔ Report saved to '${EXPORT_FILE}'${RESET}"
}

# ============================================================
# MAIN MENU — shown in a loop until user picks 12
# ============================================================
show_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║      🌍  Travel Spot Management System       ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${RESET}"
    echo -e "  ${BOLD} 1)${RESET}  Add new travel spot"
    echo -e "  ${BOLD} 2)${RESET}  List all spots"
    echo -e "  ${BOLD} 3)${RESET}  Search spots by city"
    echo -e "  ${BOLD} 4)${RESET}  Search spots by country"
    echo -e "  ${BOLD} 5)${RESET}  Add rating for a spot"
    echo -e "  ${BOLD} 6)${RESET}  List ratings for a spot"
    echo -e "  ${BOLD} 7)${RESET}  Add hotel near a spot"
    echo -e "  ${BOLD} 8)${RESET}  List hotels for a spot"
    echo -e "  ${BOLD} 9)${RESET}  Show complete summary for a spot"
    echo -e "  ${BOLD}10)${RESET}  Calculate average rating for all spots"
    echo -e "  ${BOLD}11)${RESET}  Export summary to file"
    echo -e "  ${BOLD}12)${RESET}  Exit"
    echo ""
}

# ============================================================
# ENTRY POINT — runs when script starts
# ============================================================
init_files   # create DB files if they don't exist

while true; do
    show_menu
    read -p "  Choose an option (1-12): " choice
    echo ""

    case "$choice" in
        1)  add_spot ;;
        2)  list_spots ;;
        3)  search_by_city ;;
        4)  search_by_country ;;
        5)  add_rating ;;
        6)  list_ratings ;;
        7)  add_hotel ;;
        8)  list_hotels ;;
        9)  show_summary ;;
        10) average_ratings_all ;;
        11) export_summary ;;
        12) echo -e "${GREEN}  Goodbye! All data is saved in .txt files.${RESET}"
            exit 0 ;;
        *)  echo -e "${RED}  ✘ Invalid option. Please choose 1–12.${RESET}" ;;
    esac

    echo ""
    read -p "  Press Enter to return to menu..."
done
