Select *
From Project_01..CovidDeaths
Order by 3, 4

Select *
From Project_01..CovidVaccinations
Order by 3, 4

-- Select Data that I'm going to be using
Select location, date, total_cases, new_cases, total_deaths, population
From Project_01..CovidDeaths
Order by 1, 2

-- Looking at Total Cases vs Total Deaths
Select location, date, total_deaths, total_cases, round((total_deaths/total_cases)*100,2) As DeathPercent
From Project_01..CovidDeaths
Order by 1, 2

-- Showing likelihood of dying if the person contract covid in the country
Select location, date, total_deaths, total_cases, round((total_deaths/total_cases)*100,2) As DeathPercentage
From Project_01..CovidDeaths
Where location like '%Canada%'
Order by DeathPercentage Desc

-- Looking at Total Cases vs Population
-- Show what percentage of population got Covid
Select location, date, total_cases, population, round((total_cases/population)*100,2) As PopulationGotCovidPercentage
From CovidDeaths
Where location = 'Canada'
Order by PopulationGotCovidPercentage Desc

-- Looking at countires with the highest infection rate compare to population
Select location,  Max(total_cases) As HighestInfectionCount, population,
		Round(Max((total_cases/population))*100,2) As PercentPopulationInfected
From CovidDeaths
Group by location, population
Order by PercentPopulationInfected Desc

-- Showing countries with the highest death count per population
-- Data Issue: total_deaths data type is nvarchar(255), so need to convert the data type to int using Cast
-- Data Issue: Some location shows continent instead of countries when continent field is null
Select location, Max(Cast(total_deaths As Int)) As TotalDeathCount
From CovidDeaths
Where continent Is Not Null 
Group by location
Order by TotalDeathCount Desc

-- Break things down by continent
Select continent, Max(Cast(total_deaths As Int)) As TotalDeathCount
From CovidDeaths
Where continent Is Not Null 
Group by continent
Order by TotalDeathCount Desc

Select location, Max(Cast(total_deaths As Int)) As TotalDeathCount
From CovidDeaths
Where continent Is Null AND location Not Like '%income%'
Group by location
Order by TotalDeathCount Desc

-- Break things down by income 
-- NOTES: The numbers doesn't make sense. Perhaps, low income deaths are not tracked.
Select location, Max(Cast(total_deaths As Int)) As TotalDeathCount
From CovidDeaths
Where continent Is Null AND location Like '%income%'
Group by location
Order by TotalDeathCount Desc

-- Showing continents with the highest death count per population
Select continent, Max(Cast(total_deaths As Int)) As TotalDeathCount
From CovidDeaths
Where continent Is Not Null
Group by continent
Order by TotalDeathCount Desc

-- Global Numbers
Select date, Sum(Cast(new_deaths As Int)) AS total_death, Sum(new_cases) As total_NewCase, Sum(Cast(new_deaths As Int))/Sum(new_cases)*100 As DeathPercentage
From Project_01..CovidDeaths
Where continent Is Not Null
Group by date
Order by 1, 2

Select Sum(Cast(new_deaths As Int)) AS total_death, Sum(new_cases) As total_NewCase, Sum(Cast(new_deaths As Int))/Sum(new_cases)*100 As DeathPercentage
From Project_01..CovidDeaths
Where continent Is Not Null
Order by 1, 2

-- Join tables
Select Top 1000 dea.continent, dea.location, dea.date, population, vac.new_vaccinations
From Project_01..CovidDeaths dea
	Join Project_01..CovidVaccinations vac
	ON dea.location = vac.location And dea.Date = vac.Date
Where dea.continent Is Not Null
Order by 2, 3

-- Looking at Total Population vs Vaccinations
-- Notes: Partition
-- Notes: Use Bigint b/c Arithmetic overflow error converting expression to data type int.
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
		Sum(Convert(Bigint, vac.new_vaccinations)) Over (Partition By dea.location Order by dea.location, dea.date) As RollingPeopleVaccinated
	From Project_01..CovidDeaths dea
	Join Project_01..CovidVaccinations vac
	ON (dea.location = vac.location And dea.Date = vac.Date)
Where dea.continent Is Not Null
Order by 2, 3

-- Use CTE/With Query for Population vs Vaccinations
WITH CTE_PopVsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
As
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
		Sum(Convert(Bigint, vac.new_vaccinations)) Over (Partition By dea.location Order by dea.location, dea.date) As RollingPeopleVaccinated
From Project_01..CovidDeaths dea
	Join Project_01..CovidVaccinations vac
	ON (dea.location = vac.location And dea.Date = vac.Date)
Where dea.continent Is Not Null
--Order by 2, 3 --The ORDER BY clause is invalid
)
Select *, RollingPeopleVaccinated/Population*100
From CTE_PopVsVac

-- Use Temp Table for Population vs Vaccinations
Drop Table If Exists #Temp_PercentPopulationVaccinated
Create Table #Temp_PercentPopulationVaccinated 
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert Into #Temp_PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
		Sum(Convert(Bigint, vac.new_vaccinations)) Over (Partition By dea.location Order by dea.location, dea.date) As RollingPeopleVaccinated
From Project_01..CovidDeaths dea
	Join Project_01..CovidVaccinations vac
	ON (dea.location = vac.location And dea.Date = vac.Date)
Where dea.continent Is Not Null

Select *, (RollingPeopleVaccinated/Population)*100
From #Temp_PercentPopulationVaccinated


-- Create View to store data for later visualizations
Create View PercentPopulationVaccinated As
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
		Sum(Convert(Bigint, vac.new_vaccinations)) Over (Partition By dea.location Order by dea.location, dea.date) As RollingPeopleVaccinated
From Project_01..CovidDeaths dea
	Join Project_01..CovidVaccinations vac
	ON (dea.location = vac.location And dea.Date = vac.Date)
Where dea.continent Is Not Null
--Order By 2, 3  -- The ORDER BY clause is invalid

Select *
From PercentPopulationVaccinated

--------- Create Procedure 2025-02-06 (Database: ANDREA\SQLEXPRESS.Project)
Create Procedure GetByContinetAndDate
@continent nvarchar(50),
@date Date
As
Begin
	Select *
	from CovidVaccinations
	where continent = @continent 
	and date > @date;
End;

--------- Execute Procedure 2025-02-06 NOTES: Validate the data SQL Server against Power BI Reports/Dashboards (accuracy and quality)
EXEC GetByContinetAndDate @continent = 'Europe', @date = '2021-09-01';
