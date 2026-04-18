#!/bin/bash

# ============================================================
#  lib/user.sh — User panel features and menu
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
            local bar="" filled=0 empty=10
            [ "$total_rooms" -gt 0 ] && filled=$((avail_rooms * 10 / total_rooms))
            empty=$((10 - filled))
            for ((i=0; i<filled; i++)); do bar+="█"; done
            for ((i=0; i<empty; i++)); do bar+="░"; done
            echo -e "  🏨 ${BOLD}[${hid}] ${hotel_name}${RESET}"
            echo -e "       [${GREEN}${bar}${RESET}]  ${avail_rooms}/${total_rooms} rooms  —  ৳${price}/night/room"
            echo ""
            ((count++))
        fi
    done < "$HOTELS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  No hotels for this spot yet.${RESET}"
}

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
                echo -e "  ${BOLD}[${hid}]${RESET}  ${hotel_name}  —  ৳${price}/night/room  —  ${GREEN}${avail_rooms} rooms available${RESET}"
            else
                echo -e "  ${BOLD}[${hid}]${RESET}  ${hotel_name}  —  ৳${price}/night/room  —  ${RED}Fully booked${RESET}"
            fi
            ((h_count++))
        fi
    done < "$HOTELS_FILE"

    if [ "$h_count" -eq 0 ]; then
        echo -e "${YELLOW}  No hotels for this spot yet.${RESET}"; return
    fi

    # Select hotel
    local hotel_id hotel_line selected_name selected_price avail_rooms total_rooms
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

    # Rooms — must not exceed available
    local rooms
    while true; do
        read -p "  Number of rooms (max ${avail_rooms} available): " rooms
        if [[ "$rooms" =~ ^[0-9]+$ ]] && [ "$rooms" -gt 0 ]; then
            if [ "$rooms" -le "$avail_rooms" ]; then
                break
            else
                echo -e "${RED}  ✘ Only ${avail_rooms} room(s) available. Enter ${avail_rooms} or less.${RESET}"
            fi
        else
            echo -e "${RED}  ✘ Must be a positive number.${RESET}"
        fi
    done

    # Nights
    local nights
    while true; do
        read -p "  Number of nights  : " nights
        if [[ "$nights" =~ ^[0-9]+$ ]] && [ "$nights" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive number.${RESET}"
    done

    local total timestamp new_id
    total=$(awk "BEGIN { print $selected_price * $rooms * $nights }")
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    new_id=$(next_id "$BOOKINGS_FILE")

    # Schema: BookingID|Username|HotelID|HotelName|SpotID|Rooms|Nights|Status|Timestamp
    echo "${new_id}|${CURRENT_USER}|${hotel_id}|${selected_name}|${spot_id}|${rooms}|${nights}|Pending|${timestamp}" >> "$BOOKINGS_FILE"

    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}              🛎  Booking Request Sent              ${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
    echo -e "  📍 Destination  : ${spot_name}"
    echo -e "  🏨 Hotel        : ${selected_name}"
    echo -e "  🛏  Rooms        : ${rooms}"
    echo -e "  📅 Nights       : ${nights}"
    echo -e "  💵 Rate         : ৳${selected_price}/night/room"
    echo -e "  ${BOLD}💰 Total Cost   : ৳${total}${RESET}"
    echo -e "  📋 Status       : ${YELLOW}Pending Manager Approval${RESET}"
    echo -e "  🔖 Booking ID   : #${new_id}"
    echo ""
    log_action "$CURRENT_USER" "BOOK_HOTEL" \
        "BookingID:${new_id},HotelID:${hotel_id}(${selected_name}),Rooms:${rooms},Nights:${nights},Total:${total}"
}

user_my_bookings() {
    echo ""
    echo -e "${CYAN}${BOLD}=== My Bookings ===${RESET}"
    local count=0
    # Schema: BookingID|Username|HotelID|HotelName|SpotID|Rooms|Nights|Status|Timestamp
    while IFS='|' read -r bid username hotel_id hotel_name spot_id rooms nights status timestamp; do
        [ "$bid" = "BookingID" ] && continue
        if [ "$username" = "$CURRENT_USER" ]; then
            local spot_name status_color
            spot_name=$(get_spot_name "$spot_id")
            case "$status" in
                Approved) status_color="${GREEN}" ;;
                Rejected) status_color="${RED}" ;;
                *)        status_color="${YELLOW}" ;;
            esac
            local price total
            price=$(get_hotel_price "$hotel_id")
            total=$(awk "BEGIN { print $price * $rooms * $nights }")
            echo -e "  ${BOLD}[#${bid}]${RESET}  ${hotel_name}  →  ${spot_name}"
            echo -e "        Rooms  : ${rooms}  |  Nights: ${nights}  |  Total: ৳${total}"
            echo -e "        Status : ${status_color}${status}${RESET}  |  Booked: ${timestamp}"
            echo ""
            ((count++))
        fi
    done < "$BOOKINGS_FILE"
    [ "$count" -eq 0 ] && echo -e "${YELLOW}  You have no bookings yet.${RESET}"
}

# Updated: asks for rooms AND nights, calculates rooms × nights × price
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
            echo -e "    ${BOLD}${hid})${RESET}  ${hotel_name}  —  ৳${price}/night/room  (${avail_rooms} rooms available)"
            ((h_count++))
        fi
    done < "$HOTELS_FILE"

    if [ "$h_count" -eq 0 ]; then
        echo -e "${YELLOW}  No hotels for this spot yet.${RESET}"; return
    fi

    local hotel_id hotel_line selected_name selected_price avail_rooms
    while true; do
        read -p "  Select Hotel ID: " hotel_id
        hotel_line=$(grep "^${hotel_id}|${spot_id}|" "$HOTELS_FILE")
        if [ -n "$hotel_line" ]; then
            IFS='|' read -r hid sid selected_name address selected_price total_rooms avail_rooms manager <<< "$hotel_line"
            break
        fi
        echo -e "${RED}  ✘ Invalid Hotel ID for this spot.${RESET}"
    done

    local rooms
    while true; do
        read -p "  Number of rooms   : " rooms
        if [[ "$rooms" =~ ^[0-9]+$ ]] && [ "$rooms" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive number.${RESET}"
    done

    local nights
    while true; do
        read -p "  Number of nights  : " nights
        if [[ "$nights" =~ ^[0-9]+$ ]] && [ "$nights" -gt 0 ]; then break; fi
        echo -e "${RED}  ✘ Must be a positive number.${RESET}"
    done

    local total
    total=$(awk "BEGIN { print $selected_price * $rooms * $nights }")

    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}              💰  Trip Cost Summary                 ${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
    echo -e "  📍 Destination : ${spot_name}"
    echo -e "  🏨 Hotel       : ${selected_name}"
    echo -e "  🛏  Rooms       : ${rooms}"
    echo -e "  📅 Nights      : ${nights}"
    echo -e "  💵 Rate        : ৳${selected_price}/night/room"
    echo -e "  ${BOLD}💰 Total Cost  : ৳${total}${RESET}"
    echo -e "  ${CYAN}  (Formula: ৳${selected_price} × ${rooms} rooms × ${nights} nights)${RESET}"
    echo ""
    log_action "$CURRENT_USER" "COST_CALC" \
        "Spot:${spot_id},Hotel:${hotel_id},Rooms:${rooms},Nights:${nights},Total:${total}"
}

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
