/* =====================================================================
   Curso de Banco de Dados Relacional aplicado a Fiscalizacao Tributaria
   Banco de exemplo: curso_integridade_fiscal
   Script 01 - Criacao do banco, das tabelas e das restricoes
   SGBD: PostgreSQL 12 ou superior
   ---------------------------------------------------------------------
    Script traduzido de SQL Server para PostgreSQL com o uso de IA.
   ---------------------------------------------------------------------

   ATENCAO: este script APAGA e RECRIA as tabelas do esquema, caso ja
   existam. Execute-o apenas em ambiente de estudos.

   OBSERVACOES DE PORTABILIDADE (SQL Server -> PostgreSQL):
   1) PostgreSQL nao permite CREATE DATABASE dentro de bloco condicional
      nem dentro do mesmo "script" que depois usa esse banco (nao existe
      transacao cruzando CREATE DATABASE). Por isso a criacao condicional
      do banco e feita com \gexec (recurso do psql) e a troca de conexao
      e feita com o meta-comando \c (tambem exclusivo do psql).
      Rode este arquivo com o cliente psql, por exemplo:
          psql -U postgres -f 01_criar_banco.sql
   2) Nao existe GO (separador de lote do T-SQL) em PostgreSQL; cada
      instrucao e terminada apenas por ";".
   3) SET NOCOUNT ON e um comando exclusivo do T-SQL e nao tem
      equivalente necessario em PostgreSQL (removido).
   4) PRINT foi substituido por \echo (meta-comando do psql).
   5) Os padroes de CHECK que usavam o LIKE com classe de caracteres do
      T-SQL (ex.: NOT LIKE '%[^0-9]%') foram reescritos com expressoes
      regulares POSIX, nativas do PostgreSQL (ex.: ~ '^[0-9]+$').
   6) DROP TABLE ... IF EXISTS aceita CASCADE no PostgreSQL, o que é
      usado aqui para remover dependencias residuais (ex.: indices)
      automaticamente, assim como o SQL Server remove ao dropar a tabela.
   ===================================================================== */

/* ---------------------------------------------------------------------
   1. Banco de dados
   --------------------------------------------------------------------- */
SELECT 'CREATE DATABASE curso_integridade_fiscal'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'curso_integridade_fiscal'
)\gexec

\c curso_integridade_fiscal

/* ---------------------------------------------------------------------
   2. Remocao das exibicoes e tabelas (ordem inversa das dependencias)
   --------------------------------------------------------------------- */
DROP VIEW  IF EXISTS public.vw_painel_malha;
DROP VIEW  IF EXISTS public.vw_autos_por_auditor;
DROP VIEW  IF EXISTS public.vw_nfe_saidas;
DROP VIEW  IF EXISTS public.vw_divergencia_nfe_efd;

DROP TABLE IF EXISTS public.auto_infracao   CASCADE;
DROP TABLE IF EXISTS public.ordem_servico   CASCADE;
DROP TABLE IF EXISTS public.efd_c170        CASCADE;
DROP TABLE IF EXISTS public.efd_c100        CASCADE;
DROP TABLE IF EXISTS public.nfe_item        CASCADE;
DROP TABLE IF EXISTS public.nfe             CASCADE;
DROP TABLE IF EXISTS public.referencia_preco CASCADE;
DROP TABLE IF EXISTS public.contribuinte    CASCADE;
DROP TABLE IF EXISTS public.auditor_fiscal  CASCADE;
DROP TABLE IF EXISTS public.municipio       CASCADE;

/* ---------------------------------------------------------------------
   3. Tabelas de cadastro
   --------------------------------------------------------------------- */

-- 3.1 Municipios -------------------------------------------------------
CREATE TABLE public.municipio (
    id_municipio   INT           NOT NULL,
    cod_ibge       CHAR(7)       NOT NULL,
    nome           VARCHAR(80)   NOT NULL,
    uf             CHAR(2)       NOT NULL,
    regiao_fiscal  VARCHAR(40)   NULL,      -- NULL para municipios de outras UFs
    CONSTRAINT PK_municipio        PRIMARY KEY (id_municipio),
    CONSTRAINT UQ_municipio_ibge   UNIQUE (cod_ibge),
    CONSTRAINT CK_municipio_ibge   CHECK (cod_ibge ~ '^[0-9]+$'),
    CONSTRAINT CK_municipio_uf     CHECK (uf = UPPER(uf) AND LENGTH(uf) = 2)
);

-- 3.2 Contribuintes ----------------------------------------------------
CREATE TABLE public.contribuinte (
    id_contribuinte        INT            NOT NULL,
    cnpj                   CHAR(14)       NOT NULL,
    razao_social           VARCHAR(120)   NOT NULL,
    nome_fantasia          VARCHAR(120)   NULL,
    id_municipio           INT            NOT NULL,
    regime_tributario      VARCHAR(20)    NOT NULL,
    situacao_cadastral     VARCHAR(20)    NOT NULL,
    data_inicio_atividade  DATE           NOT NULL,
    cnae_principal         CHAR(7)        NOT NULL,
    faturamento_declarado  DECIMAL(15,2)  NULL,      -- NULL = nao declarado
    CONSTRAINT PK_contribuinte           PRIMARY KEY (id_contribuinte),
    CONSTRAINT UQ_contribuinte_cnpj      UNIQUE (cnpj),
    CONSTRAINT FK_contribuinte_municipio FOREIGN KEY (id_municipio)
        REFERENCES public.municipio (id_municipio),
    CONSTRAINT CK_contribuinte_cnpj      CHECK (cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT CK_contribuinte_regime    CHECK (regime_tributario IN ('NORMAL','SIMPLES','MEI','ISENTO')),
    CONSTRAINT CK_contribuinte_situacao  CHECK (situacao_cadastral IN ('ATIVO','SUSPENSO','BAIXADO','INAPTO')),
    CONSTRAINT CK_contribuinte_fatur     CHECK (faturamento_declarado IS NULL OR faturamento_declarado >= 0)
);

-- 3.3 Auditores fiscais (auto-relacionamento) --------------------------
CREATE TABLE public.auditor_fiscal (
    matricula             INT           NOT NULL,
    nome                  VARCHAR(120)  NOT NULL,
    cargo                 VARCHAR(40)   NOT NULL,
    regiao_fiscal         VARCHAR(40)   NOT NULL,
    data_admissao         DATE          NOT NULL,
    matricula_supervisor  INT           NULL,       -- NULL no topo da hierarquia
    CONSTRAINT PK_auditor_fiscal            PRIMARY KEY (matricula),
    CONSTRAINT FK_auditor_supervisor        FOREIGN KEY (matricula_supervisor)
        REFERENCES public.auditor_fiscal (matricula),
    CONSTRAINT CK_auditor_cargo             CHECK (cargo IN ('AUDITOR','SUPERVISOR','GERENTE')),
    CONSTRAINT CK_auditor_nao_supervisiona_a_si CHECK (matricula_supervisor <> matricula)
);

-- 3.4 Pauta fiscal de referencia (usada no exemplo de juncao theta) ----
CREATE TABLE public.referencia_preco (
    ncm         CHAR(8)        NOT NULL,
    descricao   VARCHAR(120)   NOT NULL,
    valor_min   DECIMAL(15,4)  NOT NULL,
    valor_max   DECIMAL(15,4)  NOT NULL,
    CONSTRAINT PK_referencia_preco  PRIMARY KEY (ncm),
    CONSTRAINT CK_referencia_faixa  CHECK (valor_min <= valor_max)
);

/* ---------------------------------------------------------------------
   4. Documentos fiscais eletronicos
   --------------------------------------------------------------------- */

-- 4.1 NF-e (cabecalho) -------------------------------------------------
CREATE TABLE public.nfe (
    id_nfe           INT            NOT NULL,
    chave_acesso     CHAR(44)       NOT NULL,
    numero           INT            NOT NULL,
    serie            SMALLINT       NOT NULL,
    data_emissao     DATE           NOT NULL,
    id_emitente      INT            NOT NULL,
    id_destinatario  INT            NULL,      -- NULL = consumidor nao identificado
    tipo_operacao    CHAR(1)        NOT NULL,  -- 0 = entrada, 1 = saida
    valor_total      DECIMAL(15,2)  NOT NULL,
    valor_icms       DECIMAL(15,2)  NOT NULL,
    situacao         VARCHAR(20)    NOT NULL,
    CONSTRAINT PK_nfe               PRIMARY KEY (id_nfe),
    CONSTRAINT UQ_nfe_chave         UNIQUE (chave_acesso),
    CONSTRAINT FK_nfe_emitente      FOREIGN KEY (id_emitente)
        REFERENCES public.contribuinte (id_contribuinte),
    CONSTRAINT FK_nfe_destinatario  FOREIGN KEY (id_destinatario)
        REFERENCES public.contribuinte (id_contribuinte),
    CONSTRAINT CK_nfe_tipo_oper     CHECK (tipo_operacao IN ('0','1')),
    CONSTRAINT CK_nfe_situacao      CHECK (situacao IN ('AUTORIZADA','CANCELADA','DENEGADA','INUTILIZADA')),
    CONSTRAINT CK_nfe_valores       CHECK (valor_total >= 0 AND valor_icms >= 0),
    CONSTRAINT CK_nfe_emit_dest     CHECK (id_destinatario IS NULL OR id_destinatario <> id_emitente)
);

-- 4.2 Itens da NF-e ----------------------------------------------------
CREATE TABLE public.nfe_item (
    id_item           INT            NOT NULL,
    id_nfe            INT            NOT NULL,
    num_item          SMALLINT       NOT NULL,
    cod_produto       VARCHAR(30)    NOT NULL,
    descricao         VARCHAR(150)   NOT NULL,
    ncm               CHAR(8)        NOT NULL,
    cfop              CHAR(4)        NOT NULL,
    cst_icms          CHAR(3)        NOT NULL,
    quantidade        DECIMAL(15,4)  NOT NULL,
    valor_unitario    DECIMAL(15,4)  NOT NULL,
    valor_total_item  DECIMAL(15,2)  NOT NULL,
    aliquota_icms     DECIMAL(5,2)   NULL,       -- NULL quando nao tributado
    valor_icms_item   DECIMAL(15,2)  NOT NULL,
    CONSTRAINT PK_nfe_item        PRIMARY KEY (id_item),
    CONSTRAINT UQ_nfe_item_ordem  UNIQUE (id_nfe, num_item),
    CONSTRAINT FK_nfe_item_nfe    FOREIGN KEY (id_nfe)
        REFERENCES public.nfe (id_nfe) ON DELETE CASCADE,
    CONSTRAINT CK_nfe_item_ncm    CHECK (ncm ~ '^[0-9]{8}$'),
    CONSTRAINT CK_nfe_item_cfop   CHECK (cfop ~ '^[0-9]{4}$'),
    CONSTRAINT CK_nfe_item_qtd    CHECK (quantidade > 0),
    CONSTRAINT CK_nfe_item_aliq   CHECK (aliquota_icms IS NULL OR (aliquota_icms >= 0 AND aliquota_icms <= 100))
);

/* ---------------------------------------------------------------------
   5. Escrituracao Fiscal Digital (EFD) - Bloco C
   --------------------------------------------------------------------- */

-- 5.1 Registro C100 - documento escriturado ----------------------------
CREATE TABLE public.efd_c100 (
    id_c100          INT            NOT NULL,
    id_contribuinte  INT            NOT NULL,   -- declarante
    periodo_apuracao CHAR(6)        NOT NULL,   -- AAAAMM
    ind_oper         CHAR(1)        NOT NULL,   -- 0 = entrada, 1 = saida
    cod_situacao     CHAR(2)        NOT NULL,   -- 00 = regular, 02 = cancelado ...
    num_doc          INT            NOT NULL,
    serie            VARCHAR(3)     NULL,
    chave_acesso     CHAR(44)       NULL,       -- NULL em documento nao eletronico
    data_emissao     DATE           NOT NULL,
    valor_documento  DECIMAL(15,2)  NOT NULL,
    valor_icms       DECIMAL(15,2)  NOT NULL,
    CONSTRAINT PK_efd_c100            PRIMARY KEY (id_c100),
    CONSTRAINT FK_efd_c100_contrib    FOREIGN KEY (id_contribuinte)
        REFERENCES public.contribuinte (id_contribuinte),
    CONSTRAINT CK_efd_c100_ind_oper   CHECK (ind_oper IN ('0','1')),
    CONSTRAINT CK_efd_c100_periodo    CHECK (periodo_apuracao ~ '^[0-9]{6}$'),
    CONSTRAINT CK_efd_c100_valores    CHECK (valor_documento >= 0 AND valor_icms >= 0)
);
/*  Observacao didatica: NAO existe chave estrangeira entre
    efd_c100.chave_acesso e nfe.chave_acesso - e nem deveria existir.
    A EFD pode escriturar documentos emitidos em outras UFs, ausentes da
    base local, e e justamente essa ausencia de restricao que permite as
    inconsistencias que a malha fiscal procura.                          */

-- 5.2 Registro C170 - itens do documento escriturado -------------------
CREATE TABLE public.efd_c170 (
    id_c170                INT            NOT NULL,
    id_c100                INT            NOT NULL,
    num_item               SMALLINT       NOT NULL,
    cod_item               VARCHAR(30)    NOT NULL,
    descricao_complementar VARCHAR(150)   NULL,
    ncm                    CHAR(8)        NOT NULL,
    cfop                   CHAR(4)        NOT NULL,
    cst_icms               CHAR(3)        NOT NULL,
    quantidade             DECIMAL(15,4)  NOT NULL,
    valor_item             DECIMAL(15,2)  NOT NULL,
    aliquota_icms          DECIMAL(5,2)   NULL,
    valor_icms_item        DECIMAL(15,2)  NOT NULL,
    CONSTRAINT PK_efd_c170        PRIMARY KEY (id_c170),
    CONSTRAINT UQ_efd_c170_ordem  UNIQUE (id_c100, num_item),
    CONSTRAINT FK_efd_c170_c100   FOREIGN KEY (id_c100)
        REFERENCES public.efd_c100 (id_c100) ON DELETE CASCADE,
    CONSTRAINT CK_efd_c170_qtd    CHECK (quantidade > 0)
);

/* ---------------------------------------------------------------------
   6. Atividade de fiscalizacao
   --------------------------------------------------------------------- */

-- 6.1 Ordens de servico ------------------------------------------------
CREATE TABLE public.ordem_servico (
    id_os              INT           NOT NULL,
    numero_os          VARCHAR(20)   NOT NULL,
    id_contribuinte    INT           NOT NULL,
    matricula_auditor  INT           NOT NULL,
    tipo_fiscalizacao  VARCHAR(40)   NOT NULL,
    data_abertura      DATE          NOT NULL,
    data_conclusao     DATE          NULL,       -- NULL enquanto em andamento
    situacao           VARCHAR(20)   NOT NULL,
    CONSTRAINT PK_ordem_servico          PRIMARY KEY (id_os),
    CONSTRAINT UQ_ordem_servico_numero   UNIQUE (numero_os),
    CONSTRAINT FK_os_contribuinte        FOREIGN KEY (id_contribuinte)
        REFERENCES public.contribuinte (id_contribuinte),
    CONSTRAINT FK_os_auditor             FOREIGN KEY (matricula_auditor)
        REFERENCES public.auditor_fiscal (matricula),
    CONSTRAINT CK_os_tipo                CHECK (tipo_fiscalizacao IN ('MALHA FISCAL','AUDITORIA PLENA','MONITORAMENTO','DILIGENCIA')),
    CONSTRAINT CK_os_situacao            CHECK (situacao IN ('ABERTA','EM ANDAMENTO','CONCLUIDA','CANCELADA')),
    CONSTRAINT CK_os_datas               CHECK (data_conclusao IS NULL OR data_conclusao >= data_abertura)
);

-- 6.2 Autos de infracao ------------------------------------------------
CREATE TABLE public.auto_infracao (
    id_auto           INT            NOT NULL,
    numero_auto       VARCHAR(20)    NOT NULL,
    id_os             INT            NOT NULL,
    id_contribuinte   INT            NOT NULL,
    data_lavratura    DATE           NOT NULL,
    dispositivo_legal VARCHAR(80)    NOT NULL,
    valor_principal   DECIMAL(15,2)  NOT NULL,
    valor_multa       DECIMAL(15,2)  NOT NULL,
    situacao          VARCHAR(25)    NOT NULL,
    CONSTRAINT PK_auto_infracao        PRIMARY KEY (id_auto),
    CONSTRAINT UQ_auto_infracao_numero UNIQUE (numero_auto),
    CONSTRAINT FK_auto_os              FOREIGN KEY (id_os)
        REFERENCES public.ordem_servico (id_os),
    CONSTRAINT FK_auto_contribuinte    FOREIGN KEY (id_contribuinte)
        REFERENCES public.contribuinte (id_contribuinte),
    CONSTRAINT CK_auto_valores         CHECK (valor_principal >= 0 AND valor_multa >= 0),
    CONSTRAINT CK_auto_situacao        CHECK (situacao IN ('LAVRADO','IMPUGNADO','JULGADO PROCEDENTE',
                                                           'JULGADO IMPROCEDENTE','PAGO','INSCRITO DIVIDA ATIVA'))
);

/* ---------------------------------------------------------------------
   7. Indices minimos (chaves estrangeiras mais usadas nas juncoes)
      Os indices de DESEMPENHO ficam no script 08, propositalmente
      separados, para que o exercicio de plano de execucao do Modulo 10
      possa comparar o antes e o depois.
   --------------------------------------------------------------------- */
CREATE INDEX IX_nfe_emitente      ON public.nfe (id_emitente);
CREATE INDEX IX_nfe_destinatario  ON public.nfe (id_destinatario);
CREATE INDEX IX_nfe_item_nfe      ON public.nfe_item (id_nfe);
CREATE INDEX IX_efd_c100_contrib  ON public.efd_c100 (id_contribuinte);
CREATE INDEX IX_efd_c170_c100     ON public.efd_c170 (id_c100);
CREATE INDEX IX_os_contribuinte   ON public.ordem_servico (id_contribuinte);
CREATE INDEX IX_auto_os           ON public.auto_infracao (id_os);

\echo 'Script 01 concluido: banco e tabelas criados.'
