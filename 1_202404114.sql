-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans
-- Student Number: 202404114

DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INTEGER NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(book_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL,
    loan_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 5),
('Computer Networks', 2),
('Software Engineering', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM books LOOP
        IF r.available_copies = 0 THEN
            RAISE NOTICE '%: Unavailable', r.title;
        ELSIF r.available_copies <= 2 THEN
            RAISE NOTICE '%: Low on copies', r.title;
        ELSE
            RAISE NOTICE '%: Sufficiently stocked', r.title;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number %', i;
    END LOOP;
END $$;

-- 4. Borrow procedure
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: quantity must be greater than zero';
    END IF;

    SELECT available_copies INTO v_available
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book ID % does not exist', p_book_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE EXCEPTION 'Insufficient copies. Available: %, Requested: %',
            v_available, p_quantity;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans (book_id, student_number, quantity, loan_status)
    VALUES (p_book_id, p_student_number, p_quantity, 'ACTIVE');

    RAISE NOTICE 'Loan recorded successfully';
END;
$$;

-- 5. Two valid loans and one exceeding request
CALL borrow_book(1, '202404114', 2);
CALL borrow_book(2, '202400101', 1);

DO $$
BEGIN
    BEGIN
        CALL borrow_book(2, '202400102', 5);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed loan: %', SQLERRM;
    END;
END $$;

SELECT * FROM books;
SELECT * FROM book_loans;

-- 6. Return procedure
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT book_id, quantity, loan_status
    INTO v_book_id, v_quantity, v_status
    FROM book_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan ID % does not exist', p_loan_id;
    END IF;

    IF v_status = 'ACTIVE' THEN
        UPDATE books
        SET available_copies = available_copies + v_quantity
        WHERE book_id = v_book_id;

        UPDATE book_loans
        SET loan_status = 'RETURNED'
        WHERE loan_id = p_loan_id;

        RAISE NOTICE 'Loan % returned successfully', p_loan_id;
    ELSE
        RAISE NOTICE 'Loan % has already been returned. No stock restored.', p_loan_id;
    END IF;
END;
$$;

CALL return_book(1);
CALL return_book(1);

-- 7. Explicit cursor
DO $$
DECLARE
    book_cursor CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books
        WHERE available_copies <= 2;
    v_book RECORD;
BEGIN
    OPEN book_cursor;
    LOOP
        FETCH book_cursor INTO v_book;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few copies - ID: %, Title: %, Copies: %',
            v_book.book_id, v_book.title, v_book.available_copies;
    END LOOP;
    CLOSE book_cursor;
END $$;

-- 8. Zero-copy exception
DO $$
BEGIN
    BEGIN
        CALL borrow_book(1, '202404114', 0);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
