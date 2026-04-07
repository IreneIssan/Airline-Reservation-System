from flask import Flask, render_template, request, redirect, url_for, flash, session
from functools import wraps
import mysql.connector
from mysql.connector import Error

app = Flask(__name__)
app.secret_key = 'your_secret_key_here' # Change this in production

# Database Configuration
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'isqlrene', # SET YOUR MYSQL PASSWORD HERE
    'database': 'airline_management'
}

# Currency Mapping: Country -> (Symbol, Exchange Rate from USD)
CURRENCY_MAP = {
    'India': ('₹', 83.0),
    'UAE': ('AED', 3.67),
    'USA': ('$', 1.0),
    'UK': ('£', 0.79),
    'Germany': ('€', 0.92),
    'France': ('€', 0.92),
    'Netherlands': ('€', 0.92),
    'Italy': ('€', 0.92),
    'Spain': ('€', 0.92),
    'Austria': ('€', 0.92),
    'Belgium': ('€', 0.92),
    'Singapore': ('SGD', 1.34),
    'Malaysia': ('MYR', 4.73),
    'Australia': ('AUD', 1.52),
    'Japan': ('JPY', 150.0),
    'China': ('CNY', 7.19),
    'South Korea': ('KRW', 1330.0),
    'Qatar': ('QAR', 3.64),
    'Turkey': ('TRY', 31.5),
    'Canada': ('CAD', 1.35),
    'Thailand': ('THB', 35.8),
    'Sri Lanka': ('LKR', 310.0),
    'Maldives': ('MVR', 15.4),
    'Switzerland': ('CHF', 0.88),
    'Egypt': ('EGP', 30.9),
    'South Africa': ('ZAR', 19.1),
    'Kenya': ('KES', 145.0),
    'New Zealand': ('NZD', 1.63),
    'Philippines': ('PHP', 56.0),
    'Indonesia': ('IDR', 15700.0),
    'Vietnam': ('VND', 24600.0),
    'Peru': ('PEN', 3.8),
    'Brazil': ('BRL', 4.95)
}

def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host=db_config['host'],
            user=db_config['user'],
            password=db_config['password'],
            database=db_config['database']
        )
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

@app.route('/')
def index():
    # Index page with flight search form
    conn = get_db_connection()
    airports = []
    if conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM Airports")
        airports = cursor.fetchall()
        cursor.close()
        conn.close()
    return render_template('index.html', airports=airports)

@app.route('/search', methods=['POST'])
def search_flights():
    source = request.form.get('source_id')
    destination = request.form.get('destination_id')
    
    conn = get_db_connection()
    flights = []
    if conn:
        cursor = conn.cursor(dictionary=True)
        # Fetch flights with source country
        query = """
            SELECT 
            f.FlightID,
            f.FlightNumber,
            a1.AirportName AS Source,
            a1.Country AS SourceCountry,
            a2.AirportName AS Destination,
            f.DepartureTime,
            f.ArrivalTime,
            f.BaseFare
            FROM Flights f
            JOIN Airports a1 ON f.SourceAirportID = a1.AirportID
            JOIN Airports a2 ON f.DestinationAirportID = a2.AirportID
            WHERE f.SourceAirportID = %s 
              AND f.DestinationAirportID = %s 
        """
        cursor.execute(query, (source, destination))
        flights = cursor.fetchall()
        
        # Determine currency from the first result (or default)
        if flights:
            country = flights[0]['SourceCountry']
            symbol, rate = CURRENCY_MAP.get(country, ('$', 1.0))
            session['currency_symbol'] = symbol
            session['currency_rate'] = rate
        else:
            session['currency_symbol'] = '$'
            session['currency_rate'] = 1.0

        # Apply currency conversion for metadata
        for flight in flights:
            flight['currency_symbol'] = session['currency_symbol']
            flight['converted_fare'] = float(flight['BaseFare']) * session['currency_rate']
            
        cursor.close()
        conn.close()
        
    return render_template('search_results.html', flights=flights)

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form.get('name')
        gender = request.form.get('gender')
        age = request.form.get('age')
        passport = request.form.get('passport')
        phone = request.form.get('phone')
        email = request.form.get('email')
        
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute("""
                    INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (name, gender, age, passport, phone, email))
                conn.commit()
                flash('Passenger registered successfully!', 'success')
                return redirect(url_for('index'))
            except Error as e:
                flash(f'Error: {e}', 'danger')
            finally:
                cursor.close()
                conn.close()
    return render_template('register.html')

@app.route('/book/<int:flight_id>', methods=['GET', 'POST'])
def book_flight(flight_id):
    conn = get_db_connection()
    if request.method == 'POST':
        passenger_id = request.form.get('passenger_id')
        class_id = request.form.get('class_id')
        
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute("""
                    INSERT INTO Bookings (PassengerID, FlightID, ClassID)
                    VALUES (%s, %s, %s)
                """, (passenger_id, flight_id, class_id))
                conn.commit()
                booking_id = cursor.lastrowid
                flash('Flight booked successfully! Please order food or make payment.', 'success')
                return redirect(url_for('booking_summary', booking_id=booking_id))
            except Error as e:
                flash(f'Error: {e}', 'danger')
            finally:
                cursor.close()
                conn.close()
                
    # GET request: load passengers, flight info, and classes
    passengers, flight, classes = [], None, []
    if conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM Passengers")
        passengers = cursor.fetchall()
        
        cursor.execute("SELECT * FROM Flights WHERE FlightID = %s", (flight_id,))
        flight = cursor.fetchone()
        
        cursor.execute("SELECT * FROM Classes")
        classes = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
    return render_template('book.html', 
                           flight=flight, 
                           passengers=passengers, 
                           classes=classes, 
                           currency_symbol=session.get('currency_symbol', '$'),
                           currency_rate=session.get('currency_rate', 1.0))

@app.route('/food/<int:booking_id>', methods=['GET', 'POST'])
def order_food(booking_id):
    if request.method == 'POST':
        item = request.form.get('food_item')
        qty = request.form.get('quantity')
        price = request.form.get('price') # Assume price per item logic is simple or frontend sent it
        
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute("""
                    INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price)
                    VALUES (%s, %s, %s, %s)
                """, (booking_id, item, qty, price))
                conn.commit()
                flash('Food ordered successfully.', 'success')
            except Error as e:
                flash(f'Error: {e}', 'danger')
            finally:
                cursor.close()
                conn.close()
        return redirect(url_for('booking_summary', booking_id=booking_id))
        
    return render_template('food.html', 
                           booking_id=booking_id, 
                           currency_symbol=session.get('currency_symbol', '$'),
                           currency_rate=session.get('currency_rate', 1.0))

@app.route('/payment/<int:booking_id>', methods=['GET', 'POST'])
def payment(booking_id):
    conn = get_db_connection()
    if request.method == 'POST':
        mode = request.form.get('payment_mode')
        amount = request.form.get('amount_paid')
        
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute("""
                    INSERT INTO Payments (BookingID, PaymentMode, AmountPaid)
                    VALUES (%s, %s, %s)
                """, (booking_id, mode, amount))
                conn.commit()
                flash('Payment completed! Your booking is now Confirmed.', 'success')
            except Error as e:
                flash(f'Error: {e}', 'danger')
            finally:
                cursor.close()
                conn.close()
        return redirect(url_for('booking_summary', booking_id=booking_id))
        
    # Get amount needed to be paid
    booking = None
    if conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM Bookings WHERE BookingID = %s", (booking_id,))
        booking = cursor.fetchone()
        cursor.close()
        conn.close()
        
    return render_template('payment.html', 
                           booking=booking, 
                           currency_symbol=session.get('currency_symbol', '$'),
                           currency_rate=session.get('currency_rate', 1.0))

@app.route('/summary/<int:booking_id>')
def booking_summary(booking_id):
    conn = get_db_connection()
    summary = None
    orders = []
    if conn:
        cursor = conn.cursor(dictionary=True)
        # Using View: View_Booking_Summary
        cursor.execute("SELECT * FROM View_Booking_Summary WHERE BookingID = %s", (booking_id,))
        summary = cursor.fetchone()
        
        cursor.execute("SELECT * FROM FoodOrders WHERE BookingID = %s", (booking_id,))
        orders = cursor.fetchall()
        
        cursor.close()
        conn.close()
    summary['TotalAmount'] = float(summary['TotalAmount'])  
    return render_template('summary.html', 
                           summary=summary, 
                           orders=orders, 
                           currency_symbol=session.get('currency_symbol', '$'),
                           currency_rate=session.get('currency_rate', 1.0))

@app.route('/cancel/<int:booking_id>', methods=['POST'])
def cancel_booking(booking_id):
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        try:
            cursor.execute("UPDATE Bookings SET Status = 'Cancelled' WHERE BookingID = %s", (booking_id,))
            conn.commit()
            flash('Booking cancelled successfully.', 'success')
        except Error as e:
            flash(f'Error: {e}', 'danger')
        finally:
            cursor.close()
            conn.close()
    return redirect(url_for('index'))

# ── Admin Auth Helpers ────────────────────────────────────────────────────────

def login_required(f):
    """Decorator: redirects to admin login if not authenticated."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('admin_logged_in'):
            flash('Please log in to access the admin dashboard.', 'warning')
            return redirect(url_for('admin_login'))
        return f(*args, **kwargs)
    return decorated


@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    # Already logged in → go straight to dashboard
    if session.get('admin_logged_in'):
        return redirect(url_for('admin_dashboard'))

    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '').strip()

        conn = get_db_connection()
        if conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                "SELECT * FROM Admins WHERE Username = %s AND Password = %s",
                (username, password)
            )
            admin = cursor.fetchone()
            cursor.close()
            conn.close()

            if admin:
                session['admin_logged_in'] = True
                session['admin_username'] = admin['Username']
                flash(f"Welcome, {admin['Username']}!", 'success')
                return redirect(url_for('admin_dashboard'))
            else:
                flash('Invalid username or password.', 'danger')
        else:
            flash('Database connection error.', 'danger')

    return render_template('admin_login.html')


@app.route('/admin/logout')
def admin_logout():
    session.pop('admin_logged_in', None)
    session.pop('admin_username', None)
    flash('You have been logged out.', 'info')
    return redirect(url_for('admin_login'))


# ── Admin Dashboard (protected) ───────────────────────────────────────────────

@app.route('/admin')
@login_required
def admin_dashboard():
    conn = get_db_connection()
    reports = {}
    if conn:
        cursor = conn.cursor(dictionary=True)
        
        # TOP STATS
        cursor.execute("SELECT COUNT(*) AS total FROM Passengers")
        reports['total_passengers'] = cursor.fetchone()['total']

        cursor.execute("SELECT COUNT(*) AS total FROM Airports")
        reports['total_airports'] = cursor.fetchone()['total']

        cursor.execute("SELECT COUNT(*) AS total FROM Flights")
        reports['total_flights'] = cursor.fetchone()['total']

        cursor.execute("SELECT COUNT(*) AS total FROM Bookings")
        reports['total_bookings'] = cursor.fetchone()['total']

        cursor.execute("SELECT COUNT(*) AS total FROM Bookings WHERE Status = 'Confirmed'")
        reports['total_confirmed'] = cursor.fetchone()['total']

        cursor.execute("SELECT SUM(TotalAmount) AS total FROM Bookings WHERE Status = 'Confirmed'")
        res = cursor.fetchone()
        reports['total_revenue'] = res['total'] if res['total'] else 0

        
        # A) JOIN REPORT SECTION
        cursor.execute("""
            SELECT 
            p.Name,
            f.FlightNumber,
            c.ClassType,
            b.TotalAmount
            FROM Bookings b
            JOIN Passengers p ON b.PassengerID = p.PassengerID
            JOIN Flights f ON b.FlightID = f.FlightID
            JOIN Classes c ON b.ClassID = c.ClassID
        """)
        reports['join_sample'] = cursor.fetchall()

        # B) BOOKINGS PER FLIGHT (COUNT)
        cursor.execute("""
            SELECT 
            f.FlightNumber,
            COUNT(b.BookingID) AS TotalBookings
            FROM Flights f
            LEFT JOIN Bookings b ON f.FlightID = b.FlightID
            GROUP BY f.FlightNumber
        """)
        reports['bookings_per_flight'] = cursor.fetchall()
        
        # C) TOTAL REVENUE PER FLIGHT (SUM)
        cursor.execute("""
            SELECT 
            f.FlightNumber,
            SUM(b.TotalAmount) AS TotalRevenue
            FROM Flights f
            JOIN Bookings b ON f.FlightID = b.FlightID
            GROUP BY f.FlightNumber
        """)
        reports['revenue_per_flight'] = cursor.fetchall()
        
        # D) AVG PRICE PER CLASS (AVG)
        cursor.execute("""
            SELECT 
            c.ClassType,
            AVG(b.TotalAmount) AS AvgRevenue
            FROM Classes c
            JOIN Bookings b ON c.ClassID = b.ClassID
            GROUP BY c.ClassType
        """)
        reports['avg_price_class'] = cursor.fetchall()
        
        # E) MAX REVENUE FLIGHT (MAX)
        cursor.execute("""
            SELECT 
            f.FlightNumber,
            SUM(b.TotalAmount) AS Revenue
            FROM Flights f
            JOIN Bookings b ON f.FlightID = b.FlightID
            GROUP BY f.FlightNumber
            ORDER BY Revenue DESC
            LIMIT 1
        """)
        reports['max_revenue_flight'] = cursor.fetchone()
        
        # F) MONTHLY REVENUE REPORT
        cursor.execute("""
            SELECT 
            MONTH(b.`BookingDate`) AS Month,
            SUM(b.TotalAmount) AS Revenue
            FROM Bookings b
            GROUP BY MONTH(b.`BookingDate`)
            ORDER BY Month
        """)
        reports['monthly_revenue'] = cursor.fetchall()

        # ── CREATE SQL VIEW for Flight Route Performance (persists in DB) ──────
        cursor.execute("""
            CREATE OR REPLACE VIEW View_Flight_Route_Performance AS
            SELECT
                f.FlightID,
                f.FlightNumber,
                a1.AirportName AS Origin,
                a1.City        AS OriginCity,
                a2.AirportName AS Destination,
                a2.City        AS DestinationCity,
                COUNT(b.BookingID)  AS TotalPassengers,
                SUM(b.TotalAmount)  AS TotalRevenue
            FROM Flights f
            JOIN Airports a1 ON f.SourceAirportID      = a1.AirportID
            JOIN Airports a2 ON f.DestinationAirportID = a2.AirportID
            LEFT JOIN Bookings b ON f.FlightID = b.FlightID
            GROUP BY f.FlightID, f.FlightNumber,
                     a1.AirportName, a1.City,
                     a2.AirportName, a2.City
        """)

        # R1) FLIGHT ROUTE PERFORMANCE (via SQL VIEW)
        cursor.execute("""
            SELECT
                FlightNumber,
                Origin,
                OriginCity,
                Destination,
                DestinationCity,
                TotalPassengers,
                TotalRevenue
            FROM View_Flight_Route_Performance
            ORDER BY TotalRevenue DESC
        """)
        reports['route_performance'] = cursor.fetchall()

        # R2) REVENUE GENERATED PER FLIGHT (SUM + GROUP BY with route details)
        cursor.execute("""
            SELECT
                f.FlightNumber,
                a1.City AS FromCity,
                a2.City AS ToCity,
                COUNT(b.BookingID)  AS Bookings,
                SUM(b.TotalAmount)  AS TotalRevenue
            FROM Flights f
            JOIN Airports a1 ON f.SourceAirportID      = a1.AirportID
            JOIN Airports a2 ON f.DestinationAirportID = a2.AirportID
            LEFT JOIN Bookings b ON f.FlightID = b.FlightID
            GROUP BY f.FlightNumber, a1.City, a2.City
            ORDER BY TotalRevenue DESC
        """)
        reports['revenue_per_flight_report'] = cursor.fetchall()

        # R3) PASSENGER CLASS DISTRIBUTION (COUNT + GROUP BY)
        cursor.execute("""
            SELECT
                c.ClassType,
                COUNT(b.BookingID)        AS TotalBookings,
                SUM(b.TotalAmount)        AS TotalRevenue,
                ROUND(
                    COUNT(b.BookingID) * 100.0 /
                    NULLIF((SELECT COUNT(*) FROM Bookings), 0),
                1) AS PctShare
            FROM Classes c
            LEFT JOIN Bookings b ON c.ClassID = b.ClassID
            GROUP BY c.ClassType
            ORDER BY TotalBookings DESC
        """)
        reports['class_distribution'] = cursor.fetchall()

        # R4) MOST POPULAR ROUTES (COUNT + GROUP BY)
        cursor.execute("""
            SELECT
                a1.City AS Origin,
                a2.City AS Destination,
                COUNT(b.BookingID)  AS TotalBookings,
                SUM(b.TotalAmount)  AS TotalRevenue
            FROM Bookings b
            JOIN Flights  f  ON b.FlightID              = f.FlightID
            JOIN Airports a1 ON f.SourceAirportID       = a1.AirportID
            JOIN Airports a2 ON f.DestinationAirportID  = a2.AirportID
            GROUP BY a1.City, a2.City
            ORDER BY TotalBookings DESC
            LIMIT 10
        """)
        reports['popular_routes'] = cursor.fetchall()

        # R5) BOOKING SUMMARY OVERVIEW (COUNT + SUM + GROUP BY Status)
        cursor.execute("""
            SELECT
                b.Status,
                COUNT(b.BookingID)  AS TotalBookings,
                SUM(b.TotalAmount)  AS TotalAmount
            FROM Bookings b
            GROUP BY b.Status
            ORDER BY TotalBookings DESC
        """)
        reports['booking_summary'] = cursor.fetchall()

        # Passenger for Delete
        cursor.execute("SELECT * FROM Passengers")
        reports['passengers'] = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
    return render_template('admin.html', reports=reports)

@app.route('/admin/delete_passenger/<int:passenger_id>')
@login_required
def delete_passenger(passenger_id):
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        try:
            # 1. Delete from BookingMeals (if exists)
            try:
                cursor.execute("""
                    DELETE FROM BookingMeals 
                    WHERE BookingID IN (SELECT BookingID FROM Bookings WHERE PassengerID = %s)
                """, (passenger_id,))
            except mysql.connector.Error:
                # If BookingMeals doesn't exist (e.g. it's FoodOrders), just skip
                pass

            # 2. Delete related records from Bookings
            cursor.execute("DELETE FROM Bookings WHERE PassengerID = %s", (passenger_id,))

            # 3. Delete from Passengers
            cursor.execute("DELETE FROM Passengers WHERE PassengerID = %s", (passenger_id,))
            
            conn.commit()
            flash('Passenger and related records deleted successfully.', 'success')
        except Error as e:
            conn.rollback()
            flash(f'Database Error: {e}', 'danger')
        finally:
            cursor.close()
            conn.close()
    return redirect(url_for('admin_dashboard'))

if __name__ == '__main__':
    app.run(debug=True)
