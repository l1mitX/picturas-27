# Medições da Fase 2

> **Estado (2026-11-25):** RNF2 implementado (`fase2`, `a3dcdac`); `apos-rnf2` medido (estáticas, N3, *hashes* e
> carga). **Atenção:** a máquina estava mais rápida a 25/11 do que a 18/11 — a base, medida de novo a 25/11, faz o
> isolado em 6,4 s (contra 17,8 s). Os tempos só se comparam com a base do mesmo dia (`controlo-base-2026-11-25`);
> falta esse controlo para o M1 e o M2 (ver «Resultados após o RNF2», no fim).
>
> **Estado (2026-11-22):** baseline completa (RNF2 e RNF1, plano mínimo, mais o cenário M6). Escala principal do
> RNF1 e alvos decididos (relatório, capítulo 6). Próximo passo: refactoring do RNF2 e medição "após RNF2". A pasta
> `resultados/teste/` é só de teste do script: não é baseline.

## Antes de medir: decisões a respeitar (equipa e IA)

> Ler esta secção antes de correr qualquer script. Vale para quem medir e para assistentes de IA que ajudem a medir.

1. **Três momentos de medição, sempre com o mesmo método** (decisão da equipa, 2026-11-22; relatório, secções 5.1 e 6.2):

   | Momento | Quando | Etiqueta (pasta em `resultados/`) |
   |---|---|---|
   | Base | Antes de qualquer alteração (código igual a `0523102`) | `base` (feito a 2026-11-18) |
   | Após RNF2 | Depois de partir o `video_tool` em serviços (edição, legendagem, extração), ainda sem réplicas | `apos-rnf2` |
   | Após RNF1 | Depois das réplicas com ajuste automático | `apos-rnf1` |

2. **Atribuição do ganho:** o que muda entre `base` e `apos-rnf2` conta para o RNF2 (CAND-2); o que muda entre
   `apos-rnf2` e `apos-rnf1` conta para o RNF1 (CAND-1). **Não comparar só `base` com `apos-rnf1`**: o M1 melhora
   quase todo com a divisão do RNF2, e esse ganho não é das réplicas; o M6 deve melhorar sobretudo com as réplicas.
3. **Escala principal do RNF1 = M6** (cenário `paralelo`, QS-03): é o que mede o efeito das réplicas. O **M1**
   (cenário `m1`, QS-01) é complementar, mas mede-se sempre: o seu ganho vem sobretudo da divisão do RNF2. A outra
   opção (M1 principal) foi escolhida e revista no mesmo dia; ver `RNF1-EDIT-011.md`, secção 2.1. No relatório, o
   QS-03 passou a prioridade 1 e o QS-01 a prioridade 3 (capítulo 5).
4. **A medição `apos-rnf2` é obrigatória**, mesmo que só interesse o resultado final: dá o N5 do RNF2 (o desempenho
   não pode piorar) e separa os ganhos dos dois RNF.
5. **Mesmos parâmetros da base:** isolado ×5, M1 ×5, M2 só N = 4 ×3, M6 N = 4 ×5. Desde 2026-11-22 são os valores
   por omissão do `carga_rnf1.py`, por isso basta mudar a etiqueta, e.g. `python docs/fase2/medicoes/carga_rnf1.py
   apos-rnf2 m1`. Mesma máquina e mesmos recursos do Docker (ver "Ambiente da baseline").
6. **Arrancar sempre com `docker compose up -d --build`** (ver a nota sobre o arranque, mais abaixo).
7. **N3 (tamanho das imagens):** o `apt-get` não fixa versões, por isso comparar só imagens construídas no mesmo dia.
8. Valores-alvo e mínimos: estão no relatório (`docs/fase2/relatorio/capitulos/06-candidatos-rnf.typ`, Tabela 18).
   Não os mudar depois de ver os resultados.

Scripts e resultados das medições dos dois RNF. Os scripts são os mesmos em todos os momentos de medição
(base, após RNF2, após RNF1); só muda a etiqueta da pasta de resultados.

| Script | Para quê | RNF |
|---|---|---|
| `rnf2_estaticas.py` | N1 (duplicação imagem/vídeo), N2 (impacto de mudança, cenários C1–C3), N4 (tamanho e complexidade) | RNF2 |
| `regressao_hashes.py` | Referência de preservação funcional: *hash* das saídas das ferramentas de imagem e de 9 pipelines de vídeo | RNF1 e RNF2 |
| `carga_rnf1.py` | Cenários isolado, M1, M2/M3 e M6 (`paralelo`) | RNF1 (e N5 do RNF2) |

Comandos exatos no cabeçalho de cada script. Resultados em `resultados/<etiqueta>/`.

## Ambiente da baseline (2026-11-18)

| Item | Valor |
|---|---|
| Commit | `0523102` (sem alterações ao código; só `docs/` acrescentado) |
| Máquina | AMD Ryzen 5 5600H, 15,9 GB RAM, Windows 11 Home |
| Docker | Docker Desktop, Engine 29.8.0, Compose 5.5.1, WSL2 (kernel 6.18.58.1) |
| Recursos dados ao Docker | 12 CPUs, 7,7 GiB de RAM |
| Arranque | `docker compose up -d --build` (ver nota abaixo) |

> **Nota sobre o arranque.** Na primeira tentativa, `docker compose up -d` (sem `--build`) reaproveitou imagens
> antigas com o mesmo nome de projeto (`picturas-*`), construídas a 21–22/10/2026 a partir do código da Fase 1
> da equipa, e não da base. Detetado porque os testes dentro do contentor `projects` não eram os do repositório.
> A aplicação foi reconstruída com `--build` antes de qualquer medição. **Usar sempre `--build`** nas medições.

## Resultados da baseline (`resultados/base/`)

### Testes existentes

| Conjunto | Comando | Resultado |
|---|---|---|
| `projects/tests` (3 ficheiros) | `docker compose exec -T projects sh -c "node --test tests/*.test.js"` | 8 testes, 8 passam |
| `Tools/video/tests` (3 ficheiros) | `docker compose run --rm --no-deps -T video_tool sh -c "pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"` | 74 testes, 74 passam (169 s) |

### RNF2 — métricas estáticas (`rnf2_estaticas.json`)

| Métrica | Base |
|---|---|
| N1 — efeitos com duas implementações (imagem e vídeo) | **8** (brightness, contrast, saturation, rotate, resize, binarization, cut, border); 18 linhas copiadas em `Tools/video/effects.py` |
| N2 — C1 (mudar o filtro de brilho) | 2 ficheiros; reconstruir `brightness_tool` e `video_tool`; reimplanta os 3 tipos de trabalho de vídeo |
| N2 — C2 (atualizar o Faster-Whisper) | 2 ficheiros; reconstruir `video_tool`; reimplanta os 3 tipos de trabalho de vídeo |
| N2 — C3 (mudar a amostragem de fotogramas) | 1 ficheiro; reconstruir `video_tool`; reimplanta os 3 tipos de trabalho de vídeo |
| N4 — serviços de vídeo | 1 (`video`) |
| N4 — SLOC Python do vídeo | 601 (maior: `video_processor.py`, 264) |
| N4 — complexidade ciclomática máxima | 22 (`process_video`); `extract_frames` 14; `callback` 11 |
| N4 — orquestrador `projects/routes/projects.js` | 2733 linhas; 16 com ramificação imagem/vídeo (`isVideo`/`media_type`) |

> **Deteção ajustada para a estrutura do RNF2 (T043, R10, 2026-11-24).** Com a estrutura nova, a deteção dos
> cenários de N2 dava dois falsos positivos: no C1, a ferramenta de imagem `Tools/brightness/brightness.py` continua a
> ter `adjust_brightness`, mas só chama a função partilhada de `Tools/effects/brightness.py`; no C2, o comentário
> «No faster-whisper here» de `Tools/video_frames/requirements.txt` e a *docstring* de
> `Tools/video_subtitles/__init__.py` contavam como uso do Faster-Whisper. Mudou só a deteção: os cenários procuram
> no código sem comentários nem *docstrings*, e o C1 exige também `ImageEnhance.Brightness` no mesmo ficheiro. A
> definição dos cenários não mudou. Confirmado: o `rnf2_estaticas.py` novo, corrido sobre o commit da base
> (`0523102`), dá N1, N2 e N4 iguais aos de `resultados/base/rnf2_estaticas.json`.

### RNF2 — N3 (imagem Docker do vídeo)

| Item | Base |
|---|---|
| Tamanho da imagem `picturas-video_tool` | 1,69 GB (1 692 188 439 B) |
| Maiores camadas | `apt-get` ffmpeg + fontes (incl. CJK das legendas): 597 MB; `pip install` com `faster-whisper`: 457 MB |
| Tempo de build sem cache | 240 s (`docker compose build --no-cache video_tool`, 1 medição, sem outra carga na máquina) |

> O `apt-get` do Dockerfile não fixa versões: a imagem reconstruída sem cache ficou com 1 707 624 420 B (contra
> 1 692 188 439 B da construída a 10/11). Comparar tamanhos só entre imagens construídas no mesmo dia, ou
> comparar o tamanho das camadas próprias (as que vêm do `pip install` e do `COPY`).

### RNF1 — carga (`carga_*.csv`, `carga_*_resumo.json`), 2026-11-18 22:27–23:12 UTC, 1 réplica de vídeo

Plano mínimo decidido pela equipa: isolado ×5, M1 ×5, M2 só N=4 ×3. Sem falhas nem *timeouts*.

Antes da corrida, a aplicação teve de ser reposta: depois de um `docker compose stop`, o Docker religou só os
serviços com política de reinício; os serviços Node (`users`, `projects`, …) ficaram parados no `nodemon` por
terem arrancado antes das bases de dados. Foram reiniciados e foi feita uma corrida de aquecimento (descartada).

| Cenário | Medida | Base |
|---|---|---|
| Isolado (brilho em vídeo de 10 s, sozinho) | tempo do *Apply* ao resultado: p50 / p95 / média | **14,8 s** / 17,8 s / 15,2 s |
| M1 (curto submetido 5 s depois de uma legendagem) | tempo do curto: p50 / p95 | **307,6 s** / 322,6 s (≈ 20× o isolado) |
| M1 | tempo da legendagem do vídeo de 177 s: p50 / p95 | 302,3 s / 316,4 s |
| M2 (N=4: 1 legendagem + 3 curtos ao mesmo tempo) | débito | **0,70 vídeos/min** |
| M2 | p95 de todos os trabalhos / p95 só dos curtos | 353,5 s / 35,3 s |
| Recursos do serviço de vídeo | memória máxima: só edição / com legendagem | 605 MiB / **2 506 MiB** |
| M6 (4 edições curtas ao mesmo tempo, sem legendagem; ×5, terminado às 23:50 UTC) | tempo de cada trabalho: p50 / p95 | **28,8 s** / **44,0 s** |
| M6 | débito / makespan p50 | 5,54 vídeos/min / 43,2 s |
| M6 | memória máxima do serviço de vídeo | 1 464 MiB |

**Leitura (factos):**
- No M1, o trabalho curto acaba sempre 4–8 s depois da legendagem: fica em fila atrás dela o tempo todo. É a
  fragilidade principal do RNF1, medida.
- No M2, nas 3 rondas, os curtos foram processados **antes** da legendagem (acabaram em ≈ 11 s, 21 s e 32 s: um
  de cada vez, em série) e a legendagem foi a última. Com submissões simultâneas, a ordem de chegada à fila não
  é controlada; por isso o M2 mostra a **serialização** (curtos em escada de ≈ 10,7 s, débito baixo), mas não o
  bloqueio pela legendagem — esse é medido pelo M1.
- No M6, em todas as 5 rondas, os 4 trabalhos acabam em escada (≈ 11, 21, 32 e 43 s): um de cada vez, cerca de
  10,5 s cada. É a serialização do serviço de vídeo sem legendagem pelo meio, que é o que as réplicas podem
  melhorar. O M6 foi acrescentado depois da revisão do plano (ver `RNF1-EDIT-011.md`, 2.1), no mesmo build e
  logo a seguir às outras medições, com o código igual a `0523102`.

### Referência de regressão (`regressao_imagem.json`, `regressao_video.json`)

- Imagem: 8 ferramentas sobre uma imagem de entrada determinística (gerada pelo script). Concluído.
- Vídeo: 9 pipelines (V1–V8 e a pré-visualização V1p) sobre `samples/video/`, cobrindo filtros, corte, velocidade,
  extração (sozinha e depois de edições) e legendas. Concluído.
- **Determinismo verificado:** a referência de vídeo foi gerada duas vezes (`base/` e `base-repeticao/`) e os
  *hashes* são iguais nos 9 casos, incluindo as legendas (Faster-Whisper em CPU). A comparação depois do
  refactoring é, por isso, válida.

## Resultados após o RNF2 (`resultados/apos-rnf2/`)

Medido a 2026-11-25 sobre o código do commit `a3dcdac` do `fase2` (RNF2 completo), na mesma máquina e com os mesmos
recursos do Docker da base (Engine 29.8.0, Compose 5.5.1, 12 CPUs, 7,7 GiB). A carga correu numa só sessão
(11:29–12:00 UTC), com a aplicação arrancada com `docker compose up -d --build` e um aquecimento descartado (isolado ×1 e
M1 ×1), com os parâmetros da base (isolado ×5, M1 ×5, M2 N = 4 ×3, M6 N = 4 ×5). Sem falhas nem *timeouts*.

### Carga: a máquina não estava igual — controlo da base no mesmo dia

Os tempos de `apos-rnf2` saíram muito abaixo da base (e.g., isolado p95 5,9 s contra 17,8 s), mais do que o RNF2
explica: cada edição curta demorava ~10,5 s a 18/11 e ~5,4 s a 25/11, com saídas iguais (*hashes*). Para separar o
efeito do código do efeito da máquina, a aplicação da base (`0523102`) foi reconstruída e medida de novo a 25/11, logo
a seguir (12:04–12:11 UTC), com o mesmo *script*, aquecimento e parâmetros: `resultados/controlo-base-2026-11-25/`
(isolado e M6). A base de 25/11 faz o isolado em 6,4 s: **a diferença era da máquina** (causa não identificada;
hipóteses: modo de energia ou carga de fundo a 18/11). Os tempos de `apos-rnf2` comparam-se, por isso, com a base do
**mesmo dia**; os valores de `base/` (18/11) não servem para tempos (as métricas estáticas, o N3 e os *hashes* não
dependem da velocidade da máquina).

| Cenário | Base 18/11 (`base/`) | Base 25/11 (controlo) | Após RNF2 25/11 | Efeito do RNF2 (mesmo dia) |
|---|---|---|---|---|
| Isolado (N5): p50 / p95 | 14,8 / 17,8 s | 6,38 / 6,40 s | 5,88 / 5,92 s | −8 % no p95; não piora ✅ |
| M6 (4 edições curtas): p50 / p95 | 28,8 / 44,0 s | 15,2 / 24,2 s | 14,1 / 21,8 s | −10 % no p95 |
| M6: débito | 5,54 vídeos/min | 9,95 vídeos/min | 10,96 vídeos/min | +10 % |
| M1 (curto 5 s depois de uma legendagem): p50 / p95 do curto | 307,6 / 322,6 s | **por medir** | 106,0 / 108,9 s | por calcular |
| M1: legendagem do vídeo de 177 s, p50 | 302,3 s | por medir | 162,6 s | por calcular |
| M2 (1 legendagem + 3 curtos): débito / p95 dos curtos | 0,70 vídeos/min / 35,3 s | por medir | 1,35 vídeos/min / 16,5 s | por calcular |

- **Isolado e M6:** com a mesma máquina, o RNF2 não piora o trabalho isolado (H-06, SC-006) e melhora-o ~8 %; no M6
  os 4 trabalhos continuam a acabar em escada (≈ 6, 11, 16 e 22 s), um de cada vez — é o que as réplicas do RNF1 vão
  atacar (a comparação do RNF1 faz-se contra estes valores de `apos-rnf2`).
- **M1:** o curto deixa de esperar pela legendagem em si, mas **continua a esperar ~100 s**: a legendagem sozinha
  começa por um estágio de edição sem efeitos que recodifica o vídeo de 177 s (como `process_video` na base, R1 do
  RNF2; é isso que mantém os *hashes*), e o curto, enviado 5 s depois, fica na fila do `video_edit` atrás dele. Com
  réplicas do `video_edit` (RNF1) este bloqueio desaparece. Falta o controlo do M1 e do M2 com a base no mesmo dia
  (~45 min) para calcular o ganho do RNF2 nestes dois cenários (SC-008).
- **Memória máxima:** `video_edit` 1 888 MiB (M2), `video_subtitles` 1 451 MiB (M1), `video_frames` 16 MiB (não usado
  nestes cenários). Base: um só serviço com 2 506 MiB (M1). Dados para os limites de memória do RNF1 (T003, R9).

### RNF2 — métricas estáticas (`rnf2_estaticas.json`)

Deteção ajustada na T043 (ver a nota na secção da base); sobre o commit da base dá os mesmos valores.

| Métrica | Base | Após RNF2 | Alvo / mínimo |
|---|---|---|---|
| N1 — efeitos com duas implementações | 8 (18 linhas copiadas) | **0** (0 linhas) | 0 ✅ |
| N2 — C1 (filtro de brilho) | 2 ficheiros; `brightness_tool` + `video_tool`; 3 trabalhos | 1 ficheiro (`Tools/effects/brightness.py`); `brightness_tool` + `video_edit`; **1** trabalho | 2 serviços, 1 trabalho ✅ |
| N2 — C2 (Faster-Whisper, principal) | 2 ficheiros; `video_tool`; 3 trabalhos | 2 ficheiros; `video_subtitles`; **1** trabalho | 1 ✅ |
| N2 — C3 (amostragem de fotogramas) | 1 ficheiro; `video_tool`; 3 trabalhos | 1 ficheiro; `video_frames`; **1** trabalho | 1 ✅ |
| N4 — serviços de vídeo | 1 | 3 (+ `video_common`, código partilhado) | — |
| N4 — SLOC Python do vídeo | 601 | 824 (inclui 137 de `local_pipeline.py`, só para testes) | — |
| N4 — complexidade ciclomática máxima | 22 (`process_video`) | 20 (`_process_video`; e `run` do `local_pipeline.py`, só para testes) | — |
| N4 — orquestrador `projects/routes/projects.js` | 2733 linhas; 16 com ramificação imagem/vídeo | 2816 linhas (+3 %); 16 | ≤ 3006 (+10 %) ✅ |

### RNF2 — N3 (imagens Docker do vídeo), todas construídas sem *cache* a 2026-11-25

A imagem da base foi reconstruída no mesmo dia a partir de uma cópia do repositório em `0523102`
(`docker compose -p n3base build --no-cache video_tool`); as novas com `docker compose build --no-cache <serviço>`,
uma de cada vez, sem a aplicação a correr.

| Imagem | Tamanho | Tempo de build | Maiores camadas |
|---|---|---|---|
| `video_tool` (base, reconstruída hoje) | 1,66 GB (1 662 791 342 B) | 190 s | `apt-get` ffmpeg + fontes: 597 MB; `pip` com `faster-whisper`: 437 MB |
| `video_edit` | **0,86 GB** (856 481 755 B) | 123 s | `apt-get` ffmpeg: 457 MB |
| `video_subtitles` | 1,66 GB (1 662 803 933 B) | 204 s | `apt-get` ffmpeg + fontes: 597 MB; `pip` com `faster-whisper`: 437 MB |
| `video_frames` | 0,86 GB (856 422 153 B) | 137 s | `apt-get` ffmpeg: 457 MB |

SC-004: imagem da edição 0,86 GB ≤ 1,23 GB (alvo) ✅ e menor que a da base do mesmo dia (mínimo) ✅, −48 %.
A edição e a extração deixam de ter o `faster-whisper` e as fontes das legendas (RE-002); a legendagem fica com o
tamanho da imagem antiga.

### Referência de regressão (`regressao_imagem.json`, `regressao_video.json`)

- Imagem: **9 de 9** iguais à base. Vídeo: **9 de 9** iguais à base (V1–V8 e V1p), corrido na imagem do
  `video_subtitles` com o repositório montado (R7 do RNF2). INV-001 e SC-007 ✅.
- Testes (verificados a 2026-11-24 sobre o mesmo código): 68 do `projects` e 101 de vídeo (base: 8 e 74).
