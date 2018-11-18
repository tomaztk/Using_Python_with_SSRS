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


