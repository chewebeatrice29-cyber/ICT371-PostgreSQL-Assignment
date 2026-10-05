-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 2: Computer Laboratory Reservations
-- Student Number: 202404114

DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INTEGER NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstations INTEGER NOT NULL,
    reservation_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('Database Practical', 20),
('Networking Practical', 5),
('Programming Practical', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM lab_sessions LOOP
        IF r.available_workstations = 0 THEN
            RAISE NOTICE '%: Full', r.session_name;
        ELSIF r.available_workstations <= 5 THEN
            RAISE NOTICE '%: Nearly full', r.session_name;
        ELSE
            RAISE NOTICE '%: Enough workstations', r.session_name;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation check %', i;
    END LOOP;
END $$;

-- 4. Reserve procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INTEGER,
    p_lecturer VARCHAR,
    p_workstations INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid number of workstations';
    END IF;

    SELECT available_workstations INTO v_available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session ID % does not exist', p_session_id;
    END IF;

    IF v_available < p_workstations THEN
        RAISE EXCEPTION 'Insufficient workstations. Available: %, Requested: %',
            v_available, p_workstations;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations
        (session_id, lecturer, workstations, reservation_status)
    VALUES
        (p_session_id, p_lecturer, p_workstations, 'ACTIVE');

    RAISE NOTICE 'Reservation recorded successfully';
END;
$$;

-- 5. Two valid reservations and one exceeding capacity
CALL reserve_workstations(1, 'Mr Kaluba', 5);
CALL reserve_workstations(2, 'Mr Nyirenda', 3);

DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(2, 'Mr Banda', 10);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed reservation: %', SQLERRM;
    END;
END $$;

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. Cancel procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INTEGER;
    v_workstations INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT session_id, workstations, reservation_status
    INTO v_session_id, v_workstations, v_status
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation ID % does not exist', p_reservation_id;
    END IF;

    IF v_status = 'ACTIVE' THEN
        UPDATE lab_sessions
        SET available_workstations = available_workstations + v_workstations
        WHERE session_id = v_session_id;

        UPDATE reservations
        SET reservation_status = 'CANCELLED'
        WHERE reservation_id = p_reservation_id;

        RAISE NOTICE 'Reservation cancelled successfully';
    ELSE
        RAISE NOTICE 'Reservation already cancelled. No workstations released.';
    END IF;
END;
$$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- 7. Explicit cursor
DO $$
DECLARE
    session_cursor CURSOR FOR
        SELECT session_id, session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 5;
    v_session RECORD;
BEGIN
    OPEN session_cursor;
    LOOP
        FETCH session_cursor INTO v_session;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations - ID: %, Session: %, Available: %',
            v_session.session_id, v_session.session_name,
            v_session.available_workstations;
    END LOOP;
    CLOSE session_cursor;
END $$;

-- 8. Zero workstations exception
DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(1, 'Mr Test', 0);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;
