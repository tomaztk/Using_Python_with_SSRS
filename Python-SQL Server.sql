/*

Desc: Using Python with Microsoft Reporting Services (SSRS)
Author: Tomaz Kastrun
Blog: http://tomaztsql.wordpress.com
Date: 15.11.2018

*/

USE SQLPY;
GO

-- Selecting Python results with SSRS


-- Check Python runtime
EXECUTE sp_execute_external_script
	 @language =N'Python'
	,@script=N'OutputDataSet = InputDataSet'
	,@input_data_1 = N'SELECT 1 AS result'
WITH RESULT SETS
((
	result INT
))
GO


--- Check query
SELECT 
	 COUNT(*) AS nof
	,MaritalStatus
	,age 

FROM AdventureWorksDW2014.dbo.vTargetMail
WHERE
	age < 100
GROUP BY 
	maritalstatus
	,age


-- query parametrization
DECLARE @MaritalStatusIN CHAR(1) = 'S' -- S/M Single/Married

EXECUTE sp_execute_external_script
@language =N'Python',
@script = N'
import pandas as pd
df = InputDataSet
#df_gender = df[''MaritalStatus''] == "M"
df_gender = df[''MaritalStatus''] == MaritalStatus
df_gen = df[df_gender]
correlation = df_gen.corr(method=''pearson'')
#OutputDataSet = correlation.iloc[1][0]
OutputDataSet = pd.DataFrame(correlation, columns=["nof","age"])
',
 @input_data_1 = N'SELECT 
			 COUNT(*) AS nof,MaritalStatus,age 
		FROM AdventureWorksDW2014.dbo.vTargetMail
		WHERE age < 100
		GROUP BY maritalstatus,age'
,@params = N'@MaritalStatus CHAR(1)'
,@MaritalStatus = @MaritalStatusIN

WITH RESULT SETS 
	(( 
	 CountObs FLOAT
	,Age FLOAT 
	));
GO


--- creating procedure

CREATE PROCEDURE selectingPYthonResults
	@MaritalStatusIN CHAR(1) 
AS
BEGIN

EXECUTE sp_execute_external_script
@language =N'Python',
@script = N'
import pandas as pd
df = InputDataSet
#df_gender = df[''MaritalStatus''] == "M"
df_gender = df[''MaritalStatus''] == MaritalStatus
df_gen = df[df_gender]
correlation = df_gen.corr(method=''pearson'')
#OutputDataSet = correlation.iloc[1][0]
OutputDataSet = pd.DataFrame(correlation, columns=["nof","age"])
',
 @input_data_1 = N'SELECT 
			 COUNT(*) AS nof,MaritalStatus,age 
		FROM AdventureWorksDW2014.dbo.vTargetMail
		WHERE age < 100
		GROUP BY maritalstatus,age'
,@params = N'@MaritalStatus CHAR(1)'
,@MaritalStatus = @MaritalStatusIN

WITH RESULT SETS 
	(( 
	 CountObs FLOAT
	,Age FLOAT 
	))
END


EXEC SelectingPythonResults
	@MaritalStatusIN = 'S'


SELECT  MaritalStatus 
FROM AdventureWorksDW2014.dbo.vTargetMail
GROUP BY MaritalStatus