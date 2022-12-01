# PostgreSQL tests

The following are my learning notes while doing the postgresql tutorial.

# References
* [Tutorial](https://www.postgresqltutorial.com/postgresql-tutorial/)
* [Reference documentation](https://www.postgresql.org/docs/15/sql-update.html)

# Test environment
## Download [postgresql for windows](https://www.postgresql.org/download/windows/)
[Installation Tutorial](https://www.postgresqltutorial.com/postgresql-getting-started/install-postgresql/)
> Note: remember the user/password...

## VS Code
### Extension: ckolkman.vscode-postgres
  > Note: in my opinion, better than ms-ossdata.vscode-postgresql although both are good options

### Test:
1. Open the extension toolbar and select "Add Connection" with the server data
1. Create a new file and set language type to "postgres"
1. Enter a query
1. Enter command: PostgreSQL: Run Query (F5)


# Tutorial Notes


## Select
### order of evaluation:
FROM -> WHERE -> GROUP BY -> HAVING -> SELECT -> DISTINCT -> ORDER BY -> LIMIT

### Concatenation:

```
SELECT
   first_name || ' ' || last_name
```

### Aliases: AS
If spaces -> use double quotes

### operators
* LENGTH(first_name)
* COUNT
* SUM
* AVG
* ROUND(number, precision)

### ORDER BY
NULL values are put "last": so if request is ordered by DESC, NULL values will appear first. Unless:

```
ORDER BY num NULLS LAST;
```

### DISTINCT
remove duplicates on the given columns. keep first row. Can not select multiple columns while filtering duplicates on only one
The following will remove duplicates on the set (first_name, last_name):
```
SELECT
DISTINCT first_name, last_name
FROM double_customer;
```

### DISTINCT ON
A postgresql extension to SQL. Allow to specify the column to filter while also selecing others.
The following will remove duplicates on first_name but select both columns:

```
SELECT
DISTINCT ON (first_name) first_name, last_name
FROM double_customer;
```

### LIKE ''
Return true if field matches the pattern.
2 wildcards: '%' matches any character, "_" matches exactly one
Case sensitive

* SQL extension: ILIKE: case insensitive variant of LIKE; Aliases:
  * ~~  LIKE
  * ~~* ILIKE
  * !~~ NOT LIKE
  * !~~* NOT ILIKE

### BETWEEN
Possible usages:
* LENGTH(first_name) IN (3, 4, 5)
* LENGTH(first_name) BETWEEN 3 AND 5
  * in which case the matching range includes 3 and 5

### LIMIT
Like "head", limit the number of returned values
is non-sql standard but widespread.

SQL standard is:

```
OFFSET start { ROW | ROWS }
FETCH { FIRST | NEXT } [ row_count ] { ROW | ROWS } ONLY
```

### WHERE
Filter values from expression.
It is possible to use another select statement, as in:
```
SELECT
    customer_id
FROM
	customer
WHERE
	customer_id NOT IN (SELECT customer_id from rental);
```

When filtering on dates, even if column field is timestamp, one can directly use:
```
WHERE
	payment_date BETWEEN '2007-02-07' AND '2007-02-15';
```

### JOINS
Element of the FROM clause:
* [ INNER ] JOIN
* {LEFT | RIGHT | FULL} [OUTER] JOIN
* must be followed by ON or USING or NATURAL

* INNER JOIN == intersection of sets
  * Example: find all transactions for a given client
* OUTER JOIN:
  * LEFT = the source indicated just after the FROM clause
  * includes the intersecting set plus the whole LEFT|RIGHT|FULL set, using 'NULL' values in columns for rows that are not intersecting
  * returned in the order from the LEFT table, except for RIGHT JOIN
    * Examples:
      * LEFT: find all films that are not in inventory (film.inventory_id is NULL, inventory_id is added to film in JOIN)

  * ```SELECT * FROM basket_a , basket_b;```returns the combinations from both tables. It is a cross-join clause shortcut, full syntax is: `SELECT * FROM basket_a CROSS JOIN basket_b`

  * NATURAL: creates an implicit join based on the same column names in the joined tables. Should be avoided because it uses all columns implicitly.

* USING:
> USING ( a, b, ... ) is shorthand for ON left_table.a = right_table.a AND left_table.b = right_table.b .... Also, USING implies that only one of each pair of equivalent columns will be included in the join output, not both.

### GROUP BY / HAVING
GROUP BY will condense into a single row all selected rows that share the same values for the grouped expressions.
* When using GROUP BY, all elements listed in SELECT must also be GROUP'd BY
* Other elements can be selected through aggregate functions: SUM, COUNT, ...
* HAVING introduces a filter to the group
> The WHERE clause is applied to rows while the HAVING clause is applied to groups of rows.
* ROLLUP / CUBE: generated grouping sets automatically (for instance using ROLLUP to generate the subtotals and the grand total for reports)
```
SELECT
	store_id,
	COUNT (customer_id)
FROM
	customer
GROUP BY
	store_id
HAVING
	COUNT (customer_id) > 300;
```
Note we can't use WHERE to perform an equivalent filter here.


### UNION / INTERSECT / EXCEPT [ALL | DISTINCT]
Combine the output of more than one SELECT statement
* UNION: returns all rows that are in one or both of the result sets
* INTERSECT: returns all rows that are strictly in both result sets
* EXCEPT: returns the rows that are in the first result set but not in the second

In all three cases, duplicate rows are eliminated unless ALL is specified.
The noise word DISTINCT can be added to explicitly specify eliminating duplicate rows.

### SUBQUERY
* Syntax: use parenthesis around the subquery
* The subquery may return one row (value) or a list of rows
* The outer query can use:
  * IN operator (for instance in the where clause)
  * EXISTS: True if the number of row returned by the subquery is not 0 (in which case, the subquery may return multiple columns)
    * If the subquery returns NULL, EXISTS returns true
  * ANY / ALL: operators taking a subquery and a comparison operator (only if there is just one column)
    * ANY returns true if operation is true for at least one element of the suquery
    * ALL returns true if operation is true for all elements of the suquery
> PostgreSQL executes the query that contains a subquery in the following sequence:
>  * First, executes the subquery.
>  * Second, gets the result and passes it to the outer query.
>  * Third, executes the outer query.

### CTE / RECURSIVE
Usefull to parse hierarchical data: subordinates of Manager X, BOM...

## INSERT
```
INSERT INTO links (url, name)
VALUES
   ('http://www.postgresql.org','PostgreSQL'),
   ('https://www.yahoo.com','Yahoo'),
RETURNING id;
```

* RETURNING returns the information on the created row; useful when some columns are generated by the database itself, like the id
* if no value is specified for a column, use default

### Merge Resolution: Upsert (update - insert)
Inserting a new row with values already in the table is only a problem if the table defines **constraints** on some columns.

For instance:
```
CREATE TABLE customers (
	customer_id serial PRIMARY KEY,
	name VARCHAR UNIQUE,
	email VARCHAR NOT NULL,
	active bool NOT NULL DEFAULT TRUE
);
```
The *UNIQUE* constraint on the "name" column will ensure that when trying to insert a row with an already existing name, an error will be raised.

To specify the behavior to handle this situation without error, use **ON CONFLICT** clause (postgresql extension).

> ON CONFLICT [ conflict_target ] conflict_action
>
> where conflict_target can be one of:
>
>     ( { index_column_name | ( index_expression ) } [ COLLATE collation ] [ opclass ] [, ...] ) [ WHERE index_predicate ]
>     ON CONSTRAINT constraint_name
>
> and conflict_action is one of:
>
>     DO NOTHING
>     DO UPDATE SET { column_name = { expression | DEFAULT } |
>                     ( column_name [, ...] ) = [ ROW ] ( { expression | DEFAULT } [, ...] ) |
>                     ( column_name [, ...] ) = ( sub-SELECT )
>                   } [, ...]
>               [ WHERE condition ]

* Note: when using *DO UPDATE SET*, a special table alias **excluded** is created with the row proposed for insertion.

## UPDATE
> The PostgreSQL UPDATE statement allows you to modify data in a table. The following illustrates the syntax of the UPDATE statement:

```
UPDATE table_name
SET column1 = value1,
    column2 = value2,
    ...
WHERE condition;
```

> In this syntax:
> * First, specify the name of the table that you want to update data after the UPDATE keyword.
> * Second, specify columns and their new values after SET keyword. The columns that do not appear in the SET clause retain their original values.
> * Third, determine which rows to update in the condition of the WHERE clause.
The WHERE clause is optional. If you omit the WHERE clause, the UPDATE statement will update all rows in the table.

### UPDATE join using FROM clause
Update a column based on the value of another column from another set.

Basically comes down to joining tables. Warning:
> When using FROM you should ensure that the join produces at most one output row for each row to be modified.

> Because of this indeterminacy, referencing other tables only within sub-selects is safer, though often harder to read and slower than using a join.

Example:
```
UPDATE product
SET net_price = price - price * discount
FROM product_segment
WHERE product.segment_id = product_segment.id
RETURNING *;
```

## DELETE FROM
### basic syntax:
```
DELETE FROM product WHERE name LIKE 's%' RETURNING *;
```

### when needing several tables: USING
Not SQL standard. Not the same as USING in JOIN (expects a table_expression, as used in the FROM clause)
```
DELETE FROM t1
USING t2
WHERE t1.id = t2.id
```

### subquery
SQL standard
```
DELETE FROM contacts
WHERE phone IN (SELECT phone FROM blacklist);
```

## Transactions
> A database transaction is a single unit of work that consists of one or more operations.

> A PostgreSQL transaction is atomic, consistent, isolated, and durable. These properties are often > referred to as ACID:
>
> Atomicity guarantees that the transaction completes in an all-or-nothing manner.
> Consistency ensures the change to data written to the database must be valid and follow predefined > rules.
> Isolation determines how transaction integrity is visible to other transactions.
> Durability makes sure that transactions that have been committed will be stored in the database > permanently.

Example:
```
-- start a transaction
BEGIN;

-- deduct 1000 from account 1
UPDATE accounts
SET balance = balance - 1000
WHERE id = 1;

-- add 1000 to account 2
UPDATE accounts
SET balance = balance + 1000
WHERE id = 2;

-- select the data from accounts
SELECT id, name, balance
FROM accounts;

-- commit the transaction
COMMIT;
```

* To Cancel an uncommitted transaction: use ROLLBACK

# Import/Export to CSV
Use the "COPY" command.

# CREATE TABLE
Basic syntax:
```
CREATE TABLE accounts (
	user_id serial PRIMARY KEY,
	username VARCHAR ( 50 ) UNIQUE NOT NULL,
	password VARCHAR ( 50 ) NOT NULL,
	email VARCHAR ( 255 ) UNIQUE NOT NULL,
	created_on TIMESTAMP NOT NULL,
        last_login TIMESTAMP
);
```

## Pseudo Types
* SERIAL generates a sequence of integers (1 to 2,147,483,647). Also: smallserial, bigserial

## Constraints
Each row may be constrained:
> * NOT NULL – ensures that values in a column cannot be NULL.
> * UNIQUE – ensures the values in a column unique across the rows within the same table.
> * PRIMARY KEY – a primary key column uniquely identify rows in a table. A table can have one and only one primary key. The primary key constraint allows you to define the primary key of a table.
> * CHECK – a CHECK constraint ensures the data must satisfy a boolean expression.
> * FOREIGN KEY – ensures values in a column or a group of columns from a table exists in a column or group of columns in another table. Unlike the primary key, a table can have many foreign keys.

## Create table from another table: SELECT INTO / CREATE TABLE .. AS ... (preferred)
