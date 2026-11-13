-- ==============================================================================
-- FASE 3 - CAMADA OURO (GOLD): MODELAGEM RELACIONAL - ESQUEMA ESTRELA
-- Projeto: Pipeline ETL - Indicadores Educacionais por Região (INEP / MEC)
-- SGBD Alvo: MySQL 8.0+
-- Padrão de Modelagem: Star Schema (Kimball) - 4 Dimensões + 1 Tabela Fato
-- ==============================================================================

-- 1. Criação e Seleção do Banco de Dados
CREATE DATABASE IF NOT EXISTS inep_indicadores_educacionais
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE inep_indicadores_educacionais;

-- ==============================================================================
-- 2. CRIAÇÃO DAS TABELAS DIMENSÃO
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Dimensão 1: Tempo (Anos Letivos do Censo Escolar)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS fato_indicadores_educacionais;
DROP TABLE IF EXISTS dim_tempo;

CREATE TABLE dim_tempo (
    id_tempo        INT             NOT NULL AUTO_INCREMENT,
    ano             INT             NOT NULL,
    decada          VARCHAR(10)     NOT NULL COMMENT 'Ex: 2000s, 2010s, 2020s',
    ano_letivo_desc VARCHAR(20)     NOT NULL COMMENT 'Descrição: Ano Letivo YYYY',
    CONSTRAINT pk_dim_tempo PRIMARY KEY (id_tempo),
    CONSTRAINT uq_dim_tempo_ano UNIQUE (ano),
    CONSTRAINT ck_dim_tempo_ano CHECK (ano BETWEEN 1990 AND 2100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Temporal: Anos do Censo Escolar INEP';

-- ------------------------------------------------------------------------------
-- Dimensão 2: Região Geográfica (Macrorregiões do Brasil)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_regiao;

CREATE TABLE dim_regiao (
    id_regiao       INT             NOT NULL AUTO_INCREMENT,
    nome_regiao     VARCHAR(50)     NOT NULL,
    sigla_regiao    VARCHAR(2)      NOT NULL COMMENT 'NO, NE, CO, SE, SU',
    latitude        DECIMAL(8,4)    NULL COMMENT 'Centróide da macrorregião',
    longitude       DECIMAL(8,4)    NULL COMMENT 'Centróide da macrorregião',
    CONSTRAINT pk_dim_regiao PRIMARY KEY (id_regiao),
    CONSTRAINT uq_dim_regiao_nome UNIQUE (nome_regiao),
    CONSTRAINT uq_dim_regiao_sigla UNIQUE (sigla_regiao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Geográfica: Macrorregiões do Brasil';

-- ------------------------------------------------------------------------------
-- Dimensão 3: Localização (Urbana, Rural ou Total Consolidado)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_localizacao;

CREATE TABLE dim_localizacao (
    id_localizacao  INT             NOT NULL AUTO_INCREMENT,
    tipo_localizacao VARCHAR(30)    NOT NULL,
    flag_rural      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '1=Rural, 0=Urbana/Total',
    CONSTRAINT pk_dim_localizacao PRIMARY KEY (id_localizacao),
    CONSTRAINT uq_dim_localizacao_tipo UNIQUE (tipo_localizacao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Localização: Urbana, Rural ou Total';

-- ------------------------------------------------------------------------------
-- Dimensão 4: Rede de Ensino (Pública, Privada, Estadual, Municipal, Federal)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_rede;

CREATE TABLE dim_rede (
    id_rede         INT             NOT NULL AUTO_INCREMENT,
    tipo_rede       VARCHAR(30)     NOT NULL,
    categoria_rede  VARCHAR(20)     NOT NULL COMMENT 'Pública, Privada ou Consolidada',
    flag_publica    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '1=Rede Pública, 0=Privada/Outro',
    CONSTRAINT pk_dim_rede PRIMARY KEY (id_rede),
    CONSTRAINT uq_dim_rede_tipo UNIQUE (tipo_rede)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Rede de Ensino: Dependência Administrativa';

-- ==============================================================================
-- 3. CRIAÇÃO DA TABELA FATO
-- ==============================================================================

CREATE TABLE fato_indicadores_educacionais (
    id_fato                         BIGINT          NOT NULL AUTO_INCREMENT,

    -- Chaves Estrangeiras Dimensionais (NOT NULL)
    id_tempo                        INT             NOT NULL,
    id_regiao                       INT             NOT NULL,
    id_localizacao                  INT             NOT NULL,
    id_rede                         INT             NOT NULL,

    -- ==================== MÉTRICAS: ALUNOS POR TURMA (ATU) ====================
    atu_ei                          DECIMAL(6,2)    NULL COMMENT 'Média Alunos/Turma - Educação Infantil',
    atu_ef                          DECIMAL(6,2)    NULL COMMENT 'Média Alunos/Turma - Ensino Fundamental',
    atu_ef_anos_iniciais            DECIMAL(6,2)    NULL COMMENT 'Média Alunos/Turma - EF Anos Iniciais',
    atu_ef_anos_finais              DECIMAL(6,2)    NULL COMMENT 'Média Alunos/Turma - EF Anos Finais',
    atu_em                          DECIMAL(6,2)    NULL COMMENT 'Média Alunos/Turma - Ensino Médio',

    -- ==================== MÉTRICAS: HORAS-AULA DIÁRIA (HAD) ==================
    had_ei                          DECIMAL(5,2)    NULL COMMENT 'Média Horas-Aula Diária - Educação Infantil',
    had_ef                          DECIMAL(5,2)    NULL COMMENT 'Média Horas-Aula Diária - Ensino Fundamental',
    had_ef_anos_iniciais            DECIMAL(5,2)    NULL COMMENT 'Média Horas-Aula Diária - EF Anos Iniciais',
    had_ef_anos_finais              DECIMAL(5,2)    NULL COMMENT 'Média Horas-Aula Diária - EF Anos Finais',
    had_em                          DECIMAL(5,2)    NULL COMMENT 'Média Horas-Aula Diária - Ensino Médio',

    -- ==================== MÉTRICAS: DISTORÇÃO IDADE-SÉRIE (TDI) ==============
    tdi_ef                          DECIMAL(5,2)    NULL COMMENT 'Taxa Distorção Idade-Série (%) - EF',
    tdi_ef_anos_iniciais            DECIMAL(5,2)    NULL COMMENT 'Taxa Distorção (%) - EF Anos Iniciais',
    tdi_ef_anos_finais              DECIMAL(5,2)    NULL COMMENT 'Taxa Distorção (%) - EF Anos Finais',
    tdi_em                          DECIMAL(5,2)    NULL COMMENT 'Taxa Distorção Idade-Série (%) - EM',

    -- ==================== MÉTRICAS: TAXA DE APROVAÇÃO (%) ====================
    taxa_aprovacao_ef               DECIMAL(5,2)    NULL COMMENT 'Taxa Aprovação (%) - EF',
    taxa_aprovacao_ef_anos_iniciais DECIMAL(5,2)    NULL COMMENT 'Taxa Aprovação (%) - EF Anos Iniciais',
    taxa_aprovacao_ef_anos_finais   DECIMAL(5,2)    NULL COMMENT 'Taxa Aprovação (%) - EF Anos Finais',
    taxa_aprovacao_em               DECIMAL(5,2)    NULL COMMENT 'Taxa Aprovação (%) - EM',

    -- ==================== MÉTRICAS: TAXA DE REPROVAÇÃO (%) ===================
    taxa_reprovacao_ef              DECIMAL(5,2)    NULL COMMENT 'Taxa Reprovação (%) - EF',
    taxa_reprovacao_ef_anos_iniciais DECIMAL(5,2)   NULL COMMENT 'Taxa Reprovação (%) - EF Anos Iniciais',
    taxa_reprovacao_ef_anos_finais  DECIMAL(5,2)    NULL COMMENT 'Taxa Reprovação (%) - EF Anos Finais',
    taxa_reprovacao_em              DECIMAL(5,2)    NULL COMMENT 'Taxa Reprovação (%) - EM',

    -- ==================== MÉTRICAS: TAXA DE ABANDONO (%) =====================
    taxa_abandono_ef                DECIMAL(5,2)    NULL COMMENT 'Taxa Abandono / Evasão (%) - EF',
    taxa_abandono_ef_anos_iniciais  DECIMAL(5,2)    NULL COMMENT 'Taxa Abandono (%) - EF Anos Iniciais',
    taxa_abandono_ef_anos_finais    DECIMAL(5,2)    NULL COMMENT 'Taxa Abandono (%) - EF Anos Finais',
    taxa_abandono_em                DECIMAL(5,2)    NULL COMMENT 'Taxa Abandono / Evasão (%) - EM',

    -- ==================== MÉTRICAS: DOCENTES C/ CURSO SUPERIOR (DSU) =========
    dsu_ei                          DECIMAL(5,2)    NULL COMMENT 'Docentes c/ Ensino Superior (%) - EI',
    dsu_ef                          DECIMAL(5,2)    NULL COMMENT 'Docentes c/ Ensino Superior (%) - EF',
    dsu_ef_anos_iniciais            DECIMAL(5,2)    NULL COMMENT 'Docentes c/ Ensino Superior (%) - EF Anos Iniciais',
    dsu_ef_anos_finais              DECIMAL(5,2)    NULL COMMENT 'Docentes c/ Ensino Superior (%) - EF Anos Finais',
    dsu_em                          DECIMAL(5,2)    NULL COMMENT 'Docentes c/ Ensino Superior (%) - EM',

    -- ==================== MÉTRICAS: TAXA DE NÃO RESPOSTA (TNR) ===============
    tnr_ef                          DECIMAL(5,2)    NULL COMMENT 'Taxa Não Resposta (%) - EF',
    tnr_em                          DECIMAL(5,2)    NULL COMMENT 'Taxa Não Resposta (%) - EM',

    -- ==================== RESTRIÇÕES DE INTEGRIDADE ==========================
    CONSTRAINT pk_fato_indicadores PRIMARY KEY (id_fato),

    CONSTRAINT fk_fato_tempo FOREIGN KEY (id_tempo)
        REFERENCES dim_tempo (id_tempo)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_fato_regiao FOREIGN KEY (id_regiao)
        REFERENCES dim_regiao (id_regiao)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_fato_localizacao FOREIGN KEY (id_localizacao)
        REFERENCES dim_localizacao (id_localizacao)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_fato_rede FOREIGN KEY (id_rede)
        REFERENCES dim_rede (id_rede)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    -- Restrição de Unicidade Composta da Chave Natural
    CONSTRAINT uq_fato_chave_natural UNIQUE (id_tempo, id_regiao, id_localizacao, id_rede)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Tabela Fato: Métricas de Indicadores Educacionais consolidadas';

-- ==============================================================================
-- 4. ÍNDICES DE ALTA PERFORMANCE PARA BI E EDA
-- ==============================================================================

CREATE INDEX idx_fato_tempo ON fato_indicadores_educacionais (id_tempo);
CREATE INDEX idx_fato_regiao ON fato_indicadores_educacionais (id_regiao);
CREATE INDEX idx_fato_localizacao ON fato_indicadores_educacionais (id_localizacao);
CREATE INDEX idx_fato_rede ON fato_indicadores_educacionais (id_rede);
CREATE INDEX idx_fato_analise_temporal ON fato_indicadores_educacionais (id_tempo, id_regiao, id_rede);

-- ==============================================================================
-- 5. POVOAMENTO INICIAL DAS TABELAS DIMENSÃO (SEEDS)
-- ==============================================================================

-- Dimensão Tempo (2006 a 2024)
INSERT INTO dim_tempo (ano, decada, ano_letivo_desc) VALUES
    (2006, '2000s', 'Ano Letivo 2006'),
    (2007, '2000s', 'Ano Letivo 2007'),
    (2008, '2000s', 'Ano Letivo 2008'),
    (2009, '2000s', 'Ano Letivo 2009'),
    (2010, '2010s', 'Ano Letivo 2010'),
    (2011, '2010s', 'Ano Letivo 2011'),
    (2012, '2010s', 'Ano Letivo 2012'),
    (2013, '2010s', 'Ano Letivo 2013'),
    (2014, '2010s', 'Ano Letivo 2014'),
    (2015, '2010s', 'Ano Letivo 2015'),
    (2016, '2010s', 'Ano Letivo 2016'),
    (2017, '2010s', 'Ano Letivo 2017'),
    (2018, '2010s', 'Ano Letivo 2018'),
    (2019, '2010s', 'Ano Letivo 2019'),
    (2020, '2020s', 'Ano Letivo 2020'),
    (2021, '2020s', 'Ano Letivo 2021'),
    (2022, '2020s', 'Ano Letivo 2022'),
    (2023, '2020s', 'Ano Letivo 2023'),
    (2024, '2020s', 'Ano Letivo 2024')
ON DUPLICATE KEY UPDATE decada = VALUES(decada), ano_letivo_desc = VALUES(ano_letivo_desc);

-- Dimensão Região
INSERT INTO dim_regiao (nome_regiao, sigla_regiao, latitude, longitude) VALUES
    ('Norte',        'NO', -3.4653, -62.2159),
    ('Nordeste',     'NE', -8.2815, -39.4674),
    ('Centro-Oeste', 'CO', -14.6508, -52.4934),
    ('Sudeste',      'SE', -20.3155, -45.0528),
    ('Sul',          'SU', -27.6326, -51.3304)
ON DUPLICATE KEY UPDATE sigla_regiao = VALUES(sigla_regiao), latitude = VALUES(latitude), longitude = VALUES(longitude);

-- Dimensão Localização
INSERT INTO dim_localizacao (tipo_localizacao, flag_rural) VALUES
    ('Urbana', 0),
    ('Rural',  1),
    ('Total',  0)
ON DUPLICATE KEY UPDATE flag_rural = VALUES(flag_rural);

-- Dimensão Rede de Ensino
INSERT INTO dim_rede (tipo_rede, categoria_rede, flag_publica) VALUES
    ('Total',     'Consolidada', 0),
    ('Pública',   'Pública',     1),
    ('Privada',   'Privada',     0),
    ('Estadual',  'Pública',     1),
    ('Municipal', 'Pública',     1),
    ('Federal',   'Pública',     1)
ON DUPLICATE KEY UPDATE categoria_rede = VALUES(categoria_rede), flag_publica = VALUES(flag_publica);

-- ==============================================================================
-- 6. VIEWS ANALÍTICAS DESNORMALIZADAS (POWER BI & EDA)
-- ==============================================================================

CREATE OR REPLACE VIEW vw_indicadores_completos AS
SELECT
    t.ano,
    t.decada,
    t.ano_letivo_desc,
    r.nome_regiao                       AS regiao,
    r.sigla_regiao,
    r.latitude,
    r.longitude,
    l.tipo_localizacao                  AS localizacao,
    l.flag_rural,
    rd.tipo_rede                        AS rede,
    rd.categoria_rede,
    rd.flag_publica,
    f.atu_ei, f.atu_ef, f.atu_ef_anos_iniciais, f.atu_ef_anos_finais, f.atu_em,
    f.had_ei, f.had_ef, f.had_ef_anos_iniciais, f.had_ef_anos_finais, f.had_em,
    f.tdi_ef, f.tdi_ef_anos_iniciais, f.tdi_ef_anos_finais, f.tdi_em,
    f.taxa_aprovacao_ef, f.taxa_aprovacao_ef_anos_iniciais,
    f.taxa_aprovacao_ef_anos_finais, f.taxa_aprovacao_em,
    f.taxa_reprovacao_ef, f.taxa_reprovacao_ef_anos_iniciais,
    f.taxa_reprovacao_ef_anos_finais, f.taxa_reprovacao_em,
    f.taxa_abandono_ef, f.taxa_abandono_ef_anos_iniciais,
    f.taxa_abandono_ef_anos_finais, f.taxa_abandono_em,
    f.dsu_ei, f.dsu_ef, f.dsu_ef_anos_iniciais, f.dsu_ef_anos_finais, f.dsu_em,
    f.tnr_ef, f.tnr_em
FROM fato_indicadores_educacionais f
INNER JOIN dim_tempo t          ON f.id_tempo = t.id_tempo
INNER JOIN dim_regiao r         ON f.id_regiao = r.id_regiao
INNER JOIN dim_localizacao l    ON f.id_localizacao = l.id_localizacao
INNER JOIN dim_rede rd          ON f.id_rede = rd.id_rede;

-- View executiva para KPIs mais recentes
CREATE OR REPLACE VIEW vw_kpis_regionais_recente AS
SELECT
    r.nome_regiao                               AS regiao,
    r.sigla_regiao,
    t.ano,
    ROUND(AVG(f.taxa_aprovacao_em), 1)          AS taxa_aprovacao_em,
    ROUND(AVG(f.taxa_abandono_em), 1)           AS taxa_abandono_em,
    ROUND(AVG(f.tdi_em), 1)                     AS distorcao_idade_serie_em,
    ROUND(AVG(f.dsu_em), 1)                     AS docentes_superior_em,
    ROUND(AVG(f.had_em), 1)                     AS horas_aula_diaria_em,
    ROUND(AVG(f.atu_em), 1)                     AS alunos_por_turma_em
FROM fato_indicadores_educacionais f
INNER JOIN dim_tempo t          ON f.id_tempo = t.id_tempo
INNER JOIN dim_regiao r         ON f.id_regiao = r.id_regiao
INNER JOIN dim_localizacao l    ON f.id_localizacao = l.id_localizacao
INNER JOIN dim_rede rd          ON f.id_rede = rd.id_rede
WHERE l.tipo_localizacao = 'Total'
  AND rd.tipo_rede = 'Total'
  AND t.ano = (SELECT MAX(ano) FROM dim_tempo)
GROUP BY r.nome_regiao, r.sigla_regiao, t.ano
ORDER BY taxa_aprovacao_em DESC;
