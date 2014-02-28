#!/bin/bash

#Processing data for database entry
cd /var/www/sites/default/files/uploaded_data;
files=( *.txt )

if [ -r $files ];
#if [ "$files" == *.txt ];
then for file in "${files[@]}"; do
        #run postgres commands on processed file
	tablename=`echo $file | awk -F'_' '{print $1}' | sed 's/0000//'`
	tail -n +7 $file | grep --perl-regexp  -v "(0[1-9]|1[0-2])\/([0-2][0-9]|3[0-1])\/20[0-9]{2}" $file > /tmp/baddata && mv /tmp/baddata ./baddata/bad_$file
	if [ -f baddata/bad_$file  ]; then echo "Some bad rows were removed. See baddata directory";fi;
	tail -n +6 $file | grep --perl-regexp  "(0[1-9]|1[0-2])\/([0-2][0-9]|3[0-1])\/20[0-9]{2}"> /tmp/text && sudo mv /tmp/text up_$file
	
	dt=`sudo -u postgres psql -d drupal -t -c "SELECT a.field_model_value FROM field_data_field_model a LEFT JOIN field_data_field_serial b ON a.entity_id = b.entity_id WHERE b.field_serial_value = upper('$tablename') LIMIT 1;"`;
        datatype=${dt/" "/}
	case $datatype in

	"WM40"|"WM20" ) # Well START #
	
	#Adds columns calibration and retrival date
	calibration=`sudo -u postgres psql -d drupal -t -c "WITH calibration AS (
		SELECT a.field_calibration_value, a.entity_id, b.fid 
		FROM field_data_field_calibration a LEFT JOIN file_usage b  
		ON a.entity_id = b.id 
		GROUP BY a.entity_id, a.field_calibration_value, b.fid),
	file_id AS (
		SELECT d.field_calibration_value, d.fid, e.fid, e.filename
		FROM calibration d LEFT JOIN file_managed e
		ON d.fid = e.fid
		)
	SELECT cal.field_calibration_value, dat.field_date_of_retrieval_value FROM field_data_field_calibration cal 
		LEFT JOIN field_revision_field_date_of_retrieval dat ON cal.entity_id = dat.entity_id
	WHERE field_calibration_value IN (SELECT field_calibration_value f FROM file_id WHERE filename = '$file') LIMIT 1;"`
	
	cols=`echo $calibration | sed s/" | "/","/`
	awk -v d="$cols" '{print $1"," d};' up_$file > ready_$file | sed 's/                   //'
	rm up_$file
	newfile=ready_$file

	#Copies processed data into db	
	sudo -u postgres psql -c "
		CREATE TABLE IF NOT EXISTS well_$tablename ( ) INHERITS (wells);

		COPY well_$tablename (date_col, time_col, level, units,calibration,retrieval_date) FROM '/var/www/sites/default/files/uploaded_data/$newfile' 
		WITH ( FORMAT csv, HEADER );

		--populates a timestamp column
		UPDATE well_$tablename
		SET datetime = date_col + time_col
		WHERE datetime IS NULL;

		--converts all level data to cm
		UPDATE well_$tablename
		SET level = level * 2.54, units = 'cm'
		WHERE trim(units) = 'in';

		--deletes rows with incorrect calibrations
		DELETE FROM well_$tablename WHERE (datetime, retrieval_date) NOT IN (
		SELECT datetime, MIN(retrieval_date) FROM wells GROUP BY datetime
		);"

        #move raw data and porcessed data to storage locations
        mv ready_$file ./processed
        mv $file ./raw_archive
	;; # WELL END #
	
	# RAIN START #
	"RAIN" )
	#get date retrieved
	datret=`sudo -u postgres psql -d drupal -t -c "WITH one AS (
                SELECT a.field_date_of_retrieval_value, a.entity_id, b.fid
                FROM field_data_field_date_of_retrieval a LEFT JOIN file_usage b
                ON a.entity_id = b.id
                GROUP BY a.entity_id, a.field_date_of_retrieval_value, b.fid),
	file_id AS (
                SELECT d.field_date_of_retrieval_value, d.fid, e.fid, e.filename
                FROM one d LEFT JOIN file_managed e
                ON d.fid = e.fid
                )
        SELECT field_date_of_retrieval_value FROM file_id WHERE filename = '$file' LIMIT 1;"`

	sudo awk -v d="$datret" 'BEGIN{FS=","} {print d "," $1 "," $2 "," $3 } END{}' up_$file > ready_$file
	newfile=ready_$file
	rm up_$file

	sudo -u postgres psql -c "
		CREATE TABLE IF NOT EXISTS rain_$tablename ( ) INHERITS (rain);

		COPY rain_$tablename (retrieval_date, date_col, time_col, rainfall) FROM '/var/www/sites/default/files/uploaded_data/$newfile' 
		WITH ( FORMAT csv, HEADER );

		--populates a timestamp column
		UPDATE rain_$tablename
		SET datetime = date_col + time_col
		WHERE datetime IS NULL;

		--deletes rows with incorrect calibrations
		DELETE FROM rain_$tablename WHERE (datetime, retrieval_date) NOT IN (
		SELECT datetime, MIN(retrieval_date) FROM rain GROUP BY datetime
		);"
	
        #move raw data and porcessed data to storage locations
        mv ready_$file ./processed
        mv $file ./raw_archive
	
	;;	# RAIN END #
	esac;
done;
fi;
