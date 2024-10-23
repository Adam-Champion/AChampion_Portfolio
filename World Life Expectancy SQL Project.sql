#DATA CLEANING
SELECT *
FROM world_life_expectancy
;

# Looking for duplicates under the assumption that each county would only have 1 set of data each year.
# Both the country and year were merged to one field and a count generated to find any that appeared twice.
SELECT Country, Year, CONCAT(Country, Year), COUNT(CONCAT(Country, Year))
FROM world_life_expectancy
GROUP BY Country, Year, CONCAT(Country, Year)
HAVING COUNT(CONCAT(Country, Year)) > 1
;

# A function to allocate the duplicate rows with a 'row_Num and to find their Row_IDs.
SELECT *
FROM(
SELECT Row_ID,
	CONCAT(Country, Year),
	ROW_NUMBER() OVER( PARTITION BY CONCAT(Country, Year) ORDER BY CONCAT(Country, Year)) as row_Num
FROM world_life_expectancy) AS row_table
WHERE row_num > 1
;

# Deleting the duplicates using the previous function.
DELETE FROM world_life_expectancy
WHERE Row_ID IN (
SELECT Row_ID
FROM(
	SELECT Row_ID,
	CONCAT(Country, Year),
	ROW_NUMBER() OVER( PARTITION BY CONCAT(Country, Year) ORDER BY CONCAT(Country, Year)) as row_Num
	FROM world_life_expectancy) AS row_table
WHERE row_num > 1)
;

# Viewing all records where the Status was blank.
SELECT *
FROM world_life_expectancy
WHERE Status = ''
;

# Viewing The different vaules contained in the Status column.
SELECT DISTINCT(Status)
FROM world_life_expectancy
WHERE Status <> ''
;

# Views all countries with the Status of 'Developing'.
SELECT DISTINCT(Country)
FROM world_life_expectancy
WHERE Status = 'Developing'
;

# Joining the table onto itself so each row in table t1 is linked to each matching country row in table t2.alter
# Any blank Status row in t1 is then updated to 'Developing' where the t2.Status is not blank and is Developing.
UPDATE world_life_expectancy AS t1
JOIN world_life_expectancy AS t2
ON t1.Country = t2.Country
SET t1.Status = 'Developing'
WHERE t1.Status = ''
AND t2.Status <> ''
AND t2.Status = 'Developing'
;

# Same code as above, but for countries which have the status of Developed.
UPDATE world_life_expectancy AS t1
JOIN world_life_expectancy AS t2
ON t1.Country = t2.Country
SET t1.Status = 'Developed'
WHERE t1.Status = ''
AND t2.Status <> ''
AND t2.Status = 'Developed'
;

# Viewing any records where the Life expectancy column is blank.
SELECT Country, Year, `Life expectancy`
FROM world_life_expectancy
WHERE `Life expectancy` = ''
;

# Joining the table onto itself twice so that each row had the prior and future year.
# Using these, an average was calculated to be used to fill the blank Life expectancy.
SELECT t1.Country, t1.Year, t1.`Life expectancy`,
	t2.Country, t2.Year, t2.`Life expectancy`,
	t3.Country, t3.Year, t3.`Life expectancy`,
    ROUND((t2.`Life expectancy` + t3.`Life expectancy`)/2, 1)
FROM world_life_expectancy AS t1
JOIN world_life_expectancy AS t2
	ON t1.Country = t2.Country
	AND t1.Year = t2.Year - 1
JOIN world_life_expectancy AS t3
	ON t1.Country = t3.Country
	AND t1.Year = t3.Year + 1
WHERE t1.`Life expectancy` = ''
;

# Updating the blank Life expectancy with the average that was worked out previously.
UPDATE world_life_expectancy AS t1
JOIN world_life_expectancy AS t2
	ON t1.Country = t2.Country
	AND t1.Year = t2.Year - 1
JOIN world_life_expectancy AS t3
	ON t1.Country = t3.Country
	AND t1.Year = t3.Year + 1
SET t1.`Life expectancy` = ROUND((t2.`Life expectancy` + t3.`Life expectancy`)/2, 1)
WHERE t1.`Life expectancy` = ''
;

# Viewing the 'cleaned' world_life_expectancy table.
SELECT *
FROM world_life_expectancy
;

# EXPLORATORY DATA ANALYSIS
# Viewing the minimum and maximum Life expectancy for each Country, removing any which were 0.
# Then viewing the difference between the Max and Min.
SELECT Country,
MIN(`Life expectancy`),
MAX(`Life expectancy`),
ROUND(MAX(`Life expectancy`) - MIN(`Life expectancy`),1) AS life_increase_15_years
FROM world_life_expectancy
GROUP BY Country
HAVING MIN(`Life expectancy`) <> 0 AND MAX(`Life expectancy`) <> 0
ORDER BY life_increase_15_years DESC
;

#Viewing the average Life expectancy by year.
SELECT Year, ROUND(AVG(`Life expectancy`),2)
FROM world_life_expectancy
WHERE `Life expectancy` <> 0
GROUP BY Year
ORDER BY Year
;

# Viewing the average life expectancy and GDP of each country.
# Could order by GDP to see if there is a correlation between life expectancy and GDP.
SELECT Country, ROUND(AVG(`Life expectancy`),2) AS life_exp, ROUND(AVG(GDP),2) AS GDP
FROM world_life_expectancy
GROUP BY Country
HAVING life_exp > 0 AND GDP >0
;

# Comparing the life expectancy of around the top 50% of GDP countries with the bottom half.
SELECT
SUM(CASE WHEN GDP >= 1500 THEN 1 ELSE 0 END) AS high_GDP_count,
AVG(CASE WHEN GDP >= 1500 THEN `Life expectancy` ELSE NULL END) AS high_GDP_life_expectancy,
SUM(CASE WHEN GDP <= 1500 THEN 1 ELSE 0 END) AS low_GDP_count,
AVG(CASE WHEN GDP <= 1500 THEN `Life expectancy` ELSE NULL END) AS low_GDP_life_expectancy
FROM world_life_expectancy
;

# Comparing the life expectancy of a developing vs a developed country.
SELECT Status, COUNT(DISTINCT Country), ROUND(AVG(`Life expectancy`),1)
FROM world_life_expectancy
GROUP BY Status
;

# Comparing a countries average life expectancy to their BMI.
SELECT Country, ROUND(AVG(`Life expectancy`),2) AS life_exp, ROUND(AVG(BMI),2) AS BMI
FROM world_life_expectancy
GROUP BY Country
HAVING life_exp > 0 AND BMI >0
ORDER BY BMI DESC
;

# Viewing the rolling total of adult mortality for each country each year.
SELECT Country, Year, `Life expectancy`, `Adult Mortality`,
SUM(`Adult Mortality`) OVER(PARTITION BY Country ORDER BY Year) AS rolling_total
FROM world_life_expectancy
;