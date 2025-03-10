CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (-2147483649);
INSERT INTO foo (x) VALUES (-2147483648);
INSERT INTO foo (x) VALUES (2147483647);
INSERT INTO foo (x) VALUES (2147483648);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- X: -2147483648
-- X: 2147483647

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123456);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS INTEGER) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS REAL) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS DOUBLE PRECISION) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

VALUES CAST(123 AS INTEGER) + 53.7;
-- COL1: 176

VALUES 53.7 + CAST(123 AS INTEGER);
-- COL1: 176

VALUES CAST(500000000 AS INTEGER) + 2000000000.7;
-- error 22003: numeric value out of range

VALUES 500000000.7 + CAST(2000000000 AS INTEGER);
-- error 22003: numeric value out of range

VALUES CAST(123 AS INTEGER) - 53.7;
-- COL1: 69

VALUES 53.7 - CAST(123 AS INTEGER);
-- COL1: -69

VALUES CAST(-2000000000 AS INTEGER) - 500000000.7;
-- error 22003: numeric value out of range

VALUES -500000000.7 - CAST(2000000000 AS INTEGER);
-- error 22003: numeric value out of range

VALUES CAST(123 AS INTEGER) * 53.7;
-- COL1: 6605

VALUES -53.7 * CAST(123 AS INTEGER);
-- COL1: -6605

VALUES CAST(-300000 AS INTEGER) * 200000.7;
-- error 22003: numeric value out of range

VALUES -300000.7 * CAST(200000 AS INTEGER);
-- error 22003: numeric value out of range

VALUES CAST(123 AS INTEGER) / 53.7;
-- COL1: 2

VALUES -123.7 / CAST(53 AS INTEGER);
-- COL1: -2

VALUES CAST(-300000000 AS INTEGER) / 0.02;
-- error 22003: numeric value out of range

VALUES -90000.7 / CAST(3.2 AS INTEGER);
-- COL1: -30000

VALUES CAST(-30000 AS INTEGER) / 0;
-- error 22012: division by zero

VALUES -90000 / CAST(0.1 AS INTEGER);
-- error 22012: division by zero
