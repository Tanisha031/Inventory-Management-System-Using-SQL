-- -----------------------------------------------------
-- INVENTORY MANAGEMENT SYSTEM (SQL) - READY FOR DEMO
-- -----------------------------------------------------

-- 1. DATABASE SETUP
DROP DATABASE IF EXISTS InventoryManagementDB;
CREATE DATABASE InventoryManagementDB;
USE InventoryManagementDB;

-- -----------------------------------------------------
-- 2. TABLE CREATION
-- -----------------------------------------------------

-- Suppliers Table
CREATE TABLE Suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL UNIQUE,
    contact_person VARCHAR(100),
    phone_number VARCHAR(15),
    email VARCHAR(100) UNIQUE,
    address VARCHAR(255)
);

-- Products Table
CREATE TABLE Products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL UNIQUE,
    sku VARCHAR(50) UNIQUE,
    description TEXT,
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    current_stock INT NOT NULL DEFAULT 0 CHECK (current_stock >= 0),
    reorder_point INT NOT NULL DEFAULT 10 CHECK (reorder_point >= 0),
    supplier_id INT,
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

-- PurchaseOrders Table
CREATE TABLE PurchaseOrders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    order_date DATE NOT NULL,
    expected_delivery_date DATE,
    status ENUM('Pending','Shipped','Received','Cancelled') NOT NULL DEFAULT 'Pending',
    total_amount DECIMAL(10,2) CHECK (total_amount >= 0),
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

-- OrderDetails Table
CREATE TABLE OrderDetails (
    order_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
    purchase_price DECIMAL(10,2) NOT NULL CHECK (purchase_price >= 0),
    FOREIGN KEY (order_id) REFERENCES PurchaseOrders(order_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id),
    UNIQUE KEY unique_order_product (order_id, product_id)
);

-- Transactions Table
CREATE TABLE Transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    transaction_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transaction_type ENUM('IN','OUT','ADJUSTMENT') NOT NULL,
    quantity INT NOT NULL,
    reference_id INT,
    notes VARCHAR(255),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- -----------------------------------------------------
-- 3. TRIGGERS FOR AUTOMATIC STOCK UPDATE
-- -----------------------------------------------------

DELIMITER //

-- Trigger for IN or ADJUSTMENT
CREATE TRIGGER trg_update_stock_after_inbound
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'IN' OR NEW.transaction_type = 'ADJUSTMENT' THEN
        UPDATE Products
        SET current_stock = current_stock + NEW.quantity
        WHERE product_id = NEW.product_id;
    END IF;
END;
//

-- Trigger for OUT
CREATE TRIGGER trg_update_stock_after_outbound
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'OUT' THEN
        UPDATE Products
        SET current_stock = current_stock - NEW.quantity
        WHERE product_id = NEW.product_id;
    END IF;
END;
//

DELIMITER ;

-- -----------------------------------------------------
-- 4. VIEWS FOR QUICK ACCESS
-- -----------------------------------------------------

-- Low Stock Alerts
CREATE VIEW LowStockAlerts AS
SELECT
    p.product_id,
    p.product_name,
    p.sku,
    p.current_stock,
    p.reorder_point,
    s.supplier_name
FROM Products p
JOIN Suppliers s ON p.supplier_id = s.supplier_id
WHERE p.current_stock <= p.reorder_point
ORDER BY p.current_stock ASC;

-- Inventory Value
CREATE VIEW InventoryValue AS
SELECT
    SUM(p.current_stock * p.unit_price) AS total_inventory_value,
    SUM(p.current_stock) AS total_units_in_stock
FROM Products p;

-- -----------------------------------------------------
-- 5. SAMPLE DATA (Designed for demo)
-- -----------------------------------------------------

-- Suppliers
INSERT INTO Suppliers (supplier_name, contact_person, phone_number, email, address) VALUES
('Tech Supplies Corp','Alice Johnson','555-1001','alice.j@techcorp.com','123 Tech St'),
('Office Goods Inc','Bob Smith','555-2002','bob.s@officegoods.net','456 Office Rd');

-- Products
INSERT INTO Products (product_name, sku, unit_price, current_stock, reorder_point, supplier_id) VALUES
('Laptop Pro 15','LP15-001',1200.00,45,15,1),
('Wireless Mouse X1','WMX-202',25.50,140,50,1),
('A4 Printer Paper','APP-100',5.00,300,100,2),
('Ink Cartridge C3','ICC-303',45.99,10,20,2), -- This will trigger LowStockAlerts
('USB Keyboard K2','UKB-204',20.00,5,10,1); -- Another low stock item

-- Purchase Orders
INSERT INTO PurchaseOrders (supplier_id, order_date, status) VALUES
(1,'2025-11-01','Received'),
(2,'2025-11-05','Received');

-- Order Details
INSERT INTO OrderDetails (order_id, product_id, quantity_ordered, purchase_price) VALUES
(1,1,50,1150.00),
(1,2,150,24.00),
(2,3,300,4.50),
(2,4,30,40.00),
(1,5,10,18.00);

-- Transactions (Initial stock setup)
INSERT INTO Transactions (product_id, transaction_type, quantity, notes) VALUES
(1,'ADJUSTMENT',45,'Initial stock entry'),
(2,'ADJUSTMENT',140,'Initial stock entry'),
(3,'ADJUSTMENT',300,'Initial stock entry'),
(4,'ADJUSTMENT',10,'Initial stock entry'),
(5,'ADJUSTMENT',5,'Initial stock entry');

-- Sample OUT Transactions (sales)
INSERT INTO Transactions (product_id, transaction_type, quantity, notes) VALUES
(1,'OUT',5,'Sale to Customer A'),
(2,'OUT',10,'Sale to Customer B');

-- Sample IN Transaction (restocking)
INSERT INTO Transactions (product_id, transaction_type, quantity, reference_id, notes) VALUES
(4,'IN',20,2,'Received remainder of PO 2');

-- -----------------------------------------------------
-- 6. QUERIES 
-- -----------------------------------------------------

-- Query 1: All Products & Stock
SELECT product_id, product_name, sku, current_stock, reorder_point FROM Products;

-- Query 2: Low Stock Alerts
SELECT * FROM LowStockAlerts;

-- Query 3: Total Inventory Value
SELECT * FROM InventoryValue;

-- Query 4: Supplier Details
SELECT * FROM Suppliers;

-- Query 5: Purchase Orders with Details
SELECT po.order_id, po.order_date, po.status, p.product_name, od.quantity_ordered, od.purchase_price
FROM PurchaseOrders po
JOIN OrderDetails od ON po.order_id = od.order_id
JOIN Products p ON od.product_id = p.product_id
ORDER BY po.order_date DESC;

-- Query 6: Transactions Log
SELECT transaction_id, product_id, (SELECT product_name FROM Products WHERE product_id = Transactions.product_id) AS product_name,
transaction_type, quantity, transaction_date, notes
FROM Transactions
ORDER BY transaction_date DESC;

-- Query 7: Stock After Transactions
SELECT product_name, current_stock FROM Products;

-- Query 8: Products by Supplier
SELECT s.supplier_name, p.product_name, p.current_stock
FROM Products p
JOIN Suppliers s ON p.supplier_id = s.supplier_id
ORDER BY s.supplier_name, p.product_name;

-- Query 9: Reorder Status Highlight
SELECT product_name, current_stock, reorder_point,
CASE WHEN current_stock <= reorder_point THEN 'Reorder Needed' ELSE 'Sufficient Stock' END AS status
FROM Products;

UPDATE PurchaseOrders SET status = 'Pending' WHERE order_id = 1;
UPDATE PurchaseOrders SET status = 'Shipped' WHERE order_id = 2;

-- Query 10: Incoming Purchase Orders Summary
SELECT po.order_id, po.status, SUM(od.quantity_ordered) AS total_items_ordered
FROM PurchaseOrders po
JOIN OrderDetails od ON po.order_id = od.order_id
WHERE po.status IN ('Pending','Shipped')
GROUP BY po.order_id, po.status;


