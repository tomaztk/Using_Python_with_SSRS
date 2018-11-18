/*

Desc: Using Python with Microsoft Reporting Services (SSRS)
Author: Tomaz Kastrun
Blog: http://tomaztsql.wordpress.com
Date: 15.11.2018

*/

USE SQLPY;
GO

--------------------------------------
-- Selecting Python results with SSRS
--------------------------------------

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


-- Executing SP
EXEC SelectingPythonResults
	@MaritalStatusIN = 'S'


----------------------------------------------
-- Predicting and scoring with Python in SSRS
----------------------------------------------



--- Query for scoring the model
SELECT 
	 age 
	,NumberCarsOwned AS nofCars
	,CAST(REPLACE(LEFT(CommuteDistance,2),'-','') AS TINYINT) as CommuteDistance

FROM AdventureWorksDW2014.dbo.vTargetMail
WHERE
	age < 100


--- CREATE view 
CREATE VIEW vTargetMail 
AS
SELECT 
	 age 
	,NumberCarsOwned AS nofCars
	,CAST(REPLACE(LEFT(CommuteDistance,2),'-','') AS TINYINT) as CommuteDistance

FROM AdventureWorksDW2014.dbo.vTargetMail
WHERE
	age < 100


-- creating table for storing models
DROP TABLE IF EXISTS PredictingWithPy_models;

CREATE TABLE PredictingWithPy_models
(model VARBINARY(MAX)
,modelName VARCHAR(100)
,trainSize FLOAT
)


-- CREATE Procedure for storing the models based on the test size of the dataset
CREATE OR ALTER PROCEDURE [dbo].[RunningPredictionsPy] 
(
	@size FLOAT   --- format: 0.3 or 0.4 or 0.5 
   ,@name VARCHAR(100) 
   ,@trained_model varbinary(max) OUTPUT
	)
AS
BEGIN

EXEC sp_execute_external_script
  @language = N'Python'
  ,@script = N'
import numpy as np
import pandas as pd
import pickle
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split

##Create SciKit-Learn linear regression model
X = df2[["age", "CommuteDistance"]]
y = np.ravel(df2[["nofCars"]])

name = name

##Create training (and testing) variables based on test_size
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=size)

## CreateLinear Model
SKL_lr = LinearRegression()
linRegObj = SKL_lr.fit(X_train, y_train)

##Serialize model
trained_model = pickle.dumps(linRegObj)'

,@input_data_1 = N'SELECT * FROM vTargetMail'
,@input_data_1_name = N'df2'
,@params = N'@trained_model varbinary(max) OUTPUT, @size FLOAT, @name VARCHAR(100)'
,@trained_model = @trained_model OUTPUT
,@size = @size
,@name = @name

END;
GO


-- Loading models

DECLARE @model VARBINARY(MAX);
EXEC [RunningPredictionsPy] 
	@size = 0.2  
   ,@name = 'Ln_20'
   ,@trained_model = @model OUTPUT
INSERT INTO PredictingWithPy_models (model, modelName, trainSize) VALUES(@model, 'Ln_20', 0.2);
GO

DECLARE @model VARBINARY(MAX);
EXEC [RunningPredictionsPy] 
	@size = 0.3  
   ,@name = 'Ln_30'
   ,@trained_model = @model OUTPUT
INSERT INTO PredictingWithPy_models (model, modelName, trainSize) VALUES(@model, 'Ln_30', 0.3);
GO

DECLARE @model VARBINARY(MAX);
EXEC [RunningPredictionsPy] 
	@size = 0.4  
   ,@name = 'Ln_40'
   ,@trained_model = @model OUTPUT
INSERT INTO PredictingWithPy_models (model, modelName, trainSize) VALUES(@model, 'Ln_40', 0.4);
GO

DECLARE @model VARBINARY(MAX);
EXEC [RunningPredictionsPy] 
	@size = 0.5  
   ,@name = 'Ln_50'
   ,@trained_model = @model OUTPUT
INSERT INTO PredictingWithPy_models (model, modelName, trainSize) VALUES(@model, 'Ln_50', 0.5);
GO

-- Check the models
SELECT * FROM PredictingWithPy_models


-- CREATE Procedure to predict the number of cars owned

CREATE OR ALTER PROCEDURE [dbo].[RunningPredictionWithValesPy] 
(
	@model varchar(100)
   ,@age INT
   ,@commuteDistance INT
)
AS
BEGIN

DECLARE @modelIN VARBINARY(MAX) = (SELECT model FROM PredictingWithPy_models WHERE modelName = @model)

DECLARE @q NVARCHAR(MAX) = N'SELECT '+CAST(@age AS VARCHAR(5))+' AS age, '+ CAST(@commuteDistance AS VARCHAR(5))+' AS CommuteDistance'


-- Store the new values for prediction in temp table
DROP TABLE IF EXISTS #t
CREATE TABLE #t (age INT, CommuteDistance INT)
INSERT INTO #t (age, CommuteDistance)
EXEC sp_executesql @q

EXEC sp_execute_external_script
   @language = N'Python'
  ,@script = N'
import pickle
import numpy as np
import pandas as pd
from sklearn import metrics

##Deserialize model
mod = pickle.loads(modelIN)
X = InputDataSet[["age", "CommuteDistance"]]

##Create numpy Array when you introducte more values at the same time (bulk prediction)
predArray = mod.predict(X)
OutputDataSet = pd.DataFrame(data = predArray, columns = ["predictions"])
'  
-- ,@input_data_1 = N'SELECT '+@age+' AS age, '+ @commuteDistance+' AS CommuteDistance'
 ,@input_data_1 = N'SELECT * FROM #t'
 ,@input_data_1_name = N'InputDataSet'
 ,@params = N'@modelIN varbinary(max)'
 ,@modelIN = @modelIN
WITH RESULT SETS 
	((
	prediction_Score FLOAT
	));
END
GO


EXEC [RunningPredictionWithValesPy]
	@model = 'Ln_30'
   ,@age = 44
   ,@commuteDistance = 1


----------------------------------------------
-- Visualizing with Python in SSRS
----------------------------------------------

CREATE OR ALTER PROCEDURE [dbo].[VisualizeWithPyR2] 
(
	@inputVariable VARCHAR(100)
)
AS
BEGIN

DECLARE @q NVARCHAR(MAX) = N'SELECT '+CAST(@inputVariable AS VARCHAR(50))+' AS val1  FROM vTargetMail'

-- Store the new values for prediction in temp table
DROP TABLE IF EXISTS #t
CREATE TABLE #t (val1 FLOAT)
INSERT INTO #t (val1)
EXEC sp_executesql @q

EXEC sp_execute_external_script
   @language = N'Python'
  ,@script = N'
import numpy as np
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt

fig = plt.figure(figsize=(12, 5))
plt.plot(plotdataset)
fig.savefig(''C:\\\PyGraphs\\firstGraph.png'') 
OutputDataSet = pd.DataFrame(data =[1], columns = ["plot"])
'  
,@input_data_1 = N'SELECT * FROM #t'
,@input_data_1_name = N'plotdataset'
WITH RESULT SETS 
((
plot INT
));

END
GO


EXEC [dbo].[VisualizeWithPyR2] 
	@inputVariable = 'age' --CommuteDistance | --NofCars


--  Get Column List
SELECT 
	column_name 
FROM information_schema.columns
WHERE
	table_name = 'vTargetMail'
ORDER By Ordinal_position	