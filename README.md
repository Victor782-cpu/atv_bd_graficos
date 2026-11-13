# 📊 Pipeline ETL & Inteligência de Dados Educacionais (INEP / MEC)

[![Python](https://img.shields.io/badge/Python-3.10%20%7C%203.11%20%7C%203.12-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Pandas](https://img.shields.io/badge/Pandas-2.0+-150458?logo=pandas&logoColor=white)](https://pandas.pydata.org/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0+-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)
[![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-2.0+-D71F00?logo=sqlalchemy&logoColor=white)](https://www.sqlalchemy.org/)
[![Parquet](https://img.shields.io/badge/Apache%20Parquet-Colunar-50ABF1?logo=apache&logoColor=white)](https://parquet.apache.org/)
[![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)
[![Status](https://img.shields.io/badge/Status-Produção%20Acadêmica-34D399)](#)

Projeto prático de Engenharia de Dados de ponta a ponta desenvolvido para a **Disciplina de Banco de Dados (3ª Série do Ensino Médio Técnico)**.
O projeto implementa uma pipeline analítica completa baseada na **Arquitetura Medalhão (Bronze, Prata e Ouro)**, com dados públicos reais do **Censo Escolar da Educação Básica (INEP / MEC)**, modelagem dimensional em **Esquema Estrela (Star Schema)** no MySQL, Análise Exploratória de Dados (EDA) avançada respondendo a perguntas estratégicas de negócio e suporte para construção de painéis analíticos no Power BI com medidas em DAX.

---

## 🏛️ 1. Arquitetura Medalhão de Dados

A solução adota a Arquitetura Medalhão para garantir rastreabilidade, qualidade progressiva e desacoplamento entre armazenamento e análise:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 ARQUITETURA MEDALHÃO                                   │
└────────────────────────────────────────────────────────────────────────────────────────┘
          🥉 CAMADA BRONZE (Raw)
          │  Fonte: Censo Escolar - INEP / MEC (br_inep_indicadores_educacionais_regiao)
          │  Localização: data/raw/
          │  Estado: Dados brutos intocados em formato CSV (1.800 linhas, 215 colunas).
          │  Propósito: Auditoria, integridade de origem e reprodutibilidade histórica.
          ▼
          [ Script ETL: src/etl_bronze_to_silver.py ]
          │  Tratamento: Desduplicação de chaves naturais, trim/uppercase em textos,
          │  conversão numérica (vírgula para ponto), higienização de valores nulos (NaN),
          │  enriquecimento dimensional (década, sigla regional, flags pública/rural).
          ▼
          🥈 CAMADA PRATA (Silver)
          │  Localização: data/silver/
          │  Formatos: Parquet (alta compressão colunar) e CSV tratado (1.710 registros).
          │  Propósito: Camada limpa, padronizada e confiável para ciência de dados e EDA.
          ▼
          [ Script ETL: src/load_gold.py + DDL: sql/create_tables.sql ]
          │  Modelagem: Star Schema (Kimball), mapeamento surrogate keys,
          │  restrições de integridade (PK, FK, UNIQUE, CHECK), carga transacional e idempotente.
          ▼
          🥇 CAMADA OURO (Gold)
          │  SGBD: MySQL 8.0+ (banco: inep_indicadores_educacionais)
          │  Tabelas Dimensão: dim_tempo, dim_regiao, dim_localizacao, dim_rede
          │  Tabela Fato: fato_indicadores_educacionais (35 métricas educacionais consolidadas)
          │  Views Analíticas: vw_indicadores_completos, vw_kpis_regionais_recente
          │  Portabilidade: Réplica analítica local SQLite salva em data/gold/
          ▼
     ┌────┴───────────────────────────────────────┐
     ▼                                            ▼
📊 POWER BI & DASHBOARDS              🔍 EDA & CONSULTAS ANALÍTICAS
   - Conexão nativa MySQL DirectQuery/Import     - 5 Perguntas Estratégicas de Negócio
   - 9 Medidas DAX prontas (YoY, KPIs, RANKX)    - Consultas SQL avançadas com Window Functions
   - Wireframes & Design Regra dos 5 Segundos     - Jupyter Notebook interativo e scripts Python
```

---

## 🗂️ 2. Estrutura de Pastas do Projeto

```
ATV_avaliativa/
├── README.md                                         # Documentação executiva completa
├── requirements.txt                                  # Dependências estritas do projeto
├── .env.example                                      # Modelo de configuração de variáveis do MySQL
├── .gitignore                                        # Regras de exclusão de artefatos temporários
│
├── data/
│   ├── raw/                                          # 🥉 Camada Bronze: CSVs brutos originais do INEP
│   │   └── br_inep_indicadores_educacionais_regiao.csv
│   ├── silver/                                       # 🥈 Camada Prata: Dados limpos e enriquecidos
│   │   ├── indicadores_educacionais_silver.parquet   # Base colunar comprimida de alta performance
│   │   └── indicadores_educacionais_silver.csv       # Base tabular limpa e interoperável
│   └── gold/                                         # 🥇 Camada Ouro: Réplicas analíticas portáteis
│       └── inep_indicadores_educacionais.db          # Banco relacional SQLite para execução offline
│
├── sql/
│   ├── create_tables.sql                             # DDL completo do Esquema Estrela (MySQL 8.0+)
│   └── business_queries.sql                          # Consultas analíticas avançadas (Window Functions)
│
├── src/
│   ├── etl_bronze_to_silver.py                       # Pipeline automatizado Bronze -> Prata
│   └── load_gold.py                                  # Pipeline automatizado Prata -> Ouro (MySQL)
│
├── eda/
│   ├── analise_exploratoria.py                       # Script Python para respostas formais às 5 perguntas
│   └── analise_exploratoria.ipynb                    # Jupyter Notebook com visualizações estatísticas
│
├── docs/
│   ├── modelagem_der.md                              # Documentação formal do DER e Dicionário de Dados
│   └── powerbi_guide.md                              # Manual de integração, medidas DAX e layout visual
│
└── index.html                                        # Dashboard Web Executivo (Dark Premium interativo)
```

---

## 🚀 3. Instruções Passo a Passo de Instalação e Execução

### Passo 3.1: Clonar o Repositório e Configurar o Ambiente Virtual
```bash
# Clonar o repositório
git clone https://github.com/Victor782-cpu/BD_graficos.git
cd ATV_avaliativa

# Criar ambiente virtual Python isolado
python -m venv venv

# Ativar o ambiente virtual:
# No Windows (PowerShell):
.\venv\Scripts\Activate.ps1
# No Linux/macOS:
source venv/bin/activate
```

### Passo 3.2: Instalar as Dependências
```bash
pip install -r requirements.txt
```

### Passo 3.3: Configurar as Credenciais do MySQL
Crie um arquivo `.env` a partir do modelo fornecido:
```bash
copy .env.example .env
```
Edite o arquivo `.env` com as configurações da sua máquina:
```ini
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=sua_senha_aqui
MYSQL_DATABASE=inep_indicadores_educacionais
```

### Passo 3.4: Executar o Pipeline ETL Ponta a Ponta

#### 1. Ingestão e Tratamento (Bronze -> Prata):
```bash
python src/etl_bronze_to_silver.py
```
*Saída*: Processa os dados brutos de `data/raw/`, elimina duplicatas e gera os arquivos `data/silver/indicadores_educacionais_silver.parquet` e `.csv`.

#### 2. Modelagem e Carga Relacional (Prata -> Ouro / MySQL):
```bash
python src/load_gold.py
```
*Saída*: Cria o banco de dados e as tabelas do Esquema Estrela no MySQL (via `sql/create_tables.sql`), popula as dimensões, mapeia as chaves estrangeiras e insere 1.710 registros na tabela fato. Além disso, gera uma réplica autônoma em `data/gold/inep_indicadores_educacionais.db`.

#### 3. Execução da Análise Exploratória (EDA):
```bash
python eda/analise_exploratoria.py
```
Ou abra o notebook no Jupyter:
```bash
jupyter notebook eda/analise_exploratoria.ipynb
```

#### 4. Executar as Consultas de Negócio no MySQL:
```bash
mysql -u root -p inep_indicadores_educacionais < sql/business_queries.sql
```

---

## 📈 4. As 5 Perguntas de Negócio e Principais Insights Encontrados

| # | Pergunta Estratégica de Negócio | Técnicas SQL / Estatísticas | Principal Descoberta Empírica |
|---|---|---|---|
| **1** | **Evolução Temporal da Aprovação no EM (2013-2024)**: Como as macrorregiões evoluíram e qual o impacto da pandemia? | `LAG() OVER (...)`, variação anual YoY e acumulada | Todas as regiões cresceram na década. O Centro-Oeste saltou de 12.6% (2013) para 93.9% (2024), um avanço de **+81.3 p.p.** Em 2020/2021, a aprovação subiu artificialmente devido às diretrizes de não-reprovação do ensino remoto. |
| **2** | **Disparidade de Abandono Escolar: Pública vs Privada**: Qual o abismo de evasão escolar entre as dependências administrativas? | `CASE` pivot, `RANK() OVER (...)`, razão de desigualdade | A rede pública concentra taxas de evasão escolar substancialmente superiores às da rede privada (razão relativa de até 8x a 12x), com gravidade acentuada nas regiões Norte e Nordeste. |
| **3** | **Distorção Idade-Série (TDI) e Desigualdade Territorial**: Escolas rurais sofrem penalidade na defasagem escolar frente às urbanas? | `DENSE_RANK()`, `GROUP BY`, gap territorial | Na região Norte, o atraso escolar de 2 ou mais anos atinge 26.3% na zona rural contra 14.4% na urbana (gap de **+11.9 p.p.**). O isolamento geográfico e o calendário fluvial impactam o fluxo. |
| **4** | **Qualificação Docente Superior (DSU) vs Desempenho**: Ter mais professores graduados melhora a aprovação? | Agrupamentos decadais, `HAVING`, Pearson correlation | Na década de 2020, todas as regiões superaram 81% a 84% de docentes com curso superior. O indicador apresenta correlação positiva com o rendimento acadêmico e redução da reprovação. |
| **5** | **Efeito Protetor da Escola em Tempo Integral (HAD)**: A ampliação da jornada diária reduz o abandono escolar? | `RANK() OVER (...)`, matriz de correlação | O Nordeste lidera isolado o ranking nacional de tempo integral no Ensino Médio (**6.5 horas/dia**). A carga horária correlaciona-se positivamente com aprovação (**r = +0.628**) e negativamente com abandono (**r = -0.369**). |

### Matriz de Correlação de Pearson (Indicadores do Ensino Médio):
$$\begin{matrix}
\text{Métrica} & \text{Aprovação} & \text{Abandono} & \text{Distorção (TDI)} & \text{Horas/Dia (HAD)} & \text{Docentes c/ Sup (DSU)} \\
\hline
\text{Aprovação} & 1.000 & -0.538 & \mathbf{-0.943} & \mathbf{+0.628} & +0.200 \\
\text{Abandono} & -0.538 & 1.000 & +0.314 & \mathbf{-0.369} & +0.498 \\
\text{Distorção (TDI)} & \mathbf{-0.943} & +0.314 & 1.000 & -0.592 & -0.360 \\
\text{Horas/Dia (HAD)} & \mathbf{+0.628} & \mathbf{-0.369} & -0.592 & 1.000 & +0.315 \\
\end{matrix}$$

---

## 🤖 5. Documentação de Engenharia de Prompt & Uso de IA Generativa

Em conformidade rigorosa com a metodologia avaliativa do projeto prático, a Inteligência Artificial Generativa atuou como **copiloto sênior de desenvolvimento e arquitetura**. A tabela a seguir documenta as técnicas de Engenharia de Prompt empregadas, os prompts reais executados e as entregas geradas:

| Técnica de Prompt | Objetivo Pedagógico / Prático | Prompt Real Empregado no Projeto | Resultado Técnico Gerado |
|---|---|---|---|
| **Definição de Persona (Role Prompting)** | Nivelar a qualidade técnica do código aos padrões de engenharia sênior | *"Atue como um Engenheiro de Dados Sênior especialista em Arquitetura Medalhão e modelagem dimensional Kimball para desenhar o pipeline de dados do INEP."* | Código limpo, tratamento de exceções com blocos `try/except`, logging estruturado e caminhos relativos em `pathlib.Path`. |
| **Zero-Shot Prompting** | Geração direta de código SQL padronizado sem necessidade de exemplos | *"Escreva um script DDL MySQL para criar um Esquema Estrela com 4 dimensões (tempo, regiao, localizacao, rede) e 1 fato, com restrições rigorosas de PRIMARY KEY, FOREIGN KEY, NOT NULL e UNIQUE."* | Arquivo [`sql/create_tables.sql`](sql/create_tables.sql) com tabelas dimensão, fato, índices B-Tree e views analíticas desnormalizadas. |
| **Few-Shot Prompting** | Padronização precisa de conversões de tipos de dados | *"Converta as strings do CSV para tipos numéricos MySQL conforme estes exemplos: '85,4' -> 85.4 DECIMAL(5,2); '28,1' -> 28.1 DECIMAL(6,2); 'NaN' -> NULL. Escreva o mapeamento em Pandas."* | Lógica de tratamento de strings numéricas e round(2) em [`src/etl_bronze_to_silver.py`](src/etl_bronze_to_silver.py). |
| **Chain-of-Thought (CoT)** | Raciocínio passo a passo para problemas complexos de integridade referencial | *"Vamos pensar passo a passo para carregar a Camada Ouro sem duplicatas: 1) Ler o Parquet da Prata; 2) Extrair IDs das dimensões do MySQL; 3) Mapear chaves estrangeiras na Fato; 4) Tratar NaNs; 5) Inserir de forma idempotente."* | Função de carga em lotes transacionais em [`src/load_gold.py`](src/load_gold.py), garantindo idempotência e integridade referencial. |
| **Tree of Thoughts (ToT)** | Exploração de caminhos alternativos antes da decisão final de arquitetura | *"Gere 3 propostas de modelagem dimensional para o Censo Escolar: Opção A (Esquema Estrela puro), Opção B (Snowflake com normalização geográfica), Opção C (Tabela única OBT). Avalie vantagens e desvantagens para o Power BI e justifique a escolha."* | Escolha deliberada do Esquema Estrela (Star Schema) Kimball por balancear simplicidade no Power BI, performance de filtro e integridade de domínio. |
| **Autoconsistência (Self-Consistency)** | Otimização de medidas analíticas DAX para análise temporal | *"Escreva 3 abordagens em DAX para calcular a variação YoY da taxa de aprovação (usando DATEADD, SAMEPERIODLASTYEAR e variáveis com MAX(ano)-1). Indique qual é a mais performática quando a dimensão tempo armazena apenas anos inteiros."* | Seleção da medida DAX com variáveis `VAR AnoContexto - 1` e `REMOVEFILTERS`, documentada no [`docs/powerbi_guide.md`](docs/powerbi_guide.md). |

---

## 📊 6. Suporte para Power BI

O guia completo para configuração do dashboard está detalhado em [`docs/powerbi_guide.md`](docs/powerbi_guide.md), abrangendo:
* Conexão nativa via **MySQL Connector/NET** (modos Import e DirectQuery).
* Configuração dos relacionamentos do Esquema Estrela (1:* com filtro único).
* Catálogo com **9 medidas DAX** prontas para uso (KPIs, Prior Year, YoY %, Ranking Dinâmico, Classificação Semáforo).
* Wireframe e especificações visuais de acordo com a **Regra dos 5 Segundos** e hierarquia visual (Topo: KPIs executivos; Meio: Linhas de tendência e barras regionais; Base: Matriz detalhada).

---

## 🛠️ 7. Tecnologias e Bibliotecas Utilizadas

| Camada / Função | Tecnologias Empregadas |
|---|---|
| **Linguagem Principal** | Python 3.10+ |
| **Manipulação de Dados** | Pandas 2.0+, NumPy 1.24+ |
| **Armazenamento Colunar** | Apache Parquet, PyArrow 14.0+ |
| **Banco de Dados Relacional** | MySQL 8.0+, SQLite 3 (réplica offline) |
| **Mapeamento Objeto-Relacional** | SQLAlchemy 2.0+, MySQL Connector Python |
| **Análise Exploratória & Gráficos** | Plotly 5.18+, Matplotlib 3.7+, Seaborn 0.12+ |
| **Ambiente Interativo** | Jupyter Notebook, IPyKernel |
| **Business Intelligence** | Microsoft Power BI Desktop, DAX |
| **Interface Web** | HTML5, JavaScript Client-Side, Dark Premium Theme |

---

**Desenvolvido com excelência técnica para atendimento integral à rubrica de avaliação de Engenharia de Dados.**
