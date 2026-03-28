# 🌍 Travel Spot Management System v2.0

**OS Course Project** — Secure, role-based interactive Bash application.

**Student:** SHIMANTO SHIRSHO (2204009)
**Course:** Operating Systems, CSE Department

## How to Run
```bash
chmod +x travel_manager.sh
./travel_manager.sh
```

**Default admin login:** `admin` / `admin123`

## Requirements
- Linux terminal with Bash (version 4+)
- Mac: use OrbStack or any Linux VM
- Windows: use **WSL** (Windows Subsystem for Linux)

## v2.0 Features

### Security
- SHA-256 password hashing via `sha256sum`
- Role-Based Access Control (Admin vs User)
- Input sanitization (pipe-character injection prevention)
- `trap` handles Ctrl+C without corrupting files

### User Features
- Submit spots/hotels (goes to pending queue)
- Add ratings, search by city/country/season
- Travel cost calculator (spot + hotel + nights)
- View top-rated spots

### Admin Features
- Approve/reject pending spots and hotels
- Cascade delete (removes spot + hotels + ratings)
- View all users and full audit log
- Export summary report

## File Schema

| File | Schema |
|---|---|
| `users.txt` | UserID \| Username \| PasswordHash \| Role |
| `spots.txt` | SpotID \| Name \| City \| Country \| Description \| BestSeason |
| `pending_spots.txt` | same as spots + SubmittedBy |
| `hotels.txt` | HotelID \| SpotID \| HotelName \| Address \| PricePerNight |
| `pending_hotels.txt` | same as hotels + SubmittedBy |
| `ratings.txt` | SpotID \| Username \| Rating \| Comment |
| `audit_log.txt` | Timestamp \| Actor \| Action \| TargetID |
