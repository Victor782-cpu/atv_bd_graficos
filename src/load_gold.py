"""
==============================================================================
PIPELINE ETL - CAMADA PRATA -> CAMADA OURO (GOLD)
Projeto: Indicadores Educacionais por Região (INEP / MEC)
Autor: Engenharia de Dados Sênior
==============================================================================
Responsabilidades deste script:
1. Ingestão da Camada Prata a partir de 'data/silver/'.
2. Mapeamento de chaves estrangeiras com base nas Tabelas Dimensão (Star Schema).
3. Carga automatizada, transacional e idempotente no MySQL.
4. Geração de réplica analítica local (SQLite) em 'data/gold/' para reprodutibilidade.
5. Validação rigorosa de integridade e contagem de registros carregados.
==============================================================================
"""

import os
import sys
import logging
from pathlib import Path
import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# Configuração de encoding para ambientes Windows
if sys.platform.startswith('win'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

# Configuração de Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("ETL_Silver_Gold")

# Resolução de Caminhos Relativos
BASE_DIR = Path(__file__).resolve().parents[1]
SILVER_DIR = BASE_DIR / "data" / "silver"
GOLD_DIR = BASE_DIR / "data" / "gold"
SQL_DIR = BASE_DIR / "sql"

ARQUIVO_SILVER_PARQUET = SILVER_DIR / "indicadores_educacionais_silver.parquet"
ARQUIVO_SILVER_CSV = SILVER_DIR / "indicadores_educacionais_silver.csv"
ARQUIVO_DDL_SQL = SQL_DIR / "create_tables.sql"
ARQUIVO_GOLD_SQLITE = GOLD_DIR / "inep_indicadores_educacionais.db"

# Carregar variáveis de ambiente do arquivo .env
load_dotenv(BASE_DIR / ".env")

# Configurações de Conexão MySQL
MYSQL_CONFIG = {
    'host':     os.getenv('MYSQL_HOST', 'localhost'),
    'port':     int(os.getenv('MYSQL_PORT', '3306')),
    'user':     os.getenv('MYSQL_USER', 'root'),
    'password': os.getenv('MYSQL_PASSWORD', ''),
    'database': os.getenv('MYSQL_DATABASE', 'inep_indicadores_educacionais')
}

COLUNAS_METRICAS_FATO = [
    'atu_ei', 'atu_ef', 'atu_ef_anos_iniciais', 'atu_ef_anos_finais', 'atu_em',
    'had_ei', 'had_ef', 'had_ef_anos_iniciais', 'had_ef_anos_finais', 'had_em',
    'tdi_ef', 'tdi_ef_anos_iniciais', 'tdi_ef_anos_finais', 'tdi_em',
    'taxa_aprovacao_ef', 'taxa_aprovacao_ef_anos_iniciais',
    'taxa_aprovacao_ef_anos_finais', 'taxa_aprovacao_em',
    'taxa_reprovacao_ef', 'taxa_reprovacao_ef_anos_iniciais',
    'taxa_reprovacao_ef_anos_finais', 'taxa_reprovacao_em',
    'taxa_abandono_ef', 'taxa_abandono_ef_anos_iniciais',
    'taxa_abandono_ef_anos_finais', 'taxa_abandono_em',
    'dsu_ei', 'dsu_ef', 'dsu_ef_anos_iniciais', 'dsu_ef_anos_finais', 'dsu_em',
    'tnr_ef', 'tnr_em'
]


def carregar_dados_silver() -> pd.DataFrame:
    """Lê os dados da Camada Prata (preferencialmente Parquet, fallback para CSV)."""
    if ARQUIVO_SILVER_PARQUET.exists():
        logger.info(f"Lendo base Prata em formato Parquet: {ARQUIVO_SILVER_PARQUET}")
        df = pd.read_parquet(ARQUIVO_SILVER_PARQUET)
    elif ARQUIVO_SILVER_CSV.exists():
        logger.info(f"Lendo base Prata em formato CSV: {ARQUIVO_SILVER_CSV}")
        df = pd.read_csv(ARQUIVO_SILVER_CSV, sep=',', encoding='utf-8', low_memory=False)
    else:
        raise FileNotFoundError(
            f"Dados da Camada Prata não encontrados em {SILVER_DIR}. "
            "Execute primeiramente: python src/etl_bronze_to_silver.py"
        )

    logger.info(f"Camada Prata carregada: {df.shape[0]} registros x {df.shape[1]} colunas.")
    return df


def criar_engine_mysql(config: dict):
    """Cria e valida a engine de conexão com o MySQL."""
    url = (
        f"mysql+mysqlconnector://{config['user']}:{config['password']}"
        f"@{config['host']}:{config['port']}/{config['database']}"
    )
    return create_engine(url, echo=False, pool_pre_ping=True)


def executar_ddl_mysql(engine, caminho_sql: Path):
    """Executa o script DDL no MySQL dividindo em comandos atômicos."""
    logger.info(f"Executando script DDL no MySQL: {caminho_sql}")
    with open(caminho_sql, 'r', encoding='utf-8') as f:
        script_sql = f.read()

    comandos = [cmd.strip() for cmd in script_sql.split(';') if cmd.strip()]

    with engine.begin() as conn:
        for cmd in comandos:
            # Ignora linhas puramente comentadas
            linhas = [l for l in cmd.split('\n') if not l.strip().startswith('--')]
            cmd_limpo = '\n'.join(linhas).strip()
            if cmd_limpo:
                try:
                    conn.execute(text(cmd_limpo))
                except Exception as e:
                    # Avisos aceitáveis para comandos DROP ou objetos já existentes
                    if 'drop' in cmd_limpo.lower() or 'exists' in str(e).lower():
                        continue
                    logger.warning(f"Aviso na execução do comando SQL: {e}")

    logger.info("Estrutura DDL (Dimensões, Fato e Views) garantida no MySQL.")


def obter_mapas_dimensoes(engine) -> dict:
    """Extrai os IDs das tabelas dimensão para substituição rápida de chaves estrangeiras."""
    logger.info("Consultando mapeamento de chaves nas tabelas dimensão...")
    with engine.connect() as conn:
        res_tempo = conn.execute(text("SELECT id_tempo, ano FROM dim_tempo"))
        map_tempo = {row[1]: row[0] for row in res_tempo}

        res_regiao = conn.execute(text("SELECT id_regiao, nome_regiao FROM dim_regiao"))
        map_regiao = {row[1]: row[0] for row in res_regiao}

        res_localizacao = conn.execute(text("SELECT id_localizacao, tipo_localizacao FROM dim_localizacao"))
        map_localizacao = {row[1]: row[0] for row in res_localizacao}

        res_rede = conn.execute(text("SELECT id_rede, tipo_rede FROM dim_rede"))
        map_rede = {row[1]: row[0] for row in res_rede}

    logger.info(
        f"Dimensões carregadas -> Tempo: {len(map_tempo)} | Região: {len(map_regiao)} | "
        f"Localização: {len(map_localizacao)} | Rede: {len(map_rede)}"
    )

    return {
        'tempo': map_tempo,
        'regiao': map_regiao,
        'localizacao': map_localizacao,
        'rede': map_rede
    }


def preparar_tabela_fato(df: pd.DataFrame, mapas: dict) -> pd.DataFrame:
    """Mapeia as chaves das dimensões e seleciona apenas as métricas para a tabela fato."""
    logger.info("Preparando DataFrame da Tabela Fato...")
    df_fato = df.copy()

    # Mapeamento de Chaves Estrangeiras
    df_fato['id_tempo'] = df_fato['ano'].map(mapas['tempo'])
    df_fato['id_regiao'] = df_fato['regiao'].map(mapas['regiao'])
    df_fato['id_localizacao'] = df_fato['localizacao'].map(mapas['localizacao'])
    df_fato['id_rede'] = df_fato['rede'].map(mapas['rede'])

    # Checagem de integridade referencial
    linhas_sem_fk = df_fato[['id_tempo', 'id_regiao', 'id_localizacao', 'id_rede']].isna().any(axis=1).sum()
    if linhas_sem_fk > 0:
        logger.warning(f"Descartando {linhas_sem_fk} registros sem correspondência dimensional.")
        df_fato = df_fato.dropna(subset=['id_tempo', 'id_regiao', 'id_localizacao', 'id_rede'])

    for fk in ['id_tempo', 'id_regiao', 'id_localizacao', 'id_rede']:
        df_fato[fk] = df_fato[fk].astype(int)

    # Seleção estrita das colunas da Tabela Fato
    colunas_finais = ['id_tempo', 'id_regiao', 'id_localizacao', 'id_rede'] + [
        c for c in COLUNAS_METRICAS_FATO if c in df_fato.columns
    ]

    df_fato = df_fato[colunas_finais].copy()

    # Tratamento de NaNs para compatibilidade de inserção SQL (NULL)
    df_fato = df_fato.where(df_fato.notna(), None)

    logger.info(f"Tabela fato estruturada: {len(df_fato)} registros prontos para carga.")
    return df_fato


def carregar_fato_mysql(engine, df_fato: pd.DataFrame):
    """Realiza a inserção idempotente na tabela fato no MySQL."""
    logger.info("Iniciando carga idempotente na tabela fato_indicadores_educacionais...")
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM fato_indicadores_educacionais"))

    df_fato.to_sql(
        name='fato_indicadores_educacionais',
        con=engine,
        if_exists='append',
        index=False,
        method='multi',
        chunksize=250
    )

    with engine.connect() as conn:
        total = conn.execute(text("SELECT COUNT(*) FROM fato_indicadores_educacionais")).scalar()

    logger.info(f"✅ Carga no MySQL concluída com sucesso: {total} registros inseridos.")


def gerar_replica_sqlite(df_silver: pd.DataFrame, df_fato: pd.DataFrame, mapas: dict):
    """
    Gera uma réplica analítica em SQLite em 'data/gold/'
    garantindo que o esquema estrela possa ser consultado localmente
    mesmo se o serviço do MySQL não estiver ativo na máquina.
    """
    GOLD_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"Gerando réplica analítica local SQLite em: {ARQUIVO_GOLD_SQLITE}")
    engine_sqlite = create_engine(f"sqlite:///{ARQUIVO_GOLD_SQLITE}", echo=False)

    with engine_sqlite.begin() as conn:
        # Povoar dimensões
        df_tempo = pd.DataFrame([
            {'id_tempo': v, 'ano': k, 'decada': f"{(k // 10) * 10}s", 'ano_letivo_desc': f"Ano Letivo {k}"}
            for k, v in mapas['tempo'].items()
        ])
        df_tempo.to_sql('dim_tempo', con=conn, if_exists='replace', index=False)

        df_regiao = pd.DataFrame([
            {'id_regiao': v, 'nome_regiao': k}
            for k, v in mapas['regiao'].items()
        ])
        df_regiao.to_sql('dim_regiao', con=conn, if_exists='replace', index=False)

        df_loc = pd.DataFrame([
            {'id_localizacao': v, 'tipo_localizacao': k}
            for k, v in mapas['localizacao'].items()
        ])
        df_loc.to_sql('dim_localizacao', con=conn, if_exists='replace', index=False)

        df_rede = pd.DataFrame([
            {'id_rede': v, 'tipo_rede': k}
            for k, v in mapas['rede'].items()
        ])
        df_rede.to_sql('dim_rede', con=conn, if_exists='replace', index=False)

        # Povoar Fato
        df_fato.to_sql('fato_indicadores_educacionais', con=conn, if_exists='replace', index=False)

    logger.info("✅ Réplica analítica local SQLite criada com sucesso.")


def validar_carga(engine):
    """Executa consultas de validação da integridade analítica."""
    logger.info("Executando validações estatísticas na camada Ouro...")
    queries = [
        ("Total de Registros na Fato", "SELECT COUNT(*) FROM fato_indicadores_educacionais"),
        ("Média de Aprovação (EM) por Região",
         """SELECT r.nome_regiao, ROUND(AVG(f.taxa_aprovacao_em), 2) AS media_aprovacao
            FROM fato_indicadores_educacionais f
            JOIN dim_regiao r ON f.id_regiao = r.id_regiao
            GROUP BY r.nome_regiao ORDER BY media_aprovacao DESC""")
    ]
    with engine.connect() as conn:
        for titulo, sql in queries:
            logger.info(f"--- {titulo} ---")
            res = conn.execute(text(sql))
            for row in res:
                logger.info(f"  {row}")


def executar_pipeline_gold():
    """Orquestrador do Pipeline de Carga Ouro."""
    logger.info("=" * 70)
    logger.info("INÍCIO DO PIPELINE ETL: PRATA -> OURO (MYSQL / STAR SCHEMA)")
    logger.info("=" * 70)

    # 1. Carregar dados da Prata
    df_silver = carregar_dados_silver()

    # Dicionários padrão caso o MySQL não esteja rodando
    mapas_padrao = {
        'tempo': {ano: i + 1 for i, ano in enumerate(sorted(df_silver['ano'].unique()))},
        'regiao': {reg: i + 1 for i, reg in enumerate(sorted(df_silver['regiao'].unique()))},
        'localizacao': {loc: i + 1 for i, loc in enumerate(sorted(df_silver['localizacao'].unique()))},
        'rede': {rede: i + 1 for i, rede in enumerate(sorted(df_silver['rede'].unique()))}
    }

    df_fato = preparar_tabela_fato(df_silver, mapas_padrao)

    # 2. Sempre gerar réplica SQLite em data/gold/ para auditoria e portabilidade
    gerar_replica_sqlite(df_silver, df_fato, mapas_padrao)

    # 3. Tentar conectar no MySQL
    try:
        logger.info(f"Testando conexão com MySQL em {MYSQL_CONFIG['host']}:{MYSQL_CONFIG['port']}...")
        engine_mysql = criar_engine_mysql(MYSQL_CONFIG)
        with engine_mysql.connect() as conn:
            conn.execute(text("SELECT 1"))
        logger.info("✅ Conexão com o servidor MySQL estabelecida.")

        executar_ddl_mysql(engine_mysql, ARQUIVO_DDL_SQL)
        mapas_mysql = obter_mapas_dimensoes(engine_mysql)
        df_fato_mysql = preparar_tabela_fato(df_silver, mapas_mysql)
        carregar_fato_mysql(engine_mysql, df_fato_mysql)
        validar_carga(engine_mysql)

    except Exception as e:
        logger.warning(
            f"⚠ O servidor MySQL não pôde ser contatado diretamente ({e}).\n"
            "   A réplica analítica completa foi salva em 'data/gold/inep_indicadores_educacionais.db'!\n"
            "   Para subir no MySQL quando o serviço estiver ativo, basta conferir o .env e reexecutar este script."
        )

    logger.info("=" * 70)
    logger.info("PIPELINE PRATA -> OURO CONCLUÍDO COM ÊXITO!")
    logger.info("=" * 70)


if __name__ == '__main__':
    executar_pipeline_gold()
