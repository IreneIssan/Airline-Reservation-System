# Airline Reservation Management System ✈️

This is a complete Web-Based Airline Reservation Management System built using Python (Flask) and MySQL. It strictly follows DBMS Mini Project Guidelines and includes complex SQL structures like DDL, DML, JOINs, Aggregate Functions, Views, and Triggers.

## Features & Highlights
- **Database Architecture**: 7 related tables (`Passengers`, `Airports`, `Flights`, `Classes`, `Bookings`, `Payments`, `FoodOrders`).
- **Pre-populated Data**: Includes `generate_sql.py` which creates the database and populates 50 dummy records per table.
- **Triggers implemented**:
  1. Auto-calculates Booking TotalAmount before insert using flight base fare and class multiplier.
  2. Prevents passenger deletion if active bookings exist.
  3. Auto-updates Booking status to "Confirmed" upon payment insertion.
- **Views & Aggregates**: Provides an Admin Dashboard demonstrating `COUNT`, `SUM`, `AVG`, `MAX`, complex `JOINs`, and multiple `VIEWs`.
- **Modern Web Interface**: Built with raw HTML/CSS for a fast, responsive, and beautiful airline theme.

## Prerequisites
- Python 3.8+
- MySQL Server 8.0+

## Setup Instructions

### 1. Database Setup
1. Ensure your MySQL server is running.
2. The project contains a pre-generated SQL file: `database.sql`. You can directly import this into your local MySQL instance. 
   - *Alternative*: If you wish to regenerate the tables and dummy data, run:
     ```bash
     python generate_sql.py
     ```
3. Import the SQL file via command line:
   ```bash
   mysql -u root -p < database.sql
   ```
   *Note: if your username is not root, adjust accordingly.*

### 2. Application Setup
1. Navigate to the project directory in your terminal.
2. Create and activate a virtual environment (optional but recommended).
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure Database Credentials:
   Open `app.py` in your text editor. Find the `get_db_connection()` function near line 8 and update the `password` field (and `user` if needed) to match your local MySQL credentials.
   ```python
   def get_db_connection():
       connection = mysql.connector.connect(
           host='localhost',
           user='root',
           password='YOUR_PASSWORD_HERE', # <--- Update this
           database='airline_management'
       )
   ```

### 3. Running the App
1. Start the Flask server:
   ```bash
   python app.py
   ```
2. Open your browser and navigate to `http://127.0.0.1:5000/`.

## Author
Developed for DBMS Mini Project requirements. Enjoy your flight!
