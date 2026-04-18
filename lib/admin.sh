#!/bin/bash

# ============================================================
#  lib/admin.sh — Admin panel features and menu
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
            echo -e "  ${BOLD}[${id}]${RESET}  ${hotel_name}  near ${sname}  —  ৳${price}/night/room  —  ${total_rooms} rooms  — by ${YELLOW}${submitted_by}${RESET}"
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
            echo -e "${YELLOW}  Hotel: ${hotel_name}  —  ৳${price}/night/room  —  ${total_rooms} rooms  — by ${submitted_by}${RESET}"
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
    awk -F'|' -v sid="$spot_id" 'NR==1 || $5 != sid' "$BOOKINGS_FILE" \
        > "${BOOKINGS_FILE}.tmp" && mv "${BOOKINGS_FILE}.tmp" "$BOOKINGS_FILE"

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
    # Schema: BookingID|Username|HotelID|HotelName|SpotID|Rooms|Nights|Status|Timestamp
    while IFS='|' read -r bid username hotel_id hotel_name spot_id rooms nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        local spot_name manager status_color price total
        spot_name=$(get_spot_name "$spot_id")
        manager=$(get_hotel_manager "$hotel_id")
        price=$(get_hotel_price "$hotel_id")
        total=$(awk "BEGIN { print $price * $rooms * $nights }")
        case "$status" in
            Approved) status_color="${GREEN}" ;;
            Rejected) status_color="${RED}" ;;
            *)        status_color="${YELLOW}" ;;
        esac
        echo -e "  ${BOLD}[#${bid}]${RESET}  ${username}  →  ${hotel_name}  (${spot_name})"
        echo -e "        Rooms   : ${rooms}  |  Nights: ${nights}  |  Total: ৳${total}"
        echo -e "        Manager : ${manager}  |  Status: ${status_color}${status}${RESET}"
        echo -e "        Time    : ${timestamp}"
        echo ""
        ((count++))
    done < "$BOOKINGS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No bookings yet.${RESET}"
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
