/*
Cookie Data Exploration, SQL Queries by Andrea Chen.

Create Table, Import/Update Data from an Excel File to the existing SQL Table, Add a column, Insert the data to a new column, Drop a column, 
Check the file's total row is updated correctly, Clean/Delete all data in the existing table. If it requires to update the whole table 
again from the Excel file, import the updated Excel file and then insert all data into the empty SQL table,
Aggregate Functions, Partition By, CTE's (With Query), Create Temp Table, Create Views, Create Procedure w/ or w/o parameter(s), 
Case, Having

Fictional Raw Dataset Source by Kevin Stratvert:
*/
-------------------------------------------------------------------------------------
-- 1. Create Table

Create Table CookieOrder
(OrderID Int not null Primary Key,
CustomerID Int not null,
Product nvarchar(255),
UnitsSold numeric,
Ddate datetime)

---------------------------------------------------------------------------------------
-- 2. Before running the Insert statement, import "Order" Excel file to the SQL Sever. Assume that this Excel file will be updated 
-- weekly/monthly, so ensure the format is the same. If the updated Excel file name is same, during importing process, select 
-- Edit Mappings "delete row in the destination table". Of course, writing a query to clean all old data imported from the previous version
-- of Excel is another approach. There are other options.
-- Highlight Database -> Tasks -> Import Data, This is not working for me, so I have to go to MS SQL Server under All Apps -> 
-- Import/Export Data (64-bit). 

Insert Into CookieOrder
Select *
From [dbo].[Orders]

---------------------------------------------------------------------------------------
-- 3. Add a column

Alter Table CookieOrder
Add Date datetime


---------------------------------------------------------------------------------------
-- 4. Insert values to the new column just created.

Update CookieOrder
Set Date = Orders.Date
From Orders

---------------------------------------------------------------------------------------
-- 5. Drop Column

Alter Table CookieOrder
Drop Column Ddate

---------------------------------------------------------------------------------------
-- 6. The information about how many rows/records in the file could be useful when the file is huge or try to consolidate data.

Select count(*)
From CookieOrder

---------------------------------------------------------------------------------------
-- 7. Be very careful to try to DELETE all values in the table. If the Excel file is only appending new data, do not delete the values 
-- in the table. Only use this approach When the Excel file includes all historical data and new updates. 
-- Notes: If the Excel only includes new updates, then try to UPDATE, don't delete all values in the table.

Delete From [dbo].[CookieOrder]
Where [date] is not null

Select *
From CookieOrder

Select count(*)
From CookieOrder

---------------------------------------------------------------------------------------
-- 8. After DELETE all values in the table INSERT all data again.

Insert into CookieOrder
Select *
From Orders

---------------------------------------------------------------------------------------
-- **9. Total Units Sold by Product(Cookie) Types? (This information may be useful for the sales/marketing, marmanufactory, inventory, etc.)
-- -- GROUP BY normally reduces the number of rows returned by rolling them up and calculating averages or sums for each row. It does not need to use DISTINCT.


Select Product,Sum(UnitsSold) As TotalUnitsSold
From CookieOrder
Group By Product
Order By 2 Desc

Select Distinct Product,
Sum(UnitsSold) OVER (Partition BY Product Order By Product) As TotalUnitsSold
From CookieOrder
Order By 2 Desc


Select Product,
Sum(UnitsSold) OVER (Partition BY Product Order By Product) As TotalUnitsSold
From CookieOrder
Order By 2 Desc

---------------------------------------------------------------------------------------
-- 10. Max Units of Cookie sold in one day? (This information may be useful for the marketing, manufactory and inventory.)

Select Product, Date, Max(UnitsSold) MaxUnitsSoldDayByProduct
From CookieOrder
Group By Product, Date
Order By 2 Desc


Select Distinct Product, Date,
Max(UnitsSold) Over (Partition By Product, Date Order By Product) MaxUnitsSoldDayByProduct
From CookieOrder
Order By 2 Desc

---------------------------------------------------------------------------------------
-- 11. CTEs(With Query and Create Temp Table. Gross Revenue and Net Revenue by cookie type

Select *
From CookieTypes

Select Count(*)
From CookieOrder

With UnitAndRevenue
As
(
Select *
From CookieOrder ord
Join CookieTypes typ
ON ord.Product = typ.CookieType
)
Select *, 
Convert(Money, UnitsSold*RevenuePerCookie) GrossRevenuePerDay, 
Convert(Money, UnitsSold*(RevenuePerCookie - CostPerCookie)) NetRevenuePerDay
From UnitAndRevenue


Drop Table If Exists #TempUnitAndRevenue
Create Table #TempUnitAndRevenue
(OrderID Int,
CustomerID Int,
Product nvarchar(255),
UnitsSold numeric,
Date datetime,
CookieType nvarchar(255),
RevenuePerCookie money,
CostPerCookie money,
GrossRevenuePerDay money,
NetRevenuePerDay money
)


Insert Into #TempUnitAndRevenue
Select *,
Convert(Money, UnitsSold*RevenuePerCookie) Gross, 
Convert(Money, UnitsSold*(RevenuePerCookie - CostPerCookie)) Net
From CookieOrder ord
Join CookieTypes typ
ON ord.Product = typ.CookieType


Select *
From #TempUnitAndRevenue

Select Product, GrossRevenuePerDay, NetRevenuePerDay
From #TempUnitAndRevenue

Select Product, Sum(GrossRevenuePerDay) TotalGrossRevenue, Sum(NetRevenuePerDay) TotalNetRevenue
From #TempUnitAndRevenue
Group By Product
Order By 3 Desc

---------------------------------------------------------------------------------------
-- 12. Create View

Create View vCookie
As
Select OrderID, UnitsSold, Date, CookieType, RevenuePerCookie, CostPerCookie, 
Convert(Money, UnitsSold*RevenuePerCookie) GrossRevenue,
Convert(Money, UnitsSold*(RevenuePerCookie - CostPerCookie)) NetRevenue,
ord.CustomerID, Name, Phone, Address, City, [State/Province], Zip, Country, Notes
From CookieOrder ord
Join CookieTypes typ
ON ord.Product = typ.CookieType
Left Outer Join CookieCustomer cus
ON ord.CustomerID = cus.CustomerID

Select Count(*)
From vCookie

Select *
From vCookie

Select Product, Sum(GrossRevenuePerDay) TotalGrossRevenue, Sum(NetRevenuePerDay) TotalNetRevenue
From #TempUnitAndRevenue
Group By Product

Select CookieType, Sum(GrossRevenue) TotalGrossRevenue, Sum(NetRevenue) TotalNetRevenue
From vCookie
Group By CookieType

--Create View vCookie2
--As 
--Select *
--From CookieOrder ord
--Join CookieTypes typ
--ON ord.Product = typ.CookieType

--Select *
--From vCookie2

--Drop View vCookie2

---------------------------------------------------------------------------------------
-- 13. The customer(s) generated the highest Gross Revenue and Net Revenue


Select Name Customer, Sum(GrossRevenue) TotalGrossRevenue, Sum(NetRevenue) TotalNetRevenue
From vCookie
Group By Name
Order by 2 Desc;


Select Customer, TotalGrossRevenue, TotalNetRevenue
From(
	Select Name Customer,
	Sum(GrossRevenue) TotalGrossRevenue,
	Sum(NetRevenue)TotalNetRevenue,
	Rank() Over (Order By Sum(GrossRevenue) Desc) RankGross, 
	Rank() Over (Order By Sum(NetRevenue) Desc) RankNet
        From vCookie
	Group By Name
    )t
Where RankGross = 1 And RankNet = 1



-------------------------------------------------------------------------------------------------------
-- 14. Create Procedure. Revenue by customer and by type see Procedure pCookie2


Create Procedure Test
As
Select *
From vCookie

Exec Test

Drop Procedure Test

-- Should execute Create + Insert + Select together. Otherwise, Exec may get no result.
--
Create Procedure pCookie
As
Create Table #TempCookie
(OrderID Int,
CustomerID Int,
Product nvarchar(255),
UnitsSold numeric,
Date datetime,
CookieType nvarchar(255),
RevenuePerCookie money,
CostPerCookie money,
GrossRevenuePerDay money,
NetRevenuePerDay money
)

Insert Into #TempCookie
Select *,
Convert(Money, UnitsSold*RevenuePerCookie) Gross, 
Convert(Money, UnitsSold*(RevenuePerCookie - CostPerCookie)) Net
From CookieOrder ord
Join CookieTypes typ
ON ord.Product = typ.CookieType

Select *
From #TempCookie


Exec pCookie


--Drop Procedure pCookie2
Create Procedure pCookie2
AS
Create Table #TempCookie2
(CustomerID Int,
Customer nvarchar(255),
CookieType nvarchar(255),
TotalGrossRevenue money,
TotalNetRevenue money
)

Insert Into #TempCookie2
Select ord.CustomerID, Name, CookieType, 
Sum(Convert(Money, UnitsSold*RevenuePerCookie)) TotalGrossRevenue,
Sum(Convert(Money, UnitsSold*(RevenuePerCookie - CostPerCookie))) TotalNetRevenue 
From CookieOrder ord
Join CookieTypes typ
ON ord.Product = typ.CookieType
Left Outer Join CookieCustomer cus
ON ord.CustomerID = cus.CustomerID
Where Date Between '2019-01-01' And '2021-01-01'
Group By ord.CustomerID, Name, CookieType

Select *
From #TempCookie2

--

Exec pCookie2


-- Modify Procedure such as adding a parameter (Programmability -> Highlight the stored procedure -> Modify ...) 
-- To test the syntax, on the Query menu, select "Parse". "Execute" to save the updated Procedure. 

USE [SQL Tutorial]
GO
/****** Object:  StoredProcedure [dbo].[pCookie2]    Script Date: 2022-01-12 7:53:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER Procedure [dbo].[pCookie2]
@CustomerID
AS
Create Table #TempCookie2
(CustomerID Int,
Customer nvarchar(255),
CookieType nvarchar(255),
TotalGrossRevenue money,
TotalNetRevenue money
)

Insert Into #TempCookie2
Select ord.CustomerID, Name, CookieType, 
Sum(Convert(Money, UnitsSold*RevenuePerCookie)) TotalGrossRevenue,
Sum(Convert(Money, UnitsSold*(RevenuePerCookie - CostPerCookie))) TotalNetRevenue 
From CookieOrder ord
Join CookieTypes typ
ON ord.Product = typ.CookieType
Left Outer Join CookieCustomer cus
ON ord.CustomerID = cus.CustomerID
Where Date Between '2019-01-01' And '2021-01-01' And org.CustomerID = @CustomerID
Group By ord.CustomerID, Name, CookieType

Select *
From #TempCookie2

-------------

Exec pCookie2 @CustomerID = 1



-------------------------------------------------------------------------------------------------------------------
-- 16. Case ..When..Then..Else..End As.   Having
-- Verity results in SQL Query vs Power Pivot/Power BI. Count(Distinct Column_Name), 

Select *
From vCookie

Select CookieType, Sum(NetRevenue) TotalNetRevenue, Sum(UnitsSold) TotalUnitSold
From vCookie
Group By CookieType
Order By 2 Desc

Select Sum(NetRevenue) TotalNetRevenue, Sum(NetRevenue)/Count(Distinct Name) AvgNetRevenuePerCustomer 
From vCookie

Select Name Customer, Sum(NetRevenue) TotalNetRevenue
From vCookie
Group By Name
Order By 2 Desc

Select Name Customer, 
Case 
When Sum(NetRevenue) >= 543420.83 Then 'Meet or Above Goal'
Else 'Below Goal' 
End KPI
From vCookie
Group By Name
Order By 2 Desc

Select Name Customer, Sum(NetRevenue) TotalNetRevenue
From vCookie
Group By Name
Having Sum(NetRevenue) >= 543420.83 -- Aggregation may not appear in Where, Where is before group, Haivng is after group
Order By 2 Desc

