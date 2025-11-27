#!/bin/bash
set -euo pipefail

# Create namespace
kubectl create ns mysql

# Create a directory for MySQL data on the node
ssh node01 "mkdir -p /mnt/mysql-data"

# Create a PersistentVolume with Retain policy (simulating existing data)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv-retain
  labels:
    type: local
spec:
  storageClassName: ""
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/mnt/mysql-data"
    type: "DirectoryOrCreate" 
EOF


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: mysql
spec:
  storageClassName: ""
  volumeName: mysql-pv-retain
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Mi
EOF


sleep 5

kubectl delete pvc mysql-pvc -n mysql


# Create some dummy data to simulate existing database files
ssh node01

cat <<EOF > /mnt/mysql-data/movie-booking.sql
-- Movie booking sample MySQL dump
-- Charset and engine
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS booking_seats;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS shows;
DROP TABLE IF EXISTS seats;
DROP TABLE IF EXISTS screens;
DROP TABLE IF EXISTS theaters;
DROP TABLE IF EXISTS movies;
DROP TABLE IF EXISTS users;

-- Users
CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Movies
CREATE TABLE movies (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  duration_minutes INT UNSIGNED NOT NULL,
  language VARCHAR(50),
  rating VARCHAR(10), -- e.g. PG-13
  release_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Theaters
CREATE TABLE theaters (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  address VARCHAR(500),
  city VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Screens (auditoriums)
CREATE TABLE screens (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  theater_id INT UNSIGNED NOT NULL,
  name VARCHAR(100) NOT NULL, -- e.g. Screen 1
  total_seats INT UNSIGNED DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (theater_id) REFERENCES theaters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seats (per screen)
CREATE TABLE seats (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  screen_id INT UNSIGNED NOT NULL,
  row_label VARCHAR(4) NOT NULL,
  seat_number INT UNSIGNED NOT NULL,
  seat_code VARCHAR(10) NOT NULL, -- e.g. A1
  type ENUM('standard','premium','vip') DEFAULT 'standard',
  UNIQUE(screen_id, seat_code),
  FOREIGN KEY (screen_id) REFERENCES screens(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Shows (a movie playing on a screen at a time)
CREATE TABLE shows (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  movie_id INT UNSIGNED NOT NULL,
  screen_id INT UNSIGNED NOT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  base_price DECIMAL(8,2) NOT NULL,
  language VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (movie_id) REFERENCES movies(id) ON DELETE CASCADE,
  FOREIGN KEY (screen_id) REFERENCES screens(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Bookings
CREATE TABLE bookings (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  show_id INT UNSIGNED NOT NULL,
  booking_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  total_amount DECIMAL(9,2) NOT NULL,
  status ENUM('pending','confirmed','cancelled','refunded') DEFAULT 'pending',
  notes TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (show_id) REFERENCES shows(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Booking seats (one row per seat in a booking)
CREATE TABLE booking_seats (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id INT UNSIGNED NOT NULL,
  seat_id INT UNSIGNED NOT NULL,
  price DECIMAL(8,2) NOT NULL,
  CONSTRAINT uq_booking_seat UNIQUE(booking_id, seat_id),
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
  FOREIGN KEY (seat_id) REFERENCES seats(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Payments
CREATE TABLE payments (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id INT UNSIGNED NOT NULL,
  paid_amount DECIMAL(9,2) NOT NULL,
  payment_method ENUM('card','wallet','upi','cash') DEFAULT 'card',
  payment_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  transaction_ref VARCHAR(255),
  status ENUM('success','failed','pending') DEFAULT 'success',
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Sample data

-- users
INSERT INTO users (email,name,phone) VALUES
('alice@example.com','Alice Sharma','+919800000001'),
('bob@example.com','Bob Mehta','+919800000002'),
('carol@example.com','Carol Singh','+919800000003');

-- movies
INSERT INTO movies (title,duration_minutes,language,rating,release_date) VALUES
('The Lost City',120,'English','PG-13','2023-05-05'),
('Midnight Heist',98,'Hindi','UA','2024-11-08'),
('Galactic Drift',142,'English','U','2025-06-20'),
('Silent River',110,'Tamil','UA','2024-02-14'),
('Comedy Nights',125,'Hindi','U','2025-01-20');

-- theaters
INSERT INTO theaters (name,address,city) VALUES
('Prism Multiplex','12 MG Road, Near Central Park','Mumbai'),
('CineSquare','Plot 45, Broadway Avenue','Bengaluru');

-- screens
INSERT INTO screens (theater_id,name,total_seats) VALUES
(1,'Screen 1',30),
(1,'Screen 2',40),
(2,'IMAX Screen',50);

-- seats - small sample seat layout for screens (A1..A10, B1..B10)
-- Screen 1 seats
INSERT INTO seats (screen_id,row_label,seat_number,seat_code,type) VALUES
(1,'A',1,'A1','standard'),(1,'A',2,'A2','standard'),(1,'A',3,'A3','standard'),(1,'A',4,'A4','standard'),(1,'A',5,'A5','standard'),
(1,'A',6,'A6','standard'),(1,'A',7,'A7','standard'),(1,'A',8,'A8','standard'),(1,'A',9,'A9','standard'),(1,'A',10,'A10','standard'),
(1,'B',1,'B1','premium'),(1,'B',2,'B2','premium'),(1,'B',3,'B3','premium'),(1,'B',4,'B4','premium'),(1,'B',5,'B5','premium');

-- Screen 2 seats
INSERT INTO seats (screen_id,row_label,seat_number,seat_code,type) VALUES
(2,'A',1,'A1','standard'),(2,'A',2,'A2','standard'),(2,'A',3,'A3','standard'),(2,'A',4,'A4','standard'),(2,'A',5,'A5','standard'),
(2,'B',1,'B1','standard'),(2,'B',2,'B2','standard'),(2,'B',3,'B3','standard'),(2,'B',4,'B4','standard'),(2,'B',5,'B5','standard'),
(2,'C',1,'C1','vip'),(2,'C',2,'C2','vip'),(2,'C',3,'C3','vip');

-- IMAX Screen seats (screen_id = 3)
INSERT INTO seats (screen_id,row_label,seat_number,seat_code,type) VALUES
(3,'A',1,'A1','standard'),(3,'A',2,'A2','standard'),(3,'A',3,'A3','standard'),(3,'A',4,'A4','standard'),(3,'A',5,'A5','standard'),
(3,'B',1,'B1','premium'),(3,'B',2,'B2','premium'),(3,'B',3,'B3','premium'),(3,'B',4,'B4','premium'),(3,'B',5,'B5','premium'),
(3,'C',1,'C1','vip'),(3,'C',2,'C2','vip'),(3,'C',3,'C3','vip'),(3,'C',4,'C4','vip');

-- shows (movie playing times)
-- Note: adjust DATETIME values to your timezone/server; these are illustrative
INSERT INTO shows (movie_id,screen_id,start_time,end_time,base_price,language) VALUES
(1,1,'2025-11-27 10:00:00','2025-11-27 12:00:00',250.00,'English'),
(2,1,'2025-11-27 13:00:00','2025-11-27 15:00:00',200.00,'Hindi'),
(3,3,'2025-11-27 18:00:00','2025-11-27 20:22:00',450.00,'English'),
(4,2,'2025-11-27 16:00:00','2025-11-27 17:50:00',220.00,'Tamil'),
(5,2,'2025-11-27 20:00:00','2025-11-27 22:05:00',230.00,'Hindi');

-- bookings (some sample bookings)
INSERT INTO bookings (user_id,show_id,booking_time,total_amount,status,notes) VALUES
(1,1,'2025-11-25 09:12:00',500.00,'confirmed','2 seats front row A'),
(2,3,'2025-11-26 14:05:00',900.00,'confirmed','VIP seats for IMAX'),
(3,5,'2025-11-26 19:40:00',460.00,'pending','couple seats requested');

-- booking_seats (which seats were booked and price paid per seat)
-- booking 1 (Alice) -> show 1, Screen 1, seats A1 and A2
INSERT INTO booking_seats (booking_id,seat_id,price) VALUES
(1,1,250.00),(1,2,250.00);

-- booking 2 (Bob) -> show 3 (IMAX) seats C1 and C2 (vip price)
-- find seat ids in screen 3 for C1 and C2 (we inserted them consecutively above; their ids depend on insert order).
-- For this dump we will reference the seat ids based on insertion order:
-- Seats were inserted in order: screen1: 15 rows (ids 1..15), screen2: 13 rows (ids 16..28), screen3: 13 rows (ids 29..41)
-- Thus screen3 C1 may be id 39 etc. To be robust, assume typical order (if you add rows, adjust accordingly).
INSERT INTO booking_seats (booking_id,seat_id,price) VALUES
(2,39,450.00),(2,40,450.00);

-- booking 3 (Carol) -> show 5 (Screen 2) seats B1 and B2
INSERT INTO booking_seats (booking_id,seat_id,price) VALUES
(3,22,230.00),(3,23,230.00);

-- payments
INSERT INTO payments (booking_id,paid_amount,payment_method,payment_time,transaction_ref,status) VALUES
(1,500.00,'card','2025-11-25 09:13:00','TXN-A1B2C3','success'),
(2,900.00,'upi','2025-11-26 14:06:00','TXN-D4E5F6','success');

-- Basic indexes for faster lookups
ALTER TABLE shows ADD INDEX idx_shows_movie (movie_id), ADD INDEX idx_shows_start (start_time);
ALTER TABLE bookings ADD INDEX idx_bookings_user (user_id), ADD INDEX idx_bookings_show (show_id);
ALTER TABLE seats ADD INDEX idx_seats_screen (screen_id);
ALTER TABLE paymentS ADD INDEX idx_pay_booking (booking_id);

SET FOREIGN_KEY_CHECKS = 1;
EOF

echo "Existing database data preserved" > /mnt/mysql-data/.data_exists

# Wait for PV to be available
sleep 3

ssh controlplane


# Create the MySQL Deployment manifest WITHOUT volume mount (student needs to add it)
cat <<'EOF' > ~/mysql-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: mysql
  labels:
    app: mysql
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
        tier: database
    spec:
      containers:
        - name: mysql
          image: mysql:5.7
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "rootpassword123"
            - name: MYSQL_DATABASE
              value: "customerdb"
          ports:
            - containerPort: 3306
              name: mysql
EOF


k apply -f ~/mysql-deploy.yaml

echo "✅ Setup complete!"
echo ""
echo "📊 Current Status:"
echo "  ✅ PersistentVolume 'mysql-pv-retain' is available with existing data"
echo "  ✅ MySQL Deployment manifest is ready at ~/mysql-deploy.yaml"
echo "  ⚠️  MySQL Deployment has been deleted (simulating the incident)"
echo "  ⚠️  You need to create a PVC and update the Deployment to use it"
echo ""
echo "🎯 Your Mission: Restore MySQL without losing data!"
