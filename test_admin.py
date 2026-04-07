from app import app, get_db_connection
import traceback

with app.app_context():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    queries = [
        ("TOTAL PASSENGERS", "SELECT COUNT(*) AS total FROM Passengers"),
        ("JOIN SAMPLE", """
            SELECT 
            p.Name,
            f.FlightNumber,
            c.ClassType,
            b.TotalAmount
            FROM Bookings b
            JOIN Passengers p ON b.PassengerID = p.PassengerID
            JOIN Flights f ON b.FlightID = f.FlightID
            JOIN Classes c ON b.ClassID = c.ClassID
        """),
        ("MONTHLY REVENUE", """
            SELECT 
            MONTH(b.BookingDate) AS Month,
            SUM(b.TotalAmount) AS Revenue
            FROM Bookings b
            GROUP BY MONTH(b.BookingDate)
            ORDER BY Month
        """)
    ]
    for name, q in queries:
        try:
            print(f"Running {name}...")
            cursor.execute(q)
            print("Success:", len(cursor.fetchall()), "rows")
        except Exception as e:
            print(f"FAILED on {name}: {e}")
            
    cursor.close()
    conn.close()
