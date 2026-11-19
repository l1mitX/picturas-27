# Medições da Fase 2

> **Estado (2026-11-18, 23:50):** baseline completa (RNF2 e RNF1, plano mínimo, mais o cenário M6). Próximo
> passo: a equipa decide a escala principal do RNF1 e os alvos; depois, refactoring do RNF2. A pasta `resultados/teste/` é só de teste do script: não é baseline.

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
