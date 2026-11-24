-- Tabelas de saída do pipeline da Aula 5 (criadas no primeiro boot do Postgres)

CREATE TABLE IF NOT EXISTS vendas_por_janela (
    janela_inicio  TIMESTAMPTZ NOT NULL,
    janela_fim     TIMESTAMPTZ NOT NULL,
    categoria      TEXT        NOT NULL,
    pedidos        INTEGER     NOT NULL,
    unidades       INTEGER     NOT NULL,
    receita        NUMERIC(12,2) NOT NULL,
    atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (janela_inicio, categoria)
);

CREATE TABLE IF NOT EXISTS cliques_por_janela (
    janela_inicio  TIMESTAMPTZ NOT NULL,
    janela_fim     TIMESTAMPTZ NOT NULL,
    categoria      TEXT        NOT NULL,
    cliques        INTEGER     NOT NULL,
    atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (janela_inicio, categoria)
);

CREATE TABLE IF NOT EXISTS alertas (
    id          BIGSERIAL PRIMARY KEY,
    tipo        TEXT        NOT NULL,   -- 'login_suspeito' | 'pedido_sem_pagamento'
    chave       TEXT        NOT NULL,   -- usuario_id ou pedido_id
    detalhe     TEXT,
    ts_evento   TIMESTAMPTZ NOT NULL,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tipo, chave, ts_evento)     -- reprocessamento não duplica alertas
);
