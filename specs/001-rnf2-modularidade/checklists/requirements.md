# Checklist de qualidade da especificação: RNF2 — Modularidade do processamento de vídeo

**Objetivo**: validar que a *spec* está completa e com qualidade antes do plano
**Criada**: 2026-11-22
**Feature**: [spec.md](../spec.md)

## Qualidade do conteúdo

- [x] Sem detalhes de implementação (linguagens, *frameworks*, APIs) — **adaptado**: numa *spec* de *refactoring* o
  requisito é a própria estrutura (constituição, princípios I e III). Os requisitos estruturais (RE-001 a RE-006) nomeiam
  serviços, filas e pastas porque são o objeto da DA-2; linguagens, bibliotecas e passos de implementação ficam no
  `plan.md` e no `research.md`.
- [x] Focada no valor para os *stakeholders* — histórias da equipa que mantém o código (QS-02, QS-04) e do utilizador
  final (preservação, QS-01).
- [x] Escrita para *stakeholders* não técnicos — **adaptado**: o *stakeholder* principal dos cenários QS-02 e QS-04 é a
  própria equipa de desenvolvimento; a história 3 está escrita do ponto de vista do utilizador.
- [x] Todas as secções obrigatórias preenchidas (cenários e testes, requisitos, critérios de sucesso, pressupostos).

## Completude dos requisitos

- [x] Não ficam marcadores `[NEEDS CLARIFICATION]` — as dúvidas foram resolvidas nas decisões DA-2 e TAT-07 a TAT-09.
- [x] Requisitos testáveis e sem ambiguidade — cada invariante tem um teste ou uma medida (`regressao_hashes.py`,
  testes existentes e novos); cada requisito estrutural cita a sua tática.
- [x] Critérios de sucesso mensuráveis — SC-001 a SC-008 com unidade e valores da Tabela 18 do relatório.
- [x] Critérios de sucesso sem detalhes de tecnologia — **adaptado**: as medidas são contagens, tamanhos e tempos; os
  nomes de serviços que aparecem identificam o que se conta (N2), não a forma de o implementar.
- [x] Cenários de aceitação definidos para as três histórias.
- [x] Casos-limite identificados (combinações de estágios, pré-visualização, erros, cancelamento entre estágios).
- [x] Âmbito delimitado — réplicas e ajuste automático ficam fora (RNF1, `specs/002-rnf1-capacidade`).
- [x] Dependências e pressupostos identificados (plataforma, uma instância por serviço, *scripts* de medição, nomes
  da DA-2 sujeitos a desvio registado).

## Prontidão da feature

- [x] Todos os requisitos têm critério de aceitação claro (invariantes ↔ SC-007; estruturais ↔ SC-001 a SC-005).
- [x] Os cenários cobrem os fluxos principais (mudança de legendagem, mudança de efeito, uso normal pelo utilizador).
- [x] A feature cumpre os resultados mensuráveis definidos nos critérios de sucesso.
- [x] Não há detalhes de implementação a escapar para a *spec* além dos estruturais justificados acima.

## Notas

- Três itens estão marcados como **adaptados** à natureza da Fase 2 (só *refactoring*), em linha com a constituição e
  com a nota no início da `spec.md`. Não exigem alterações à *spec*.
- Validação feita a 2026-11-22, depois de escrita a *spec* e antes do `speckit-analyze`.
