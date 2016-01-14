/*
 *  A simple account system containing login, register, admin functions as 
 *  well couple of simple example commands.
 *  If you find any bugs or if you find places where improvement can be made 
 *  then contact me on the LH-MP (lh-mp.eu) forums, my username is Rolandd.
 *
 *  --
 *
 *  NOTICE:
 *  Download and include following files yourself (github.com/iAmRoland/lhmp-scripts):
 *      /classes/sqlite3.nut
 *  
 *  --
 *
 *  Version: 1.0.0
 *  Last edit: 2016-01-14 03:00
 *  Copyright (c) 2016  iAmRoland
 *
 *  Licensed under the MIT License (MIT)
 *  http://opensource.org/licenses/MIT
 */



/* This is one way you can include a file.
 * Another is to just copy and paste the content from the other file into this one.
 * Include path starts from "gamemodes" folder, ex: "gamemodes/MY_GAMEMODE/file.nut" */
dofile( "path/to/sqlite3.nut" );


// 
::SCRIPT_NAME       <- "Simple Account System";
::SCRIPT_VERSION    <- "SAS-1.0";
::RCON_PASSWORD     <- "DankPassword!";

//
::DB        <- {};
::PLAYERS   <- {};


/**
 *  SCRIPTINIT
 */
function onServerInit () {
    print(" ");
    print("| - - " + SCRIPT_NAME + " loaded succesfully! - - |");
    print(" ");

    serverSetGamemodeName(SCRIPT_VERSION);

    // Create a new SQLite instance for users
    DB.users <- SQLite("users.db", true);

    // Create a users table if it does not exist
    DB.users.create("users( username varchar(20) UNIQUE NOT NULL, password varchar(40) NOT NULL, admin int(1), money int(10), last_login varchar(20), created varchar(20) )").finalize()
}



/**
 *   PLAYERCONNECT 
 */
function onPlayerConnect (playerid) {

    // This can contain all sorts of player stats
    PLAYERS[playerid] <- {
        NAME = playerGetName(playerid),
        ADMIN = 0,
        LOGGED_IN = false,
    };

    // Enable player ingame money
    playerEnableMoney(playerid, 1);

    // Send 2 messages, using format() function to insert values later into string
    // Makes it a bit easier to read
    sendPlayerMessage(playerid, format("%sScript: %s | Created by: Rolandd", "#fffa00", SCRIPT_NAME));
    sendPlayerMessage(playerid, format("%s---", "#ffff00"));

    sendAllMessage(format("%sSYS: %s connected.", "#32cd32", playerGetName(playerid)));
}



/**
 *   PLAYERDISCONNECT 
 */
function onPlayerDisconnect (playerid) {
    // Put the player name in a variable
    local username  = playerGetName(playerid);
    
    // Check if user is logged in
    if (PLAYERS[playerid].LOGGED_IN == true) {

        // Update users table with given stats where username from variable
        DB.users.update("users", 
            {
                "admin": PLAYERS[playerid].ADMIN,
                "money": playerGetMoney(playerid)
            }, 
            // Where username is the variable username
            {"username": username}
        ).finalize();

        // Just print a debug, so we know user stats were saved
        print(format("PLAYER DISCONNECT DEBUG :: Player %s left the server, stats were saved!", username));
    }

    // Clear the slot in PLAYERS array
    PLAYERS[playerid].clear();
    // Delete the slot completely
    PLAYERS.rawdelete(playerid);

    // Send a disconnect message to all
    sendAllMessage(format("%sSYS: %s left, bye.", "#ffcc00", username));
}



/**
 *   PLAYERSPAWN 
 */
function onPlayerSpawn ( playerid ) {
    // Lock player controls temporarly
    playerLockControls(playerid, false);

    // Set health and other things
    playerSetHealth(playerid, 200.0);
    playerSetMoney(playerid, 100);

    // Set the player position
    playerSetPosition(playerid, -1985.966675,-5.037054,4.284860);

    // Unlock the player controls now
    playerLockControls(playerid, false);

    // If not logged in then send message
    if (PLAYERS[playerid].LOGGED_IN == false) {
        sendPlayerMessage(playerid, format("%sSYS: You are not logged in, to save your stats please /login or /register.", "#fffa00") );
    }
}



/**
 * ONPLAYERCOMMAND
 */
function onPlayerCommand (playerid, command, params) {
    switch(command) {

        /**
         *  PLAYER ACCOUNT COMMANDS
         */
        case "rcon": {
            // Split params string into an array
            local vargv = split(params, " ");

            // Check if there is enough parameters
            if (vargv.len() < 1) {
                // Give invalid command message, to not encourage them to keep on trying
                sendPlayerMessage(playerid, format("%sSYS: Invalid command!", "#fa2814"));
                return false;
            }
            
            // Get the inserted password 
            local password = vargv[0].tostring();
            // If passwords match
            if ( password == RCON_PASSWORD ) {
                PLAYERS[playerid].ADMIN = 69;
                sendPlayerMessage(playerid, format("%sSYS: Welcome to the cool kid club!", "#32cd32"));
            } else {
                sendPlayerMessage(playerid, format("%sSYS: Invalid command!", "#fa2814"));
            }
        }
        break;


        case "login": {
            // Split params string into an array
            local vargv = split(params, " ");

            // Check if there is enough parameters
            if (vargv.len() < 1) {
                sendPlayerMessage(playerid, format("%sSYS: Usage: /login [PASSWORD]", "#fa2814"));
                return false;
            }

            // Get the password
            local password = vargv[0].tostring();

            // If user is already logged in
            if (PLAYERS[playerid].LOGGED_IN == true) {
                playerSendMessage(playerid, format("%sSYS: You are already logged in.", "#fffa00"));
                return false;
            }

            // Get connected users name
            local username = playerGetName(playerid);

            // Get the current date
            local current_date = getDate();

            // Fetch password from connected username
            local query = DB.users.query("SELECT * FROM users WHERE username = ?", [username]).finalize();

            // Check if any results were found
            if (query.count != 0) {
                // Set data from results slot into a user_data variable
                local user_data = query.results[0];

                // Check if password from DB match with input password
                if (user_data.password == password) {
                    // Update DB, set last_login date to current date
                    DB.users.update("users", {"last_login": current_date}, {"username": username}).finalize();

                    // Set user stats
                    PLAYERS[playerid].ADMIN = user_data.admin.tointeger();
                    playerSetMoney(playerid, user_data.money.tointeger());

                    // Set login state to true
                    PLAYERS[playerid].LOGGED_IN = true;
                    
                    // Inform player that they have been logged in
                    sendPlayerMessage(playerid, format("%sSYS: You have been logged in.", "#fffa00"));
                    return true;
                }
            }
            // Login failed, inform user
            sendPlayerMessage(playerid, format("%sSYS: Login failed! Either user does not exists or incorrect password was entered.", "#fa2814"));
        }
        break;


        case "register": {
            // Split params string into an array
            local vargv = split(params, " ");

            // Check if there is enough parameters
            if (vargv.len() < 1) {
                sendPlayerMessage(playerid, format("%sSYS: Usage: /register [PASSWORD]", "#fa2814"));
                return false;
            }

            // If user is already logged in
            if (PLAYERS[playerid].LOGGED_IN == true) {
                playerSendMessage(playerid, format("%sSYS: You are already logged in.", "#fffa00"));
                return false;
            }

            // Get the password
            local password = vargv[0].tostring();

            // If password length is below 4 characters or if user is logged in already then return false
            if (password.len() < 4) {
                sendPlayerMessage(playerid, format("%sSYS: Password must be atleast 4 characters!", "#fa2814"));
                return false;
            }


            // Get connected users name
            local username = playerGetName(playerid);

            // Get the current date
            local current_date = getDate();

            // Check if such user already exists in DB
            local query = DB.users.query("SELECT `username` FROM users WHERE username = ?", [username]).finalize();

            // If user does not exist
            if (query.count == 0) {
                // Get user stats to insert into DB
                local money = playerGetMoney(playerid);
                local admin = PLAYERS[playerid].ADMIN;

                // Insert the user into DB
                DB.users.insert("users", [username, password, admin, money, current_date, current_date]).finalize();

                // Call the login command and log the user in
                onPlayerCommand(playerid, "login", password);
                
                // Inform user about successful registration and that they have been logged in
                sendPlayerMessage(playerid, format("%sSYS: Account has been successfully registered! Logging you in...", "#fffa00"));
                return true;
            }
            sendPlayerMessage(playerid, format("%sSYS: Registration failed, username '%s' already exists!", "#fa2814", username));
        }
        break;


        /**
         * Example commands
         */
        case "admin":
            if (PLAYERS[playerid].ADMIN > 0 ) {
                sendPlayerMessage(playerid, format("%sSYS: Yes, you are an admin, your admin rank is: %d", "#32cd32", PLAYERS[playerid].ADMIN));
            } else {
                sendPlayerMessage(playerid, format("%sSYS: Sorry son, you are not part of the cool kids club.", "#fa2814"));
            }
        break;


        case "givemoney": {
            // If player admin rank is below 3 then cancel right away
            if (PLAYERS[playerid].ADMIN < 3) { 
                sendPlayerMessage(playerid, format("%sSYS: You are not allowed to use this command!", "#fa2814"));
                return false;
            }

            // Split params string into an array
            local vargv = split(params, " ");

            // Check if there is enough parameters
            if (vargv.len() < 2) {
                sendPlayerMessage(playerid, format("%sSYS: Usage: /givemoney [TARGET PLAYER] [AMOUNT]", "#fa2814"));
                return false;
            }

            // Set targetid and amount into variables
            local targetid = vargv[0].tostring();
            local amount = vargv[1].tostring();

            // Check if both variables are numeric
            if (isNumeric(targetid) && isNumeric(amount)) {
                // Convert both variables to integers
                targetid = targetid.tointeger(), amount = amount.tointeger();

                // Is the target player online
                if (playerIsConnected(targetid)) {
                    // Get admin username and the target username
                    local username = playerGetName(playerid);
                    local target_name = playerGetName(targetid);

                    // Give cash to the target player
                    playerSetMoney(targetid, (playerGetMoney(targetid) + amount));

                    // Inform both players about the success
                    sendPlayerMessage(targetid, format("%sSYS: You have recieved $%d from admin %s", "#32cd32", amount, username));
                    sendPlayerMessage(playerid, format("%sSYS: You gave $%d to player %s", "#32cd32", amount, target_name));
                } else {
                    sendPlayerMessage(playerid, format("%sSYS: Target player is not online.", "#fa2814"));
                }
            } else {
                sendPlayerMessage(playerid, format("%sSYS: Error, invalid target playerid or cash amount!", "#fa2814"));
            }
        }
        break;


        /**
         * Invalid command
         */
        default: 
            sendPlayerMessage(playerid, format("%sSYS: Invalid command!", "#fa2814"));
    }
}





/**
 * Format date to look like this: "YYYY-MM-DD HH:MM"
 *
 * @param int optional time  Set your own custom time or leave blank to use current time
 * @return string 
 */
function getDate ( time = time() ) {
    // Get date from time
    local now = date( time );
            // Format date to look like this YYYY-MM-DD
    return  now.year + "-" +
            ( (now.month+1 < 10) ? "0" + (now.month+1) : (now.month+1) ) + "-" +
            ( (now.day < 10) ? "0" + now.day : now.day ) + " " +

            // Format time to look like this HH:MM
            ( (now.hour < 10) ? "0" + now.hour : now.hour ) + ":" +
            ( (now.min < 10) ? "0" + now.min : now.min );
}



/**
 * Check if a given string is a numeric or not.
 * Returns either 1 (is numeric) or 0 (not numeric)
 * 
 * @param string string  The string to check
 * @return int
 */
function isNumeric ( string ) {
    try {
        string.tointeger();
    } catch( string ) {
        local errors = 0;
        foreach ( str in string ) {
            try {
                str.tointeger();
            } catch ( string ) {
                errors++;
            }
        }
        print( "errors: " + errors );
        return ( errors == 0 ? 1 : 0);
    }
    return 1;
}
