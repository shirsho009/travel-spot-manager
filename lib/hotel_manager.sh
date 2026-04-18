#!/bin/bash

# ============================================================
#  lib/hotel_manager.sh — Hotel Manager panel features and menu
# ============================================================

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
        read -p "  Price/night/room (BDT): " price
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
            echo -e "       Price   : ৳${price}/night/room"
            echo -e "       Rooms   : ${avail_rooms}/${total_rooms} available"
            echo ""
            ((count++))
        fi
    done < "$HOTELS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  You have no approved hotels yet.${RESET}"
}

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

hm_booking_requests() {
    echo ""
    echo -e "${BLUE}${BOLD}=== All Booking Requests — My Hotels ===${RESET}"
    local count=0
    # Schema: BookingID|Username|HotelID|HotelName|SpotID|Rooms|Nights|Status|Timestamp
    while IFS='|' read -r bid username hotel_id hotel_name spot_id rooms nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        local manager
        manager=$(get_hotel_manager "$hotel_id")
        if [ "$manager" = "$CURRENT_USER" ]; then
            local spot_name status_color price total
            spot_name=$(get_spot_name "$spot_id")
            price=$(get_hotel_price "$hotel_id")
            total=$(awk "BEGIN { print $price * $rooms * $nights }")
            case "$status" in
                Approved) status_color="${GREEN}" ;;
                Rejected) status_color="${RED}" ;;
                *)        status_color="${YELLOW}" ;;
            esac
            echo -e "  ${BOLD}[Booking #${bid}]${RESET}"
            echo -e "    Guest  : ${BOLD}${username}${RESET}"
            echo -e "    Hotel  : ${hotel_name}  (ID: ${hotel_id})"
            echo -e "    Spot   : ${spot_name}"
            echo -e "    Rooms  : ${rooms}  |  Nights: ${nights}  |  Total: ৳${total}"
            echo -e "    Status : ${status_color}${status}${RESET}"
            echo -e "    Time   : ${timestamp}"
            echo ""
            ((count++))
        fi
    done < "$BOOKINGS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No booking requests for your hotels.${RESET}"
}

hm_approve_booking() {
    echo ""
    echo -e "${BLUE}${BOLD}=== Approve / Reject a Booking ===${RESET}"

    # Show only Pending bookings for this manager's hotels
    local count=0
    while IFS='|' read -r bid username hotel_id hotel_name spot_id rooms nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        [ "$status" != "Pending" ] && continue
        local manager
        manager=$(get_hotel_manager "$hotel_id")
        if [ "$manager" = "$CURRENT_USER" ]; then
            echo -e "  ${BOLD}[#${bid}]${RESET}  ${BOLD}${username}${RESET}  →  ${hotel_name}  —  ${rooms} room(s), ${nights} night(s)"
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

    # Schema col positions: 1=BookingID 2=Username 3=HotelID 4=HotelName
    #                       5=SpotID 6=Rooms 7=Nights 8=Status 9=Timestamp
    IFS='|' read -r bid b_username hotel_id hotel_name spot_id rooms nights status timestamp <<< "$booking_line"

    local manager
    manager=$(get_hotel_manager "$hotel_id")
    if [ "$manager" != "$CURRENT_USER" ]; then
        echo -e "${RED}  ✘ This booking does not belong to your hotel.${RESET}"; return
    fi
    if [ "$status" != "Pending" ]; then
        echo -e "${RED}  ✘ This booking is already ${status}.${RESET}"; return
    fi

    local price total
    price=$(get_hotel_price "$hotel_id")
    total=$(awk "BEGIN { print $price * $rooms * $nights }")

    echo ""
    echo -e "  Guest  : ${BOLD}${b_username}${RESET}"
    echo -e "  Hotel  : ${hotel_name}"
    echo -e "  Rooms  : ${rooms}  |  Nights: ${nights}  |  Total: ৳${total}"
    echo ""
    echo -e "  ${BOLD}A)${RESET} Approve  |  ${BOLD}R)${RESET} Reject  |  ${BOLD}0)${RESET} Cancel"
    read -p "  Choose (A/R/0): " action

    case "${action^^}" in
        A)
            local avail_rooms
            avail_rooms=$(get_available_rooms "$hotel_id")
            if [ "$avail_rooms" -lt "$rooms" ]; then
                echo -e "${RED}  ✘ Only ${avail_rooms} room(s) available. Cannot approve ${rooms} room(s).${RESET}"
                return
            fi
            local new_avail=$((avail_rooms - rooms))
            # Update booking Status — column 8
            update_field "$BOOKINGS_FILE" "$booking_id" 8 "Approved"
            # Update hotel AvailableRooms — column 7
            update_field "$HOTELS_FILE" "$hotel_id" 7 "$new_avail"
            log_action "$CURRENT_USER" "APPROVE_BOOKING" \
                "BookingID:${booking_id},Guest:${b_username},Rooms:${rooms},HotelID:${hotel_id}"
            echo -e "${GREEN}  ✔ Booking #${booking_id} approved. ${rooms} room(s) assigned to ${b_username}.${RESET}"
            echo -e "${CYAN}  ℹ Remaining available rooms: ${new_avail}${RESET}"
            ;;
        R)
            read -p "  Confirm rejection? (yes/no): " confirm
            if [ "${confirm,,}" = "yes" ]; then
                # Update booking Status — column 8
                update_field "$BOOKINGS_FILE" "$booking_id" 8 "Rejected"
                log_action "$CURRENT_USER" "REJECT_BOOKING" \
                    "BookingID:${booking_id},Guest:${b_username},HotelID:${hotel_id}"
                echo -e "${GREEN}  ✔ Booking #${booking_id} rejected.${RESET}"
            else
                echo -e "${YELLOW}  Cancelled.${RESET}"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}  ✘ Invalid choice.${RESET}" ;;
    esac
}

# Revenue report: sum of (price × rooms × nights) for all Approved bookings
hm_revenue_report() {
    echo ""
    echo -e "${BLUE}${BOLD}=== 💹 Revenue Report — My Hotels ===${RESET}"
    echo ""

    local grand_total=0
    local found_hotel=0

    while IFS='|' read -r hid sid hotel_name address price total_rooms avail_rooms manager; do
        [ "$hid" = "HotelID" ] && continue
        [ "$manager" != "$CURRENT_USER" ] && continue

        ((found_hotel++))
        local spot_name hotel_total=0 booking_count=0
        spot_name=$(get_spot_name "$sid")

        # Sum all Approved bookings for this hotel
        while IFS='|' read -r bid username b_hotel_id b_hotel_name spot_id rooms nights status timestamp; do
            [ "$bid" = "BookingID" ] && continue
            [ "$b_hotel_id" != "$hid" ] && continue
            [ "$status" != "Approved" ] && continue
            local booking_revenue
            booking_revenue=$(awk "BEGIN { print $price * $rooms * $nights }")
            hotel_total=$((hotel_total + booking_revenue))
            ((booking_count++))
        done < "$BOOKINGS_FILE"

        grand_total=$((grand_total + hotel_total))

        printf "  🏨 ${BOLD}%-30s${RESET}  (near %s)\n" "$hotel_name" "$spot_name"
        printf "     Approved bookings : %d\n" "$booking_count"
        printf "     Hotel revenue     : ${GREEN}৳%d${RESET}\n" "$hotel_total"
        echo ""

    done < "$HOTELS_FILE"

    if [ "$found_hotel" -eq 0 ]; then
        echo -e "${YELLOW}  You have no approved hotels yet.${RESET}"
        return
    fi

    echo -e "  ────────────────────────────────────────"
    echo -e "  ${BOLD}💰 Total Revenue (all hotels) : ${GREEN}৳${grand_total}${RESET}"
    echo ""
    log_action "$CURRENT_USER" "VIEW_REVENUE" "Total:${grand_total}"
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
        echo -e "  ${BOLD}11)${RESET}  Revenue report  💹"
        echo -e "  ${BOLD}12)${RESET}  Logout"
        echo ""
        read -p "  Choose (1-12): " choice
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
            11) hm_revenue_report ;;
            12) do_logout; return ;;
            *)  echo -e "${RED}  ✘ Invalid option. Choose 1–12.${RESET}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}
