# Database Setup Guide

This guide explains how to initialize and verify the SQLite database for the Contingent Worker Management System.

## Prerequisites
- Python 3.x installed or a database client like [DBeaver](https://dbeaver.io/) or DB Browser for SQLite.

## Initializing Database via Command Line (sqlite3)
If you have the `sqlite3` CLI installed:
1. Open your terminal in the `d:\Code\DB\database` folder.
2. Run the following command to create the database file and initialize our schemas:
   ```bash
   sqlite3 app.db < schema.sql
   ```
   *This reads the SQL statements from `schema.sql` and executes them, creating all tables in a new file named `app.db`.*

## Initializing Database via Python
Since our backend is built in Python, you can initialize the database using the built-in `sqlite3` module.

1. Ensure your terminal is in the project's root folder `d:\Code\DB`.
2. You can create a quick python script `setup_db.py` or run these lines directly in your python shell:
   ```python
   import sqlite3
   import os

   # Navigate to our database directory
   db_path = os.path.join('database', 'app.db')
   schema_path = os.path.join('database', 'schema.sql')

   # Connect to (or create) the application database
   conn = sqlite3.connect(db_path)
   cursor = conn.cursor()
   
   # Read the schema file
   with open(schema_path, 'r') as file:
       schema_script = file.read()
       
   # Execute the script to create tables and triggers
   cursor.executescript(schema_script)
   conn.commit()
   conn.close()
   
   print("Database initialized successfully!")
   ```

## Confirming the Connection
To browse the tables and see the data visually:
- Download **DBeaver** or **DB Browser for SQLite**.
- Open the application.
- Choose "Open Database" or Create a New Connection (selecting SQLite as the driver).
- Navigate to `d:\Code\DB\database` and select the `app.db` file.
- You can now expand the "Tables" view to see `vendors`, `sows`, `change_orders`, `workers`, `assignments`, `cost_centers`, `resource_managers`, and `users`.

## Schema Overview Details
The setup code makes use of the following constructs to ensure top-notch data hygiene:
- **Foreign Keys:** Enforces referential integrity (for example, you cannot accidentally insert a worker `assignment` linked to a nonexistent `sow_id`). Ensure you insert records into parent tables (like `vendors`) before children tables.
- **Triggers:** Automated background actions that fire to modify the `updated_at` timestamps on tables each time a record is mutated.

## Troubleshooting Common Setup Issues
- **Foreign Key Errors:** We explicitly enable `PRAGMA foreign_keys = ON;`. If you encounter constraint errors when inserting, verify you are linking an existing Primary Key reference (PK).
- **File Not Found Errors:** SQLite databases are file-based. Always ensure your application code properly points an absolute or accurate relative path to where `app.db` is stored.
