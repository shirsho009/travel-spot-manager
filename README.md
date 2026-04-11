# 🌍 Travel Spot Management System

A fully interactive, terminal-based travel management application built in pure Bash.
Manage travel destinations, hotels, ratings, and users — all through a secure,
role-based interface running entirely on text files.

**Student:** SHIMANTO SHIRSHO (2204009)  
**Course:** Operating Systems, CSE Department, CUET

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

# Make the script executable (first time only)
chmod +x travel_manager.sh

# Run
./travel_manager.sh
```

On first run, all database files are automatically created with sample data.
You do not need to create any files manually.

### Default Admin Login
Username : admin
Password : admin123


> Change this password after first login by editing users.txt directly,
> or ask your system admin to update it.

---

## How It Works

When you run the program, you land on a **splash screen** with three options:
1. Login
2. Sign Up
3. Exit

After logging in, the system routes you to one of two panels depending on your role:
- **User Panel** — for regular users who browse and submit content
- **Admin Panel** — for administrators who manage and approve content

---

## Signing Up

Select **Sign Up** from the splash screen.

- Choose a unique username
- Enter a password (hidden while typing)
- Confirm your password

All new accounts are assigned the **User** role automatically.
Passwords are never stored as plain text — they are hashed using SHA-256 before saving.

---

## User Panel

### 1. List All Spots
Displays every approved travel spot in the database with its location and best season to visit.

### 2. Search by City
Type part of a city name (case-insensitive). Shows all spots in matching cities.
Example: typing `cox` will find Cox's Bazar.

### 3. Search by Country
Type part of a country name. Shows all spots in matching countries.

### 4. Search by Best Season
Enter a season — `Winter`, `Summer`, `Spring`, `Monsoon`, or `Any`.
The system returns spots whose best visiting season matches your input.
Useful for planning trips around specific times of year.

### 5. Submit a New Spot
Submit a travel destination for admin review. Fill in:
- Spot name
- City
- Country
- Description
- Best season to visit

Your submission goes into a **pending queue** and does not appear in the live database
until an admin approves it.

### 6. Submit a New Hotel
Submit a hotel near an existing spot. The system shows you the current spot list
so you can pick the correct Spot ID. Fill in:
- Hotel name
- Address
- Price per night (BDT)

Like spots, hotel submissions go into a pending queue awaiting admin approval.

### 7. Add Rating for a Spot
Rate any approved spot from **1 to 5** and leave a comment.
Your username is automatically attached to your rating.

### 8. List Ratings for a Spot
View all user ratings and comments for any spot.
The system shows the spot list first so you can find the correct ID.

### 9. Show Full Summary for a Spot
View everything about a spot in one screen:
- Location and description
- Best season
- All ratings with usernames and comments
- Calculated average rating
- All available hotels with prices
- Price range (lowest to highest)

### 10. Top Rated Spots
Shows all spots ranked from highest to lowest average rating.
Spots with no ratings appear at the bottom.

### 11. Travel Cost Calculator
Plan your trip budget:
1. Select a destination spot
2. Choose a hotel from available options
3. Enter number of nights
4. The system calculates your total accommodation cost

### 12. Logout
Ends your session and returns to the splash screen.

---

## Admin Panel

Admins have full control over the database, including approving content,
managing users, and viewing system activity.

### 1. List All Spots
Same as the user view — shows all approved spots.

### 2. Approve Pending Spots
View all spot submissions waiting for review. For each pending spot you can:

- **Approve (A):** Moves the spot from the pending queue into the live database.
  The spot instantly becomes visible to all users.
- **Disapprove (D):** Permanently removes the submission from the queue.
  The submitting user's entry is discarded.
- **Cancel (0):** Return without taking action.

### 3. Approve Pending Hotels
View all hotel submissions waiting for review. Same Approve / Disapprove / Cancel
flow as spots.

> If a hotel's linked spot was deleted while the hotel was still pending,
> the system flags it with a warning. You cannot approve a hotel for a
> spot that no longer exists — use Disapprove to clean it up.

### 4. Delete a Spot (Cascade)
Permanently delete a spot and **all data linked to it**:
- The spot itself
- All approved hotels for that spot
- All ratings for that spot
- All pending hotel submissions for that spot

You must type `YES` (uppercase) to confirm. This action cannot be undone.
The cascade ensures no orphaned data remains after deletion.

### 5. View All Registered Users
Displays a table of all user accounts with their ID, username, and role.
Passwords are never shown — only their secure hashes are stored.

### 6. View Audit Log
Every significant action in the system is recorded with:
- Timestamp
- Who performed the action
- What the action was
- What it targeted

Actions logged include: logins, logouts, signups, spot/hotel submissions,
approvals, disapprovals, deletions, cost calculations, report exports,
and force exits via Ctrl+C.

### 7. Average Ratings for All Spots
Displays a table showing every spot's average rating and total number of reviews.
Spots with no ratings show N/A.

### 8. Show Full Summary for a Spot
Same detailed view as the user version — location, season, all ratings,
average score, and all hotels with prices.

### 9. Top Rated Spots
Spots ranked by average rating, highest first.

### 10. Export Summary Report
Generates a `summary_report.txt` file containing every spot's full details —
description, all ratings with averages, and all hotels.
Useful for printing or submitting as documentation.

### 11. Logout
Ends the admin session and returns to the splash screen.

---

## Database Files

All data is stored as plain pipe-delimited text files in the project folder.
You can open any of them with a text editor to inspect the raw data.

| File | What it stores |
|---|---|
| `users.txt` | UserID, Username, Password Hash, Role |
| `spots.txt` | Approved travel spots |
| `pending_spots.txt` | Spot submissions awaiting admin approval |
| `hotels.txt` | Approved hotels linked to spots |
| `pending_hotels.txt` | Hotel submissions awaiting admin approval |
| `ratings.txt` | User ratings and comments per spot |
| `audit_log.txt` | Full timestamped log of all system actions |
| `summary_report.txt` | Generated when admin exports a report |

---

## Safety Features

**Password security:** Passwords are hashed with SHA-256 before storage.
The original password is never saved anywhere.

**Input sanitization:** The pipe character `|` is stripped from all user input
to prevent data corruption since `|` is used as the column separator.

**Atomic writes:** When approving content, the system writes to the live file first,
confirms the write succeeded, and only then removes it from the pending queue.
This prevents data loss if something goes wrong mid-operation.

**Cascade delete:** Deleting a spot automatically removes all linked hotels,
ratings, and pending hotel submissions — no orphaned data is left behind.

**Graceful exit:** Pressing `Ctrl+C` at any point logs the interruption to the
audit trail, clears the session, and exits cleanly without corrupting any files.

---

## For Teammates on Windows (WSL)

```bash
# Install WSL if not already (run in PowerShell as Administrator)
wsl --install

# Open WSL, then clone and run
git clone https://github.com/shirsho009/travel-spot-manager.git
cd travel-spot-manager
chmod +x travel_manager.sh
./travel_manager.sh
```