# Checklist de qualidade da especificação: RNF1 — Capacidade e elasticidade do processamento de vídeo

**Objetivo**: validar que a *spec* está completa e com qualidade antes do plano
**Criada**: 2026-11-22
**Feature**: [spec.md](../spec.md)

## Qualidade do conteúdo

- [x] Sem detalhes de implementação (linguagens, *frameworks*, APIs) — **adaptado**: os requisitos estruturais
  (RE-001 a RE-008) nomeiam o `video_autoscaler`, o *heartbeat* e o `consumer_timeout` porque são o objeto da DA-1 e da
  TAT-13; bibliotecas e passos de implementação ficam no `plan.md` e no `research.md`.
- [x] Focada no valor para os *stakeholders* — utilizadores que editam ao mesmo tempo (QS-03) e operação do sistema
  (elasticidade, disponibilidade).
- [x] Escrita para *stakeholders* não técnicos — **adaptado**: as histórias 1 e 2 estão do ponto de vista do utilizador
  e da operação; a história 3 é técnica por natureza (tática de disponibilidade).
- [x] Todas as secções obrigatórias preenchidas.

## Completude dos requisitos

- [x] Não ficam marcadores `[NEEDS CLARIFICATION]` — os parâmetros da política de réplicas estão assumidos como
  configuração a decidir pela equipa antes de medir (Pressupostos), sem valores inventados na *spec*.
- [x] Requisitos testáveis e sem ambiguidade — cada RE tem teste ou medida (RE-008, SC-001 a SC-007).
- [x] Critérios de sucesso mensuráveis — com unidade e valores da Tabela 18 (M6, M4, M1, isolado) e contagens (SC-006, SC-007).
- [x] Critérios de sucesso sem detalhes de tecnologia — **adaptado**: o SC-007 usa o estado `OOMKilled` do Docker como
  instrumento de contagem.
- [x] Cenários de aceitação definidos para as três histórias.
- [x] Casos-limite identificados (arranque simultâneo do Whisper, paragem sem trabalho, falha das APIs, memória).
- [x] Âmbito delimitado — parte do RNF2 concluído; não muda a divisão em serviços.
- [x] Dependências e pressupostos identificados (RNF2, plataforma, *socket* do Docker, parâmetros da política).

## Prontidão da feature

- [x] Todos os requisitos têm critério de aceitação claro.
- [x] Os cenários cobrem os fluxos principais (paralelismo, elasticidade, entrada e saída de réplicas).
- [x] A feature cumpre os resultados mensuráveis definidos nos critérios de sucesso.
- [x] Não há detalhes de implementação a escapar para a *spec* além dos estruturais justificados acima.

## Notas

- Três itens marcados como **adaptados** à natureza da Fase 2, como na *spec* do RNF2.
- Validação feita a 2026-11-22.
