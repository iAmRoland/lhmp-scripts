/*
 *  Wrapper for LH-MP sqlite3_* functions (http://lh-mp.eu/wiki/index.php/Functions#SQLite)
 *  Used to simplify the sqlite3_ usage. If you find any bugs or if you find places where 
 *  improvement can be made then contact me on the LH-MP forums, my username is Rolandd.
 *  
 *  --
 *
 *  Version: 1.0.0
 *  Last edit: 2016-01-11 04:30
 *  Copyright (c) 2016  Rolandd
 *
 *  Licensed under the MIT License (MIT)
 *  http://opensource.org/licenses/MIT
 *
 *  --
 *
 *  Usage (more usage examples can be found below):
 *      local sql = SQLite( "filename.db" );
 *      
 *      # Create new table
 *      sql.create( "table_name( SOME_ID int(10), FIRST_VALUE varchar(20) UNIQUE, SECOND_VALUE varchar(50) )" ).finalize();
 *      # Insert value into table
 *      sql.insert( "table_name", [1, "My first value", "My second value!"] ).finalize();
 *      # Update existing value in table
 *      sql.update( "table_name", {"FIRST_VALUE": "My new first value"}, {"SOME_ID": 1} );
 *
 *      # Selecting existing values from table
 *      local value = sql.query( "SELECT * FROM table_name WHERE SOME_ID = '1'" ).finalize();
 *          # Using the value
 *          value.count; // Returns the result count
 *          value.results; // Returns an array containing values inside a table
 *          value.results[0].FIRST_VALUE; // This is how you would fetch the FIRST_VALUE from Database
 *
 *      # Deleting existing value from table
 *      sql.query( "DELETE FROM table_name WHERE SOME_ID = '1'" ).finalize();
 *
 *
 *  |||>>> NOTICE! <<<|||
 *  Remember to always use .finalize() when you are done with your query requests!
 */
class SQLite {


    // File to fetch data from
    _sql_file = null;
    
    // Holds the active sqlite3 instance
    _sql_active = null;

    // Will hold results from sqlite3_step function
    _sql_step = null;
    
    // Will collect the results returned from sqlite3_ functions
    _results = [];
    
    // Will contain the count returned from last query
    _count = 0;
    
    // Will contain debug mode toggle state, by default its false
    _debug = false;


    /**
     * Class constructor
     *
     * @param sql_file  .db file to use for editing
     * @param bool optional debug_mode  If the debug mode should be enabled or not
     */
    constructor ( sql_file, debug_mode = false ) {
        // If activated then it will print the full SQL query string
        _debug = debug_mode;

        // If given filename is not null or empty
        if ( sql_file != null || sql_file.len() > 0 ) {
            // Now we can use _sql_file in our other functions
            _sql_file = sql_file;
        }
    }


    /**
     * Print a string if debug mode is enabled
     * @param string debug_string  String to print
     */
    function printDebug ( debug_string ) {
        if ( _debug == true )
            print( "SQLITE3 DEBUG :: \"" + debug_string + "\"" );
    }


    /**
     * Create a new table, it just uses query function, but do it this way so no mixup is made.
     *
     * @param string sql_query Must contain the table name and values to create
     * @usage
     *  Example #1:
     *      .create( "users( USERNAME varchar(25), PASSWORD varchar(25) )" )
     *  Example #2:
     *      .create( "user( USERNAME varchar(25), PASSWORD varchar(25) )" )
     *      .create( "items( ID int(10), NAME varchar(30), WEIGHT int(10) )" )
     */
    function create ( sql_query ) {
        // Finalize if already active sqlite connection exits
        if ( _sql_active != null )
            this.finalize();

        // If string "CREATE TABLE IF EXISTS" does not exists then add it
        if ( sql_query.toupper().find( "CREATE TABLE IF NOT EXISTS" ) == null ) 
            sql_query = "CREATE TABLE IF NOT EXISTS " + sql_query;

        // Query the string
        this.query( sql_query );
        return this;
    }


    /**
     * Insert new value(s) to an existing table
     *
     * @param string sql_table
     * @param array / table insert_array
     *
     * @usage
     *  Example #1 (array: username, password, admin, money): 
     *      .insert( "users", ['username', 'secure_password', 0, 300] ).finalize()
     *  Example #2:
     *      .insert( "users", ['username', 'secure_password', 0, 300] )
     *      .insert( "users", ['username_2', 'secure_password123', 2, 200] ).finalize()
     *
     *  Example #3 (Table with specific values only):
     *      .insert( "users", {"username": "User Name", "password": "password123", "admin": 1} ).finalize()
     */
    function insert ( sql_table, insert_data ) {
        // Array with two slots for query string
        local sql_values = ["", ""]

        // Loop through the array with insert values
        foreach (idx, insert in insert_data ) {
            // If insert_data is a table
            if ( typeof insert_data == "table" ) {
                // Set the column names inside backticks
                sql_values[0] += "`" + idx + "`,";

                // Set the column values in single quotes
                sql_values[1] += "'" + this.patchSingleQuotes( insert ) + "',";

            // Otherwise it must be an array
            } else {
                // Add values onto the sql_values wrapped in in single quotes
                sql_values[1] += "'" + this.patchSingleQuotes( insert ) + "',";
            }
        }


        // Remove the last comma from string
        sql_values[1] = sql_values[1].slice( 0, sql_values[1].len() - 1 );

        // If first array slot is not empty
        if ( sql_values[0].len() != 0 ) { 
            // Remove the last comma from string
            sql_values[0] = sql_values[0].slice( 0, sql_values[0].len() - 1 );

            // Wrap slot [0] in round brackets
            sql_values[0] = "(" + sql_values[0] + ")";
        }
        
        // Build string to query
        local sql_query = "INSERT INTO " + sql_table + " " + sql_values[0] + " VALUES( " + sql_values[1] + " )";

        // Do the query
        this.query( sql_query );
        return this;
    }


    /**
     * Update existing rows and columns in an existing table
     *
     * @param string sql_table  String on which table to update
     * @param table update_tbl  Table with names to update in DB
     * @param table where_tbl  Table with names to specify which column to update exactly
     *
     * @usage
     *  Example #1:
     *      .update( "users", {"MONEY": 500, "ADMIN": 5}, {"USERNAME": "user_1"} ).finalize()
     *  Example #2:
     *      .update( "users", {"MONEY": 500, "ADMIN": 5}, {"USERNAME": "user_1"} )
     *      .update( "users", {"MONEY": 69, "ADMIN": 1}, {"USERNAME": "user_2"} ).finalize()
     */
    function update ( sql_table, update_tbl, where_tbl ) {
        // Empty string for update and where values
        local sql_values = "";
        local sql_where = "";

        // Loop through the array with update values
        foreach ( idx, value in update_tbl ) {
            // Add values onto the sql_values wrapped in in single quotes
            sql_values += idx + " = '" + this.patchSingleQuotes( value ) + "',";
        }

        // Loop through the array with update values
        foreach ( idx, value in where_tbl ) {
            // Add values onto the sql_values wrapped in in single quotes
            sql_where = " " + idx + " = '" + this.patchSingleQuotes( value ) + "' AND" + sql_where;
        }

        // Remove the last comma from sql_values
        sql_values = sql_values.slice( 0, sql_values.len() - 1 );

        // If sql_where variable is not empty
        if ( sql_where.len() != 0 ) {
            // Remove that last AND from sql_where
            sql_where = " WHERE" + sql_where.slice( 0, sql_where.len() - 4 );
        }

        // Build string to query
        local sql_query = "UPDATE " + sql_table + " SET " + sql_values + sql_where;

        //
        this.query( sql_query );
        return this;
    }


    /**
     * Make a query to fetch, insert, delete or update content.
     * NOTICE: Either query with params_arr only or without params_arr, this to prevent errors.
     *          Pick one which you like the most, I added params_arr to make queries easier to read.
     *
     * @param string sql_query  The sql string to query
     * @param array params_arr  Parameters to insert into the query string,
     *                          size of this must match the questionmarks count in the sql_query string
     *
     * @usage
     *  Example #1:
     *      .query( "SELECT * FROM users WHERE USERNAME = 'user_1' AND PASSWORD = 'my_password'" ).finalize()
     *  Example #2 (RECOMMENDED, This will escape single quotes):
     *      .query( "SELECT * FROM users WHERE USERNAME = ? AND PASSWORD = ?", ["user_1", "password"] ).finalize()
     */
    function query ( sql_query, params_arr = [] ) {

        // If params_arr does contain something
        if ( params_arr.len() != 0 ) {
            // Will hold the index for last found questionmark
            local src_idx = 0;
            // Index which is set when a questionmark is found
            local found_idx = 0;
            // Used to fetch from right slot in array
            local incr_idx = 0;
            // Will hold the rebuilt query with all the values added
            local query_rebuild = "";

            // Keep looping while a questionmark is found
            // Start search in string from index in src_idx
            // The found index is inserted into found_idx
            while ( ( found_idx = sql_query.find( "?", src_idx ) ) != null ) {
                // Slice out the part between last found index and next found index
                query_rebuild += sql_query.slice( src_idx, found_idx );

                // Patch the value from array from single quotes and insert it into string
                query_rebuild += "'" + this.patchSingleQuotes( params_arr[ incr_idx ] ) + "'";

                // Increment the index used for params_arr
                incr_idx++;
                // Set the last found index incremented by 1
                src_idx = found_idx+1;
            }

            // Add rest of the query string if exists
            query_rebuild += sql_query.slice( src_idx, sql_query.len() );
                
            // Replace the value in given query string parameter
            sql_query = query_rebuild;
        }

        // print the given query if debug is enabled
        this.printDebug( sql_query );

        // Do the query with file name and the query string
        _sql_active = sqlite3_query( _sql_file, sql_query );

        // Do a step, set count and build the returned results
        this.step();
        this.setCount();
        this.buildResults();

        // Return the class instance
        return this;
    }


    /**
     * Build a result array containt objects with values
     */
    function buildResults () {
        // Index for setting array slot
        local index = 0;

        // Loop while _sql_step is equal to SQLITE_ROW
        while ( _sql_step == SQLITE_ROW ) {
            // Empty table object
            local result_addon = {};
            
            // Use the _count set in query() to loop and get values
            for ( local i = 0; i < _count; i++ ) {
                // Get column name and text
                local column_name = sqlite3_column_name( _sql_active, i );
                local column_text = sqlite3_column_text( _sql_active, i );

                // Add the name and value into the table object
                result_addon[column_name] <- column_text;
            }

            // Insert the object into the classes _result array variable
            _results.insert( index, result_addon );
            // Make a new step to fetch next batch of data.
            this.step();
            // Increment the index value
            index++;
        }
        // Set count to how many rows were fetched
        _count = _results.len();
    }


    /**
     * This will replace a single quote in value to double quote.
     * Otherwise users can type a single quote and perform their own query, 
     * so we essentially need to escape it.
     * This way it will store that one single quote and at the same time prevent a SQL injection.
     * Don't want the user to "accidentally" DELETE the entire DB ;)
     *
     * @param string patch_string
     * @return patched string
     */
    function patchSingleQuotes ( patch_string ) {
        // Convert patch_string to string and check if no single quotes exist
        if ( patch_string.tostring().find( "'" ) == null )
            return patch_string;

        // f_idx = found index, src_idx = index to start from
        local f_idx = 0, src_idx = 0;
        // Will hold the new string
        local new_string = "";

        // Keep looping while a single quote is found
        // Start search in string from index in src_idx .find( string, [Start index, optional])
        // The found index is inserted into f_idx
        while ( ( f_idx = patch_string.find( "'", src_idx ) ) != null ) {
            /* Add the new sliced part onto the new_string variable.
             * Slice string between last source index and next found index
             * Then add double single quotes after the sliced string */
            new_string += patch_string.slice( src_idx, f_idx ) + "''";

            // Set src_idx to f_idx and increment it by 1
            src_idx = f_idx + 1;
        }
        // Add the remaining string if there is any
        new_string += patch_string.slice( src_idx, patch_string.len() );

        // Print this string for debug purposes
        this.printDebug( "ESCAPED STRING :: " + new_string );

        // Replace patch_string
        return new_string;
    }


    /**
     * Make a step on current active sql query
     */
    function step () {
        // Do we have an active query
        if ( _sql_active != null ) 
            // Do the step and set the number into _sql_step variable
            _sql_step = sqlite3_step( _sql_active );
    }


    /**
     * Set the count on current active sql query
     */
    function setCount () {
        // If active query exists then set count from function, default to 0 otherwise
        _count = _sql_active != null ? sqlite3_column_count( _sql_active ) : 0;
    }


    /**
     * Finalize current active query, must be used at the end of each query
     * @return table object with results and count
     */
    function finalize () {
        if ( _sql_active != null ) 
            sqlite3_finalize( _sql_active );

        return {"results": _results, "count": _count};
    }
}