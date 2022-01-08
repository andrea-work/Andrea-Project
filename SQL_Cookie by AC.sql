/*
Cookie Data Exploration, SQL Queries by Andrea Chen.

Create Table, Update Data from Excel File to the existing SQL Table, Add Column, Insert data to the new column, Drop column,
Check the file total row is accurate, Clean/Delete all data in the existing table if need to update the whold table again from Excel file,
Import the updated Excel file and Insert all data into the empty SQL table,
Aggregate Functions, Partition By, CTE's (With Query), Create Temp Table, Create Views, 
Create Procedure w/ or w/o parameter(s), Case, Having

Row Date Source by Kevin Stratvert:
https://onedrive.live.com/?authkey=%21AMGFcNnnBmsa3Js&id=B09F9559F6A16B6C%2171378&cid=B09F9559F6A16B6C
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
-- 2. Before running the Insert statement, import "Order" Excel file to SQL Sever. This the Excel file will be updated weekly/monthly, so ensure the format is the same. If the updated Excel file name is same, during importing process, select Edit Mappings "delete row in the desination table".) 

Insert Into CookieOrder
Select *
From [dbo].[Orders]

---------------------------------------------------------------------------------------
-- 3. Add column

Alter Table CookieOrder
Add Date datetime


---------------------------------------------------------------------------------------
-- 4. Insert value to column

Update CookieOrder
Set Date = Orders.Date
From Orders

---------------------------------------------------------------------------------------
-- 5. Drop column

Alter Table CookieOrder
Drop Column Ddate

---------------------------------------------------------------------------------------
-- 6. How many record int the file which could be useful when the file is huge.

Select count(*)
From CookieOrder

---------------------------------------------------------------------------------------
-- 7. Be very careful to try this. Delete all value in table. If the Excel file is not just appending new data. It also includes all historical data updates and new updates. Clean the all table before Insert new data.
-- Notes: If the Excel only includes partial historical updates and new updates, then try Update, don't delete all values in the table.

Delete From [dbo].[CookieOrder]
Where [date] is not null

Select *
From CookieOrder

Select count(*)
From CookieOrder

---------------------------------------------------------------------------------------
-- 8. After clean the table INSERT all data again.

Insert into CookieOrder
Select *


From Orders

---------------------------------------------------------------------------------------
-- 9. Cookie sold by total units? (This information may be useful for the marketing, marmanufactory and inventory. )

Select Distinct Product, 
Sum(UnitsSold) Over (Partition By (Product) Order By Product) TotalUnitsSold
From CookieOrder	
Order By 2 Desc

---------------------------------------------------------------------------------------
-- 10. Cookie sold by Max units sold that day? (This information may be useful for the marketing, manufactory and inventory.)

Select Distinct Product, 
Max(UnitsSold) Over (Partition By (Product) Order By Product) MaxUnitsSoldDay
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

Select Distinct Product, Sum(GrossRevenuePerDay) TotalGrossRevenue, Sum(NetRevenuePerDay) TotalNetRevenue
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

---------------------------------------------------------------------------------------
-- 13. The customer(s) generated the highest Gross Revenue and Net Revenue

Select Name Customer, Sum(GrossRevenue) TotalGrossRevenue, Sum(NetRevenue) TotalNetRevenue
From vCookie
Group By Name
Order by 2 Desc


-------------------------------------------------------------------------------------------------------
-- 14. Create Procedure. Revenue by customer and by type see Procedure pCookie2

Create Procedure Test
As
Select *
From vCookie

Exec Test

Drop Procedure Test

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
--
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


Exec pCookie2

------------------------------------------------------------------------------------------------
-- 15. Alter Procedure by opening Modify window
USE [SQL Tutorial]
GO
/****** Object:  StoredProcedure [dbo].[pCookie2]    Script Date: 2021-12-28 3:18:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER Procedure [dbo].[pCookie2]
@CustomerID Int
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
Where Date Between '2019-01-01' And '2021-01-01' And ord.CustomerID = @CustomerID
Group By ord.CustomerID, Name, CookieType

Select *
From #TempCookie2

--

Exec pCookie2 @CustomerId = 2


-------------------------------------------------------------------------------------------------------------------
-- 16. Case ..When..Then..Else..End As.   Having
-- Verity results in SQL Query vs Power Pivot/Power BI. Count(Distinct Column_Name), 

Select *
From vCookie

Select CookieType, Sum(NetRevenue) TotalProfit, Sum(UnitsSold) TotalUnitSold
From vCookie
Group By CookieType
Order By 2 Desc

Select Sum(NetRevenue) TotalNetRevenue, Sum(NetRevenue)/Count(Distinct Name) AvgNetRevenuePerCustomer 
From vCookie

Select Name Customer, Sum(NetRevenue) TotalProfit
From vCookie
Group By Name
Order By 2 Desc

Select Name Customer, 
Case 
When Sum(NetRevenue) >= 543420.83 Then 'Meet or Above Average'
Else 'Below Average' 
End KPI
From vCookie
Group By Name
Order By 2 Desc

Select Name Customer, Sum(NetRevenue) TotalProfit
From vCookie
Group By Name
Having Sum(NetRevenue) >= 543420.83 -- Aggregation may not appear in Where, Where is before group, Haivng is after group
Order By 2 Desc

