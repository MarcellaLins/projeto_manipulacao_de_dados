# Gabarito das divergencias propositais (SQL Server x PostgreSQL)

Este arquivo documenta TODAS as diferencas inseridas de proposito nos scripts de insercao em PostgreSQL, simulando erros de ETL na migracao a partir do banco original em SQL Server. Guarde-o separado da analise para nao enviesar o exercicio.

## Resumo por tabela

| Tabela | Linhas SQL Server | Linhas PostgreSQL | Diferenca | Alteracoes qualitativas |
|---|---|---|---|---|
| municipio | 35 | 35 | +0 | 0 |
| auditor_fiscal | 20 | 21 | +1 | 2 |
| contribuinte | 60 | 60 | +0 | 5 |
| referencia_preco | 28 | 28 | +0 | 1 |
| nfe | 10636 | 10636 | +0 | 4 |
| nfe_item | 30794 | 30786 | -8 | 2 |
| efd_c100 | 8059 | 8060 | +1 | 2 |
| efd_c170 | 23158 | 23152 | -6 | 1 |
| ordem_servico | 150 | 150 | +0 | 2 |
| auto_infracao | 72 | 70 | -2 | 1 |

## Detalhamento


### 02_inserir_cadastros.sql

- **auditor_fiscal** [QUANTITATIVO (+1 linha)]: Adicionada matricula 1036, clone de 1020 (RITA DE CASSIA NOBREGA) com regiao_fiscal em minusculo -> registro duplicado por falha de deduplicacao no ETL.
- **auditor_fiscal** [QUALITATIVO]: matricula 1024: data_admissao '2016-01-26' -> '2016-01-25' (deslocamento de 1 dia, tipico de problema de fuso horario).
- **auditor_fiscal** [QUALITATIVO]: matricula 1032: regiao_fiscal '3A GERENCIA REGIONAL' -> '3a Gerencia Regional' (diferenca de caixa alta/baixa).
- **contribuinte** [QUALITATIVO]: id_contribuinte 1: razao_social com espaco em branco final adicionado ("'ALFA DISTRIBUIDORA DE BEBIDAS EIRELI'" -> "'ALFA DISTRIBUIDORA DE BEBIDAS EIRELI '").
- **contribuinte** [QUALITATIVO]: id_contribuinte 5: faturamento_declarado 18453989.97 -> 18453989.96 (diferenca de 1 centavo, erro de arredondamento).
- **contribuinte** [QUALITATIVO]: id_contribuinte 17: nome_fantasia NULL -> 'BOREAL' (valor NULL na origem foi preenchido incorretamente no destino).
- **contribuinte** [QUALITATIVO]: id_contribuinte 43: id_municipio 23 -> 24 (referencia trocada, ambos os municipios existem - erro de JOIN).
- **contribuinte** [QUALITATIVO]: id_contribuinte 58: situacao_cadastral 'BAIXADO' -> 'ATIVO' (status divergente do cadastro original).
- **referencia_preco** [QUALITATIVO]: ncm 30049099: valor_max 276 -> 276.5 (valor de pauta divergente).

### 03_inserir_nfe.sql

- **nfe** [QUALITATIVO]: id_nfe 1: valor_icms 2954.35 -> 2954.30 (erro de arredondamento).
- **nfe** [QUALITATIVO]: id_nfe 25: situacao 'AUTORIZADA' -> 'CANCELADA' (situacao divergente).
- **nfe** [QUALITATIVO]: id_nfe 100: data_emissao '2025-11-24' -> '2025-11-23' (deslocamento de 1 dia, fuso horario).
- **nfe** [QUALITATIVO]: id_nfe 500: id_destinatario 50 -> 51 (referencia trocada por outro contribuinte valido).
- **nfe_item** [QUANTITATIVO (-8 linhas)]: Linhas removidas (id_item / id_nfe): 50/16, 1500/511, 5000/1678, 10000/3424, 15000/5165, 20000/6905, 25000/8663, 30000/10366 -> itens perdidos durante a carga (nao afeta integridade referencial, cabecalho da NF-e permanece).
- **nfe_item** [QUALITATIVO]: id_item 1: valor_icms_item 987.26 -> 987.20 (erro de arredondamento).
- **nfe_item** [QUALITATIVO]: id_item 2: aliquota_icms 20 -> NULL (aliquota perdida na migracao).

### 04_inserir_efd.sql

- **efd_c100** [QUANTITATIVO (+1 linha)]: Adicionado id_c100 8060, clone do id_c100 1 (mesma chave_acesso/num_doc) -> documento escriturado em duplicidade.
- **efd_c100** [QUALITATIVO]: id_c100 2: valor_documento 226.48 -> 226.50 (erro de arredondamento).
- **efd_c100** [QUALITATIVO]: id_c100 3: chave_acesso '25250127712979000187550010000000251122060400' -> NULL (referencia perdida na migracao).
- **efd_c170** [QUANTITATIVO (-6 linhas)]: Linhas removidas (id_c170 / id_c100): 10/3, 2000/664, 6000/2081, 10000/3460, 15000/5206, 20000/6956.
- **efd_c170** [QUALITATIVO]: id_c170 1: aliquota_icms 18 -> 17; valor_icms_item 3.33 -> 3.30.

### 05_inserir_fiscalizacao.sql

- **ordem_servico** [QUALITATIVO]: id_os 1: situacao 'CANCELADA' -> 'CONCLUIDA'.
- **ordem_servico** [QUALITATIVO]: id_os 2: data_conclusao NULL -> '2025-06-01' (preenchida indevidamente, OS continua 'ABERTA').
- **auto_infracao** [QUANTITATIVO (-2 linhas)]: Linhas removidas (id_auto): 8, 19.
- **auto_infracao** [QUALITATIVO]: id_auto 1: valor_multa 217015.63 -> 217015.60 (erro de arredondamento).
