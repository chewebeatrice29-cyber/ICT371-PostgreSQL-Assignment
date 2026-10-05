-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- Student Number: 202404114

DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    dispensing_id SERIAL PRIMARY KEY,
    medicine_id INTEGER REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL,
    dispensing_status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol', 50),
('Amoxicillin', 8),
('Ibuprofen', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM medicines LOOP
        IF r.stock_quantity = 0 THEN
            RAISE NOTICE '%: Out of stock', r.medicine_name;
        ELSIF r.stock_quantity <= 10 THEN
            RAISE NOTICE '%: Low on stock', r.medicine_name;
        ELSE
            RAISE NOTICE '%: Sufficiently stocked', r.medicine_name;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock review day %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection %', i;
    END LOOP;
END $$;

-- 4. Dispense procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Dispensing quantity must be greater than zero';
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine ID % does not exist', p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %',
            v_stock, p_quantity;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records
        (medicine_id, student_number, quantity, dispensing_status)
    VALUES
        (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

    RAISE NOTICE 'Medicine dispensed successfully';
END;
$$;

-- 5. Two valid quantities and one exceeding stock
CALL dispense_medicine(1, '202404114', 10);
CALL dispense_medicine(2, '202400101', 3);

DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(2, '202400102', 20);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed dispensing: %', SQLERRM;
    END;
END $$;

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. Reverse dispensing procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_dispensing_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT medicine_id, quantity, dispensing_status
    INTO v_medicine_id, v_quantity, v_status
    FROM dispensing_records
    WHERE dispensing_id = p_dispensing_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record % does not exist', p_dispensing_id;
    END IF;

    IF v_status = 'DISPENSED' THEN
        UPDATE medicines
        SET stock_quantity = stock_quantity + v_quantity
        WHERE medicine_id = v_medicine_id;

        UPDATE dispensing_records
        SET dispensing_status = 'REVERSED'
        WHERE dispensing_id = p_dispensing_id;

        RAISE NOTICE 'Dispensing reversed successfully';
    ELSE
        RAISE NOTICE 'Record already reversed. Stock not restored again.';
    END IF;
END;
$$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- 7. Explicit cursor
DO $$
DECLARE
    medicine_cursor CURSOR FOR
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity < 10;
    v_medicine RECORD;
BEGIN
    OPEN medicine_cursor;
    LOOP
        FETCH medicine_cursor INTO v_medicine;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock - ID: %, Medicine: %, Stock: %',
            v_medicine.medicine_id, v_medicine.medicine_name,
            v_medicine.stock_quantity;
    END LOOP;
    CLOSE medicine_cursor;
END $$;

-- 8. Negative dispensing quantity exception
DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(1, '202404114', -2);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY dispensing_id;
