---

description: "Lista de tarefas do RNF2 — modularidade do processamento de vídeo (DA-2)"
---

# Tarefas: RNF2 — Modularidade do processamento de vídeo

**Entrada**: documentos de `specs/001-rnf2-modularidade/` (`spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/mensagens-estagio.md`, `quickstart.md`) e a constituição v1.0.0.

**Testes**: incluídos. A constituição (princípio II) e a *spec* (INV-006, RE-006) exigem testes de preservação e testes
novos; os testes de cada fase escrevem-se antes da implementação e devem falhar primeiro.

**Organização**: por história da *spec* (US1 = P1, US2 = P2, US3 = P3). Cada tarefa cita a decisão de que parte
(`R-n` de `research.md`, `TAT-nn`, `H-nn`), para as mensagens de *commit* poderem citar os mesmos IDs.

**Revisão**: v2 (2026-11-22), depois do `speckit-analyze` (C1, C2, F1, F2, E1, E2); tarefas renumeradas.

## Formato: `[ID] [P?] [História] Descrição`

- **[P]**: pode correr em paralelo (ficheiros diferentes, sem dependências por concluir)
- **[US1]/[US2]/[US3]**: história a que a tarefa pertence
- Caminhos relativos à raiz do repositório

---

## Fase 1: Preparação

**Objetivo**: pastas novas e ponto de partida conhecido.

- [x] T001 Criar as pastas `Tools/effects/`, `Tools/video_common/`, `Tools/video_edit/tests/`, `Tools/video_subtitles/tests/` e `Tools/video_frames/tests/` (estrutura do `plan.md`)
- [x] T002 Confirmar que a base está verde antes de mexer: `projects/tests` (8) e `Tools/video/tests` (74) a passar, e `docs/fase2/medicoes/resultados/base/regressao_*.json` presentes; registar o resultado em `specs/001-rnf2-modularidade/quickstart.md` (secção «Registo»)

---

## Fase 2: Fundações (bloqueia todas as histórias)

**Objetivo**: o plano de estágios, o código comum dos *workers* e o executor local, que provam o comportamento esperado
antes de se partir o `video_tool`.

**⚠️ Nenhuma história começa antes de esta fase estar concluída.**

### Testes primeiro

- [x] T003 Criar `projects/tests/fixtures/video_stage_plans.json` (R2) com uma entrada por pipeline, identificada por um nome, com `tools`, `preview` e o plano esperado (`service`, `tools`, `preview`, `progressRange` de cada estágio). Incluir **todos** os pipelines usados (a) em `VIDEO_CASES` de `docs/fase2/medicoes/regressao_hashes.py`, (b) nas chamadas a `process_video` de `Tools/video/tests/test_video_processor.py`, `test_subtitles.py` e `test_frame_extraction.py` (e.g., `[trim, subtitles, speed]`, `[subtitles, efeito, subtitles]`) e (c) nos casos-limite da *spec* (só legendas; legendas no início — estágio de edição vazio antes; só extração; edição + extração com faixas `[0, 70]` e `[70, 100]`; pré-visualização com `trim`/`speed` antes e depois de legendas). Derivar cada plano esperado das regras de `Tools/video/video_processor.py:286-369`
- [x] T004 [P] Escrever `projects/tests/videoStages.test.js`: para cada entrada do ficheiro de T003, `planStages(tools, preview)` devolve exatamente o plano esperado (deve falhar até T005)

### Implementação

- [x] T005 Implementar `planStages(tools, preview)` em `projects/utils/videoStages.js` (R1, R4): regras de divisão de `process_video` (extração no fim; partir à volta de `subtitles`; estágio de edição vazio se a lista começar por `subtitles`; `preview` só no estágio `preview_stage` — último estágio de edição com `trim` ou `speed`, 0 se não houver — e na extração; edição antes da extração sempre sem `preview`) e faixas de progresso (estágio *i* de *n* em `[i·100/n, (i+1)·100/n]`; edição + extração em `[0, 70]` + `[70, 100]`). T004 passa
- [x] T006 [P] Criar `Tools/video_common/errors.py` com os códigos 2000–2005 e as exceções `InvalidVideo`, `InvalidTrim`, `InvalidSpeed`, `ProcessingError`, `UnsupportedEffect`, movidos de `Tools/video/video.py` (`CODES`), `Tools/video/video_processor.py:34-48` e `Tools/video/effects.py` (R6)
- [x] T007 [P] Criar `Tools/video_common/probe.py` com `probe(path, prefer_video_duration=False)` movido de `Tools/video/video_processor.py:50-95`, sem alterações (R6)
- [x] T008 Criar `Tools/video_common/worker.py` com a classe base do *worker* a partir de `Tools/video/video.py`: ligação com `heartbeat=0` (inalterado nesta *spec*), `basic_qos(prefetch_count=1)`, consumo com `auto_ack=False` e `basic_ack` só no fim, respostas de sucesso e erro na `project_queue` com o mesmo formato (`contracts/mensagens-estagio.md`), progresso na `ws_queue` com a conversão para `progress.range` (R4). Recebe como parâmetros o nome da fila, a `procedure` esperada, o identificador `microservice` e a função que processa o estágio (depende de T006)
- [x] T009 [P] Criar `Tools/video_common/requirements.txt` (`pika==1.3.2`, `pytz`, `python-dotenv`, `pillow==11.0.0`), copiado pelos três serviços de vídeo e por nenhum de imagem (R6)
- [x] T010 Criar `Tools/video_common/local_pipeline.py` (R7), só para testes: `run(name_or_tools, input, output, preview=False, progress_cb=None)` lê o plano **apenas** do ficheiro de T003 (falha com uma mensagem clara se o pipeline não estiver lá; nunca calcula o plano em Python, R2), executa os estágios por ordem chamando diretamente as funções dos três serviços, com ficheiros intermédios temporários e escrita final atómica, e devolve o mesmo `dict` que `process_video` devolvia (depende de T003, T007; as funções dos serviços chegam em US1)

**Checkpoint**: plano de estágios testado; código comum pronto.

---

## Fase 3: História 1 — Atualizar o motor de legendagem sem tocar no resto (P1) 🎯 MVP

**Objetivo**: três serviços de vídeo, cada um com a sua fila e o seu Dockerfile, encadeados pelo `projects` (TAT-07,
TAT-09). Só a legendagem tem `faster-whisper`.

**Teste independente**: `rnf2_estaticas.py` → N2 do cenário C2 = 1 tipo de trabalho; a aplicação processa vídeos com
os três serviços; `regressao_hashes.py video` igual à base.

### Testes primeiro

- [x] T011 [P] [US1] Repartir `Tools/video/tests/test_video_processor.py` para `Tools/video_edit/tests/test_video_edit.py`, sem perder casos; os que testam pipelines completos passam a usar `local_pipeline` (T010) (INV-006)
- [x] T012 [P] [US1] Repartir `Tools/video/tests/test_subtitles.py` para `Tools/video_subtitles/tests/test_subtitles.py`, sem perder casos; os que combinam legendas com efeitos usam `local_pipeline` (INV-006)
- [x] T013 [P] [US1] Repartir `Tools/video/tests/test_frame_extraction.py` para `Tools/video_frames/tests/test_frame_extraction.py`, sem perder casos; acrescentar um caso em que a informação do vídeo chega por `sourceInfo` (R5) (INV-006)
- [x] T014 [P] [US1] Copiar `Tools/video/tests/conftest.py` para cada `Tools/video_*/tests/`, ajustando o `sys.path` à pasta do serviço e a `Tools/video_common/`
- [x] T015 [P] [US1] Teste em `projects/tests/`: dado um plano com vários estágios, a resposta de sucesso do estágio *i* cria o `Process` do estágio *i+1* (com `cur_pos = i+1` e o plano guardado) e envia a mensagem para a fila do serviço seguinte; a resposta do último estágio é tratada como fim da cadeia (`data-model.md`, transições)
- [x] T016 [P] [US1] Teste em `projects/tests/`: a pré-visualização de um pipeline com legendas e `trim` envia os estágios com `preview: true` só no estágio previsto pelo plano e trata a resposta do último como pré-visualização (RE-006)

### Implementação

- [x] T017 [P] [US1] Criar o serviço de edição em `Tools/video_edit/`: `video_processor.py` com `_process_video`, `resolve_trim`, `resolve_speed`, `atempo_chain`, `validate_tools` e `_start_encoder` movidos de `Tools/video/video_processor.py` (sem alterar a lógica); `video_edit.py` como ponto de entrada (classe de T008, fila `video_edit_queue`, `procedure` `video_edit`, `microservice` `picturas-video-edit-ms`); por agora com `effects.py` movido de `Tools/video/effects.py` (substituído em US2)
- [x] T018 [P] [US1] Criar `Tools/video_edit/Dockerfile` (ffmpeg, sem `fonts-noto-cjk` nem `faster-whisper`; copia `video_edit`, `video_common`, `utils`) e `Tools/video_edit/requirements.txt` sem `faster-whisper` (RE-002)
- [x] T019 [P] [US1] Criar o serviço de legendagem em `Tools/video_subtitles/`: `subtitles.py` movido de `Tools/video/subtitles.py`; `video_subtitles.py` como ponto de entrada (fila `video_subtitles_queue`, `procedure` `video_subtitles`, executa `caption_video` sobre a entrada do estágio); `Dockerfile` (ffmpeg e as fontes de `Tools/video/Dockerfile`) e `requirements.txt` com `faster-whisper==1.2.1` — o único serviço com esta dependência (RE-002)
- [x] T020 [P] [US1] Criar o serviço de extração em `Tools/video_frames/`: `frame_extraction.py` movido de `Tools/video/frame_extraction.py`; `video_frames.py` como ponto de entrada (fila `video_frames_queue`, `procedure` `video_frames`); usa `parameters.sourceInfo` quando existe e, sem ele, `probe(..., prefer_video_duration=True)` (R5); `Dockerfile` e `requirements.txt` sem `faster-whisper`
- [x] T021 [US1] Em `docs/fase2/medicoes/regressao_hashes.py`, trocar só a chamada `process_video` (`run_video`, ~l. 136-139) pelo executor `Tools/video_common/local_pipeline.py`, e atualizar o comando do cabeçalho para a imagem do serviço de edição (R7). Correr `regressao_hashes.py video apos-rnf2` → *hashes* iguais aos de `resultados/base/` (depende de T010, T017, T019, T020)
- [x] T022 [US1] Declarar `video_edit_queue`, `video_subtitles_queue` e `video_frames_queue` em `rabbitMQ/definitions.json`, com as mesmas propriedades da `video_queue` (R9)
- [x] T023 [US1] Mapear `video_edit`, `video_subtitles` e `video_frames` para as filas novas em `projects/utils/project_msg.js` (R9)
- [x] T024 [US1] Acrescentar ao esquema Mongoose em `projects/models/process.js` o campo do plano de estágios (e.g., `stages: { type: Array }`, opcional, para não afetar os `Process` de imagem), senão o Mongoose descarta-o ao gravar (`data-model.md`)
- [x] T025 [US1] Em `projects/routes/projects.js`, no *Apply* (`POST /:user/:project/process`, ~l. 1630-1645) e na pré-visualização (`POST /:user/:project/preview/:img`, ~l. 1110-1125): calcular `planStages`, guardar o plano no `Process` (T024), atribuir os caminhos dos estágios em `…/projects/<projeto>/stages/<token>/<imgId>-<índice>.mp4` (R3) e enviar só o primeiro estágio, com `progress.range` e `stage` (`contracts/mensagens-estagio.md`)
- [x] T026 [US1] Em `projects/routes/projects.js`, no tratamento das respostas (~l. 196-520): para vídeo, `chainEnd` passa a ser «último estágio do plano» em vez de `sourceIsVideo`; ao receber sucesso de um estágio intermédio, verificar o `activeToken` (como hoje), criar o `Process` do estágio seguinte e enviá-lo, passando `video_info` como `sourceInfo` quando o seguinte é a extração (R5). Os ramos de pré-visualização, extração (`holdsRunCommit`) e registo do resultado mantêm-se, agora aplicados ao último estágio (INV-003, INV-004). T015 e T016 passam
- [x] T027 [US1] Em `docker-compose.yaml`, substituir `video_tool` por `video_edit`, `video_subtitles` e `video_frames` (volume `image_data` nos três; `whisper_models` e `WHISPER_*` só na legendagem; `VIDEO_PREVIEW_SECONDS` na edição e na extração; `restart: on-failure` nos três)
- [x] T028 [US1] Correr os testes e confirmar que o total de casos de vídeo não é inferior a 74: `docker compose exec -T projects sh -c "node --test tests/*.test.js"` e, para cada serviço `S` em `video_edit`, `video_subtitles`, `video_frames`: `docker compose run --rm --no-deps -T -v "<raiz>:/repo" -w /repo/Tools/S S sh -c "pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"` (o repositório montado dá aos testes o ficheiro de casos do `projects` e o código dos outros serviços, usados pelo `local_pipeline`; sem ele há testes que falham ou são saltados)

**Checkpoint**: a aplicação processa vídeos pelos três serviços; N2 (C2) = 1 tipo; *hashes* de vídeo iguais à base; o M1
deixa de esperar pela legendagem.

---

## Fase 4: História 2 — Alterar um efeito num único sítio (P2)

**Objetivo**: os 8 efeitos com uma única implementação em `Tools/effects/`, um ficheiro por efeito (TAT-08, R8).

**Teste independente**: `rnf2_estaticas.py` → N1 = 0 e C1 reconstrói 2 serviços; `regressao_hashes.py imagem` e
`video` com *hashes* iguais aos da base.

### Testes primeiro

- [X] T029 [US2] Comparar, efeito a efeito, o código inline de cada ferramenta de imagem com a cópia em `Tools/video/effects.py:11-41`; se algum diferir, registar a diferença em `specs/001-rnf2-modularidade/research.md` (R8, «Cuidado») antes de unificar (H-07)

### Implementação

- [X] T030 [P] [US2] Criar `Tools/effects/brightness.py`, `contrast.py`, `saturation.py`, `rotate.py`, `resize.py`, `binarization.py`, `cut.py`, `border.py`, cada um com a função PIL de `Tools/video/effects.py` correspondente, com os mesmos nomes de parâmetros
- [X] T031 [P] [US2] `Tools/brightness/brightness.py` (`adjust_brightness`) e `Tools/brightness/Dockerfile` (`COPY ./effects/brightness.py ./effects/brightness.py`): usar `effects.brightness` em vez do código inline
- [X] T032 [P] [US2] Idem para `Tools/contrast/` (`contrast_image`) e `Tools/saturation/` (`saturation_image`), cada Dockerfile a copiar só o seu ficheiro de efeito
- [X] T033 [P] [US2] Idem para `Tools/rotate/` (`rotate_image`), `Tools/resize/` (`resize_image`) e `Tools/cut/` (`cut_image`)
- [X] T034 [P] [US2] Idem para `Tools/binarization/` (`add_binarization`) e `Tools/border/` (`add_border`)
- [x] T035 [US2] Em `Tools/video_edit/`, apagar `effects.py`, criar o registo `apply_frame_effects` (com `FRAME_EFFECTS`, `TIME_EFFECTS`, `SUPPORTED`) a importar de `Tools/effects/`, e fazer o `Dockerfile` copiar `./effects` inteira (depende de T017)
- [x] T036 [US2] Correr `regressao_hashes.py imagem apos-rnf2` e `regressao_hashes.py video apos-rnf2` (adaptado em T021) e confirmar *hashes* iguais aos de `resultados/base/` (SC-007)

**Checkpoint**: N1 = 0; mudar o brilho reconstrói só `brightness_tool` e `video_edit`.

---

## Fase 5: História 3 — O utilizador não nota diferença (P3)

**Objetivo**: provar a preservação funcional ponta a ponta e tratar os casos de falha e cancelamento do pipeline
repartido (INV-001 a INV-005, H-08).

**Teste independente**: testes novos de cancelamento e de erro, e verificação manual do `quickstart.md`.

### Testes primeiro

- [x] T037 [P] [US3] Teste em `projects/tests/`: cancelar entre dois estágios (o `activeToken` muda antes de chegar a resposta do estágio *i*) → o estágio *i+1* não é enviado, nada é registado, nenhuma mensagem de sucesso chega ao cliente, e a quota fica como na base (H-08)
- [x] T038 [P] [US3] Teste em `projects/tests/`: erro num estágio intermédio → o erro chega ao cliente com o mesmo código (2000–2005), o pipeline não continua e a pasta `stages/<token>/` é apagada

### Implementação

- [x] T039 [US3] Em `projects/routes/projects.js`, apagar `…/stages/<token>/` no fim do pipeline (sucesso, erro e cancelamento) (R3). T037 e T038 passam (feito por vídeo e também no cancelamento: ver o desvio registado na R3)
- [X] T040 [US3] Verificação manual do `quickstart.md`, secção 1, passo 4 (projeto com 2 imagens e 2 vídeos; brilho; legendas + brilho; corte + extração; pré-visualizações; cancelamento a meio), confirmando também que as interfaces HTTP e a interface do utilizador não mudaram (INV-005); registar o resultado

**Checkpoint**: preservação funcional provada; pipeline repartido robusto a erros e cancelamento.

---

## Fase final: Acabamento e transversal

- [x] T041 [P] README curto em `Tools/video_edit/`, `Tools/video_subtitles/` e `Tools/video_frames/` (o que faz, fila, comando dos testes da T028)
- [x] T042 Retirar `Tools/video/` e a `video_queue` de `rabbitMQ/definitions.json`, depois de T028, T036 e T040
- [x] T043 Confirmar a deteção do `rnf2_estaticas.py` com a nova estrutura (R10); se for preciso adaptar, mudar só a deteção e registar em `docs/fase2/medicoes/README.md`
- [x] T044 Medição completa `apos-rnf2` (`quickstart.md`, secções 2 e 3): `rnf2_estaticas.py`, N3 com imagens do mesmo dia, `carga_rnf1.py` (`isolado`, `m1`, `m2`, `paralelo`) → `docs/fase2/medicoes/resultados/apos-rnf2/`
- [x] T045 Atualizar o estado de H-06 a H-09 em `docs/fase2/exercicios/RAS-exercicio_6_bloco1_SWdesign_template_PT.md` (secção 2.6) e preencher «Implementação» e «Desvios face à decisão» da DA-2 no relatório (cap. 8); se houver desvios, atualizar `docs/fase2/relatorio/images/vista_depois.puml` e regenerar o SVG

---

## Dependências e ordem

- **Fase 1 → Fase 2 → histórias.** A Fase 2 bloqueia tudo.
- **US1** depende só da Fase 2. É o MVP: sem ela não há serviços separados. Dentro da US1: T021 depende dos três serviços (T017, T019, T020); T025 depende de T024; T026 depende de T025.
- **US2**: a parte de imagem (T030–T034) pode começar logo a seguir à Fase 2, em paralelo com US1; T035 depende de T017; T036 depende de T021 e T035.
- **US3**: depende de US1 (T025, T026).
- **Acabamento**: T042 só depois de todas as histórias; T044 só com tudo verde; T045 no fim.

## Paralelismo

- Fase 2: T004 ∥ (T006, T007, T009) depois de T003.
- US1: T011–T016 em paralelo; T017–T020 em paralelo (um serviço por pessoa); T022–T027 em sequência no `projects` e na configuração.
- US2: T030 e depois T031–T034 em paralelo (ferramentas de imagem diferentes).
- US3: T037 ∥ T038.

Exemplo para 3 pessoas depois da Fase 2: A — T017, T018, T011; B — T019, T012; C — T020, T013, T030.

## Estratégia

1. **MVP (US1)**: Fase 1, Fase 2 e US1 → validar N2 (C2), *hashes* de vídeo e a aplicação a processar vídeos pelos
   três serviços. Fazer a US1 num ramo próprio e juntar ao `fase2` só com os testes a passar.
2. **US2**: efeitos partilhados → N1 = 0 e *hashes* iguais.
3. **US3**: cancelamento, erros e limpeza → preservação provada.
4. **Acabamento e medição `apos-rnf2`** antes de começar o RNF1 (`specs/002-rnf1-capacidade`).
