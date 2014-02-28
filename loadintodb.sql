-- This script will create and update a table in the postgres database.
-- It will also perform some tasks so make the data more meaningful. 

-- Create the table, based on the tablename given in the bash script
CREATE TABLE IF NOT EXISTS $tablename (date_col date, time_col time, level numeric, units text);

COPY $tablename FROM /var/www/sites/default/files/uploaded_files/$file;

--Create a new timestamp column called datetime which is combined from adding cols date and time 

ALTER TABLE $tablename ADD COLUMN IF NOT EXISTS datetime timestamp;
UPDATE $tablename
SET datetime = date date_col + time time_col;

-- Convert in to cm 

UPDATE $tablename
SET (level, units) = (level*2.54, "cm")
WHERE trim(units) == 'in';
