#!/bin/bash

# ============================================================
#  lib/shared.sh — Features available to all roles
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
            echo -e "       Price   : ৳${price}/night/room"
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
            echo -e "     - ${BOLD}${hotel_name}${RESET} — ৳${price}/night/room  (${avail_rooms}/${total_rooms} rooms available)"
            ((h_count++))
            if [ "$min_p" -eq 0 ] || [ "$price" -lt "$min_p" ]; then min_p=$price; fi
            [ "$price" -gt "$max_p" ] && max_p=$price
        fi
    done < "$HOTELS_FILE"
    if [ "$h_count" -gt 0 ]; then
        echo -e "  ${CYAN}  ➤ ${h_count} hotel(s)  (৳${min_p} – ৳${max_p}/night/room)${RESET}"
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
                    echo "    [${hid}] ${hname}  |  ${addr}  |  BDT ${price}/night/room  |  ${avail_rooms}/${total_rooms} rooms  |  Manager: ${manager}"
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
