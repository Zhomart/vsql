// values.v contains logic for the VALUES statement.

module vsql

// A ValuesOperation provides a VALUES derived implicit table.
struct ValuesOperation {
	rows        []RowExpr
	offset      Expr
	correlation Correlation
	params      map[string]Value
mut:
	conn &Connection
}

// TODO(elliotchance): It's important we return a pointer, otherwise there's
//  some weird memory issues where the rows can just disappear sometimes. I
//  suspect this is just immaturity with the garbage collector and the pointer
//  may be removed in the future. Run the test suite a few times and if it
//  passes you're in the clear.
fn new_values_operation(rows []RowExpr, offset Expr, correlation Correlation, mut conn Connection, params map[string]Value) !&ValuesOperation {
	if correlation.columns.len > 0 {
		for row in rows {
			if row.exprs.len != correlation.columns.len {
				return sqlstate_42601('ROW provides the wrong number of columns for the correlation')
			}
		}
	}

	mut new_rows := []RowExpr{}
	for row in rows {
		new_rows << resolve_identifiers(conn, row, conn.catalog().storage.tables)! as RowExpr
	}

	return &ValuesOperation{new_rows, offset, correlation, params, conn}
}

fn (o &ValuesOperation) str() string {
	mut rows := []string{}
	for row in o.rows {
		rows << row.pstr(o.params)
	}

	return 'VALUES (${o.columns()}) = ${rows.join(', ')}'
}

fn (o &ValuesOperation) columns() Columns {
	if o.correlation.columns.len > 0 {
		mut columns := []Column{}
		for i, column in o.correlation.columns {
			typ := eval_as_type(o.conn, Row{}, o.rows[0].exprs[i], o.params) or { panic(err) }
			columns << Column{
				name: column
				typ: typ
			}
		}

		return columns
	}

	mut columns := []Column{}

	// TODO(elliotchance): All check all exprs are RowExpr AND they have the
	//  right number of columns AND types.
	for i in 1 .. o.rows[0].exprs.len + 1 {
		typ := eval_as_type(o.conn, Row{}, o.rows[0].exprs[i - 1], o.params) or { panic(err) }
		columns << Column{
			name: Identifier{
				sub_entity_name: 'COL${i}'
			}
			typ: typ
		}
	}

	return columns
}

fn (mut o ValuesOperation) execute(_ []Row) ![]Row {
	mut offset := 0
	if o.offset !is NoExpr {
		offset = int((eval_as_value(mut o.conn, Row{}, o.offset, o.params)!).f64_value())
	}

	mut rows := []Row{}
	if offset >= o.rows.len {
		return rows
	}

	for row in o.rows[offset..] {
		rows << eval_row(mut o.conn, Row{
			data: map[string]Value{}
		}, row.exprs, o.params)!
	}

	columns := o.columns()
	if columns.len > 0 {
		for mut row in rows {
			mut data := map[string]Value{}
			for i in 1 .. row.data.len + 1 {
				name := columns[i - 1].name
				data[name.sub_entity_name] = row.data['COL${i}']
			}

			row = Row{
				data: data
			}
		}
	}

	return rows
}
