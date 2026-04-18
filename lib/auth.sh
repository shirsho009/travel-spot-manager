#!/bin/bash

# ============================================================
#  lib/auth.sh — Signup, Login, Logout, Splash Screen
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

splash_screen() {
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║      🌍 Travel Spot Management System            ║${RESET}"
        echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════╣${RESET}"
        echo -e "${BOLD}${CYAN}║         1) Login    2) Sign Up    3) Exit        ║${RESET}"
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
