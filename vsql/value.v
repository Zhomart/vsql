// value.v allows values of differnet types to be stored and dealt with at
// runtime and for storage. The Value object is used extensively internally, but
// also is the exposed type when sending results back.

module vsql

import math.big
import strings

// Possible values for a BOOLEAN.
//
// snippet: v.Boolean
pub enum Boolean {
	// These must not be negative values because they are encoded as u8 on disk.
	is_unknown = 0 // same as NULL
	is_false = 1
	is_true = 2
}

// Returns ``TRUE``, ``FALSE`` or ``UNKNOWN``.
//
// snippet: v.Boolean.str
pub fn (b Boolean) str() string {
	return match b {
		.is_false { 'FALSE' }
		.is_true { 'TRUE' }
		.is_unknown { 'UNKNOWN' }
	}
}

// A single value. It contains it's type information in ``typ``.
//
// snippet: v.Value
pub struct Value {
pub mut:
	// TODO(elliotchance): Make these non-mutable.
	// The type of this Value.
	//
	// snippet: v.Value.typ
	typ Type
	// Used by all types (including those that have NULL built in like BOOLEAN).
	//
	// snippet: v.Value.is_null
	is_null bool
	// v packs the actual value. You need to use one of the methods to get the
	// actual value safely.
	v InternalValue
}

union InternalValue {
mut:
	// BOOLEAN
	bool_value Boolean
	// DOUBLE PRECISION and REAL
	f64_value f64
	// BIGINT, INTEGER and SMALLINT
	int_value i64
	// CHARACTER VARYING(n) and CHARACTER(n)
	// NUMERIC
	string_value string
	// DATE
	// TIME(n) WITH TIME ZONE and TIME(n) WITHOUT TIME ZONE
	// TIMESTAMP(n) WITH TIME ZONE and TIMESTAMP(n) WITHOUT TIME ZONE
	time_value Time
}

// new_null_value creates a NULL value of a specific type. In SQL, all NULL
// values need to have a type.
//
// snippet: v.new_null_value
pub fn new_null_value(typ SQLType) Value {
	return Value{
		typ: Type{typ, 0, 0, false}
		is_null: true
	}
}

// new_boolean_value creates a ``TRUE`` or ``FALSE`` value. For ``UNKNOWN`` (the
// ``BOOLEAN`` equivilent of NULL) you will need to use ``new_unknown_value``.
//
// snippet: v.new_boolean_value
pub fn new_boolean_value(b bool) Value {
	return Value{
		typ: Type{.is_boolean, 0, 0, false}
		v: InternalValue{
			bool_value: if b { .is_true } else { .is_false }
		}
	}
}

// new_unknown_value returns an ``UNKNOWN`` value. This is the ``NULL``
// representation of ``BOOLEAN``.
//
// snippet: v.new_unknown_value
pub fn new_unknown_value() Value {
	return Value{
		typ: Type{.is_boolean, 0, 0, false}
		v: InternalValue{
			bool_value: .is_unknown
		}
	}
}

// new_double_precision_value creates a ``DOUBLE PRECISION`` value.
//
// snippet: v.new_double_precision_value
pub fn new_double_precision_value(x f64) Value {
	return Value{
		typ: Type{.is_double_precision, 0, 0, false}
		v: InternalValue{
			f64_value: x
		}
	}
}

// new_integer_value creates an ``INTEGER`` value.
//
// snippet: v.new_integer_value
pub fn new_integer_value(x int) Value {
	return Value{
		typ: Type{.is_integer, 0, 0, false}
		v: InternalValue{
			int_value: x
		}
	}
}

// new_bigint_value creates a ``BIGINT`` value.
//
// snippet: v.new_bigint_value
pub fn new_bigint_value(x i64) Value {
	return Value{
		typ: Type{.is_bigint, 0, 0, false}
		v: InternalValue{
			int_value: x
		}
	}
}

// new_real_value creates a ``REAL`` value.
//
// snippet: v.new_real_value
pub fn new_real_value(x f32) Value {
	return Value{
		typ: Type{.is_real, 0, 0, false}
		v: InternalValue{
			f64_value: x
		}
	}
}

// new_smallint_value creates a ``SMALLINT`` value.
//
// snippet: v.new_smallint_value
pub fn new_smallint_value(x i16) Value {
	return Value{
		typ: Type{.is_smallint, 0, 0, false}
		v: InternalValue{
			int_value: x
		}
	}
}

// new_varchar_value creates a ``CHARACTER VARYING`` value.
//
// snippet: v.new_varchar_value
pub fn new_varchar_value(x string, size int) Value {
	return Value{
		typ: Type{.is_varchar, size, 0, false}
		v: InternalValue{
			string_value: x
		}
	}
}

// new_character_value creates a ``CHARACTER`` value. The value will be padded
// with spaces up to the size specified.
//
// snippet: v.new_character_value
pub fn new_character_value(x string, size int) Value {
	// TODO(elliotchance): Doesn't handle size < x.len

	return Value{
		typ: Type{.is_character, size, 0, false}
		v: InternalValue{
			string_value: x + strings.repeat(` `, size - x.len)
		}
	}
}

// This is not public yet becuase numeric is not officially supported. It's just
// to interally create a typeless numeric value.
fn new_numeric_value(x string) Value {
	return Value{
		// size = 0 means that we don't know the precision yet. It will have to be
		// converted to something else at some point.
		typ: Type{.is_numeric, 0, 0, false}
		v: InternalValue{
			string_value: x
		}
	}
}

// new_timestamp_value creates a ``TIMESTAMP`` value.
//
// snippet: v.new_timestamp_value
pub fn new_timestamp_value(ts string) !Value {
	t := new_timestamp_from_string(ts)!

	return Value{
		typ: t.typ
		v: InternalValue{
			time_value: t
		}
	}
}

// new_time_value creates a ``TIME`` value.
//
// snippet: v.new_time_value
pub fn new_time_value(ts string) !Value {
	t := new_time_from_string(ts)!

	return Value{
		typ: t.typ
		v: InternalValue{
			time_value: t
		}
	}
}

// new_date_value creates a ``DATE`` value.
//
// snippet: v.new_date_value
pub fn new_date_value(ts string) !Value {
	t := new_date_from_string(ts)!

	return Value{
		typ: t.typ
		v: InternalValue{
			time_value: t
		}
	}
}

fn f64_string(x f64) string {
	s := '${x:.6}'.trim('.').split('.')
	if s.len == 1 {
		return s[0]
	}

	return '${s[0]}.${s[1].trim_right('0')}'
}

// as_int() is not safe to use if the value is not numeric. It is used in cases
// where a placeholder might be anythign but needs to be an int (such as for an
// OFFSET).
fn (v Value) as_int() i64 {
	if v.typ.typ == .is_numeric {
		return i64(v.string_value().f64())
	}

	if v.typ.uses_int() {
		return v.int_value()
	}

	return i64(v.f64_value())
}

fn (v Value) as_f64() f64 {
	if v.typ.typ == .is_numeric {
		return v.string_value().f64()
	}

	if v.typ.uses_int() {
		return v.int_value()
	}

	return v.f64_value()
}

fn (v Value) as_numeric() !big.Integer {
	if v.typ.typ == .is_numeric {
		int_part := v.string_value().split('.')[0]

		return big.integer_from_string(int_part)
	}

	if v.typ.uses_int() {
		return big.integer_from_i64(v.int_value())
	}

	return big.integer_from_i64(i64(v.f64_value()))
}

// The string representation of this value. Different types will have different
// formatting.
//
// snippet: v.Value.str
pub fn (v Value) str() string {
	if v.is_null && v.typ.typ != .is_boolean {
		return 'NULL'
	}

	return match v.typ.typ {
		.is_boolean {
			v.bool_value().str()
		}
		.is_double_precision, .is_real {
			f64_string(v.f64_value())
		}
		.is_bigint, .is_integer, .is_smallint {
			v.int_value().str()
		}
		.is_varchar, .is_character, .is_numeric {
			v.string_value()
		}
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			v.time_value().str()
		}
	}
}

// cmp returns for the first argument:
//
//   -1 if v < v2
//    0 if v == v2
//    1 if v > v2
//
// The SQL standard doesn't define if NULLs should be always ordered first or
// last. In vsql, NULLs are always considered to be less than any other non-null
// value. The second return value will be true if either value is NULL.
//
// Or an error if the values are different types (cannot be compared).
//
// snippet: v.Value.cmp
pub fn (v Value) cmp(v2 Value) !(int, bool) {
	if v.is_null && v2.is_null {
		return 0, true
	}

	if v.is_null {
		return -1, true
	}

	if v2.is_null {
		return 1, true
	}

	if v.typ.typ == .is_numeric || v2.typ.typ == .is_numeric {
		return cmp_value(v.as_f64(), v2.as_f64())
	}

	// TODO(elliotchance): BOOLEAN shouldn't be compared this way.
	if v.typ.uses_int() {
		if v2.typ.uses_int() {
			return cmp_value(v.int_value(), v2.int_value())
		}

		if v2.typ.uses_f64() {
			return cmp_value(v.int_value(), v2.f64_value())
		}
	}

	if v.typ.uses_f64() {
		if v2.typ.uses_int() {
			return cmp_value(v.f64_value(), v2.int_value())
		}

		if v2.typ.uses_f64() {
			return cmp_value(v.f64_value(), v2.f64_value())
		}
	}

	if v.typ.uses_string() && v2.typ.uses_string() {
		return cmp_value(v.string_value(), v2.string_value())
	}

	return error('cannot compare ${v.typ} and ${v2.typ}')
}

fn cmp_value[A, B](lhs A, rhs B) (int, bool) {
	if lhs < rhs {
		return -1, false
	}

	if lhs > rhs {
		return 1, false
	}

	return 0, false
}

pub fn (v Value) bool_value() Boolean {
	unsafe {
		return v.v.bool_value
	}
}

pub fn (v Value) int_value() i64 {
	unsafe {
		return v.v.int_value
	}
}

pub fn (v Value) f64_value() f64 {
	unsafe {
		return v.v.f64_value
	}
}

pub fn (v Value) string_value() string {
	unsafe {
		return v.v.string_value
	}
}

pub fn (v Value) time_value() Time {
	unsafe {
		return v.v.time_value
	}
}
