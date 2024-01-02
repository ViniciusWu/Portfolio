-- was testing my vscode setup
CREATE TABLE fodass( id SERIAL PRIMARY KEY);


COPY example_table (id, iso_code, continent, location, date, total_cases, new_cases, new_cases_smoothed, total_deaths, new_deaths, new_deaths_smoothed, total_cases_per_million, new_cases_per_million, new_cases_smoothed_per_million, total_deaths_per_million, new_deaths_per_million, new_deaths_smoothed_per_million,reproduction_rate, icu_patients, icu_patients_per_million, hosp_patients, hosp_patients_per_million, weekly_icu_admissions, weekly_icu_admissions_per_million, weekly_hosp_admissions, weekly_hosp_admissions_per_million, population)                                                    
FROM '/Users/vinicius/Desktop/new_covid_deaths.csv'
DELIMITER ','    
CSV HEADER ;



SELECT *
FROM example_table
ORDER BY 1,2
LIMIT 1000;

-- 01 Looking at Total Cases against Total Deaths
-- Shows the likelihood of dying if you contract covid in your pg_index_column_has_property

SELECT location, date, total_cases, total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS float))*100 AS DeathPercentage
FROM example_table
WHERE total_cases <> 0 AND location = 'Canada'
ORDER BY 1,2
LIMIT 1000;


-- 02 Total Cases vs Population


SELECT location, date, total_cases, population, (CAST(total_cases AS float)/CAST(population AS float))*100 AS InfectionPercentage
FROM example_table
WHERE total_cases <> 0 AND location = 'Canada'
ORDER BY 1,2
LIMIT 1000;

-- 03 Countries with Highest Infection Rate compared to Population


SELECT location,population ,MAX(total_cases) AS HighestInfectionCount,  MAX((CAST(total_cases AS float)/CAST(population AS float))*100) AS InfectionPercentage
FROM example_table
WHERE total_cases <> 0
GROUP BY location, population
ORDER BY InfectionPercentage DESC
LIMIT 1000;

-- Countries with highest death count per population
-- where continent is 0 is a wrap up of continent for that reason we take them out
SELECT location, MAX(total_deaths) AS TotaltDeathCount
FROM example_table
WHERE continent <> '0'
GROUP BY location
ORDER BY  TotaltDeathCount DESC
LIMIT 1000;

-- Breaking down for continent
SELECT continent, MAX(total_deaths) AS TotaltDeathCount
FROM example_table
WHERE continent <> '0'
GROUP BY continent
ORDER BY  TotaltDeathCount DESC
LIMIT 1000;

-- Region breakdown
SELECT location, MAX(total_deaths) AS TotaltDeathCount
FROM example_table
WHERE continent = '0'
GROUP BY location
ORDER BY  TotaltDeathCount DESC
LIMIT 1000;

-- Global numbers 
SELECT date, SUM(new_cases) AS TotalCases, SUM(new_deaths) AS TotalDeaths, SUM(new_deaths)/SUM(new_cases) AS DeathPercentage
FROM example_table
WHERE new_cases <> 0
GROUP BY date
ORDER BY 1,2;

-- Vaccination table join

SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations
FROM example_table As d
JOIN covid_vac AS v
ON d.date = v.date 
AND d.location = v.location
WHERE d.continent <> '0' AND d.location = 'Canada'
ORDER BY 1,2
LIMIT 1000;

-- Total by country of vaccinations (Overall)
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations
,SUM(v.new_vaccinations) OVER (PARTITION BY d.location) AS TotalbyCountry
FROM example_table As d
JOIN covid_vac AS v
ON d.date = v.date 
AND d.location = v.location
WHERE d.continent <> '0'
ORDER BY 1,2
LIMIT 1000;

-- Total by country of vaccinations (Rolling Sum)
-- Ordering by location and date break it down the window FUNCTION
-- and make a adding up effect to the final that we will find the total for the country

SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations
,SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location,d.date) AS RollingSum
FROM example_table As d
JOIN covid_vac AS v
ON d.date = v.date 
AND d.location = v.location
WHERE d.continent <> '0'
ORDER BY 2,3
LIMIT 1000;

---- find the vaccinated to population ratio using CREATE
WITH vac_percent (continent, location, date, population,
                 new_vac, RollingSum)
AS
(

SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations
,SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location,d.date) AS RollingSum
FROM example_table As d
JOIN covid_vac AS v
ON d.date = v.date 
AND d.location = v.location
WHERE d.continent <> '0'
)
SELECT *,(RollingSum/population)*100 AS VaccinatedPercentage
FROM vac_percent
ORDER BY 2,3
LIMIT 1000;

---- find the vaccinated to population ratio using Temp table_am_handler_in
DROP TABLE IF EXISTS VacPercentage;

    -- Create temporary table VacPercentage
CREATE TEMPORARY TABLE VacPercentage AS
SELECT
    d.continent,
    d.location,
    d.date,
    d.population,
    v.new_vaccinations,
    SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.date) AS RollingSum
FROM
    example_table AS d
JOIN
    covid_vac AS v ON d.date = v.date AND d.location = v.location
WHERE
    d.continent <> '0';

    -- Select data from VacPercentage with vaccination percentage calculation
SELECT
    *,
    (RollingSum / population) * 100 AS VaccinatedPercentage
FROM
    VacPercentage
ORDER BY
    location,
    date
LIMIT
    1000;


-- Creating View to store data for visualizations

--Vaccinate percentage CTE as a view
CREATE VIEW VaccinatePercentage AS
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations
,SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location,d.date) AS RollingSum
FROM example_table As d
JOIN covid_vac AS v
ON d.date = v.date 
AND d.location = v.location
WHERE d.continent <> '0'

--
