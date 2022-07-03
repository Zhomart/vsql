VALUES DATE '2022-06-30 21:47:32';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32' is not valid

VALUES DATE '2022-06-30 21:47:32+05:12';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32+05:12' is not valid

VALUES DATE '21:47:32';
-- error 42601: syntax error: DATE '21:47:32' is not valid

VALUES DATE '21:47:32+05:12';
-- error 42601: syntax error: DATE '21:47:32+05:12' is not valid

VALUES DATE '2022-06-30 21:47:32-11:30';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32-11:30' is not valid

VALUES DATE '2022-06-30 00:00:00';
-- error 42601: syntax error: DATE '2022-06-30 00:00:00' is not valid

VALUES DATE '2022-06-30 21:47:32.123';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32.123' is not valid

VALUES DATE '2022-06-30 21:47:32.456000+05:12';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32.456000+05:12' is not valid

VALUES DATE '2022-06-30T21:47:32';
-- error 42601: syntax error: DATE '2022-06-30T21:47:32' is not valid

VALUES DATE 'a2022-06-30 21:47:32';
-- error 42601: syntax error: DATE 'a2022-06-30 21:47:32' is not valid

VALUES DATE '2022-06-30 21:47:32a';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32a' is not valid

VALUES DATE '2022-06-30';
-- COL1: 2022-06-30

VALUES DATE '21:47:32';
-- error 42601: syntax error: DATE '21:47:32' is not valid

VALUES DATE 'FOO BAR';
-- error 42601: syntax error: DATE 'FOO BAR' is not valid

VALUES DATE '2022-06-30 21:47:75';
-- error 42601: syntax error: DATE '2022-06-30 21:47:75' is not valid

VALUES DATE '10000-06-30T21:47:32';
-- error 42601: syntax error: DATE '10000-06-30T21:47:32' is not valid

VALUES DATE '-1-06-30T21:47:32';
-- error 42601: syntax error: DATE '-1-06-30T21:47:32' is not valid

VALUES DATE '2022-06-30 21:47:32+12:00';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32+12:00' is not valid

VALUES DATE '2022-06-30 21:47:32-12:00';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32-12:00' is not valid

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- F1: 2022-06-30
