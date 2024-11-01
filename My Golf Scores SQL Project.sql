# Viewing the rounds table after converting the Excel table to a CSV and using the import wizard
SELECT * 
FROM golf_scores.rounds;

# Manually creating the courses table, then using the import wizard to import the data
CREATE TABLE courses
(Course TEXT,
Hole INT,
Par INT,
Length INT,
Tee TEXT);

SELECT * 
FROM golf_scores.courses;

# Creating a copy of the raw data before cleaning incase the original is needed in the future
CREATE TABLE rounds_raw
LIKE rounds;

INSERT INTO rounds_raw
SELECT *
FROM rounds;

SELECT * 
FROM golf_scores.rounds_raw;


# DATA CLEANING - courses table
# Both tables do not have unique IDs, so I felt it is best to clean the data first before creating these
# Viewing the distinct course data and amending any that are incorrect
SELECT DISTINCT Course
FROM rounds;

UPDATE rounds
SET Course = 'Upchurch River Valley (South)'
WHERE Course = 'Upchurch River Valley (Soth)';

# Checking that all dates are between the start of 2024 and after the current date
# Initially the data was thought of as text, so I had to convert these to dates before filtering
UPDATE rounds
SET Date = STR_TO_DATE(DATE, '%d/%m/%Y');

SELECT *
FROM rounds
WHERE `Date` NOT BETWEEN '2024-01-01' AND curdate();

UPDATE rounds
SET `Date` = '2024-10-12'
WHERE `Date` = '2027-10-12';

# Checking that all the hole data was between 1 & 18, then updating
SELECT *
FROM rounds
WHERE Hole NOT BETWEEN 1 AND 18;

UPDATE rounds
SET Hole = 3
WHERE Hole = 33;

# Looking into Fairway_Hit & GIR to ensure they are consistent
SELECT DISTINCT Fairway_Hit
FROM rounds;

SELECT DISTINCT GIR
FROM rounds;

UPDATE rounds
SET Fairway_Hit = 'N'
WHERE Fairway_Hit = 'M';

UPDATE rounds
SET GIR = 'N'
WHERE GIR = 'M';

# I decided to Null the blank values in the GIR column as I felt they shouldn't be picked up by the calculations
UPDATE rounds
SET Fairway_Hit = null
WHERE Fairway_Hit = '';

# Finally the Putts column must be between 0 & 4, and any not within this range are amended
# After reviewing the data dictionary, I realised the range of 1-4 was incorrect
SELECT *
FROM rounds
WHERE Putts NOT BETWEEN 0 AND 4;

UPDATE rounds
SET Putts = 3
WHERE Putts = 5;

# I expect will be needed later to Join the tables
ALTER TABLE rounds
ADD COLUMN id TEXT;

UPDATE rounds
SET id = CONCAT(Course, Hole);

# Now all columns are cleaned I merged the Course, Hole & Date columns to create a filterable ID to check for duplicates
SELECT CONCAT(Course, Hole, Date), COUNT(CONCAT(Course, Hole, Date))
FROM rounds
GROUP BY CONCAT(Course, Hole, Date)
HAVING COUNT(CONCAT(Course, Hole, Date)) > 1;

# Where there was no unique reference in the table, it was difficult to delete the duplicate value.
# After trying CTEs, attempting to create an reference column using ROW_NUMBER, I managed to find a solution using a temporary table
# I had to copy all the data from my rounds table but with the addition of a row number column to generate my duplicate differentiator
# I then deleted all records from my rounds table, added a new column to match my temp table and inserted the temp data into the original table
# Finally to clean things up, I dropped the temp table and the column I was forced to add as it no longer provided any value
CREATE TEMPORARY TABLE temp_table
SELECT *
FROM(
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY CONCAT(Course, Hole, Date) ORDER BY CONCAT(Course, Hole, Date)) as row_Num
FROM rounds) AS row_table
WHERE row_num = 1;

DELETE FROM rounds;

ALTER TABLE rounds
ADD COLUMN ref INT;

INSERT INTO rounds
SELECT *
FROM temp_table;

DROP TABLE temp_table;

ALTER TABLE rounds
DROP COLUMN ref;

# To view the cleaned data
SELECT *
FROM rounds;


# DATA CLEANING - courses table
# Simple data checking functions to ensure the data was within the range set by the courses data dictionary
# A ref column was added to help with a join later on
SELECT DISTINCT Course
FROM courses;

SELECT *
FROM courses
WHERE Hole NOT BETWEEN 1 AND 18;

SELECT *
FROM courses
WHERE PAR NOT BETWEEN 3 AND 5;

ALTER TABLE courses
ADD COLUMN id TEXT;

UPDATE courses
SET id = CONCAT(Course, Hole);

SELECT *
FROM courses;


# DATA ANALYSIS
# Average length per hole of each course
SELECT Course, ROUND(AVG(Length),2) AS Average_Length
FROM courses
GROUP BY Course
ORDER BY Average_Length;

# Average hole length by Par
SELECT Par, ROUND(AVG(Length),2) AS Average_Length
FROM courses
GROUP BY Par
ORDER BY Par;

# Score each round
SELECT r.Course, Date, SUM(Score-Par) AS To_Par
FROM rounds AS r
JOIN courses AS c
ON r.id = c.id
GROUP BY r.Course, Date
ORDER BY Date DESC;

# Average scores based on Par of the hole
SELECT Par, ROUND(AVG(Score),2) AS Average_Score
FROM rounds AS r
JOIN courses AS c
ON r.id = c.id
GROUP BY Par
ORDER BY Par;


# AUTOMATED DATA CLEANING
ALTER TABLE rounds
ADD COLUMN `TimeStamp` TIMESTAMP DEFAULT NULL;

UPDATE rounds
SET `TimeStamp` = CURRENT_TIMESTAMP;

# Procedure used to automatically run some cleaning steps on new data from rounds_new table
DELIMITER $$
DROP PROCEDURE IF EXISTS copy_and_clean_data;
CREATE PROCEDURE copy_and_clean_data ()
BEGIN
# Copy data into 'cleaned' table
	INSERT INTO rounds
	SELECT *, CURRENT_TIMESTAMP
	FROM rounds_new;
        # DATA CLEANING - courses table
		UPDATE rounds_new
		SET Date = STR_TO_DATE(DATE, '%d/%m/%Y');

		UPDATE rounds_new
		SET Fairway_Hit = null
		WHERE Fairway_Hit = '';

		UPDATE rounds_new
		SET Fairway_Hit = 'N'
		WHERE Fairway_Hit = 'n';

		UPDATE rounds_new
		SET Fairway_Hit = 'Y'
		WHERE Fairway_Hit = 'y';

		UPDATE rounds_new
		SET GIR = 'N'
		WHERE GIR = 'n';

		UPDATE rounds_new
		SET GIR = 'Y'
		WHERE GIR = 'y';

		UPDATE rounds_new
		SET Putts = 4
		WHERE Putts > 4;

		ALTER TABLE rounds_new
		ADD COLUMN id TEXT;

		UPDATE rounds_new
		SET id = CONCAT(Course, Hole);

		# Removing duplicates
		CREATE TEMPORARY TABLE temp_table
		SELECT *
		FROM(
			SELECT *,
				ROW_NUMBER() OVER(PARTITION BY CONCAT(Course, Hole, Date) ORDER BY CONCAT(Course, Hole, Date)) as row_Num
			FROM rounds_new) AS row_table
		WHERE row_num = 1;

		DELETE FROM rounds_new;

		ALTER TABLE rounds_new
		ADD COLUMN ref INT;

		INSERT INTO rounds_new
		SELECT *
		FROM temp_table;

		ALTER TABLE rounds_new
		DROP COLUMN ref; 

END $$
DELIMITER ;

# Event to run the above procedure every week
CREATE EVENT run_data_cleaning
ON SCHEDULE EVERY 1 WEEK
DO CALL copy_and_clean_data ();