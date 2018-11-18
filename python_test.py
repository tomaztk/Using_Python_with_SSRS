import pandas as pd
import pyodbc

sql_conn = pyodbc.connect('DRIVER={ODBC Driver 13 for SQL Server};SERVER=TOMAZK\\MSSQLSERVER2017;DATABASE=SQLPY;Trusted_Connection=yes') 
query = '''
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
'''

df = pd.read_sql(query, sql_conn)

df.head(3)

#df_gender = df[''MaritalStatus''] == "M"
df_gender = df['MaritalStatus'] == "M"
df_gen = df[df_gender]
correlation = df_gen.corr(method='pearson')
pd.DataFrame(correlation, columns=["nof","age"])


### Predicting the model
import pandas as pd
import numpy as np
import pickle
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split

sql_conn = pyodbc.connect('DRIVER={ODBC Driver 13 for SQL Server};SERVER=TOMAZK\\MSSQLSERVER2017;DATABASE=SQLPY;Trusted_Connection=yes') 
query2 = '''
SELECT 
	 age 
	,NumberCarsOwned AS nofCars
	,CAST(REPLACE(LEFT(CommuteDistance,2),'-','') AS TINYINT) as CommuteDistance

FROM AdventureWorksDW2014.dbo.vTargetMail
WHERE
	age < 100
'''

df2 = pd.read_sql(query2, sql_conn)

##Create SciKit-Learn linear regression model
X = df2[["age", "CommuteDistance"]]
y = np.ravel(df2[["nofCars"]])

##Create training (and testing) variables based on test_size
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3)

## CreateLinear Model
SKL_lr = LinearRegression()
linRegObj = SKL_lr.fit(X_train, y_train)

##Serialize model
trained_model = pickle.dumps(linRegObj)


##Predicting

## Deserializing the model
mod = pickle.loads(trained_model)

##Create numpy Array when you introducte more values at the same time (bulk prediction)
predArray = mod.predict(X_test)

## Store results
## In-database version with SQL Server, only one row will be returned
Out = pd.DataFrame(data = predArray, columns = ["predictions"])


## Visualizing R2
from sklearn.metrics import r2_score
import matplotlib
import matplotlib.pyplot as plt

def R2EvalMod(test_sizeIN):
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_sizeIN)
    SKL_lr = LinearRegression()
    linRegObj = SKL_lr.fit(X_train, y_train)
    predArray = linRegObj.predict(X_test)
    R2 = r2_score(y_test, predArray) 
    return R2

R2EvalMod(0.3)

sql_conn = pyodbc.connect('DRIVER={ODBC Driver 13 for SQL Server};SERVER=TOMAZK\\MSSQLSERVER2017;DATABASE=SQLPY;Trusted_Connection=yes') 
query3 = '''
SELECT trainSize FROM [dbo].[PredictingWithPy_models]
'''
df3 = pd.read_sql(query3, sql_conn)

R2List = []
for i in range(len(df3)):
    z = df3.at[i, 'trainSize']
    R2=R2EvalMod(z)
    R2List.append(([z],[R2]))
    
R2List
labels = ['trainsize', 'R2']
df33 = pd.DataFrame.from_records(R2List, columns=labels)   
plt.plot(df33)
 
sql_conn = pyodbc.connect('DRIVER={ODBC Driver 13 for SQL Server};SERVER=TOMAZK\\MSSQLSERVER2017;DATABASE=SQLPY;Trusted_Connection=yes') 
query4 = '''
 SELECT age FROM vTargetMail'''
df4 = pd.read_sql(query4, sql_conn)

plt.plot(df4)
