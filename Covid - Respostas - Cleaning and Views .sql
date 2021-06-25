use [Covid]

---------------- DATA CLEANING (DC) -----------------------

---- (DC) MOBILITY TABLE ---------------------------------

--Convertendo o formato de data da tabela de mobilidade
ALTER TABLE [dbo].[mobility-covid]
ALTER COLUMN [DAY] DATE;

--Convertendo o tipo de dado das colunas que indicam as variações para FLOAT.

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

--Uniformizando o perído de análise. Restringir para o período de 01/03/20 a 01/06/21.
DELETE FROM [dbo].[mobility-covid]
WHERE   [Day] < '2020-03-01' OR [Day] > '2021-06-01'


SELECT [Day], [Entity] FROM [dbo].[mobility-covid]
WHERE   [Day] < '2020-03-01' OR [Day] > '2021-06-01'
ORDER BY [Day]


--Criando uma coluna com a média das variações de [retail_and_recreation] e  [workplaces]

ALTER TABLE [dbo].[mobility-covid]
ADD Media_var_Visitas_comercio FLOAT;

UPDATE [dbo].[mobility-covid]
SET Media_var_Visitas_comercio = ([retail_and_recreation] + [workplaces])/2

--Criarei uma métrica para representar o isolamento Social 
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


--Uniformizando o perído de análise. Restringir para 01/03 a 01/06.
DELETE FROM [dbo].[owid]
WHERE   [date] < '2020-03-01' OR [date] > '2021-06-01'


-----CRIANDO COLUNAS CONCATENADA (KEY-LIKE) PARA MELHORAR A INTEGRAÇÃO ENTRE TABELAS ----- 

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

-- As tabelas serão copiadas para o Excel uma vez que Tableau Public não permite acessar a db diretamente.

--VIEW 1: Mortes x vacinação x Isolamento - Dispersão

IF OBJECT_ID ('dbo.Vacina x Isolamento x Mortes') IS NOT NULL
DROP VIEW [dbo].[Vacina x Isolamento x Mortes];
GO

CREATE VIEW [DBO].[Vacina x Isolamento x Mortes] AS

SELECT	
O.[date], O.[continent], O.[location], 
O.[new_deaths_smoothed_per_million] as "Mortes diárias " , 
O.[people_vaccinated_per_hundred] AS "(%) Pessoas Vacinadas",
M.[Isolamento_Social] AS "Isolamento Social"

FROM [dbo].[owid] AS O
LEFT JOIN
[dbo].[mobility-covid] AS M
ON    [Concat_Loc_Date] = [Concat_Loc_Date_Mob]
WHERE O.[continent] <> ''
GO

--Impressão da View1.
SELECT * FROM [DBO].[Vacina x Isolamento x Mortes]
where [continent] = ''
ORDER BY  [location], [date]




--VIEW 2 - Mortes Diárias -  Mapa

IF OBJECT_ID('[DBO].[Mapa_Mortes]') IS NOT NULL
DROP VIEW [DBO].[Mapa_Mortes];
GO

CREATE VIEW [DBO].[Mapa_Mortes]
AS
SELECT MAX([continent]) AS "Continente",
[location] AS "País",
MAX([total_deaths_per_million]) AS "Mortes por Milhão de Habitantes",
MAX([total_deaths]) AS "Total de Mortes"
FROM [dbo].[owid]
WHERE [continent] <> ''
GROUP BY [location]

GO

--Impressão da View2.
SELECT * FROM [DBO].[Mapa_Mortes]
ORDER BY [País]


-- VIEW 3 - Resumo dos Países - tabela.

IF OBJECT_ID('[DBO].[Resumo]') IS NOT NULL
DROP VIEW [DBO].[Resumo];
GO

CREATE VIEW [DBO].[Resumo]
AS
SELECT [location] AS "País", 
MAX([gdp_per_capita]) AS "PIB per Capita",
MAX([population_density]) AS "Densidade Populacional",
MAX([people_vaccinated_per_hundred]) AS "População vacinadas (%)",
MAX([total_deaths_per_million]) AS "Total de Mortes por Milhão",
MAX([total_deaths]) AS "Total de Mortes"
FROM [dbo].[owid]
WHERE [continent] <> ''
GROUP BY [location]
GO

--Impressão da View3 
SELECT * FROM [DBO].[Resumo]
ORDER BY [País]




-- VIEW 4 - tabela: Paises semelhantes com Melhor desempenho.

IF OBJECT_ID('[DBO].[Sugestao_País]') IS NOT NULL
DROP VIEW [DBO].[Sugestao_País];
GO

CREATE VIEW [DBO].[Sugestao_País]
AS
WITH TEMP3 AS
(
SELECT [location] AS "País", 
MAX([continent]) AS "Continente", 
MAX([total_deaths_per_million]) AS "Mortes por mi", 
MAX([population_density]) AS "Densidade Populacional",
MAX([people_vaccinated_per_hundred]) AS "População vacinada (%)",
MAX([gdp_per_capita]) AS "PIB per capita"
FROM [dbo].[owid]
GROUP BY [location]
)
SELECT O.[País], O.[Densidade Populacional],O.[PIB per capita],
O.[População vacinada (%)], O.[Mortes por mi],
OJ.[Continente] AS "Continente (2)",
OJ.[País] AS "País (2) com densidade pop. semelhante", 
OJ.[Densidade Populacional] AS "Densidade Populacional (2)",
OJ.[PIB per capita] AS "PIB per capita (2)",
OJ.[População vacinada (%)] AS "População vacinada (%) (2)",
OJ.[Mortes por mi] AS "Mortes por mi (2)"

FROM [TEMP3] AS O
CROSS JOIN
[TEMP3] AS OJ
WHERE 
O.[País] <> OJ.[País]
AND O.[PIB per capita] BETWEEN 0.85*OJ.[PIB per capita] AND 1.15*OJ.[PIB per capita]
AND O.[Continente] <> ''
AND OJ.[Continente] <> ''
AND O.[PIB per capita] > 0
AND O.[Densidade Populacional] > 0
GO

--Impressão da View4
SELECT *  FROM [DBO].[Sugestao_País]
ORDER BY [País], [Mortes por mi], [PIB per capita]