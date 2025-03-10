// planner.v contains the query planner which determines the best strategy for
// finding rows. The plan is built from a stack of operations, where each
// operation may take in rows but will always produce rows that can be fed into
// the next operation. You can find the operations in:
//
//   ExprOperation           eval.v
//   GroupOperation          group.v
//   LimitOperation          limit.v
//   PrimaryKeyOperation     walk.v
//   TableOperation          table.v
//   WhereOperation          where.v
//   ValuesOperation         values.v
//   VirtualTableOperation   virtual_table.v

module vsql

import time

interface PlanOperation {
	str() string
	// A PlanOperation may return different columns from the input rows. This
	// will return the columns (including their types) from the result of this
	// operation. It's safe to invoke this before execute() and invokes multiple
	// times if needed.
	columns() Columns
mut:
	execute(row []Row) ![]Row
}

fn create_plan(stmt Stmt, params map[string]Value, mut c Connection) !Plan {
	match stmt {
		DeleteStmt { return create_delete_plan(stmt, params, mut c) }
		QueryExpression { return create_query_expression_plan(stmt, params, mut c, Correlation{}) }
		UpdateStmt { return create_update_plan(stmt, params, mut c) }
		else { return error('cannot create plan for ${stmt}') }
	}
}

fn create_basic_plan(body SimpleTable, offset Expr, params map[string]Value, mut c Connection, allow_virtual bool, correlation Correlation) !(Plan, map[string]Table) {
	match body {
		SelectStmt {
			return create_select_plan(body, offset, params, mut c, allow_virtual)
		}
		// VALUES
		[]RowExpr {
			mut plan := Plan{}

			plan.operations << new_values_operation(body, NoExpr{}, correlation, mut c,
				params)!

			return plan, map[string]Table{}
		}
	}
}

fn create_select_plan(body SelectStmt, offset Expr, params map[string]Value, mut c Connection, allow_virtual bool) !(Plan, map[string]Table) {
	from_clause := body.table_expression.from_clause

	match from_clause {
		TablePrimary {
			plan, table := create_select_plan_without_join(body, from_clause, offset,
				params, mut c, allow_virtual)!
			return plan, {
				table.name.id(): table
			}
		}
		QualifiedJoin {
			left_table_clause := from_clause.left_table as TablePrimary
			left_plan, left_table := create_select_plan_without_join(body, left_table_clause,
				offset, params, mut c, allow_virtual)!

			right_table_clause := from_clause.right_table as TablePrimary
			right_plan, right_table := create_select_plan_without_join(body, right_table_clause,
				offset, params, mut c, allow_virtual)!

			mut plan := Plan{}
			plan.subplans['\$1'] = left_plan
			plan.subplans['\$2'] = right_plan

			tables := {
				left_table.name.id():  left_table
				right_table.name.id(): right_table
			}

			plan.operations << new_join_operation(left_plan.columns(), from_clause.join_type,
				right_plan.columns(), resolve_identifiers(c, from_clause.specification,
				tables)!, params, c, plan)

			return plan, tables
		}
	}
}

fn create_select_plan_without_join(body SelectStmt, from_clause TablePrimary, offset Expr, params map[string]Value, mut c Connection, allow_virtual bool) !(Plan, Table) {
	mut plan := Plan{}
	mut covered_by_pk := false
	where := body.table_expression.where_clause
	mut table := Table{}

	match from_clause.body {
		Identifier {
			mut table_name := c.resolve_table_identifier(from_clause.body, allow_virtual)!
			table_name_id := table_name.storage_id()
			mut catalog := c.catalogs[table_name.catalog_name] or {
				return error('unknown catalog: ${table_name.catalog_name}')
			}

			if allow_virtual && table_name_id in catalog.virtual_tables {
				plan.operations << VirtualTableOperation{table_name_id, catalog.virtual_tables[table_name_id]}
				table = catalog.virtual_tables[table_name_id].table()
			} else if table_name_id in catalog.storage.tables {
				table = catalog.storage.tables[table_name_id]

				// This is a special case to handle "PRIMARY KEY = INTEGER".
				if table.primary_key.len > 0 && where is BinaryExpr {
					left := where.left
					right := where.right
					if where.op == '=' && left is Identifier {
						if left.sub_entity_name == table.primary_key[0] {
							covered_by_pk = true
							plan.operations << new_primary_key_operation(table, right,
								right, params, c)
						}
					}
				}

				if !covered_by_pk {
					plan.operations << TableOperation{table_name, false, table, params, c, plan.subplans}
				}

				if where !is NoExpr && !covered_by_pk {
					last_operation := plan.operations[plan.operations.len - 1]
					mut resolved_where := resolve_identifiers(c, where, {
						table.name.id(): table
					})!
					plan.operations << new_where_operation(resolved_where, params, c,
						last_operation.columns())
				}
			} else {
				return sqlstate_42p01('table', table_name.str())
			}
		}
		QueryExpression {
			// TODO(elliotchance): Needs to increment.
			mut table_name := Identifier{
				custom_id: '\$1'
			}

			if from_clause.correlation.name.sub_entity_name != '' {
				table_name = from_clause.correlation.name
			}

			subplan := create_query_expression_plan(from_clause.body, params, mut c, from_clause.correlation)!
			plan.subplans[table_name.id()] = subplan

			mut subplan_columns := []Column{}
			for col in subplan.columns() {
				subplan_columns << Column{Identifier{
					entity_name: table_name.id()
					sub_entity_name: col.name.sub_entity_name
				}, col.typ, col.not_null}
			}

			// NOTE: This has to be assigned to a variable otherwise the value
			// is lost. This must be a bug in V.
			table = Table{
				name: table_name
				columns: subplan_columns
			}

			plan.operations << TableOperation{table_name, true, table, params, c, plan.subplans}
		}
	}

	// GROUP BY.
	//
	// TODO(elliotchance): This will break if trying to use GROUP BY on
	// "SELECT *".
	match body.exprs {
		[]DerivedColumn {
			tables := {
				table.name.id(): table
			}
			group_exprs := resolve_identifiers_exprs(c, body.table_expression.group_clause,
				tables)!

			mut select_exprs := []DerivedColumn{}
			for expr in body.exprs {
				select_exprs << DerivedColumn{resolve_identifiers(c, expr.expr, tables)!, expr.as_clause}
			}

			add_group_by_plan(mut &plan, group_exprs, select_exprs, params, mut c, table)!
		}
		AsteriskExpr, QualifiedAsteriskExpr {
			// It's not possible to have a GROUP BY in this case.
		}
	}

	return plan, table
}

fn add_group_by_plan(mut plan Plan, group_clause []Expr, select_exprs []DerivedColumn, params map[string]Value, mut c Connection, table Table) ! {
	// There can be an explicit GROUP BY clause. However, if any of the
	// expressions contain an aggregate function we need to have an implicit
	// GROUP BY for the whole set.
	mut has_agg := false
	empty_row := new_empty_table_row({
		table.name.id(): table
	})
	for e in select_exprs {
		if expr_is_agg(c, e.expr, empty_row, params)! {
			has_agg = true
			break
		}
	}

	if group_clause.len == 0 && !has_agg {
		return
	}

	mut order := []SortSpecification{}
	for col in group_clause {
		order << SortSpecification{
			expr: col
			is_asc: true
		}
	}

	// We do not need to sort the set if the all rows belong to the same set.
	if group_clause.len > 0 {
		plan.operations << new_order_operation(order, params, c, plan.columns())
	}

	plan.operations << new_group_operation(select_exprs, group_clause, params, mut c,
		table)!
}

fn create_delete_plan(stmt DeleteStmt, params map[string]Value, mut c Connection) !Plan {
	select_stmt := SelectStmt{
		exprs: AsteriskExpr(true)
		table_expression: TableExpression{
			from_clause: TablePrimary{
				body: stmt.table_name
			}
			where_clause: stmt.where
		}
	}

	plan, _ := create_select_plan(select_stmt, NoExpr{}, params, mut c, false)!

	return plan
}

fn create_update_plan(stmt UpdateStmt, params map[string]Value, mut c Connection) !Plan {
	select_stmt := SelectStmt{
		exprs: AsteriskExpr(true)
		table_expression: TableExpression{
			from_clause: TablePrimary{
				body: stmt.table_name
			}
			where_clause: stmt.where
		}
	}

	plan, _ := create_select_plan(select_stmt, NoExpr{}, params, mut c, false)!

	return plan
}

fn create_query_expression_plan(stmt QueryExpression, params map[string]Value, mut c Connection, correlation Correlation) !Plan {
	mut plan, tables := create_basic_plan(stmt.body, stmt.offset, params, mut c, true,
		correlation)!

	if stmt.order.len > 0 {
		mut order := []SortSpecification{}
		for spec in stmt.order {
			order << SortSpecification{
				expr: resolve_identifiers(c, spec.expr, tables)!
				is_asc: spec.is_asc
			}
		}

		plan.operations << new_order_operation(order, params, c, plan.columns())
	}

	if stmt.fetch !is NoExpr || stmt.offset !is NoExpr {
		plan.operations << new_limit_operation(stmt.fetch, stmt.offset, params, mut c,
			plan.columns())
	}

	if stmt.body is SelectStmt {
		plan.operations << new_expr_operation(mut c, params, stmt.body.exprs, tables)!
	}

	return plan
}

// The Plan itself is a PlanOperation. This allows more complex operations to be
// nested later.
struct Plan {
mut:
	operations []PlanOperation
	params     map[string]Value
	// subplans represent the subqueries. These are indexed by name and may be
	// referenced by expressions.
	subplans map[string]Plan
}

fn (mut o Plan) execute(_ []Row) ![]Row {
	mut rows := []Row{}
	for mut operation in o.operations {
		rows = operation.execute(rows)!
	}

	return rows
}

fn (p Plan) str() string {
	return p.operations.map(it.str()).join('\n')
}

fn (p Plan) columns() Columns {
	// The columns at the end of the plan will always be whatever the last
	// operation returns.
	return p.operations[p.operations.len - 1].columns()
}

fn (p Plan) explain(elapsed_parse time.Duration) Result {
	mut rows := []Row{}

	for name, subplan in p.subplans {
		rows << new_row({
			'EXPLAIN': new_varchar_value(name + ':', 0)
		})
		for line in subplan.str().split('\n') {
			rows << new_row({
				'EXPLAIN': new_varchar_value('  ' + line, 0)
			})
		}
	}

	for operation in p.operations {
		rows << new_row({
			'EXPLAIN': new_varchar_value(operation.str(), 0)
		})
	}

	return new_result([
		Column{Identifier{ sub_entity_name: 'EXPLAIN' }, new_type('VARCHAR', 0, 0), false},
	], rows, elapsed_parse, 0)
}
