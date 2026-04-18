
# 🌍 Travel Spot Management System

A fully interactive, terminal-based travel management application built in pure Bash.
Manage travel destinations, hotels, bookings, ratings, and user accounts — all through
a secure, role-based interface running entirely on text files.

**Student:** SHIMANTO SHIRSHO (ID: 2204009) <br>
**Course:** CSE-336: Operating Systems, Dept of CSE, CUET

---

## Getting Started

### Requirements

- Linux terminal with Bash
- **Mac:** OrbStack or any Linux VM
- **Windows:** WSL (Windows Subsystem for Linux)

### Run the Program

```bash
# Clone the repository (first time only)
git clone https://github.com/shirsho009/travel-spot-manager.git
cd travel-spot-manager

# Make all scripts executable (first time only)
chmod +x travel_manager.sh lib/init.sh lib/auth.sh lib/shared.sh lib/user.sh lib/hotel_manager.sh lib/admin.sh

# Run
./travel_manager.sh
```

On first run, all database files are automatically created with sample data.
You do not need to create any files manually.

### Default Admin Login

```
Username : admin
Password : admin123
```

---

## Project Structure

```
travel-spot-manager/
├── travel_manager.sh        ← entry point, run this
└── lib/
    ├── init.sh              ← global variables, helpers, database initializer
    ├── auth.sh              ← signup, login, logout, splash screen
    ├── shared.sh            ← features shared across all roles
    ├── user.sh              ← user panel and features
    ├── hotel_manager.sh     ← hotel manager panel and features
    └── admin.sh             ← admin panel and features
```

---

## How It Works

When you run the program, you land on a **splash screen** with three options:

```
1) Login
2) Sign Up
3) Exit
```

After logging in, the system routes you to a panel based on your role:
- **User Panel** — browse spots, book hotels, leave ratings
- **Hotel Manager Panel** — manage hotels, handle bookings, view revenue
- **Admin Panel** — approve content, manage the database, view system activity

---

## Signing Up

Select **Sign Up** from the splash screen.

- Choose a unique username
- Enter a password (hidden while typing)
- Confirm your password
- Select your account type: **Regular User** or **Hotel Manager**

Passwords are never stored as plain text — they are hashed using SHA-256 before saving.

---

## User Panel

### 1. List All Spots
Displays every approved travel spot with its location and best season to visit.

### 2. Search by City
Type part of a city name (case-insensitive). Example: typing `cox` finds Cox's Bazar.

### 3. Search by Country
Type part of a country name. Example: `bangladesh` returns all spots in Bangladesh.

### 4. Search by Best Season
Enter a season — `Winter`, `Summer`, `Spring`, `Monsoon`, or `Any`.
Returns spots whose best visiting season matches your input.

### 5. Submit a New Spot
Propose a new travel destination by providing its name, city, country, description,
and best season. The submission enters a pending queue and is not visible to others
until an admin approves it.

### 6. Add Rating for a Spot
Rate any approved spot from **1 to 5** and leave a comment.
Your username is automatically attached to the rating.

### 7. List Ratings for a Spot
View all user ratings and comments for a selected spot.

### 8. Show Full Summary for a Spot
View everything about a spot in one screen — location, description, best season,
all ratings with average score, and all hotels with room availability and pricing.

### 9. View Available Rooms
Select a spot to see all hotels nearby with a visual room availability bar
showing how many rooms are currently free out of total capacity.

### 10. Book a Hotel
Book a hotel directly through the system:
1. Select a destination spot
2. Choose a hotel from the available options
3. Enter the number of rooms (cannot exceed available rooms)
4. Enter the number of nights

The booking request is sent directly to the hotel's manager for approval.
You receive a booking ID and a full cost summary at the end.

### 11. My Bookings
View all your booking requests with their current status — Pending, Approved, or Rejected —
along with the total cost for each booking.

### 12. Top Rated Spots
All spots ranked from highest to lowest average rating.

### 13. Travel Cost Calculator
Estimate your trip cost without making a booking:
1. Select a spot and hotel
2. Enter number of rooms
3. Enter number of nights
4. The system calculates: **Price per room × Rooms × Nights = Total**

### 14. Logout
Ends your session and returns to the splash screen.

---

## Hotel Manager Panel

Hotel Managers own and operate hotels in the system. They submit hotels for admin
approval, manage room availability, and handle guest booking requests.

### 1. List All Spots
View all approved spots in the database.

### 2. Search by City
Search spots by city name.

### 3. Search by Country
Search spots by country name.

### 4. List Ratings for a Spot
View all user ratings for any spot.

### 5. List Hotels for a Spot
View all approved hotels near a selected spot, including room availability and manager details.

### 6. Add New Hotel
Submit a new hotel for admin approval. Provide:
- The spot the hotel is located near
- Hotel name and address
- Price per room per night (BDT)
- Total number of rooms

The submission enters a pending queue. It does not appear in the live database
until an admin approves it. Once approved, you become the manager of that hotel.

### 7. My Hotels
View all approved hotels under your management, with addresses, pricing, and current room availability.

### 8. Available Seats — My Hotels
See a visual room availability bar for each of your hotels showing
available rooms out of total capacity.

### 9. Booking Requests
View all booking requests (Pending, Approved, and Rejected) for your hotels.
Each entry shows the guest name, number of rooms, number of nights, total cost, and booking time.

### 10. Approve / Reject a Booking
Review pending booking requests and take action:

- **Approve (A):** Confirms the booking. Available rooms are reduced by the number
  of rooms requested. The system prevents approval if there are not enough rooms available.
- **Reject (R):** Declines the booking. Room count is not affected.
- **Cancel (0):** Return without taking action.

### 11. Revenue Report
Generates a full revenue summary across all your hotels. For each hotel, it shows:
- Number of approved bookings
- Total revenue from those bookings (Price × Rooms × Nights)
- Grand total revenue across all your hotels combined

### 12. Logout
Ends your session and returns to the splash screen.

---

## Admin Panel

Admins have full control over the database — approving content submitted by users
and hotel managers, managing spots, and monitoring all system activity.

### 1. List All Spots
View all approved spots in the database.

### 2. Approve Pending Spots
View all spot submissions from users waiting for review. For each entry:

- **Approve (A):** Moves the spot into the live database. Instantly visible to all users.
- **Disapprove (D):** Permanently removes the submission.
- **Cancel (0):** Return without taking action.

### 3. Approve Pending Hotels
View all hotel submissions from Hotel Managers. Same Approve / Disapprove / Cancel flow.

> If a hotel's linked spot was deleted while the hotel was still pending, the system
> flags it with a warning. You cannot approve a hotel for a spot that no longer exists
> — use Disapprove to clean it up.

When a hotel is approved, the submitting Hotel Manager automatically becomes
its manager and can start receiving bookings.

### 4. Delete a Spot (Cascade)
Permanently delete a spot and **all data linked to it**:
- The spot itself
- All approved hotels for that spot
- All ratings for that spot
- All bookings associated with that spot
- All pending hotel submissions for that spot

You must type `YES` (uppercase) to confirm. This action cannot be undone.

### 5. View All Registered Users
Displays all user accounts with their ID, username, and role.
Password hashes are never shown.

### 6. View Audit Log
Every significant action in the system is recorded with a timestamp, actor, action type,
and target. Actions logged include: logins, logouts, signups, spot and hotel submissions,
approvals, disapprovals, deletions, bookings, cost calculations, revenue views,
report exports, and force exits via Ctrl+C.

### 7. Average Ratings for All Spots
A table showing every spot's average rating and total review count.

### 8. Show Full Summary for a Spot
Complete view of a spot — location, season, all ratings with average, and all hotels with pricing.

### 9. Top Rated Spots
All spots ranked by average rating from highest to lowest.

### 10. View All Bookings
A full list of every booking in the system across all hotels and managers,
showing guest, hotel, rooms, nights, total cost, manager, status, and timestamp.

### 11. Export Summary Report
Generates `summary_report.txt` with every spot's full details including
ratings, averages, and hotels. Useful for printing or archival.

### 12. Logout
Ends the admin session and returns to the splash screen.

---

## Database Files

All data is stored as plain pipe-delimited (`|`) text files in the project folder.

| File | Schema |
|---|---|
| `users.txt` | UserID \| Username \| PasswordHash \| Role |
| `spots.txt` | SpotID \| Name \| City \| Country \| Description \| BestSeason |
| `pending_spots.txt` | SpotID \| Name \| City \| Country \| Description \| BestSeason \| SubmittedBy |
| `hotels.txt` | HotelID \| SpotID \| HotelName \| Address \| PricePerNight \| TotalRooms \| AvailableRooms \| ManagerUsername |
| `pending_hotels.txt` | HotelID \| SpotID \| HotelName \| Address \| PricePerNight \| TotalRooms \| SubmittedBy |
| `ratings.txt` | SpotID \| Username \| Rating \| Comment |
| `bookings.txt` | BookingID \| Username \| HotelID \| HotelName \| SpotID \| Rooms \| Nights \| Status \| Timestamp |
| `audit_log.txt` | Timestamp \| Actor \| Action \| TargetID |
| `summary_report.txt` | Generated on demand by admin export |

---

## Booking Cost Formula

All cost calculations across the system use the same formula:

```
Total Cost = Price per Room per Night × Number of Rooms × Number of Nights
```

This applies to the booking flow, the travel cost calculator, the revenue report,
and the booking history view.

---

## Safety Features

**Password security:** Passwords are hashed with SHA-256 via `sha256sum` before storage.
The original password is never saved anywhere in the system.

**Input sanitization:** The pipe character `|` is stripped from all user input
to prevent delimiter injection since `|` is the column separator in all database files.

**Room availability enforcement:** The booking system checks available rooms in real time
and prevents users from requesting more rooms than are currently free.
The hotel manager approval step also re-checks availability before confirming.

**Atomic writes:** When approving content, the system writes to the live file first,
confirms the write succeeded, and only then removes the entry from the pending queue.
This prevents data loss if an operation fails mid-execution.

**Cascade delete:** Deleting a spot automatically removes all linked hotels, ratings,
pending hotel submissions, and bookings — no orphaned data is left behind.

**Graceful exit:** Pressing `Ctrl+C` at any point logs the interruption to the audit trail,
clears the session, and exits cleanly without corrupting any files.

---

## For Teammates on Windows (WSL)

```bash
# Install WSL if not already (run in PowerShell as Administrator)
wsl --install

# Open WSL, then clone and run
git clone https://github.com/shirsho009/travel-spot-manager.git
cd travel-spot-manager
chmod +x travel_manager.sh lib/init.sh lib/auth.sh lib/shared.sh lib/user.sh lib/hotel_manager.sh lib/admin.sh
./travel_manager.sh
```

Everything works identically on WSL as it does on Mac/OrbStack.
