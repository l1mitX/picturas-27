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

- **2026-11-26**: T040 (secção 1, passo 4), na interface, com o ramo `fase2` em `4efb104` (RNF2 e RNF1 integrados;
  `video_autoscaler` ligado). Projeto com 2 imagens e 2 vídeos (`sample_10s_720p.mp4`, `sample_6s.mov`), utilizador
  Premium.
  - **Brilho**: as 2 imagens e os 2 vídeos dão `success`. Os vídeos passam no `video_edit` (`tools=['brightness']`). O
    2.º vídeo foi para uma 2.ª réplica criada pelo autoscaler.
  - **Legendas + brilho**: cada vídeo faz três estágios pela ordem do pipeline: `video_edit` (preparação) →
    `video_subtitles` → `video_edit` (brilho). Todos dão `success`; as imagens recebem só o brilho. Os vídeos de teste
    não têm fala, por isso saem sem legendas, como na base.
  - **Corte + extração**: o vídeo onde o corte foi definido faz `video_edit` (trim) → `video_frames`; o outro vai
    direto ao `video_frames`, porque o corte é por vídeo (`PER_VIDEO_TOOLS`, regra da base). Os dois dão fotogramas.
  - **Pré-visualizações**: vídeo pelo `video_edit` com `preview=True` (~4 s, `success`); imagem com `success`.
  - **Cancelamento a meio (H-08)**: legendas em `speech_mandela_177s_1080p.webm`, cancelado às 21:17:01 durante a
    preparação no `video_edit`. O `projects` limpou os resultados (`[CANCEL][RESULTS-CLEAN]`). Quando o estágio acabou,
    a resposta foi ignorada (T037/T039): nenhuma mensagem para `video_subtitles`, pastas `out/` e `stages/` vazias,
    filas a 0. Nada ficou registado.
  - **INV-005**: `frontend/`, `apiGateway/` e `wsGateway/` têm 0 linhas alteradas face a `0523102`; a lista de rotas
    de `projects/routes/projects.js` é igual à da base (mudou só o tratamento interno dos estágios de vídeo).
  - **Observações (comportamento da base, não corrigido)**: (1) o botão de criar projeto não fica bloqueado enquanto os
    ficheiros carregam, e cliques repetidos criaram 3 projetos iguais; (2) um Apply feito 2 s depois de adicionar uma
    ferramenta recebeu 409 (`Project version conflict`): adicionar a ferramenta subiu a versão do projeto, mas o
    browser enviou o Apply com a versão anterior. O Apply não recupera do 409 (mostra «Falha no processamento») e só
    funcionou depois de recarregar a página; a barra de ferramentas já recarrega o projeto num 409. A lógica de versões do `projects` e o frontend
    são os da base. Ficam como trabalho futuro.
