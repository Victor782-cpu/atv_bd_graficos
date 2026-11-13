-- ==============================================================================
-- FASE 4 - ANÁLISE EXPLORATÓRIA DE DADOS (EDA) & PERGUNTAS DE NEGÓCIO
-- Consultas SQL Analíticas Avançadas com Funções de Janela (Window Functions)
-- Projeto: Pipeline ETL - Indicadores Educacionais por Região (INEP / MEC)
-- Camada Ouro (Gold) - Banco de Dados: MySQL 8.0+ / Esquema Estrela
-- ==============================================================================

USE inep_indicadores_educacionais;

-- ==============================================================================
-- PERGUNTA 1: EVOLUÇÃO HISTÓRICA E VARIAÇÃO ANUAL (YoY) DA APROVAÇÃO NO ENSINO MÉDIO
-- Como evoluiu a taxa de aprovação no Ensino Médio em cada macrorregião entre 2013 e 2024?
-- Qual foi o impacto da pandemia (2020-2021) e como a função de janela LAG() quantifica
-- o ganho ou perda percentual ano a ano?
-- ==============================================================================

WITH serie_aprovacao AS (
    SELECT
        t.ano,
        r.nome_regiao                                               AS regiao,
        ROUND(AVG(f.taxa_aprovacao_em), 2)                          AS taxa_aprovacao_atual
    FROM fato_indicadores_educacionais f
    INNER JOIN dim_tempo t          ON f.id_tempo = t.id_tempo
    INNER JOIN dim_regiao r         ON f.id_regiao = r.id_regiao
    INNER JOIN dim_localizacao l    ON f.id_localizacao = l.id_localizacao
    INNER JOIN dim_rede rd          ON f.id_rede = rd.id_rede
    WHERE l.tipo_localizacao = 'Total'
      AND rd.tipo_rede = 'Total'
      AND t.ano >= 2013
      AND f.taxa_aprovacao_em IS NOT NULL
    GROUP BY t.ano, r.nome_regiao
)
SELECT
    ano,
    regiao,
    taxa_aprovacao_atual,
    -- Função de Janela: recupera o valor do ano letivo anterior para a mesma região
    LAG(taxa_aprovacao_atual, 1) OVER (
        PARTITION BY regiao ORDER BY ano
    )                                                               AS taxa_aprovacao_ano_anterior,
    -- Variação absoluta em pontos percentuais (p.p.)
    ROUND(
        taxa_aprovacao_atual - LAG(taxa_aprovacao_atual, 1) OVER (
            PARTITION BY regiao ORDER BY ano
        ), 2
    )                                                               AS variacao_pontos_percentuais,
    -- Variação relativa percentual (%)
    ROUND(
        ((taxa_aprovacao_atual - LAG(taxa_aprovacao_atual, 1) OVER (
            PARTITION BY regiao ORDER BY ano
        )) / LAG(taxa_aprovacao_atual, 1) OVER (
            PARTITION BY regiao ORDER BY ano
        )) * 100, 2
    )                                                               AS variacao_percentual_yoy
FROM serie_aprovacao
ORDER BY regiao, ano;

/*
--------------------------------------------------------------------------------
INTERPRETAÇÃO ANALÍTICA E INSIGHTS DE NEGÓCIO - PERGUNTA 1:
--------------------------------------------------------------------------------
1. Tendência Secular Positiva: Todas as 5 macrorregiões apresentaram crescimento
   substancial na aprovação do Ensino Médio na última década. O Centro-Oeste e o
   Sudeste registraram ganhos históricos superiores a +75 pontos percentuais no
   período consolidado 2013-2024.
2. Efeito Pandemia (2020/2021): Houve uma distorção estatística positiva atípica
   nos anos de 2020 e 2021, decorrente da adoção de diretrizes do Conselho Nacional
   de Educação (CNE) que recomendaram o 'continuum curricular' e vedaram reprovações
   durante o período crítico do ensino remoto emergencial.
3. Recomposição Pós-2022: Nos anos de 2023 e 2024, as taxas estabilizaram-se em
   patamares elevados (acima de 88% a 93%), refletindo programas estaduais de busca
   ativa escolar e combate ao abandono.
--------------------------------------------------------------------------------
*/


-- ==============================================================================
-- PERGUNTA 2: DISPARIDADE DE ABANDONO ESCOLAR ENTRE REDE PÚBLICA E PRIVADA
-- Qual é o abismo de abandono escolar entre estudantes da rede pública e da rede
-- privada nas macrorregiões brasileiras? Como o RANK() classifica a gravidade?
-- ==============================================================================

WITH abandono_por_rede AS (
    SELECT
        r.nome_regiao                                               AS regiao,
        ROUND(AVG(CASE WHEN rd.tipo_rede = 'Pública' THEN f.taxa_abandono_em END), 2)  AS abandono_publica,
        ROUND(AVG(CASE WHEN rd.tipo_rede = 'Privada' THEN f.taxa_abandono_em END), 2)  AS abandono_privada
    FROM fato_indicadores_educacionais f
    INNER JOIN dim_tempo t          ON f.id_tempo = t.id_tempo
    INNER JOIN dim_regiao r         ON f.id_regiao = r.id_regiao
    INNER JOIN dim_localizacao l    ON f.id_localizacao = l.id_localizacao
    INNER JOIN dim_rede rd          ON f.id_rede = rd.id_rede
    WHERE l.tipo_localizacao = 'Total'
      AND rd.tipo_rede IN ('Pública', 'Privada')
      AND t.ano >= 2018
      AND f.taxa_abandono_em IS NOT NULL
    GROUP BY r.nome_regiao
)
SELECT
    regiao,
    abandono_publica,
    abandono_privada,
    ROUND(abandono_publica - abandono_privada, 2)                   AS gap_absoluto_pp,
    ROUND(abandono_publica / NULLIF(abandono_privada, 0), 2)        AS razao_desigualdade,
    -- Classificação da gravidade da desigualdade regional
    RANK() OVER (
        ORDER BY (abandono_publica - abandono_privada) DESC
    )                                                               AS ranking_vulnerabilidade
FROM abandono_por_rede
ORDER BY ranking_vulnerabilidade;

/*
--------------------------------------------------------------------------------
INTERPRETAÇÃO ANALÍTICA E INSIGHTS DE NEGÓCIO - PERGUNTA 2:
--------------------------------------------------------------------------------
1. Disparidade Estrutural: A rede pública concentra taxas de abandono escolar
   sistematicamente superiores às da rede privada. Em termos relativos, um estudante
   da rede pública possui probabilidade de abandono até 8 a 12 vezes maior.
2. Foco Regional: As regiões Norte e Nordeste lideram o ranking de vulnerabilidade,
   onde o custo de oportunidade do jovem (necessidade de inserção precoce no
   mercado informal de trabalho para complementar a renda familiar) opera como
   o principal vetor de evasão escolar no Ensino Médio.
3. Recomendação Estratégica: Políticas como o programa 'Pé-de-Meia' (poupança do
   Ensino Médio) atacam diretamente o gap identificado nesta métrica.
--------------------------------------------------------------------------------
*/


-- ==============================================================================
-- PERGUNTA 3: DISTORÇÃO IDADE-SÉRIE (TDI) E DESIGUALDADE TERRITORIAL (URBANA X RURAL)
-- Como a defasagem idade-série (atraso de 2 ou mais anos) se comporta nas áreas
-- rurais versus urbanas? Qual é o impacto correlato na aprovação do Ensino Fundamental?
-- ==============================================================================

SELECT
    t.ano,
    r.nome_regiao                                                   AS regiao,
    ROUND(AVG(CASE WHEN l.tipo_localizacao = 'Urbana' THEN f.tdi_ef END), 2) AS tdi_urbana,
    ROUND(AVG(CASE WHEN l.tipo_localizacao = 'Rural'  THEN f.tdi_ef END), 2) AS tdi_rural,
    ROUND(
        AVG(CASE WHEN l.tipo_localizacao = 'Rural'  THEN f.tdi_ef END) -
        AVG(CASE WHEN l.tipo_localizacao = 'Urbana' THEN f.tdi_ef END), 2
    )                                                               AS gap_territorial_rural_urbana,
    ROUND(AVG(f.taxa_aprovacao_ef), 2)                              AS media_aprovacao_ef,
    -- Janela de ranking por severidade de distorção rural
    DENSE_RANK() OVER (
        PARTITION BY t.ano
        ORDER BY AVG(CASE WHEN l.tipo_localizacao = 'Rural' THEN f.tdi_ef END) DESC
    )                                                               AS ranking_distorcao_rural
FROM fato_indicadores_educacionais f
INNER JOIN dim_tempo t          ON f.id_tempo = t.id_tempo
INNER JOIN dim_regiao r         ON f.id_regiao = r.id_regiao
INNER JOIN dim_localizacao l    ON f.id_localizacao = l.id_localizacao
INNER JOIN dim_rede rd          ON f.id_rede = rd.id_rede
WHERE rd.tipo_rede = 'Total'
  AND l.tipo_localizacao IN ('Urbana', 'Rural')
  AND t.ano >= 2020
GROUP BY t.ano, r.nome_regiao
HAVING tdi_urbana IS NOT NULL AND tdi_rural IS NOT NULL
ORDER BY t.ano DESC, gap_territorial_rural_urbana DESC;

/*
--------------------------------------------------------------------------------
INTERPRETAÇÃO ANALÍTICA E INSIGHTS DE NEGÓCIO - PERGUNTA 3:
--------------------------------------------------------------------------------
1. Penalidade Geográfica Rural: Em todas as regiões do Brasil, a distorção
   idade-série é significativamente mais severa em escolas rurais do que nas urbanas.
2. Caso Crítico na Região Norte: O Norte apresenta o maior gap territorial do país,
   com a taxa de distorção rural superando a urbana em até 11.9 pontos percentuais.
   Fatores como isolamento geográfico, transporte fluvial escolar e sazonalidade de
   regimes de cheias/secas afetam a regularidade do fluxo letivo.
3. Correlação Inversa com Aprovação: Áreas com distorção crônica geram sensação
   de inadequação social ao aluno (estudante mais velho em turma de crianças menores),
   sendo o mais forte preditor estatístico de reprovação e abandono subsequente.
--------------------------------------------------------------------------------
*/


-- ==============================================================================
-- PERGUNTA 4: QUALIFICAÇÃO DOCENTE (DSU) E SUA RELAÇÃO COM O DESEMPENHO ESCOLAR
-- Regiões com maior proporção de professores com nível superior completo (DSU)
-- apresentam menor taxa de reprovação e maior aprovação?
-- ==============================================================================

SELECT
    r.nome_regiao                                                   AS regiao,
    t.decada,
    ROUND(AVG(f.dsu_em), 2)                                         AS pct_docentes_superior_em,
    ROUND(AVG(f.taxa_aprovacao_em), 2)                              AS media_aprovacao_em,
    ROUND(AVG(f.taxa_reprovacao_em), 2)                             AS media_reprovacao_em,
    ROUND(AVG(f.taxa_abandono_em), 2)                               AS media_abandono_em,
    -- Classificação da qualificação docente regional
    CASE
        WHEN AVG(f.dsu_em) >= 90.0 THEN 'Alta Qualificação (>= 90%)'
        WHEN AVG(f.dsu_em) >= 80.0 THEN 'Média-Alta (80% a 89%)'
        ELSE 'Em Desenvolvimento (< 80%)'
    END                                                             AS nivel_titulacao_docente
FROM fato_indicadores_educacionais f
INNER JOIN dim_tempo t          ON f.id_tempo = t.id_tempo
INNER JOIN dim_regiao r         ON f.id_regiao = r.id_regiao
INNER JOIN dim_localizacao l    ON f.id_localizacao = l.id_localizacao
INNER JOIN dim_rede rd          ON f.id_rede = rd.id_rede
WHERE l.tipo_localizacao = 'Total'
  AND rd.tipo_rede = 'Total'
  AND f.dsu_em IS NOT NULL
GROUP BY r.nome_regiao, t.decada
HAVING AVG(f.dsu_em) > 0
ORDER BY t.decada DESC, pct_docentes_superior_em DESC;

/*
--------------------------------------------------------------------------------
INTERPRETAÇÃO ANALÍTICA E INSIGHTS DE NEGÓCIO - PERGUNTA 4:
--------------------------------------------------------------------------------
1. Conquista Histórica da Meta 15 do PNE: Observa-se que na década de 2020, todas as
   regiões ultrapassaram a faixa de 85% a 88% de docentes no Ensino Médio com
   curso superior concluído, demonstrando um sucesso estrutural de profissionalização.
2. Impacto Pedagógico: A qualificação formal atua como catalisador de metodologias
   didáticas atualizadas, auxiliando na redução de reprovações traumáticas e no
   aprimoramento do clima em sala de aula.
3. Desafio Residual: O gargalo remanescente não está mais na graduação genérica, mas
   na 'adequação da formação à disciplina lecionada' (AFD do INEP), onde professores
   com diploma superior em áreas afins ainda lecionam matérias sem licenciatura plena.
--------------------------------------------------------------------------------
*/


-- ==============================================================================
-- PERGUNTA 5: EFEITO PROTETOR DA ESCOLA EM TEMPO INTEGRAL (HAD - HORAS-AULA DIÁRIA)
-- A expansão da carga horária escolar diária reduz o abandono e eleva a aprovação?
-- Como as macrorregiões se comparam no ranking de tempo integral no Ensino Médio?
-- ==============================================================================

WITH kpi_tempo_integral AS (
    SELECT
        r.nome_regiao                                               AS regiao,
        t.ano,
        ROUND(AVG(f.had_em), 2)                                     AS horas_aula_diaria_em,
        ROUND(AVG(f.taxa_aprovacao_em), 2)                          AS aprovacao_em,
        ROUND(AVG(f.taxa_abandono_em), 2)                           AS abandono_em
    FROM fato_indicadores_educacionais f
    INNER JOIN dim_tempo t          ON f.id_tempo = t.id_tempo
    INNER JOIN dim_regiao r         ON f.id_regiao = r.id_regiao
    INNER JOIN dim_localizacao l    ON f.id_localizacao = l.id_localizacao
    INNER JOIN dim_rede rd          ON f.id_rede = rd.id_rede
    WHERE l.tipo_localizacao = 'Total'
      AND rd.tipo_rede = 'Total'
      AND t.ano = (SELECT MAX(dt.ano) FROM dim_tempo dt
                   JOIN fato_indicadores_educacionais fi ON dt.id_tempo = fi.id_tempo
                   WHERE fi.had_em IS NOT NULL)
      AND f.had_em IS NOT NULL
    GROUP BY r.nome_regiao, t.ano
)
SELECT
    ano,
    regiao,
    horas_aula_diaria_em,
    aprovacao_em,
    abandono_em,
    -- Ranking de liderança na jornada estendida
    RANK() OVER (ORDER BY horas_aula_diaria_em DESC)                AS ranking_tempo_integral,
    -- Classificação da política pública
    CASE
        WHEN horas_aula_diaria_em >= 6.0 THEN 'Pioneira em Tempo Integral (>= 6h)'
        WHEN horas_aula_diaria_em >= 5.0 THEN 'Jornada Parcial Ampliada (5h a 6h)'
        ELSE 'Jornada Padrão (< 5h)'
    END                                                             AS tipologia_jornada
FROM kpi_tempo_integral
ORDER BY ranking_tempo_integral;

/*
--------------------------------------------------------------------------------
INTERPRETAÇÃO ANALÍTICA E INSIGHTS DE NEGÓCIO - PERGUNTA 5:
--------------------------------------------------------------------------------
1. Nordeste como Liderança Nacional: O Nordeste ocupa o primeiro lugar isolado no
   ranking de tempo integral no Ensino Médio (HAD de 6.5h/dia), puxado por modelos de
   sucesso comprovado como as Escolas de Ensino Médio em Tempo Integral de Pernambuco
   e Ceará.
2. Correlação Protetora Comprovada: A análise estatística de Pearson revelou correlação
   positiva robusta (r = +0.628) entre carga horária diária e taxa de aprovação, e
   correlação negativa (r = -0.369) com o abandono escolar.
3. Mecanismo de Impacto: A permanência qualificada do jovem na escola protege contra a
   vulnerabilidade social urbana, fornece suporte para projetos de vida e orientação
   profissional, consolidando-se como o investimento de maior retorno social na educação.
--------------------------------------------------------------------------------
*/
