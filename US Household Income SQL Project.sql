# DATA CLEANING
SELECT *
FROM us_project.us_household_income;

SELECT *
FROM us_project.us_household_income_statistics;

# Renaming a column so that it is more managable.
ALTER TABLE us_household_income_statistics
RENAME COLUMN `ï»¿id` TO id;

# Checking us_household_income for duplicates.
SELECT id, COUNT(id)
FROM us_household_income
GROUP BY id
HAVING COUNT(id) > 1;

# Allocating each duplicate a row number of 2.
SELECT *
FROM (
SELECT row_id,
	id,
	ROW_NUMBER() OVER(PARTITION BY id ORDER BY id) AS row_num
FROM us_household_income) AS row_table
WHERE row_num > 1;

# Deleting the duplicates using the previous function.
DELETE FROM us_household_income
WHERE row_id IN (
	SELECT row_id
	FROM (
		SELECT row_id,
		id,
		ROW_NUMBER() OVER(PARTITION BY id ORDER BY id) AS row_num
		FROM us_household_income) AS row_table
	WHERE row_num > 1);

# Checking 2nd table for duplicates.
SELECT id, COUNT(id)
FROM us_household_income_statistics
GROUP BY id
HAVING COUNT(id) > 1;

# Checking state name for errors.
SELECT DISTINCT State_Name
FROM us_household_income;

# Amending an incorrect state name.
UPDATE us_household_income
SET State_Name = 'Georgia'
WHERE State_Name = 'georia';

UPDATE us_household_income
SET State_Name = 'Alabama'
WHERE State_Name = 'alabama';

# Checking each field for blank values, 1 found in Place.
SELECT *
FROM us_household_income
WHERE City = '';

UPDATE us_household_income
SET Place = 'Autaugaville'
WHERE County = 'Autauga County' AND City = 'Vinemont';

# Investigating the Type field for errors.
SELECT Type, COUNT(Type)
FROM us_household_income
GROUP BY Type
ORDER BY Type;

# Correcting a duplication error.
UPDATE us_household_income
SET Type = 'Borough'
WHERE Type = 'Boroughs';

# Investigating if there are errors in either area column.
SELECT ALand, AWater
FROM us_household_income
WHERE (ALand = 0 OR ALand = '' OR ALand IS NULL)
AND (AWater = 0 OR AWater = '' OR AWater IS NULL);


# EXPLORATORY DATA ANALYSIS
# Investigating the States with the largest areas of land or water.
SELECT State_Name, SUM(ALand), SUM(AWater)
FROM us_household_income
GROUP BY State_Name
ORDER BY SUM(ALand) DESC
LIMIT 10;

SELECT State_Name, SUM(ALand), SUM(AWater)
FROM us_household_income
GROUP BY State_Name
ORDER BY SUM(AWater) DESC
LIMIT 10;

# Inner join used as a number of us_household_income records did not import due to their errors.
# us_household_income_statistics records without Mean data were also filtered out.
SELECT *
FROM us_household_income AS u
INNER JOIN us_household_income_statistics AS us
ON u.id = us.id
WHERE Mean <> 0;

# Investigating the mean and median of each State.
SELECT u.State_Name, ROUND(AVG(Mean),2), ROUND(AVG(Median),2)
FROM us_household_income AS u
INNER JOIN us_household_income_statistics AS us
	ON u.id = us.id
WHERE Mean <> 0
GROUP BY u.State_Name
ORDER BY 2
LIMIT 5;

SELECT u.State_Name, ROUND(AVG(Mean),2), ROUND(AVG(Median),2)
FROM us_household_income AS u
INNER JOIN us_household_income_statistics AS us
	ON u.id = us.id
WHERE Mean <> 0
GROUP BY u.State_Name
ORDER BY 2 DESC
LIMIT 10;

# Investigating the mean and median of each Type of State.
SELECT Type, COUNT(Type), ROUND(AVG(Mean),2), ROUND(AVG(Median),2)
FROM us_household_income AS u
INNER JOIN us_household_income_statistics AS us
	ON u.id = us.id
WHERE Mean <> 0
GROUP BY Type
HAVING COUNT(Type) > 100
ORDER BY 3 DESC;

# Investigating the Cities with the highest mean and median.
SELECT u.State_Name, City, ROUND(AVG(MEAN),1), ROUND(AVG(Median),1)
FROM us_household_income AS u
INNER JOIN us_household_income_statistics AS us
	ON u.id = us.id
GROUP BY u.State_Name, City
ORDER BY ROUND(AVG(MEAN),1) DESC;