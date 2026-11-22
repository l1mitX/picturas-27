# Guia de validação: RNF2 — Modularidade do processamento de vídeo

Cenários para provar que a *spec* está cumprida. Correm-se na mesma máquina da base (constituição, princípio IV).

## Pré-requisitos

- Código no estado `apos-rnf2`; `docker compose up -d --build` (nunca sem `--build`).
- Amostras em `samples/video/`; resultados da base em `docs/fase2/medicoes/resultados/base/`.

## 1. Preservação funcional (SC-007, INV-001, INV-006)

1. Testes do `projects`, incluindo o planeador de estágios e o ficheiro de casos `video_stage_plans.json` (R2):
   `docker compose exec -T projects sh -c "node --test tests/*.test.js"` → todos passam.
2. Testes de cada serviço de vídeo (comando no README de cada `Tools/video_*`) → todos passam; o total de casos não é
   inferior aos 74 da base.
3. `regressao_hashes.py imagem apos-rnf2` e `regressao_hashes.py video apos-rnf2` (comandos no cabeçalho do *script*)
   → *hashes* iguais aos de `resultados/base/`.
4. Manual, na interface: um projeto com 2 imagens e 2 vídeos; aplicar brilho, legendas + brilho, corte + extração;
   pré-visualizar cada um; cancelar um pipeline com legendas a meio (H-08). Os resultados, o progresso e as mensagens
   de erro são os da base, e nada fica registado após o cancelamento.

## 2. Modularidade (SC-001 a SC-005)

1. `rnf2_estaticas.py apos-rnf2` (confirmar antes a deteção, R10) → N2: C2 = 1 tipo; C1 = `brightness_tool` +
   edição; C3 = 1 tipo; N1 = 0; N4 do orquestrador ≤ 2733 + 10 %.
2. N3: construir no mesmo dia a imagem da base (a partir de uma cópia do repositório em `0523102`, e.g. `git worktree add ../base 0523102`) e as imagens novas, sem
   *cache*; `docker image inspect` → imagem da edição ≤ 1,23 GB (alvo), menor que a da base (mínimo).

## 3. Efeitos colaterais (SC-006, SC-008)

`carga_rnf1.py apos-rnf2 isolado` e `carga_rnf1.py apos-rnf2 m1` (e, para manter os três momentos completos, `paralelo`
e `m2`) → trabalho isolado p95 ≤ 19,6 s (mínimo); registar o M1 e comparar com a base.

## Registo

Resultados em `docs/fase2/medicoes/resultados/apos-rnf2/`. Hipóteses confirmadas ou refutadas (H-06 a H-09) atualizam o
Exercício 6, Bloco 1; desvios face à DA-2 vão para o relatório (cap. 8, «Desvios face à decisão»).
