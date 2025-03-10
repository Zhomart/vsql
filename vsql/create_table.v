// create_table.v contains the implementation for the CREATE TABLE statement.

module vsql

import time

// TODO(elliotchance): A table is allowed to have zero columns.

fn execute_create_table(mut c Connection, stmt CreateTableStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	mut table_name := c.resolve_schema_identifier(stmt.table_name)!
	if table_name.storage_id() in catalog.storage.tables {
		return sqlstate_42p07(table_name.str()) // duplicate table
	}

	mut columns := []Column{}
	mut primary_key := []string{}
	for table_element in stmt.table_elements {
		match table_element {
			Column {
				columns << Column{Identifier{
					catalog_name: table_name.catalog_name
					schema_name: table_name.schema_name
					entity_name: table_name.entity_name
					sub_entity_name: table_element.name.sub_entity_name
				}, table_element.typ, table_element.not_null}
			}
			UniqueConstraintDefinition {
				if primary_key.len > 0 {
					return sqlstate_42601('only one PRIMARY KEY can be defined')
				}

				if table_element.columns.len > 1 {
					return sqlstate_42601('PRIMARY KEY only supports one column')
				}

				for column in table_element.columns {
					// Only some types are allowed in the PRIMARY KEY.
					mut found := false
					for e in stmt.table_elements {
						if e is Column {
							if e.name.sub_entity_name == column.sub_entity_name {
								match e.typ.typ {
									.is_smallint, .is_integer, .is_bigint {
										primary_key << column.sub_entity_name
									}
									else {
										return sqlstate_42601('PRIMARY KEY does not support ${e.typ}')
									}
								}

								found = true
							}
						}
					}

					if !found {
						return sqlstate_42601('unknown column ${column} in PRIMARY KEY')
					}
				}
			}
		}
	}

	catalog.storage.create_table(table_name, columns, primary_key)!

	return new_result_msg('CREATE TABLE 1', elapsed_parse, t.elapsed())
}
