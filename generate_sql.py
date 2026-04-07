import random
from datetime import datetime, timedelta

def esc(s):
    return "'" + str(s).replace("'", "''") + "'"

def generate_sql():
    sql: list[str] = []
    
    # DDL
    sql.append("-- 1. DATABASE COMPILATION")
    sql.append("DROP DATABASE IF EXISTS airline_management;")
    sql.append("CREATE DATABASE airline_management;")
    sql.append("USE airline_management;\n")
    
    sql.append("-- 2. CREATE TABLES")
    
    # Passengers
    sql.append("""
CREATE TABLE Passengers (
    PassengerID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Gender ENUM('Male', 'Female', 'Other') NOT NULL,
    Age INT NOT NULL CHECK (Age > 0),
    PassportNo VARCHAR(20) UNIQUE NOT NULL,
    Phone VARCHAR(15),
    Email VARCHAR(100)
);""")

    # Airports
    sql.append("""
CREATE TABLE Airports (
    AirportID INT AUTO_INCREMENT PRIMARY KEY,
    AirportName VARCHAR(100) NOT NULL,
    City VARCHAR(100) NOT NULL,
    Country VARCHAR(100) NOT NULL
);""")

    # Flights
    sql.append("""
CREATE TABLE Flights (
    FlightID INT AUTO_INCREMENT PRIMARY KEY,
    FlightNumber VARCHAR(10) UNIQUE NOT NULL,
    SourceAirportID INT NOT NULL,
    DestinationAirportID INT NOT NULL,
    DepartureTime DATETIME NOT NULL,
    ArrivalTime DATETIME NOT NULL,
    BaseFare DECIMAL(10, 2) NOT NULL CHECK (BaseFare > 0),
    FOREIGN KEY (SourceAirportID) REFERENCES Airports(AirportID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DestinationAirportID) REFERENCES Airports(AirportID) ON DELETE RESTRICT ON UPDATE CASCADE
);""")

    # Classes
    sql.append("""
CREATE TABLE Classes (
    ClassID INT AUTO_INCREMENT PRIMARY KEY,
    ClassType VARCHAR(50) NOT NULL,
    PriceMultiplier DECIMAL(4, 2) NOT NULL DEFAULT 1.00 CHECK (PriceMultiplier > 0)
);""")

    # Bookings
    sql.append("""
CREATE TABLE Bookings (
    BookingID INT AUTO_INCREMENT PRIMARY KEY,
    PassengerID INT NOT NULL,
    FlightID INT NOT NULL,
    ClassID INT NOT NULL,
    BookingDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    TotalAmount DECIMAL(10, 2) DEFAULT 0 CHECK (TotalAmount >= 0),
    Status ENUM('Pending', 'Confirmed', 'Cancelled') DEFAULT 'Pending',
    FOREIGN KEY (PassengerID) REFERENCES Passengers(PassengerID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (FlightID) REFERENCES Flights(FlightID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (ClassID) REFERENCES Classes(ClassID) ON DELETE RESTRICT ON UPDATE CASCADE
);""")

    # Payments
    sql.append("""
CREATE TABLE Payments (
    PaymentID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    PaymentDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    PaymentMode ENUM('Credit Card', 'Debit Card', 'UPI', 'Net Banking') NOT NULL,
    AmountPaid DECIMAL(10, 2) NOT NULL CHECK (AmountPaid > 0),
    FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID) ON DELETE CASCADE ON UPDATE CASCADE
);""")

    # FoodOrders
    sql.append("""
CREATE TABLE FoodOrders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    FoodItem VARCHAR(100) NOT NULL,
    Quantity INT NOT NULL DEFAULT 1 CHECK (Quantity > 0),
    Price DECIMAL(10, 2) NOT NULL CHECK (Price > 0),
    FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID) ON DELETE CASCADE ON UPDATE CASCADE
);""")

    sql.append("\n-- 3. TRIGGERS")
    sql.append("DELIMITER //")
    
    # Trigger 1: Automatically calculate TotalAmount in Booking before insert
    sql.append("""
CREATE TRIGGER Before_Booking_Insert
BEFORE INSERT ON Bookings
FOR EACH ROW
BEGIN
    DECLARE v_BaseFare DECIMAL(10,2);
    DECLARE v_Multiplier DECIMAL(4,2);
    
    SELECT BaseFare INTO v_BaseFare FROM Flights WHERE FlightID = NEW.FlightID;
    SELECT PriceMultiplier INTO v_Multiplier FROM Classes WHERE ClassID = NEW.ClassID;
    
    SET NEW.TotalAmount = (v_BaseFare * v_Multiplier) + (v_BaseFare * v_Multiplier * 0.10); -- 10% fixed tax
END;
//""")

    # Trigger 2: Prevent deletion of Passenger if booking exists
    sql.append("""
CREATE TRIGGER Prevent_Passenger_Deletion
BEFORE DELETE ON Passengers
FOR EACH ROW
BEGIN
    DECLARE booking_count INT;
    SELECT COUNT(*) INTO booking_count FROM Bookings WHERE PassengerID = OLD.PassengerID;
    IF booking_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete passenger because they have existing bookings.';
    END IF;
END;
//""")

    # Trigger 3: Automatically update Booking status to "Confirmed" after Payment insertion
    sql.append("""
CREATE TRIGGER After_Payment_Insert
AFTER INSERT ON Payments
FOR EACH ROW
BEGIN
    UPDATE Bookings SET Status = 'Confirmed' WHERE BookingID = NEW.BookingID;
END;
//

CREATE TRIGGER After_FoodOrder_Insert
AFTER INSERT ON FoodOrders
FOR EACH ROW
BEGIN
    UPDATE Bookings SET TotalAmount = TotalAmount + (NEW.Price * NEW.Quantity) WHERE BookingID = NEW.BookingID;
END;
//""")
    
    sql.append("DELIMITER ;\n")
    
    sql.append("-- 4. VIEWS")
    
    # View 1: View_Booking_Summary
    sql.append("""
CREATE VIEW View_Booking_Summary AS
SELECT 
    b.BookingID,
    p.Name AS PassengerName,
    f.FlightNumber,
    c.ClassType,
    b.TotalAmount,
    b.Status AS BookingStatus,
    b.BookingDate
FROM Bookings b
JOIN Passengers p ON b.PassengerID = p.PassengerID
JOIN Flights f ON b.FlightID = f.FlightID
JOIN Classes c ON b.ClassID = c.ClassID;
""")

    # View 2: View_Flight_Revenue
    sql.append("""
CREATE VIEW View_Flight_Revenue AS
SELECT 
    f.FlightNumber,
    COUNT(b.BookingID) AS TotalBookings,
    SUM(b.TotalAmount) AS TotalRevenue
FROM Flights f
LEFT JOIN Bookings b ON f.FlightID = b.FlightID AND b.Status = 'Confirmed'
GROUP BY f.FlightID;
""")

    # View 3: View_Passenger_History
    sql.append("""
CREATE VIEW View_Passenger_History AS
SELECT 
    p.Name AS PassengerName,
    f.FlightNumber,
    a1.AirportName AS SourceAirport,
    a2.AirportName AS DestinationAirport,
    b.BookingDate,
    b.Status
FROM Passengers p
JOIN Bookings b ON p.PassengerID = b.PassengerID
JOIN Flights f ON b.FlightID = f.FlightID
JOIN Airports a1 ON f.SourceAirportID = a1.AirportID
JOIN Airports a2 ON f.DestinationAirportID = a2.AirportID;
""")

    sql.append("\n-- 5. DUMMY DATA INSERTION\n")
    
    # Let's generate 50 records per table
    first_names = ["John", "Jane", "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Heidi", "Ivan", "Judy", "Mallory", "Victor", "Peggy", "Trent", "Sybil", "Olivia", "Liam", "Emma", "Noah", "Ava", "William", "Sophia", "James", "Isabella", "Benjamin", "Mia", "Elijah", "Charlotte", "Lucas"]
    last_names = ["Smith", "Doe", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White"]
    
    # Passengers
    sql.append("-- Inserting Passengers")
    for i in range(1, 61):
        name = random.choice(first_names) + " " + random.choice(last_names)
        gender = random.choice(["Male", "Female", "Other"])
        age = random.randint(18, 80)
        passport = f"P{random.randint(1000000, 9999999)}_{i}"
        phone = f"555-{random.randint(1000, 9999)}"
        email = f"{name.split()[0].lower()}{i}@example.com"
        sql.append(f"INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ({esc(name)}, '{gender}', {age}, '{passport}', '{phone}', '{email}');")

    # Airports
    sql.append("\n-- Inserting Airports")
    realistic_airports = [
        ("Hartsfield-Jackson Atlanta", "Atlanta", "USA"), ("Dallas/Fort Worth", "Dallas", "USA"), 
        ("Denver", "Denver", "USA"), ("O'Hare", "Chicago", "USA"), 
        ("Dubai", "Dubai", "UAE"), ("Los Angeles", "Los Angeles", "USA"), 
        ("Istanbul", "Istanbul", "Turkey"), ("Heathrow", "London", "UK"), 
        ("Indira Gandhi", "New Delhi", "India"), ("Charles de Gaulle", "Paris", "France"),
        ("Haneda", "Tokyo", "Japan"), ("Guangzhou Baiyun", "Guangzhou", "China"), 
        ("Schiphol", "Amsterdam", "Netherlands"), ("Chhatrapati Shivaji", "Mumbai", "India"), 
        ("Frankfurt", "Frankfurt", "Germany"), ("Barajas", "Madrid", "Spain"), 
        ("Suvarnabhumi", "Bangkok", "Thailand"), ("Changi", "Singapore", "Singapore"), 
        ("Kuala Lumpur", "Kuala Lumpur", "Malaysia"), ("Sydney Kingsford Smith", "Sydney", "Australia"), 
        ("Melbourne", "Melbourne", "Australia"), ("Toronto Pearson", "Toronto", "Canada"), 
        ("Vancouver", "Vancouver", "Canada"), ("Incheon", "Seoul", "South Korea"), 
        ("Hong Kong", "Hong Kong", "Hong Kong"), ("Hamad", "Doha", "Qatar"), 
        ("Pudong", "Shanghai", "China"), ("Beijing Capital", "Beijing", "China"), 
        ("Gatwick", "London", "UK"), ("Munich", "Munich", "Germany"),
        ("Leonardo da Vinci", "Rome", "Italy"), ("George Bush Intercontinental", "Houston", "USA"),
        ("Sea-Tac", "Seattle", "USA"), ("Orlando", "Orlando", "USA"),
        ("McCarran", "Las Vegas", "USA"), ("Charlotte Douglas", "Charlotte", "USA"),
        ("Phoenix Sky Harbor", "Phoenix", "USA"), ("Miami", "Miami", "USA"),
        ("Newark Liberty", "Newark", "USA"), ("John F. Kennedy", "New York", "USA"),
        ("San Francisco", "San Francisco", "USA"), ("Zurich", "Zurich", "Switzerland"),
        ("Copenhagen", "Copenhagen", "Denmark"), ("Oslo Gardermoen", "Oslo", "Norway"),
        ("Stockholm Arlanda", "Stockholm", "Sweden"), ("Helsinki", "Helsinki", "Finland"),
        ("Vienna", "Vienna", "Austria"), ("Lisbon", "Lisbon", "Portugal"),
        ("Athens", "Athens", "Greece"), ("Dublin", "Dublin", "Ireland"),
        ("King Abdulaziz", "Jeddah", "Saudi Arabia"), ("King Khalid", "Riyadh", "Saudi Arabia")
    ]
    # Length of realistic_airports is 52
    for i in range(1, 53): # insert 52 airports
        airport_name, city, country = realistic_airports[i-1]
        sql.append(f"INSERT INTO Airports (AirportName, City, Country) VALUES ({esc(airport_name)}, {esc(city)}, {esc(country)});")

    # Flights
    sql.append("\n-- Inserting Flights")
    # Specific Required Times: 06:00, 09:30, 12:45, 15:20, 18:10, 21:00
    departure_times = ["06:00", "09:30", "12:45", "15:20", "18:10", "21:00"]
    # 60 flights
    for i in range(1, 61):
        fn = f"FL-{random.randint(100, 999)}-{i}"
        src = random.randint(1, 52)
        dest = random.randint(1, 52)
        while dest == src:
            dest = random.randint(1, 52)
        
        # Pick a random date in the next 30 days
        base_date = datetime.now() + timedelta(days=random.randint(1, 30))
        # Pick from specific departure times
        dep_str = random.choice(departure_times)
        hour, minute = map(int, dep_str.split(':'))
        dep_time = base_date.replace(hour=hour, minute=minute, second=0, microsecond=0)
        
        # Arrival time: 1-5 hours after departure
        arr_time = dep_time + timedelta(hours=random.randint(1, 5), minutes=random.randint(0, 59))
        
        # Base Fare: $120 - $600
        base_fare = random.uniform(120.0, 600.0)
        
        sql.append(f"INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('{fn}', {src}, {dest}, '{dep_time.strftime('%Y-%m-%d %H:%M:%S')}', '{arr_time.strftime('%Y-%m-%d %H:%M:%S')}', {base_fare:.2f});")

    # Classes
    sql.append("\n-- Inserting Classes")
    # Multipliers adjusted for realism ($120 - $600 base)
    class_types = [
        ("Economy", 1.0),
        ("Premium Economy", 1.5),
        ("Business", 2.5),
        ("First Class", 4.0)
    ]
    for i in range(1, 61):
        ctype, base_mult = class_types[(i-1) % 4]
        ctype_name = f"{ctype} - Tier {i}"
        mult_val = base_mult + random.uniform(-0.05, 0.05)
        sql.append(f"INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('{ctype_name}', {mult_val:.2f});")

    # Bookings
    sql.append("\n-- Inserting Bookings (status Pending initially, some will become Confirmed when Payment is made)")
    # Trigger calculates TotalAmount, so we skip it in INSERT
    for i in range(1, 61):
        pid = random.randint(1, 60)
        fid = random.randint(1, 60)
        cid = random.randint(1, 60)
        bdate = datetime.now() - timedelta(days=random.randint(1, 30))
        sql.append(f"INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES ({pid}, {fid}, {cid}, '{bdate.strftime('%Y-%m-%d %H:%M:%S')}');")

    # Payments
    sql.append("\n-- Inserting Payments (Triggers 'Confirmed' status in Bookings)")
    modes = ['Credit Card', 'Debit Card', 'UPI', 'Net Banking']
    for i in range(1, 61):
        # Let's pay for all bookings to simplify Dummy data
        bid = i
        pdate = datetime.now() - timedelta(days=random.randint(0, 5))
        mode = random.choice(modes)
        # We don't have exact amount here easily since trigger calculated it in DB, 
        # so let's just insert some random amount or assume full payment.
        # Actually it says "AmountPaid > 0"
        amt = random.uniform(100.0, 1000.0)
        sql.append(f"INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES ({bid}, '{pdate.strftime('%Y-%m-%d %H:%M:%S')}', '{mode}', {amt:.2f});")

    # FoodOrders
    sql.append("\n-- Inserting FoodOrders")
    foods = ["Vegetarian Meal", "Chicken Sandwich", "Pasta", "Salad", "Steak", "Fruit Platter", "Wine"]
    for i in range(1, 61):
        bid = random.randint(1, 60)
        item = random.choice(foods)
        qty = random.randint(1, 3)
        price = random.uniform(5.0, 25.0)
        sql.append(f"INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES ({bid}, '{item}', {qty}, {price:.2f});")

    with open("database.sql", "w") as f:
        f.write("\n".join(sql))
        
if __name__ == '__main__':
    generate_sql()
    print("database.sql generated successfully.")
