"""
==============================================================================
PIPELINE ETL - CAMADA BRONZE -> CAMADA PRATA (SILVER)
Projeto: Indicadores Educacionais por Região (INEP / MEC)
Autor: Engenharia de Dados
==============================================================================
Responsabilidades deste script:
1. Ingestão segura dos dados brutos a partir de 'data/raw/'.
2. Higienização: remoção de duplicatas de chaves primárias/compostas.
3. Tratamento de tipos de dados: normalização de strings e conversão numérica.
4. Enriquecimento: derivação de atributos dimensionais (década, siglas, flags).
5. Persistência na camada Prata em formatos interoperáveis (CSV limpo e Parquet).
==============================================================================
"""

import os
import sys
import logging
from pathlib import Path
import pandas as pd
import numpy as np

# Configuração de encoding para ambientes Windows
if sys.platform.startswith('win'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

# Configuração de Logging Estruturado
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("ETL_Bronze_Silver")

# Definição de Caminhos Relativos baseados na raiz do projeto
BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"
SILVER_DIR = BASE_DIR / "data" / "silver"

ARQUIVO_RAW_CSV = RAW_DIR / "br_inep_indicadores_educacionais_regiao.csv"
ARQUIVO_SILVER_CSV = SILVER_DIR / "indicadores_educacionais_silver.csv"
ARQUIVO_SILVER_PARQUET = SILVER_DIR / "indicadores_educacionais_silver.parquet"

# Mapeamentos auxiliares para enriquecimento
SIGLAS_REGIAO = {
    'Norte': 'NO',
    'Nordeste': 'NE',
    'Centro-Oeste': 'CO',
    'Sudeste': 'SE',
    'Sul': 'SU'
}

REDES_PUBLICAS = {'Pública', 'Estadual', 'Municipal', 'Federal'}


def garantir_diretorios():
    """Garante a existência das pastas necessárias no padrão Medalhão."""
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    SILVER_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"Diretórios validados: Raw={RAW_DIR} | Silver={SILVER_DIR}")


def extrair_bronze(caminho_csv: Path) -> pd.DataFrame:
    """Lê os dados brutos intocados da camada Bronze."""
    if not caminho_csv.exists():
        # Fallback de busca caso o arquivo esteja na raiz do repositório
        caminho_alternativo = BASE_DIR / "br_inep_indicadores_educacionais_regiao.csv"
        if caminho_alternativo.exists():
            logger.warning(f"Arquivo não localizado em {caminho_csv}. Utilizando cópia de {caminho_alternativo}")
            caminho_csv = caminho_alternativo
        else:
            raise FileNotFoundError(f"Arquivo de dados brutos não localizado em: {caminho_csv}")

    logger.info(f"Carregando dados brutos da Camada Bronze: {caminho_csv}")
    df_raw = pd.read_csv(caminho_csv, sep=',', encoding='utf-8', low_memory=False)
    logger.info(f"Dados brutos carregados com sucesso: {df_raw.shape[0]} linhas x {df_raw.shape[1]} colunas.")
    return df_raw


def transformar_dados(df_raw: pd.DataFrame) -> pd.DataFrame:
    """
    Executa todas as regras de higienização, tipagem e enriquecimento
    para transição Bronze -> Silver.
    """
    logger.info("Iniciando processo de higienização e transformação...")
    df = df_raw.copy()

    # 1. Remoção de duplicatas estritas na chave natural
    chaves_naturais = ['ano', 'regiao', 'localizacao', 'rede']
    qtd_inicial = len(df)
    df = df.drop_duplicates(subset=chaves_naturais).copy()
    duplicatas_removidas = qtd_inicial - len(df)
    if duplicatas_removidas > 0:
        logger.info(f"Removidas {duplicatas_removidas} linhas duplicadas com base nas chaves {chaves_naturais}.")

    # 2. Padronização e sanitização de strings
    for col in ['regiao', 'localizacao', 'rede']:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()

    # 3. Conversão de tipo de 'ano'
    df['ano'] = pd.to_numeric(df['ano'], errors='coerce').fillna(0).astype(int)

    # 4. Tratamento das colunas numéricas / métricas
    colunas_categoricas = set(chaves_naturais)
    colunas_metricas = [c for c in df.columns if c not in colunas_categoricas]

    for col in colunas_metricas:
        # Substitui vírgula por ponto e converte para numérico
        df[col] = pd.to_numeric(
            df[col].astype(str).str.replace(',', '.').str.strip(),
            errors='coerce'
        ).round(2)

    # 5. Enriquecimento de Dados
    logger.info("Aplicando enriquecimento de dados (derivação dimensional)...")
    
    # Década
    df['decada'] = df['ano'].apply(
        lambda a: f"{(a // 10) * 10}s" if a > 0 else "Indefinida"
    )

    # Sigla da Região
    df['regiao_sigla'] = df['regiao'].map(SIGLAS_REGIAO).fillna('BR')

    # Flag de Rede Pública (1 = Pública/Estadual/Municipal/Federal, 0 = Privada/Outro)
    df['flag_rede_publica'] = df['rede'].apply(lambda r: 1 if r in REDES_PUBLICAS else 0)

    # Flag de Localização Rural (1 = Rural, 0 = Urbana/Total)
    df['flag_rural'] = df['localizacao'].apply(lambda l: 1 if l == 'Rural' else 0)

    # Categoria Macro de Rede
    df['categoria_rede'] = df['rede'].apply(
        lambda r: 'Pública' if r in REDES_PUBLICAS else ('Privada' if r == 'Privada' else 'Consolidada')
    )

    logger.info(f"Transformação concluída: {df.shape[0]} registros limpos e tipados.")
    return df


def carregar_silver(df_silver: pd.DataFrame):
    """Persiste os dados limpos e enriquecidos na Camada Prata."""
    logger.info(f"Salvando base Prata em CSV: {ARQUIVO_SILVER_CSV}")
    df_silver.to_csv(ARQUIVO_SILVER_CSV, index=False, encoding='utf-8')

    try:
        logger.info(f"Salvando base Prata em Parquet: {ARQUIVO_SILVER_PARQUET}")
        df_silver.to_parquet(ARQUIVO_SILVER_PARQUET, index=False, engine='pyarrow')
        logger.info("Arquivo Parquet persistido com sucesso (compressão e alta performance colunar).")
    except Exception as e:
        logger.warning(f"Não foi possível salvar em formato Parquet ({e}). Mantendo apenas versão CSV.")

    logger.info("Persistência na Camada Prata concluída com êxito.")


def executar_pipeline_bronze_silver():
    """Função orquestradora da etapa Bronze -> Silver."""
    logger.info("=" * 70)
    logger.info("INÍCIO DO PIPELINE ETL: BRONZE -> PRATA")
    logger.info("=" * 70)
    garantir_diretorios()
    df_raw = extrair_bronze(ARQUIVO_RAW_CSV)
    df_silver = transformar_dados(df_raw)
    carregar_silver(df_silver)
    logger.info("=" * 70)
    logger.info("PIPELINE BRONZE -> PRATA CONCLUÍDO COM SUCESSO!")
    logger.info("=" * 70)
    return df_silver


if __name__ == '__main__':
    executar_pipeline_bronze_silver()
