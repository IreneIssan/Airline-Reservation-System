-- 1. DATABASE COMPILATION
DROP DATABASE IF EXISTS airline_management;
CREATE DATABASE airline_management;
USE airline_management;

-- 2. CREATE TABLES

CREATE TABLE Passengers (
    PassengerID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Gender ENUM('Male', 'Female', 'Other') NOT NULL,
    Age INT NOT NULL CHECK (Age > 0),
    PassportNo VARCHAR(20) UNIQUE NOT NULL,
    Phone VARCHAR(15),
    Email VARCHAR(100)
);

CREATE TABLE Airports (
    AirportID INT AUTO_INCREMENT PRIMARY KEY,
    AirportName VARCHAR(100) NOT NULL,
    City VARCHAR(100) NOT NULL,
    Country VARCHAR(100) NOT NULL
);

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
);

CREATE TABLE Classes (
    ClassID INT AUTO_INCREMENT PRIMARY KEY,
    ClassType VARCHAR(50) NOT NULL,
    PriceMultiplier DECIMAL(4, 2) NOT NULL DEFAULT 1.00 CHECK (PriceMultiplier > 0)
);

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
);

CREATE TABLE Payments (
    PaymentID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    PaymentDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    PaymentMode ENUM('Credit Card', 'Debit Card', 'UPI', 'Net Banking') NOT NULL,
    AmountPaid DECIMAL(10, 2) NOT NULL CHECK (AmountPaid > 0),
    FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE FoodOrders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    FoodItem VARCHAR(100) NOT NULL,
    Quantity INT NOT NULL DEFAULT 1 CHECK (Quantity > 0),
    Price DECIMAL(10, 2) NOT NULL CHECK (Price > 0),
    FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID) ON DELETE CASCADE ON UPDATE CASCADE
);

-- 3. TRIGGERS
DELIMITER //

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
//

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
//

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
//
DELIMITER ;

-- 4. VIEWS

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


CREATE VIEW View_Flight_Revenue AS
SELECT 
    f.FlightNumber,
    COUNT(b.BookingID) AS TotalBookings,
    SUM(b.TotalAmount) AS TotalRevenue
FROM Flights f
LEFT JOIN Bookings b ON f.FlightID = b.FlightID AND b.Status = 'Confirmed'
GROUP BY f.FlightID;


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


-- 5. DUMMY DATA INSERTION

-- Inserting Passengers
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Victor Davis', 'Male', 64, 'P7422523_1', '555-1007', 'victor1@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Liam Doe', 'Other', 23, 'P5986515_2', '555-6415', 'liam2@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Emma Smith', 'Female', 53, 'P9180596_3', '555-1666', 'emma3@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Benjamin Lopez', 'Male', 31, 'P8690396_4', '555-5756', 'benjamin4@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Mia Moore', 'Other', 33, 'P8429031_5', '555-7638', 'mia5@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Ivan Perez', 'Other', 43, 'P7060872_6', '555-7397', 'ivan6@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Victor Hernandez', 'Other', 63, 'P3080143_7', '555-5174', 'victor7@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Ava Lopez', 'Other', 46, 'P7889085_8', '555-3223', 'ava8@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Isabella Martinez', 'Female', 67, 'P7787966_9', '555-2161', 'isabella9@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('William Lopez', 'Other', 26, 'P7050600_10', '555-3603', 'william10@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('William Lee', 'Female', 60, 'P9461810_11', '555-1092', 'william11@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Mia Wilson', 'Other', 70, 'P3205774_12', '555-2774', 'mia12@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Judy Smith', 'Female', 33, 'P1114171_13', '555-5311', 'judy13@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Jane Lopez', 'Male', 31, 'P5712713_14', '555-3322', 'jane14@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Mia Doe', 'Male', 37, 'P5662134_15', '555-5175', 'mia15@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Bob White', 'Female', 63, 'P8922240_16', '555-5256', 'bob16@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Frank Moore', 'Female', 42, 'P1664263_17', '555-1229', 'frank17@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Sybil Johnson', 'Female', 24, 'P4888573_18', '555-6281', 'sybil18@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('James Lopez', 'Other', 56, 'P1611067_19', '555-3658', 'james19@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Benjamin Smith', 'Other', 19, 'P6101075_20', '555-6431', 'benjamin20@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Eve Wilson', 'Female', 61, 'P8061310_21', '555-4416', 'eve21@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Emma Johnson', 'Female', 24, 'P6676577_22', '555-3317', 'emma22@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Emma Johnson', 'Female', 22, 'P1231861_23', '555-3969', 'emma23@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Ivan Hernandez', 'Other', 57, 'P5478301_24', '555-3002', 'ivan24@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Frank Anderson', 'Female', 69, 'P7614516_25', '555-2167', 'frank25@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Charlotte Anderson', 'Female', 67, 'P7349563_26', '555-3012', 'charlotte26@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Grace Martin', 'Female', 50, 'P7335058_27', '555-1922', 'grace27@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Isabella White', 'Female', 21, 'P8764220_28', '555-5676', 'isabella28@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('William Thompson', 'Female', 75, 'P2082449_29', '555-5101', 'william29@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Liam Gonzalez', 'Other', 59, 'P4499918_30', '555-3406', 'liam30@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Liam Thompson', 'Male', 40, 'P5226901_31', '555-2123', 'liam31@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Elijah Thomas', 'Female', 71, 'P9363663_32', '555-2450', 'elijah32@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('John Rodriguez', 'Male', 21, 'P3509407_33', '555-1175', 'john33@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Judy Gonzalez', 'Other', 32, 'P5607751_34', '555-3809', 'judy34@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Mallory Lee', 'Other', 39, 'P5526211_35', '555-4478', 'mallory35@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Olivia Williams', 'Other', 65, 'P6550314_36', '555-1447', 'olivia36@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Eve Gonzalez', 'Female', 31, 'P8165544_37', '555-1051', 'eve37@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Charlie Garcia', 'Other', 49, 'P9347954_38', '555-3835', 'charlie38@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Judy Davis', 'Male', 47, 'P4938599_39', '555-6429', 'judy39@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Sophia White', 'Male', 35, 'P6677042_40', '555-7726', 'sophia40@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Ava Garcia', 'Male', 22, 'P2044130_41', '555-8605', 'ava41@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Ava Williams', 'Male', 72, 'P8205715_42', '555-4831', 'ava42@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Heidi Thompson', 'Female', 54, 'P3211263_43', '555-7256', 'heidi43@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Emma Moore', 'Male', 58, 'P9904588_44', '555-8518', 'emma44@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Diana Thomas', 'Male', 74, 'P1705374_45', '555-1502', 'diana45@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Elijah Thompson', 'Female', 21, 'P1936558_46', '555-9291', 'elijah46@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Isabella Smith', 'Other', 72, 'P2247898_47', '555-2779', 'isabella47@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Sybil Jackson', 'Other', 68, 'P4598301_48', '555-8235', 'sybil48@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Grace Miller', 'Female', 53, 'P9023750_49', '555-4175', 'grace49@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Ava Davis', 'Female', 62, 'P6880518_50', '555-4239', 'ava50@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Mia Gonzalez', 'Other', 24, 'P5336961_51', '555-6693', 'mia51@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Eve Davis', 'Other', 57, 'P2029734_52', '555-4135', 'eve52@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Grace Martinez', 'Female', 40, 'P5252883_53', '555-2709', 'grace53@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Judy Martin', 'Male', 63, 'P5202575_54', '555-3918', 'judy54@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Charlotte Brown', 'Other', 36, 'P6707715_55', '555-4045', 'charlotte55@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Benjamin Thompson', 'Female', 48, 'P8481120_56', '555-1064', 'benjamin56@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Lucas Taylor', 'Other', 40, 'P2130072_57', '555-7207', 'lucas57@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Noah Thomas', 'Female', 21, 'P3543448_58', '555-9520', 'noah58@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Olivia Rodriguez', 'Other', 76, 'P6440499_59', '555-3267', 'olivia59@example.com');
INSERT INTO Passengers (Name, Gender, Age, PassportNo, Phone, Email) VALUES ('Mallory Jackson', 'Other', 23, 'P4301962_60', '555-8196', 'mallory60@example.com');

-- Inserting Airports
INSERT INTO Airports (AirportName, City, Country) VALUES ('Hartsfield-Jackson Atlanta', 'Atlanta', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Dallas/Fort Worth', 'Dallas', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Denver', 'Denver', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('O''Hare', 'Chicago', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Dubai', 'Dubai', 'UAE');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Los Angeles', 'Los Angeles', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Istanbul', 'Istanbul', 'Turkey');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Heathrow', 'London', 'UK');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Indira Gandhi', 'New Delhi', 'India');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Charles de Gaulle', 'Paris', 'France');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Haneda', 'Tokyo', 'Japan');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Guangzhou Baiyun', 'Guangzhou', 'China');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Schiphol', 'Amsterdam', 'Netherlands');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Chhatrapati Shivaji', 'Mumbai', 'India');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Frankfurt', 'Frankfurt', 'Germany');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Barajas', 'Madrid', 'Spain');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Suvarnabhumi', 'Bangkok', 'Thailand');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Changi', 'Singapore', 'Singapore');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Kuala Lumpur', 'Kuala Lumpur', 'Malaysia');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Sydney Kingsford Smith', 'Sydney', 'Australia');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Melbourne', 'Melbourne', 'Australia');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Toronto Pearson', 'Toronto', 'Canada');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Vancouver', 'Vancouver', 'Canada');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Incheon', 'Seoul', 'South Korea');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Hong Kong', 'Hong Kong', 'Hong Kong');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Hamad', 'Doha', 'Qatar');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Pudong', 'Shanghai', 'China');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Beijing Capital', 'Beijing', 'China');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Gatwick', 'London', 'UK');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Munich', 'Munich', 'Germany');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Leonardo da Vinci', 'Rome', 'Italy');
INSERT INTO Airports (AirportName, City, Country) VALUES ('George Bush Intercontinental', 'Houston', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Sea-Tac', 'Seattle', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Orlando', 'Orlando', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('McCarran', 'Las Vegas', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Charlotte Douglas', 'Charlotte', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Phoenix Sky Harbor', 'Phoenix', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Miami', 'Miami', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Newark Liberty', 'Newark', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('John F. Kennedy', 'New York', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('San Francisco', 'San Francisco', 'USA');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Zurich', 'Zurich', 'Switzerland');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Copenhagen', 'Copenhagen', 'Denmark');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Oslo Gardermoen', 'Oslo', 'Norway');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Stockholm Arlanda', 'Stockholm', 'Sweden');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Helsinki', 'Helsinki', 'Finland');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Vienna', 'Vienna', 'Austria');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Lisbon', 'Lisbon', 'Portugal');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Athens', 'Athens', 'Greece');
INSERT INTO Airports (AirportName, City, Country) VALUES ('Dublin', 'Dublin', 'Ireland');
INSERT INTO Airports (AirportName, City, Country) VALUES ('King Abdulaziz', 'Jeddah', 'Saudi Arabia');
INSERT INTO Airports (AirportName, City, Country) VALUES ('King Khalid', 'Riyadh', 'Saudi Arabia');

-- Inserting Flights
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-569-1', 24, 33, '2026-03-21 18:10:00', '2026-03-21 19:44:00', 333.40);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-638-2', 19, 27, '2026-03-20 15:20:00', '2026-03-20 17:03:00', 469.30);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-321-3', 29, 45, '2026-03-19 12:45:00', '2026-03-19 16:59:00', 158.65);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-517-4', 14, 21, '2026-03-27 06:00:00', '2026-03-27 08:01:00', 509.94);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-927-5', 2, 9, '2026-03-25 15:20:00', '2026-03-25 18:38:00', 440.84);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-785-6', 17, 28, '2026-03-26 06:00:00', '2026-03-26 10:36:00', 333.83);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-266-7', 19, 37, '2026-03-17 18:10:00', '2026-03-17 23:32:00', 189.25);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-975-8', 35, 29, '2026-03-14 12:45:00', '2026-03-14 15:52:00', 222.66);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-652-9', 13, 40, '2026-03-12 09:30:00', '2026-03-12 14:24:00', 482.44);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-439-10', 38, 1, '2026-03-31 15:20:00', '2026-03-31 16:38:00', 152.66);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-929-11', 36, 34, '2026-03-14 06:00:00', '2026-03-14 09:26:00', 300.81);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-447-12', 44, 21, '2026-03-14 15:20:00', '2026-03-14 17:30:00', 531.87);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-364-13', 31, 18, '2026-03-17 06:00:00', '2026-03-17 08:41:00', 463.84);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-552-14', 24, 18, '2026-03-11 21:00:00', '2026-03-12 01:31:00', 146.29);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-623-15', 44, 6, '2026-04-01 06:00:00', '2026-04-01 10:11:00', 417.76);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-249-16', 2, 5, '2026-03-17 21:00:00', '2026-03-17 22:27:00', 433.57);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-154-17', 46, 36, '2026-03-07 18:10:00', '2026-03-07 22:28:00', 377.40);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-964-18', 24, 49, '2026-03-13 15:20:00', '2026-03-13 16:36:00', 524.34);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-481-19', 50, 8, '2026-04-03 06:00:00', '2026-04-03 08:29:00', 137.62);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-326-20', 38, 46, '2026-03-25 21:00:00', '2026-03-25 22:00:00', 306.94);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-452-21', 34, 4, '2026-03-28 06:00:00', '2026-03-28 10:06:00', 267.86);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-588-22', 36, 2, '2026-04-03 15:20:00', '2026-04-03 19:32:00', 250.65);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-931-23', 42, 12, '2026-03-29 15:20:00', '2026-03-29 17:45:00', 378.54);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-523-24', 26, 23, '2026-04-02 18:10:00', '2026-04-02 19:36:00', 424.97);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-502-25', 12, 19, '2026-03-25 06:00:00', '2026-03-25 11:20:00', 260.77);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-365-26', 45, 6, '2026-03-27 15:20:00', '2026-03-27 17:27:00', 311.56);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-772-27', 45, 9, '2026-03-10 21:00:00', '2026-03-11 00:41:00', 381.40);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-650-28', 24, 22, '2026-03-26 18:10:00', '2026-03-26 21:14:00', 264.10);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-452-29', 11, 12, '2026-03-26 21:00:00', '2026-03-26 23:16:00', 455.94);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-505-30', 28, 36, '2026-03-20 09:30:00', '2026-03-20 13:24:00', 162.54);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-182-31', 28, 11, '2026-03-22 15:20:00', '2026-03-22 19:59:00', 399.84);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-985-32', 7, 32, '2026-03-16 09:30:00', '2026-03-16 15:04:00', 460.62);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-612-33', 43, 1, '2026-03-19 12:45:00', '2026-03-19 14:18:00', 333.70);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-381-34', 20, 19, '2026-03-30 12:45:00', '2026-03-30 16:25:00', 175.59);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-735-35', 52, 51, '2026-03-24 12:45:00', '2026-03-24 17:36:00', 265.30);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-181-36', 43, 32, '2026-03-14 06:00:00', '2026-03-14 07:06:00', 503.71);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-569-37', 3, 29, '2026-04-05 09:30:00', '2026-04-05 14:19:00', 326.41);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-545-38', 32, 23, '2026-03-07 12:45:00', '2026-03-07 14:29:00', 568.05);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-619-39', 22, 28, '2026-04-02 09:30:00', '2026-04-02 11:55:00', 386.21);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-532-40', 42, 20, '2026-03-11 21:00:00', '2026-03-11 22:48:00', 470.47);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-643-41', 30, 27, '2026-04-05 06:00:00', '2026-04-05 10:35:00', 179.84);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-677-42', 5, 41, '2026-03-29 21:00:00', '2026-03-30 00:54:00', 329.10);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-917-43', 11, 45, '2026-03-17 18:10:00', '2026-03-18 00:07:00', 445.34);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-695-44', 46, 21, '2026-03-07 18:10:00', '2026-03-07 23:54:00', 342.42);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-457-45', 17, 35, '2026-03-11 18:10:00', '2026-03-11 21:16:00', 124.10);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-858-46', 1, 43, '2026-03-13 15:20:00', '2026-03-13 16:30:00', 474.12);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-851-47', 48, 17, '2026-03-25 15:20:00', '2026-03-25 17:30:00', 559.94);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-274-48', 39, 44, '2026-03-25 15:20:00', '2026-03-25 21:13:00', 313.08);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-529-49', 24, 15, '2026-03-12 09:30:00', '2026-03-12 14:45:00', 217.06);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-803-50', 30, 34, '2026-03-10 12:45:00', '2026-03-10 16:00:00', 261.82);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-176-51', 42, 25, '2026-03-15 06:00:00', '2026-03-15 07:18:00', 174.59);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-970-52', 10, 22, '2026-03-17 18:10:00', '2026-03-17 21:42:00', 315.87);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-157-53', 15, 18, '2026-03-07 06:00:00', '2026-03-07 07:03:00', 231.57);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-214-54', 49, 38, '2026-03-11 18:10:00', '2026-03-11 20:08:00', 375.27);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-412-55', 10, 44, '2026-04-03 15:20:00', '2026-04-03 17:18:00', 276.50);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-839-56', 32, 6, '2026-03-24 06:00:00', '2026-03-24 07:33:00', 489.92);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-701-57', 32, 24, '2026-03-20 15:20:00', '2026-03-20 17:39:00', 243.29);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-749-58', 37, 45, '2026-03-27 12:45:00', '2026-03-27 15:37:00', 446.95);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-880-59', 18, 12, '2026-03-08 09:30:00', '2026-03-08 10:33:00', 518.50);
INSERT INTO Flights (FlightNumber, SourceAirportID, DestinationAirportID, DepartureTime, ArrivalTime, BaseFare) VALUES ('FL-443-60', 26, 36, '2026-03-13 18:10:00', '2026-03-13 22:01:00', 347.78);

-- Inserting Classes
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 1', 0.97);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 2', 1.49);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 3', 2.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 4', 4.02);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 5', 0.96);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 6', 1.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 7', 2.48);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 8', 3.99);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 9', 1.04);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 10', 1.51);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 11', 2.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 12', 4.02);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 13', 1.05);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 14', 1.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 15', 2.50);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 16', 3.96);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 17', 0.97);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 18', 1.53);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 19', 2.55);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 20', 3.95);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 21', 0.99);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 22', 1.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 23', 2.52);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 24', 4.01);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 25', 1.03);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 26', 1.55);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 27', 2.48);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 28', 3.96);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 29', 1.04);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 30', 1.52);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 31', 2.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 32', 3.97);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 33', 1.03);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 34', 1.48);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 35', 2.49);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 36', 4.03);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 37', 1.03);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 38', 1.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 39', 2.46);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 40', 4.03);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 41', 1.03);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 42', 1.53);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 43', 2.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 44', 3.95);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 45', 1.04);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 46', 1.49);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 47', 2.50);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 48', 4.03);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 49', 0.99);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 50', 1.50);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 51', 2.50);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 52', 4.04);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 53', 1.00);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 54', 1.53);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 55', 2.47);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 56', 4.02);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Economy - Tier 57', 1.00);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Premium Economy - Tier 58', 1.48);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('Business - Tier 59', 2.45);
INSERT INTO Classes (ClassType, PriceMultiplier) VALUES ('First Class - Tier 60', 3.98);

-- Inserting Bookings (status Pending initially, some will become Confirmed when Payment is made)
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (33, 47, 13, '2026-02-20 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (17, 36, 27, '2026-02-09 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (48, 7, 9, '2026-02-21 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (18, 28, 14, '2026-03-02 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (18, 38, 4, '2026-02-06 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (2, 55, 29, '2026-02-18 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (52, 11, 44, '2026-02-10 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (23, 52, 13, '2026-02-27 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (28, 32, 55, '2026-02-08 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (37, 18, 1, '2026-03-05 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (49, 53, 23, '2026-02-19 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (57, 50, 32, '2026-02-26 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (50, 20, 36, '2026-02-23 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (2, 17, 48, '2026-03-01 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (28, 56, 46, '2026-02-23 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (5, 7, 59, '2026-02-10 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (51, 53, 49, '2026-03-02 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (12, 56, 9, '2026-02-11 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (30, 9, 38, '2026-02-26 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (51, 30, 30, '2026-02-18 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (57, 16, 14, '2026-02-26 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (2, 11, 7, '2026-02-26 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (32, 24, 60, '2026-02-27 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (53, 35, 40, '2026-02-07 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (47, 40, 21, '2026-02-08 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (4, 39, 8, '2026-02-15 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (54, 28, 25, '2026-02-23 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (44, 7, 50, '2026-02-21 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (24, 13, 8, '2026-02-17 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (56, 2, 24, '2026-02-13 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (38, 60, 29, '2026-03-02 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (26, 32, 45, '2026-03-02 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (33, 52, 1, '2026-02-11 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (22, 40, 12, '2026-02-07 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (45, 55, 7, '2026-02-09 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (43, 51, 12, '2026-03-01 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (7, 24, 33, '2026-02-24 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (51, 35, 14, '2026-02-22 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (57, 13, 46, '2026-02-18 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (27, 35, 16, '2026-02-25 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (18, 8, 37, '2026-03-03 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (26, 59, 52, '2026-02-18 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (55, 51, 41, '2026-02-23 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (15, 26, 8, '2026-02-22 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (54, 52, 26, '2026-02-16 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (14, 47, 50, '2026-02-24 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (23, 28, 40, '2026-02-05 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (27, 26, 4, '2026-02-20 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (53, 26, 57, '2026-02-22 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (36, 14, 42, '2026-02-23 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (51, 6, 58, '2026-02-08 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (25, 5, 28, '2026-02-28 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (43, 18, 17, '2026-02-24 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (59, 24, 42, '2026-02-19 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (57, 16, 33, '2026-03-03 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (22, 36, 26, '2026-02-10 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (59, 28, 31, '2026-03-05 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (14, 20, 46, '2026-02-28 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (37, 27, 4, '2026-02-28 18:34:20');
INSERT INTO Bookings (PassengerID, FlightID, ClassID, BookingDate) VALUES (17, 16, 18, '2026-02-05 18:34:20');

-- Inserting Payments (Triggers 'Confirmed' status in Bookings)
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (1, '2026-03-06 18:34:20', 'Net Banking', 784.75);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (2, '2026-03-06 18:34:20', 'Debit Card', 376.69);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (3, '2026-03-05 18:34:20', 'Credit Card', 375.52);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (4, '2026-03-01 18:34:20', 'Debit Card', 440.27);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (5, '2026-03-02 18:34:20', 'UPI', 551.28);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (6, '2026-03-06 18:34:20', 'Net Banking', 344.22);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (7, '2026-03-05 18:34:20', 'Net Banking', 755.19);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (8, '2026-03-02 18:34:20', 'Credit Card', 541.78);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (9, '2026-03-06 18:34:20', 'Debit Card', 949.66);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (10, '2026-03-05 18:34:20', 'Net Banking', 543.95);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (11, '2026-03-03 18:34:20', 'Net Banking', 971.13);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (12, '2026-03-05 18:34:20', 'Credit Card', 817.02);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (13, '2026-03-05 18:34:20', 'Net Banking', 440.21);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (14, '2026-03-03 18:34:20', 'Debit Card', 830.29);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (15, '2026-03-03 18:34:20', 'Debit Card', 377.12);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (16, '2026-03-05 18:34:20', 'Credit Card', 780.04);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (17, '2026-03-05 18:34:20', 'Debit Card', 159.95);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (18, '2026-03-03 18:34:20', 'Net Banking', 986.51);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (19, '2026-03-04 18:34:20', 'UPI', 238.52);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (20, '2026-03-01 18:34:20', 'Debit Card', 866.92);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (21, '2026-03-03 18:34:20', 'UPI', 785.96);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (22, '2026-03-03 18:34:20', 'Debit Card', 254.09);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (23, '2026-03-01 18:34:20', 'Debit Card', 292.80);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (24, '2026-03-04 18:34:20', 'Credit Card', 536.77);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (25, '2026-03-03 18:34:20', 'UPI', 603.90);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (26, '2026-03-05 18:34:20', 'UPI', 309.13);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (27, '2026-03-01 18:34:20', 'Credit Card', 643.23);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (28, '2026-03-01 18:34:20', 'UPI', 554.84);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (29, '2026-03-03 18:34:20', 'Credit Card', 361.59);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (30, '2026-03-01 18:34:20', 'UPI', 180.19);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (31, '2026-03-01 18:34:20', 'UPI', 131.97);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (32, '2026-03-05 18:34:20', 'Net Banking', 277.68);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (33, '2026-03-01 18:34:20', 'UPI', 978.05);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (34, '2026-03-04 18:34:20', 'Net Banking', 216.02);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (35, '2026-03-02 18:34:20', 'UPI', 463.54);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (36, '2026-03-05 18:34:20', 'Net Banking', 692.88);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (37, '2026-03-03 18:34:20', 'Debit Card', 157.24);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (38, '2026-03-06 18:34:20', 'Debit Card', 206.44);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (39, '2026-03-05 18:34:20', 'UPI', 326.70);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (40, '2026-03-01 18:34:20', 'Credit Card', 437.98);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (41, '2026-03-03 18:34:20', 'UPI', 891.68);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (42, '2026-03-01 18:34:20', 'UPI', 169.96);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (43, '2026-03-04 18:34:20', 'UPI', 581.80);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (44, '2026-03-02 18:34:20', 'Debit Card', 246.55);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (45, '2026-03-06 18:34:20', 'Net Banking', 981.61);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (46, '2026-03-02 18:34:20', 'UPI', 610.64);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (47, '2026-03-04 18:34:20', 'Debit Card', 226.95);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (48, '2026-03-06 18:34:20', 'Debit Card', 246.50);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (49, '2026-03-06 18:34:20', 'Debit Card', 393.62);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (50, '2026-03-06 18:34:20', 'Debit Card', 418.20);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (51, '2026-03-04 18:34:20', 'Credit Card', 248.13);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (52, '2026-03-03 18:34:20', 'Credit Card', 128.37);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (53, '2026-03-03 18:34:20', 'Debit Card', 840.24);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (54, '2026-03-05 18:34:20', 'Net Banking', 205.32);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (55, '2026-03-06 18:34:20', 'Credit Card', 594.67);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (56, '2026-03-06 18:34:20', 'Net Banking', 222.67);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (57, '2026-03-02 18:34:20', 'Credit Card', 269.31);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (58, '2026-03-01 18:34:20', 'Net Banking', 447.34);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (59, '2026-03-03 18:34:20', 'UPI', 745.14);
INSERT INTO Payments (BookingID, PaymentDate, PaymentMode, AmountPaid) VALUES (60, '2026-03-02 18:34:20', 'Debit Card', 230.76);

-- Inserting FoodOrders
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (50, 'Wine', 2, 5.31);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (12, 'Fruit Platter', 2, 8.75);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (45, 'Salad', 3, 20.04);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (11, 'Wine', 3, 18.58);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (13, 'Chicken Sandwich', 3, 22.43);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (11, 'Fruit Platter', 1, 20.09);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (17, 'Pasta', 1, 19.77);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (35, 'Wine', 1, 23.42);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (43, 'Salad', 1, 24.54);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (51, 'Fruit Platter', 1, 19.47);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (57, 'Wine', 1, 15.87);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (50, 'Vegetarian Meal', 2, 20.50);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (53, 'Chicken Sandwich', 3, 15.85);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (1, 'Pasta', 2, 21.05);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (21, 'Wine', 2, 6.87);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (14, 'Vegetarian Meal', 2, 24.38);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (18, 'Chicken Sandwich', 3, 7.79);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (9, 'Fruit Platter', 3, 6.17);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (2, 'Salad', 1, 21.76);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (59, 'Vegetarian Meal', 3, 21.31);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (27, 'Pasta', 3, 6.15);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (53, 'Vegetarian Meal', 2, 17.34);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (21, 'Pasta', 3, 23.26);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (22, 'Vegetarian Meal', 1, 12.21);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (14, 'Chicken Sandwich', 3, 22.72);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (49, 'Salad', 3, 5.43);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (51, 'Chicken Sandwich', 3, 21.44);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (15, 'Salad', 3, 22.79);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (15, 'Steak', 1, 21.91);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (25, 'Fruit Platter', 3, 9.42);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (23, 'Steak', 3, 19.06);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (14, 'Vegetarian Meal', 2, 24.07);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (21, 'Chicken Sandwich', 3, 16.93);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (35, 'Wine', 2, 21.47);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (2, 'Salad', 1, 23.45);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (43, 'Salad', 1, 12.11);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (42, 'Pasta', 3, 17.76);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (18, 'Pasta', 3, 12.69);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (57, 'Chicken Sandwich', 3, 8.36);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (28, 'Steak', 3, 6.65);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (56, 'Salad', 1, 14.41);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (25, 'Vegetarian Meal', 3, 6.65);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (22, 'Salad', 1, 21.32);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (46, 'Vegetarian Meal', 2, 8.84);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (34, 'Chicken Sandwich', 2, 5.71);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (51, 'Wine', 2, 11.72);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (53, 'Pasta', 2, 11.96);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (7, 'Salad', 1, 16.48);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (56, 'Pasta', 1, 9.61);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (7, 'Fruit Platter', 3, 20.99);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (45, 'Vegetarian Meal', 1, 14.50);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (29, 'Salad', 2, 8.25);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (55, 'Vegetarian Meal', 3, 14.72);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (41, 'Wine', 3, 5.56);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (41, 'Chicken Sandwich', 1, 14.29);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (16, 'Steak', 3, 11.17);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (30, 'Pasta', 1, 6.56);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (14, 'Wine', 1, 14.50);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (51, 'Vegetarian Meal', 3, 5.72);
INSERT INTO FoodOrders (BookingID, FoodItem, Quantity, Price) VALUES (5, 'Fruit Platter', 2, 15.34);