CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (-32769);
INSERT INTO foo (x) VALUES (-32768);
INSERT INTO foo (x) VALUES (32767);
INSERT INTO foo (x) VALUES (32768);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- X: -32768
-- X: 32767

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS INTEGER) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS REAL) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS DOUBLE PRECISION) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

VALUES CAST(123 AS SMALLINT) + 53.7;
-- COL1: 176

VALUES 53.7 + CAST(123 AS SMALLINT);
-- COL1: 176

VALUES CAST(30000 AS SMALLINT) + 20000.7;
-- error 22003: numeric value out of range

VALUES 30000.7 + CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(123 AS SMALLINT) - 53.7;
-- COL1: 69

VALUES 53.7 - CAST(123 AS SMALLINT);
-- COL1: -69

VALUES CAST(-30000 AS SMALLINT) - 20000.7;
-- error 22003: numeric value out of range

VALUES -30000.7 - CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(123 AS SMALLINT) * 53.7;
-- COL1: 6605

VALUES -53.7 * CAST(123 AS SMALLINT);
-- COL1: -6605

VALUES CAST(-30000 AS SMALLINT) * 20000.7;
-- error 22003: numeric value out of range

VALUES -30000.7 * CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(123 AS SMALLINT) / 53.7;
-- COL1: 2

VALUES -123.7 / CAST(53 AS SMALLINT);
-- COL1: -2

VALUES CAST(-30000 AS SMALLINT) / 0.02;
-- error 22003: numeric value out of range

VALUES -90000.7 / CAST(3.2 AS SMALLINT);
-- COL1: -30000

VALUES CAST(-30000 AS SMALLINT) / 0;
-- error 22012: division by zero

VALUES -90000 / CAST(0.1 AS SMALLINT);
-- error 22012: division by zero
