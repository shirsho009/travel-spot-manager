#!/bin/bash

# ============================================================
#  travel_manager.sh — Entry point
#  Sources all modules from lib/ and starts the application
# ============================================================

# Resolve the directory this script lives in — works regardless
# of where you call it from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules in order — globals first, then logic
source "$SCRIPT_DIR/lib/init.sh"
source "$SCRIPT_DIR/lib/auth.sh"
source "$SCRIPT_DIR/lib/shared.sh"
source "$SCRIPT_DIR/lib/user.sh"
source "$SCRIPT_DIR/lib/hotel_manager.sh"
source "$SCRIPT_DIR/lib/admin.sh"

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
