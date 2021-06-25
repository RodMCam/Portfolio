use [Covid]

---------------- DATA CLEANING (DC) -----------------------

---- (DC) MOBILITY TABLE ---------------------------------

--Convertendo o formato de data da tabela de mobilidade
ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [DAY] DATE;

--Convertendo o tipo de dado das colunas que indicam as varia��es para FLOAT.

ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [retail_and_recreation] FLOAT;
			
ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [grocery_and_pharmacy] FLOAT;

ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [transit_stations] FLOAT;

ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [residential] FLOAT;
	
ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [parks] FLOAT;
		
ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [workplaces] FLOAT;

--Uniformizando o per�do de an�lise. Restringir para o per�odo de 01/03/20 a 01/06/21.
DELETE FROM [dbo].[mobility-covid]
WHERE   [Day] < '2020-03-01' OR [Day] > '2021-06-01'


SELECT [Day], [Entity] FROM [dbo].[mobility-covid]
WHERE   [Day] < '2020-03-01' OR [Day] > '2021-06-01'
ORDER BY [Day]


--Criando uma coluna com a m�dia das varia��es de [retail_and_recreation] e  [workplaces]

ALTER TABLE [dbo].[mobility-covid]
ADD Media_var_Visitas_comercio FLOAT;

UPDATE [dbo].[mobility-covid]
SET Media_var_Visitas_comercio = ([retail_and_recreation] + [workplaces])/2

--Criarei uma m�trica para representar o isolamento Social 
ALTER TABLE [dbo].[mobility-covid]
ADD Isolamento_Social FLOAT;

UPDATE [dbo].[mobility-covid]
SET Isolamento_Social = [Media_var_Visitas_comercio] * (-1)



 -----(DC)  COVID TABLE ----------------------------------------

ALTER TABLE [dbo].[owid]
ALTER COLUMN [date] DATE;

ALTER TABLE [dbo].[owid]
ALTER COLUMN [new_deaths_smoothed_per_million] FLOAT;

ALTER TABLE [dbo].[owid]
ALTER COLUMN [gdp_per_capita] FLOAT;

ALTER TABLE [dbo].[owid]
ALTER COLUMN [population_density] FLOAT;


--
UPDATE 
    [dbo].[owid]
SET
    [total_deaths_per_million] = REPLACE([total_deaths_per_million], ',','.')

ALTER TABLE [dbo].[owid]
ALTER COLUMN  [total_deaths_per_million] FLOAT;


ALTER TABLE [dbo].[owid]
ALTER COLUMN  [total_deaths] INT;

--
UPDATE 
    [dbo].[owid]
SET
    [people_vaccinated_per_hundred] = REPLACE([people_vaccinated_per_hundred], ',','.')

 ALTER TABLE [dbo].[owid]
ALTER COLUMN [people_vaccinated_per_hundred] FLOAT;


--Uniformizando o per�do de an�lise. Restringir para 01/03 a 01/06.
DELETE FROM [dbo].[owid]
WHERE   [date] < '2020-03-01' OR [date] > '2021-06-01'


-----CRIANDO COLUNAS CONCATENADA (KEY-LIKE) PARA MELHORAR A INTEGRA��O ENTRE TABELAS ----- 

--COVID TABLE
ALTER TABLE [dbo].[owid]
ADD "Concat_Loc_Date" NVARCHAR(255)

UPDATE [dbo].[owid]
SET "Concat_Loc_Date" = CONCAT([location],[date])

--MOBILITY TABLE
ALTER TABLE [dbo].[mobility-covid]
ADD "Concat_Loc_Date_Mob" NVARCHAR(255)

UPDATE [dbo].[mobility-covid]
SET "Concat_Loc_Date_Mob" = CONCAT([Entity],[Day])


-----------------

--CRIANDO VIEWs PARA O DASHBOARD

-- As tabelas ser�o copiadas para o Excel uma vez que Tableau Public n�o permite acessar a db diretamente.

--VIEW 1: Mortes x vacina��o x Isolamento - Dispers�o

IF OBJECT_ID ('dbo.Vacina x Isolamento x Mortes') IS NOT NULL
DROP VIEW [dbo].[Vacina x Isolamento x Mortes];
GO

CREATE VIEW [DBO].[Vacina x Isolamento x Mortes] AS

SELECT	
O.[date], O.[continent], O.[location], 
O.[new_deaths_smoothed_per_million] as "Mortes di�rias " , 
O.[people_vaccinated_per_hundred] AS "(%) Pessoas Vacinadas",
M.[Isolamento_Social] AS "Isolamento Social"

FROM [dbo].[owid] AS O
LEFT JOIN
[dbo].[mobility-covid] AS M
ON    [Concat_Loc_Date] = [Concat_Loc_Date_Mob]
WHERE O.[continent] <> ''
GO

--Impress�o da View1.
SELECT * FROM [DBO].[Vacina x Isolamento x Mortes]
where [continent] = ''
ORDER BY  [location], [date]




--VIEW 2 - Mortes Di�rias -  Mapa

IF OBJECT_ID('[DBO].[Mapa_Mortes]') IS NOT NULL
DROP VIEW [DBO].[Mapa_Mortes];
GO

CREATE VIEW [DBO].[Mapa_Mortes]
AS
SELECT MAX([continent]) AS "Continente",
[location] AS "Pa�s",
MAX([total_deaths_per_million]) AS "Mortes por Milh�o de Habitantes",
MAX([total_deaths]) AS "Total de Mortes"
FROM [dbo].[owid]
WHERE [continent] <> ''
GROUP BY [location]

GO

--Impress�o da View2.
SELECT * FROM [DBO].[Mapa_Mortes]
ORDER BY [Pa�s]


-- VIEW 3 - Resumo dos Pa�ses - tabela.

IF OBJECT_ID('[DBO].[Resumo]') IS NOT NULL
DROP VIEW [DBO].[Resumo];
GO

CREATE VIEW [DBO].[Resumo]
AS
SELECT [location] AS "Pa�s", 
MAX([gdp_per_capita]) AS "PIB per Capita",
MAX([population_density]) AS "Densidade Populacional",
MAX([people_vaccinated_per_hundred]) AS "Popula��o vacinadas (%)",
MAX([total_deaths_per_million]) AS "Total de Mortes por Milh�o",
MAX([total_deaths]) AS "Total de Mortes"
FROM [dbo].[owid]
WHERE [continent] <> ''
GROUP BY [location]
GO

--Impress�o da View3 
SELECT * FROM [DBO].[Resumo]
ORDER BY [Pa�s]




-- VIEW 4 - tabela: Paises semelhantes com Melhor desempenho.

IF OBJECT_ID('[DBO].[Sugestao_Pa�s]') IS NOT NULL
DROP VIEW [DBO].[Sugestao_Pa�s];
GO

CREATE VIEW [DBO].[Sugestao_Pa�s]
AS
WITH TEMP3 AS
(
SELECT [location] AS "Pa�s", 
MAX([continent]) AS "Continente", 
MAX([total_deaths_per_million]) AS "Mortes por mi", 
MAX([population_density]) AS "Densidade Populacional",
MAX([people_vaccinated_per_hundred]) AS "Popula��o vacinada (%)",
MAX([gdp_per_capita]) AS "PIB per capita"
FROM [dbo].[owid]
GROUP BY [location]
)
SELECT O.[Pa�s], O.[Densidade Populacional],O.[PIB per capita],
O.[Popula��o vacinada (%)], O.[Mortes por mi],
OJ.[Continente] AS "Continente (2)",
OJ.[Pa�s] AS "Pa�s (2) com densidade pop. semelhante", 
OJ.[Densidade Populacional] AS "Densidade Populacional (2)",
OJ.[PIB per capita] AS "PIB per capita (2)",
OJ.[Popula��o vacinada (%)] AS "Popula��o vacinada (%) (2)",
OJ.[Mortes por mi] AS "Mortes por mi (2)"

FROM [TEMP3] AS O
CROSS JOIN
[TEMP3] AS OJ
WHERE 
O.[Pa�s] <> OJ.[Pa�s]
AND O.[PIB per capita] BETWEEN 0.85*OJ.[PIB per capita] AND 1.15*OJ.[PIB per capita]
AND O.[Continente] <> ''
AND OJ.[Continente] <> ''
AND O.[PIB per capita] > 0
AND O.[Densidade Populacional] > 0
GO

--Impress�o da View4
SELECT *  FROM [DBO].[Sugestao_Pa�s]
ORDER BY [Pa�s], [Mortes por mi], [PIB per capita]