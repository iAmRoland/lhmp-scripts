# Classes
Will push classes which hopefully simplify the coding of some things.

## Sqlite3.nut
Wrapper for LH-MP [sqlite3_* functions](http://lh-mp.eu/wiki/index.php/Functions#SQLite), created this to simplify the usage of the sqlite3_ functions.

**Usage** (more usage examples can be found in the file):

```squirrel
// Create a new sqlite instance
local sql = SQLite( "filename.db" );

// Create new table
sql.create( "table_name( SOME_ID int(10), FIRST_VALUE varchar(20) UNIQUE, SECOND_VALUE varchar(50) )" ).finalize();

// Insert value into table
sql.insert( "table_name", [1, "My first value", "My second value!"] ).finalize();

// Update existing value in table
sql.update( "table_name", {"FIRST_VALUE": "My new first value"}, {"SOME_ID": 1} );

// Selecting existing values from table
local value = sql.query( "SELECT * FROM table_name WHERE SOME_ID = '1'" ).finalize();

// Using the values
value.count; // Returns the result count
value.results; // Returns an array containing values inside a table
value.results[0].FIRST_VALUE; // This is how you would fetch the FIRST_VALUE from Database

// Deleting existing value from table
sql.query( "DELETE FROM table_name WHERE SOME_ID = '1'" ).finalize();
```


**NOTICE**

Remember to always use .finalize() when you are done with your query requests!