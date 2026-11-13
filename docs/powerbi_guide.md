# 📊 Guia de Integração com Power BI & Catálogo de Medidas DAX

## Pipeline ETL — Indicadores Educacionais por Região (INEP / MEC)
### Arquitetura Medalhão — Camada Ouro (Gold / MySQL & SQLite)

---

## 1. Conexão Nativa do Power BI com o Banco de Dados

### 1.1 Pré-requisitos de Ambiente
Para conectar o Power BI Desktop ao banco de dados relacional gerado na Camada Ouro:
* **Power BI Desktop** (versão 2023 ou superior).
* **MySQL Connector/NET** (versão 8.0.32 ou superior) instalado no Windows ([Download Oficial Oracle MySQL](https://dev.mysql.com/downloads/connector/net/)).
* Instância do MySQL rodando com o banco `inep_indicadores_educacionais` criado e populado via script `src/load_gold.py`.
* *(Alternativa Portátil sem MySQL)*: Pode-se conectar diretamente via conector ODBC/SQLite apontando para o arquivo `data/gold/inep_indicadores_educacionais.db` gerado automaticamente pelo pipeline.

---

### 1.2 Passo a Passo da Conexão MySQL

1. Abra o **Power BI Desktop**.
2. Na faixa de opções superior (Guia **Página Inicial**), clique em **Obter Dados** > **Banco de Dados** > **Banco de Dados MySQL**.
3. Na janela modal de conexão:
   * **Servidor**: `localhost:3306` (ou o endereço IP/porta do servidor de produção).
   * **Banco de Dados**: `inep_indicadores_educacionais`.
   * **Modo de Conectividade de Dados**:
     * **Importar (Recomendado)**: Carrega os dados na memória do Power BI (VertiPaq engine). Garante máxima performance, compatibilidade irrestrita com funções DAX de série temporal (`SAMEPERIODLASTYEAR`, `DATEADD`) e navegação ágil.
     * **DirectQuery**: Mantém os dados no MySQL e realiza consultas SQL em tempo real a cada interação nos visuais. Ideal quando os dados são atualizados com alta frequência.
4. Clique em **OK**. Na tela de autenticação, selecione a guia **Banco de Dados**, informe o usuário (ex: `root`) e a respectiva senha configurada no arquivo `.env`.
5. Na janela do **Navegador**:
   * **Opção Recomendada (Esquema Estrela Completo)**: Selecione as 5 tabelas:
     - `dim_tempo`
     - `dim_regiao`
     - `dim_localizacao`
     - `dim_rede`
     - `fato_indicadores_educacionais`
   * *(Ou Opção Desnormalizada)*: Marque a view `vw_indicadores_completos`.
6. Clique em **Carregar**.

---

### 1.3 Modelagem de Dados e Relacionamentos no Power BI

No Power BI, acesse a exibição **Modelo** (ícone de diagrama na barra lateral esquerda).
Configure os relacionamentos no padrão **Esquema Estrela (Star Schema)** com cardinalidade **1 para Muitos (1:*)** e **Direção do Filtro Cruzado: Único**:

```
           ┌──────────────┐
           │  dim_tempo   │
           │  id_tempo [1]│
           └──────┬───────┘
                  │ [1]
                  │
                  │ [*] id_tempo
┌──────────────┐  │   ┌──────────────────┐
│  dim_regiao  │  │   │ dim_localizacao  │
│ id_regiao [1]├──┼───┤id_localizacao [1]│
└──────┬───────┘  │   └────────┬─────────┘
       │ [*]      │            │ [*]
       │ id_regiao│ id_localiz.│
  ┌────┴──────────┴────────────┴─────┐
  │   fato_indicadores_educacionais  │
  └──────────────────┬───────────────┘
                     │ [*] id_rede
                     │
                     │ [1]
              ┌──────┴───────┐
              │   dim_rede   │
              │  id_rede [1] │
              └──────────────┘
```

#### Tabela de Especificação dos Relacionamentos:

| Tabela Origem (Dimensão - Lado 1) | Coluna Chave Primária | Tabela Destino (Fato - Lado *) | Coluna Chave Estrangeira | Cardinalidade | Direção Filtro |
|---|---|---|---|---|---|
| `dim_tempo` | `id_tempo` | `fato_indicadores_educacionais` | `id_tempo` | 1:* | Único |
| `dim_regiao` | `id_regiao` | `fato_indicadores_educacionais` | `id_regiao` | 1:* | Único |
| `dim_localizacao` | `id_localizacao` | `fato_indicadores_educacionais` | `id_localizacao` | 1:* | Único |
| `dim_rede` | `id_rede` | `fato_indicadores_educacionais` | `id_rede` | 1:* | Único |

> **Boas Práticas de Modelagem**:
> 1. Oculte as colunas de chave estrangeira (`id_tempo`, `id_regiao`, `id_localizacao`, `id_rede`) na visualização da tabela Fato para evitar que usuários finais criem agregações sobre IDs técnicos.
> 2. Crie uma tabela dedicada exclusiva para medidas DAX (`_Medidas`).

---

## 2. Catálogo de Medidas DAX (Prontas para Copiar e Colar)

### Medida 1: Total de Registros Fato / Amostras Escolares
Contabiliza o volume total de observações educacionais analisadas no contexto filtrado:

```dax
Total Registros Analisados = 
COUNTROWS(fato_indicadores_educacionais)
```

---

### Medida 2: Taxa Média de Aprovação no Ensino Médio (%)
Calcula a taxa média aritmética de aprovação escolar:

```dax
Taxa Media Aprovacao EM = 
AVERAGE(fato_indicadores_educacionais[taxa_aprovacao_em])
```

---

### Medida 3: Taxa de Aprovação do Ano Anterior (Prior Year - PY)
Recupera o valor do indicador educacional para o ano letivo imediatamente anterior, permitindo análises comparativas e temporais consistentes:

```dax
Aprovacao EM Ano Anterior = 
VAR AnoContexto = SELECTEDVALUE(dim_tempo[ano])
VAR AnoPrevio = AnoContexto - 1
RETURN
    CALCULATE(
        [Taxa Media Aprovacao EM],
        REMOVEFILTERS(dim_tempo),
        dim_tempo[ano] = AnoPrevio
    )
```

---

### Medida 4: Variação Percentual Ano a Ano (Δ% YoY)
Calcula o crescimento relativo da taxa de aprovação em relação ao ano letivo anterior:

```dax
Variacao Pct Aprovacao YoY = 
VAR ValorAtual = [Taxa Media Aprovacao EM]
VAR ValorAnterior = [Aprovacao EM Ano Anterior]
RETURN
    IF(
        NOT ISBLANK(ValorAnterior) && ValorAnterior <> 0,
        DIVIDE(ValorAtual - ValorAnterior, ValorAnterior, BLANK()),
        BLANK()
    )
```
*(Formate esta medida como Percentual `%` com 2 casas decimais no Power BI).*

---

### Medida 5: Variação em Pontos Percentuais (Δ p.p.)
Mede a oscilação absoluta do indicador educacional entre períodos:

```dax
Variacao Pontos Percentuais Aprovacao = 
VAR ValorAtual = [Taxa Media Aprovacao EM]
VAR ValorAnterior = [Aprovacao EM Ano Anterior]
RETURN
    IF(
        NOT ISBLANK(ValorAnterior),
        ValorAtual - ValorAnterior,
        BLANK()
    )
```

---

### Medida 6: Taxa Média de Abandono Escolar no Ensino Médio (%)
Mede a evasão escolar média na série de Ensino Médio:

```dax
Taxa Media Abandono EM = 
AVERAGE(fato_indicadores_educacionais[taxa_abandono_em])
```

---

### Medida 7: Índice Sintético de Vulnerabilidade Educacional (Métrica Composta)
Combina a Distorção Idade-Série (peso 60%) com a Taxa de Abandono (peso 40%) para identificar bolsões críticos de risco pedagógico:

```dax
Indice Vulnerabilidade Educacional = 
VAR TDI = AVERAGE(fato_indicadores_educacionais[tdi_em])
VAR Abandono = AVERAGE(fato_indicadores_educacionais[taxa_abandono_em])
RETURN
    (0.60 * COALESCE(TDI, 0)) + (0.40 * COALESCE(Abandono, 0))
```

---

### Medida 8: Classificação Semáforo de Desempenho (KPI Status)
Classifica o resultado educacional para alimentar regras de formatação condicional de cores (Verde, Âmbar, Vermelho):

```dax
Status Desempenho Aprovacao = 
VAR Aprov = [Taxa Media Aprovacao EM]
RETURN
    SWITCH(
        TRUE(),
        ISBLANK(Aprov), "Sem Dados",
        Aprov >= 90.0, "Alto Desempenho (Verde)",
        Aprov >= 80.0, "Moderado (Ambar)",
        "Critico (Vermelho)"
    )
```

---

### Medida 9: Ranking Regional de Desempenho (RANKX)
Classifica dinamicamente as macrorregiões com base no melhor índice de aprovação:

```dax
Ranking Aprovacao Regional = 
IF(
    HASONEVALUE(dim_regiao[nome_regiao]),
    RANKX(
        ALL(dim_regiao[nome_regiao]),
        [Taxa Media Aprovacao EM],
        ,
        DESC,
        Dense
    ),
    BLANK()
)
```

---

## 3. Especificação Detalhada do Dashboard Visual

O painel deve seguir as diretrizes acadêmicas de **Design Executivo e Usabilidade**:
* **Regra dos 5 Segundos**: Um gestor educacional deve compreender a saúde geral da rede nos primeiros 5 segundos.
* **Hierarquia Visual**:
  * **Topo**: KPIs consolidados em números grandes e cartões com indicação de tendência.
  * **Meio**: Gráficos analíticos de tendência temporal e comparações de dispersão.
  * **Base**: Matrizes detalhadas com micrográficos (sparklines) e segmentação regional.

---

### 3.1 Página 1: Painel Executivo de Inteligência Educacional

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ FILTROS DINÂMICOS: [Ano: 2024 ▼]  [Região: Todas ▼]  [Localização: Total ▼]  [Rede: Total ▼] │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [ KPI CARD 1 ]       [ KPI CARD 2 ]       [ KPI CARD 3 ]       [ KPI CARD 4 ]          │
│ Taxa Aprovação (EM)  Taxa Abandono (EM)   Distorção (TDI EM)   Horas/Dia (HAD EM)      │
│     91.8%                2.9%                 15.4%                 5.7h               │
│   ▲ +1.2% YoY          ▼ -0.4% YoY          ▼ -1.8% YoY          ▲ +0.3h YoY           │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│ GRÁFICO DE LINHAS (Evolução Temporal):    │ GRÁFICO DE BARRAS AGRUPADAS:               │
│ Tendência da Taxa de Aprovação no Ensino  │ Comparação Regional do Censo 2024          │
│ Médio por Região (2013 a 2024)            │ (Aprovação vs Distorção Idade-Série)       │
│ Eixo X: dim_tempo[ano]                    │ Eixo X: dim_regiao[nome_regiao]            │
│ Eixo Y: [Taxa Media Aprovacao EM]         │ Eixo Y: [Taxa Media Aprovacao EM]          │
│ Legenda: dim_regiao[nome_regiao]          │         [Distorção Media TDI]              │
├───────────────────────────────────────────┴────────────────────────────────────────────┤
│ MATRIZ ANALÍTICA COM FORMATAÇÃO CONDICIONAL:                                           │
│ Linhas: dim_regiao[nome_regiao] > dim_localizacao[tipo_localizacao]                    │
│ Colunas de Métricas: Aprovação (EM) | Abandono (EM) | TDI (EM) | DSU (EM) | HAD (EM)   │
│ Gradiente Condicional: Verde para alta aprovação / Vermelho para alto abandono         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Página 2: Diagnóstico de Evasão e Desigualdades Territoriais

* **Visual 1 (Gráfico de Barras Empilhadas)**: Taxa de Abandono Escolar por Dependência Administrativa (`Pública` vs `Privada`).
* **Visual 2 (Gráfico de Colunas Clustered)**: Gap Territorial na Distorção Idade-Série (`Urbana` vs `Rural`) por Região.
* **Visual 3 (Mapa Coroplético do Brasil)**: Centróides das Regiões coloridos pela severidade do índice de vulnerabilidade educacional (`latitude` e `longitude` da `dim_regiao`).
* **Visual 4 (Scatter Plot / Dispersão)**: Eixo X: Distorção Idade-Série; Eixo Y: Taxa de Abandono; Tamanho da Bolha: Média de Alunos por Turma (`atu_em`).

---

### 3.3 Paleta de Cores e Acessibilidade

| Entidade | Cor Hexadecimal | Significado / Aplicação |
|---|---|---|
| **Norte** | `#2E7D32` | Verde Floresta institucional |
| **Nordeste** | `#E65100` | Laranja caloroso institucional |
| **Centro-Oeste** | `#F57F17` | Âmbar solar |
| **Sudeste** | `#1565C0` | Azul Safira corporativo |
| **Sul** | `#6A1B9A` | Roxo Ametista |
| **Alerta Positivo (Meta atingida)** | `#10B981` | Verde Esmeralda |
| **Alerta Negativo (Evasão/Risco)** | `#EF4444` | Vermelho Carmesim |
| **Fundo Dark Premium** | `#0F172A` / `#1E293B` | Slate moderno de alto contraste |
