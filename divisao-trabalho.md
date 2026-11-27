# RNF2 — Divisão do trabalho pela equipa

Guia prático para implementar o RNF2 a 5. Detalha o `tasks.md` desta pasta por pessoa; os números entre parênteses
(T0xx) são as tarefas de lá, para citar nos *commits*.

## Em 30 segundos

Hoje um único serviço, o `video_tool`, faz tudo o que é vídeo. Vamos:

1. partir o `video_tool` em **três serviços**: edição, legendagem e extração de fotogramas;
2. pôr o `projects` a **dividir cada pedido de vídeo em passos** («estágios») e a mandar cada passo para o serviço certo,
   como já faz com as imagens;
3. juntar num só sítio os **8 efeitos** (brilho, contraste, …) que hoje estão copiados entre imagem e vídeo.

**Regra de ouro:** o utilizador não pode notar diferença nenhuma. Os vídeos e imagens que saem têm de ser **iguais bit
a bit** aos de hoje — é isso que o `regressao_hashes.py` verifica.

## Quem faz o quê

| | Pessoa | Passo 1 (fundação) | Passo 2 (cada um a sua parte) |
|---|---|---|---|
| **A** | {nome} | Planeador de estágios no `projects` | `projects` envia e encadeia os estágios |
| **B** | {nome} | Base comum dos serviços de vídeo | Serviço de **edição** + `regressao_hashes.py` |
| **C** | {nome} | (começa no passo 2) | Serviços de **legendagem** e de **extração** |
| **D** | {nome} | Efeitos partilhados (já pode começar) | Continua os efeitos partilhados |
| **E** | {nome} | Configuração (já pode começar) | `docker-compose`, filas e preparação do RNF1 |

Depois do **Passo 3 (testar tudo junto)**, A e D têm uma segunda parte curta (ver as fichas).

## Antes de começar (todos)
Vou confirmar o plano da ficha B e os pontos que dependem de A/E, depois resumo os comandos na ordem certa.

Search for `(?i)(pessoa B|\bB\b|video_edit|video_stage_plans|comum)`

Find files matching `specs/001-rnf2-modularidade/**/*`

Read , line 1 to the end
Completed with input: {
  "path": "/home/dahmer/Universidade/4Ano/1SEM/RAS/picturas-27/divisao-trabalho.md",
  "view_range": [
    1,
    -1
  ]
}

Read 
Completed with input: {
  "path": "/home/dahmer/Universidade/4Ano/1SEM/RAS/picturas-27/Tools/video"
}

Find files matching `**/specs/001-rnf2-modularidade/**/*`

"Search" failed
Tool execution failed: Search paths do not exist: specs

Read , line 1 to the end
Completed with input: {
  "path": "/home/dahmer/Universidade/4Ano/1SEM/RAS/picturas-27/Tools/video/video.py",
  "view_range": [
    1,
    -1
  ]
}

Read , line 1 to the end
Completed with input: {
  "path": "/home/dahmer/Universidade/4Ano/1SEM/RAS/picturas-27/Tools/video/video_processor.py",
  "view_range": [
    1,
    -1
  ]
}

Ran terminal command: git --no-pager status --short --branch && git --no-pager branch --list 'rnf2-*' && git --no-pager branch --show-current

Antes dos passos finais, vou verificar se os ficheiros de especificação já existem noutras referências ou apenas noutro ramo.

Ran terminal command: git --no-pager branch -r && git --no-pager ls-tree -r --name-only HEAD | rg '(^specs/|research\.md$|tasks\.md$|video_stage_plans\.json$|mensagens-estagio\.md$)'
Tool execution failed with exit code 1

Find files matching `**/{research.md,tasks.md,spec.md,quickstart.md,video_stage_plans.json,mensage...`

Read 
Completed with input: {
  "path": "/home/dahmer/Universidade/4Ano/1SEM/RAS/picturas-27/Tools/video/tests"
}

"Read" failed
Completed with input: {
  "path": "/home/dahmer/Universidade/4Ano/1SEM/RAS/picturas-27/docs"
}
Tool execution failed: Path does not exist

Ran terminal command: git --no-pager ls-tree -r --name-only origin/fase2 | rg '(^specs/001-rnf2-modularidade/|docs/fase2/medicoes/regressao_hashes\.py$|projects/tests/fixtures/video_stage_plans\.json$)'

Ran terminal command: git --no-pager ls-tree -r --name-only origin/rnf2-a-projects | rg '(video_stage_plans\.json|mensagens-estagio\.md|spec\.md|research\.md|tasks\.md)'

És a **Pessoa B**. Usa o ramo **`rnf2-b-edicao`**.

## 1. Criar o ramo

```bash
cd /home/dahmer/Universidade/4Ano/1SEM/RAS/picturas-27
git fetch --all --prune
git switch -c fase2 --track origin/fase2
git pull
git switch -c rnf2-b-edicao
```

Confirma:

```bash
git branch --show-current
```

Deve mostrar `rnf2-b-edicao`.

## 2. Ler os documentos obrigatórios

Começa por ler:

- `spec.md`
- `research.md`
- `tasks.md`
- `mensagens-estagio.md`
- `divisao-trabalho.md`

No início, combina com A o formato de `projects/tests/fixtures/video_stage_plans.json`. Este ficheiro não deve ser alterado sozinho — avisa a equipa antes de mudar o formato.

## 3. Obter o ficheiro de casos

A pessoa A ainda não está no teu ramo. Obtém o ficheiro diretamente do ramo dela:

```bash
git fetch origin rnf2-a-projects
git checkout origin/rnf2-a-projects -- projects/tests/fixtures/video_stage_plans.json
```

Verifica:

```bash
ls projects/tests/fixtures/video_stage_plans.json
```

Não copies casos à mão. Os 32 casos já vêm gerados.

## 4. Criar a base comum — T006–T010

Cria `Tools/video_common/` com:

- `errors.py`
- `probe.py`
- `worker.py`
- `requirements.txt`
- `local_pipeline.py`

Começa pelos ficheiros existentes:

- Erros, probe e processamento: `video_processor.py`
- Carcaça RabbitMQ: `video.py`

Requisitos comuns:

- `pika`
- `pytz`
- `python-dotenv`
- `pillow`

O `worker.py` deve:

- receber uma mensagem de cada vez;
- reconhecer a mensagem só no fim;
- chamar a função de processamento do serviço;
- responder com sucesso ou erro;
- converter progresso local para `progress.range`;
- enviar 100 no último estágio.

O `local_pipeline.py`:

- lê `video_stage_plans.json`;
- procura o caso pela sequência de procedures e `preview`;
- chama diretamente os serviços;
- nunca calcula por si os estágios.

Esta base está pronta quando o `worker.py` arranca com uma função de teste e o formato dos casos foi combinado com A.

## 5. Criar o serviço de edição — T011, T014, T017, T018, T021

Cria `Tools/video_edit/` com:

- `video_edit.py`
- `Dockerfile`
- `requirements.txt`
- `tests/`
- código movido de `video_processor.py`

O Dockerfile e os requisitos não devem incluir:

- `faster-whisper`;
- fontes das legendas;
- código de legendagem ou extração.

Copia por agora `effects.py`, porque D o substituirá mais tarde.

A edição deve manter esta lógica da base:

- `_process_video`;
- corte;
- velocidade;
- trim;
- validação completa;
- efeitos;
- preview;
- codificação FFmpeg;
- resposta de sucesso ou erro.

As operações inválidas devem passar pela `validate_tools` antes de processar. Essa validação usa a `validate_params` de extração, portanto não implementes uma segunda cópia: combina com C a localização única em `video_common`.

## 6. Mover os testes

Passa para `Tools/video_edit/tests/` os testes existentes de:

`Tools/video/tests/test_video_processor.py`

Não podes perder nenhum teste.

## 7. Adaptar a regressão de hashes

Em `docs/fase2/medicoes/regressao_hashes.py`, substitui apenas a chamada direta a `process_video` por `local_pipeline`.

O resultado continua a ter de ser bit a bit igual ao da base.

## 8. Instalar e testar

Para os testes de vídeo no computador:

```bash
cd Tools/video
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest -q tests
```

Depois de criares `Tools/video_edit/tests`, testa também:

```bash
cd Tools/video_edit
python3 -m pytest -q tests
```

Durante o Passo 3, os serviços serão testados com:

```bash
docker compose run --rm --no-deps -T video_edit sh -c \
"pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"
```

Deves produzir hashes iguais aos disponíveis em `resultados/base/`:

```bash
python docs/fase2/medicoes/regressao_hashes.py video
```

## 9. Fazer commits pequenos

O ficheiro de casos pode ser incluído no teu ramo. Usa mensagens como:

```text
RNF2 T006 (TAT-07): base comum de video
RNF2 T011 (TAT-07): serviço de edição
RNF2 T021 (TAT-07): regressão com pipeline local
```

Exemplo:

```bash
git add Tools/video_common Tools/video_edit \
  projects/tests/fixtures/video_stage_plans.json \
  docs/fase2/medicoes/regressao_hashes.py

git commit -m "RNF2 T011 (TAT-07): serviço de edição

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Pronto

Só declares a tua parte pronta quando:

- todos os testes de `video_edit` passam;
- o `worker.py` arranca;
- o formato do ficheiro de casos está combinado com A;
- a `local_pipeline` encontra os casos pela sequência;
- `validate_tools` continua rejeitando pipelines inválidos;
- a regressão de vídeo produz os mesmos hashes da base;
- não foi alterado o contrato das mensagens sem avisar a equipa.
1. `git checkout fase2 && git pull`
2. Criar o vosso ramo a partir do `fase2`: `git checkout -b rnf2-<letra>-<tema>` (e.g., `rnf2-b-edicao`).
3. Ler, desta pasta: `spec.md` (o que tem de ficar igual), `research.md` (as decisões técnicas R1–R10) e o vosso
   bloco no `tasks.md`. As mensagens entre o `projects` e os serviços estão em `contracts/mensagens-estagio.md`.
4. Arrancar sempre com `docker compose up -d --build` (sem `--build` usa imagens antigas).

---

## Ficha A — `projects` (orquestrador)

**Passo 1: o planeador de estágios** (T003–T005)

*O que é:* uma função que recebe a lista de ferramentas de um vídeo e diz em que passos se divide e que serviço faz cada
um. Exemplo: `[brilho, legendas, contraste]` → edição `[brilho]` → legendagem → edição `[contraste]`.

1. Criar `projects/tests/fixtures/video_stage_plans.json`: uma lista de casos, cada um com as ferramentas de entrada e
   os estágios esperados. Os casos são **todos** os pipelines usados em `docs/fase2/medicoes/regressao_hashes.py`
   (`VIDEO_CASES`) e nos testes de `Tools/video/tests/`, mais os casos-limite da `spec.md`. Os estágios esperados tiram-se
   das regras de hoje em `Tools/video/video_processor.py:286-369` (resumidas na R1 do `research.md`). **Este ficheiro é
   usado também pela pessoa B** — combinar o formato com ela logo no início.
2. Escrever o teste `projects/tests/videoStages.test.js`: para cada caso, a função devolve os estágios esperados.
3. Escrever `projects/utils/videoStages.js` com `planStages(tools, preview)` até o teste passar.

*Pronto quando:* `cd projects && node --test tests/videoStages.test.js` passa em todos os casos.

**Passo 2: enviar e encadear os estágios** (T015, T016, T023–T026)

1. `projects/models/process.js`: acrescentar um campo opcional `stages` (o plano), senão o Mongoose apaga-o ao gravar.
2. `projects/utils/project_msg.js`: as três filas novas (`video_edit_queue`, `video_subtitles_queue`,
   `video_frames_queue`) no lugar da `video_queue`.
3. `projects/routes/projects.js`, no *Apply* e na pré-visualização: calcular o plano, guardá-lo e enviar **só o primeiro
   estágio** (formato em `contracts/mensagens-estagio.md`).
4. `projects/routes/projects.js`, onde chegam as respostas: quando um estágio acaba com sucesso e ainda há outro,
   verificar o cancelamento (como hoje) e enviar o seguinte. Só o último estágio regista o resultado.
5. Testes de encadeamento e de pré-visualização em `projects/tests/`.

*Pronto quando:* os testes do `projects` passam; no Passo 3, um vídeo com legendas passa pelos serviços certos.

**Depois do Passo 3: cancelamento, erros e limpeza** (T037–T040)

Testes e código para: cancelar a meio de um pipeline; erro num estágio do meio; apagar os ficheiros intermédios no fim.
Fazer a verificação à mão da secção 1 do `quickstart.md`.

---

## Ficha B — base comum e serviço de edição

**Passo 1: a base comum** (T006–T010), em `Tools/video_common/`

*O que é:* o código que os três serviços partilham, para não o repetir três vezes.

1. `errors.py`: os códigos 2000–2005 e as exceções, movidos de `Tools/video/`.
2. `probe.py`: a função `probe`, movida de `Tools/video/video_processor.py` sem alterações.
3. `worker.py`: a «carcaça» de um serviço de vídeo, tirada de `Tools/video/video.py` — liga-se ao RabbitMQ, recebe uma
   mensagem de cada vez, chama a função de processamento do serviço, responde (sucesso ou erro) e confirma a mensagem
   só no fim. O progresso é convertido para a faixa do estágio (R4).
4. `requirements.txt`: `pika`, `pytz`, `python-dotenv`, `pillow`.
5. `local_pipeline.py`: **só para testes**. Lê os estágios do ficheiro da pessoa A e corre-os chamando diretamente as
   funções dos três serviços. Nunca calcula estágios por si.

*Pronto quando:* o `worker.py` arranca com uma função de teste e o formato do ficheiro de casos está combinado com A.

**Passo 2: o serviço de edição** (T011, T014, T017, T018, T021), em `Tools/video_edit/`

1. Mover de `Tools/video/video_processor.py` as funções de edição (`_process_video`, corte, velocidade, …) **sem lhes
   mudar a lógica**; por agora copiar também o `effects.py` (a pessoa D substitui-o depois).
2. `video_edit.py`: o ponto de entrada, usando o `worker.py` (fila `video_edit_queue`).
3. `Dockerfile` e `requirements.txt` **sem** `faster-whisper` nem as fontes das legendas.
4. Passar para `Tools/video_edit/tests/` os testes de `Tools/video/tests/test_video_processor.py`, sem perder nenhum.
5. Em `docs/fase2/medicoes/regressao_hashes.py`, trocar só a chamada `process_video` pelo `local_pipeline`.

*Pronto quando:* os testes do serviço passam e, no Passo 3, o `regressao_hashes.py video` dá os mesmos *hashes* da base.

---

## Ficha C — serviços de legendagem e de extração

Começa quando a base comum da pessoa B estiver pronta (Passo 1). Entretanto, ler `subtitles.py`, `frame_extraction.py`
e os respetivos testes.

**Legendagem** (T012, T019), em `Tools/video_subtitles/`

1. Mover `Tools/video/subtitles.py`; ponto de entrada `video_subtitles.py` com o `worker.py` (fila `video_subtitles_queue`).
2. `Dockerfile` com o ffmpeg e as fontes de `Tools/video/Dockerfile`; `requirements.txt` com `faster-whisper==1.2.1` —
   **é o único serviço com esta dependência**.
3. Passar os testes de `test_subtitles.py`; os que juntam legendas e efeitos usam o `local_pipeline`.

**Extração** (T013, T020), em `Tools/video_frames/`

1. Mover `Tools/video/frame_extraction.py`; ponto de entrada `video_frames.py` (fila `video_frames_queue`).
2. Quando a mensagem traz `sourceInfo` (vídeo editado antes), usá-lo em vez de voltar a analisar o vídeo (R5) — senão os
   fotogramas escolhidos podem mudar.
3. `Dockerfile` e `requirements.txt` sem `faster-whisper`; passar os testes de `test_frame_extraction.py`.

*Pronto quando:* os testes dos dois serviços passam.

---

## Ficha D — efeitos partilhados

Pode começar já: não depende de ninguém.

1. **Primeiro comparar** (T029): para cada um dos 8 efeitos, o código da ferramenta de imagem (e.g.,
   `Tools/brightness/brightness.py`, `adjust_brightness`) e a cópia em `Tools/video/effects.py`. Se forem diferentes,
   escrever a diferença no `research.md` (R8) e avisar a equipa **antes** de unificar.
2. Criar `Tools/effects/` com **um ficheiro por efeito** (`brightness.py`, `contrast.py`, …), cada um com a função PIL
   (T030). **Não pôr em `Tools/utils`**: isso obrigaria a reconstruir 15 serviços a cada mudança.
3. Nas 8 ferramentas de imagem (T031–T034): chamar a função do ficheiro em vez do código próprio, e no Dockerfile copiar
   **só o seu ficheiro**, e.g. `COPY ./effects/brightness.py ./effects/brightness.py`.
4. Correr `regressao_hashes.py imagem` → *hashes* iguais à base.

**Depois do Passo 3** (T035, T036): o serviço de edição passa a usar `Tools/effects/` em vez da cópia; correr os *hashes*
de imagem e de vídeo.

*Pronto quando:* *hashes* iguais e nenhum efeito escrito duas vezes.

---

## Ficha E — configuração e preparação do RNF1

**Configuração do RNF2** (T022, T027)

1. `rabbitMQ/definitions.json`: declarar as três filas novas, iguais à `video_queue`.
2. `docker-compose.yaml`: trocar o `video_tool` por `video_edit`, `video_subtitles` e `video_frames`. O volume
   `image_data` vai para os três; o `whisper_models` e as variáveis `WHISPER_*` só para a legendagem.
3. Preparar o ramo de integração `rnf2-integracao` e conduzir o Passo 3.

**Preparação do RNF1** (ver `specs/002-rnf1-capacidade/tasks.md`) — não depende do RNF2:

1. Marcar com a equipa a decisão dos parâmetros do ajuste automático e dos limites de memória (RNF1 T003).
2. Política de réplicas com testes, `Tools/video_autoscaler/policy.py` (RNF1 T016, T017).
3. Dockerfile do autoscaler (RNF1 T019) e *script* do M4, `docs/fase2/medicoes/elasticidade_m4.py` (RNF1 T021).

**Depois do Passo 3** (T041–T044): README de cada serviço, retirar o `Tools/video/` antigo e a `video_queue`, e fazer a
medição **`apos-rnf2`** (secções 2 e 3 do `quickstart.md`).

---

## Passo 3 — testar tudo junto

Quando A, B, C e E disserem «pronto», a pessoa E junta os ramos no `rnf2-integracao`
(`git merge rnf2-a-…`, `git merge rnf2-b-…`, …) e corre:

1. `docker compose up -d --build`
2. Testes do `projects`: `docker compose exec -T projects sh -c "node --test tests/*.test.js"`
3. Testes de cada serviço `S` (`video_edit`, `video_subtitles`, `video_frames`):
   `docker compose run --rm --no-deps -T S sh -c "pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"`
   — o total de testes de vídeo não pode ser inferior a 74.
4. `regressao_hashes.py video` (comando no cabeçalho do *script*) → *hashes* iguais aos de `resultados/base/`.
5. À mão, na aplicação: um vídeo com brilho, um com legendas + brilho, um com corte + extração, e uma pré-visualização.

Se tudo passar, junta-se ao `fase2`. Se algo falhar, quem é dono da parte corrige no seu ramo e repete-se.

Segue-se a segunda parte de A (cancelamento) e D (edição com `Tools/effects/`), e depois a medição `apos-rnf2` (E).
Só então se começa o RNF1.

## Regras da equipa

- **Não mudar sozinho o que os outros usam:** o ficheiro de casos (A e B), o formato das mensagens
  (`contracts/mensagens-estagio.md`) e o `worker.py` (B). Se for preciso mudar, avisar no grupo e atualizar o documento.
- **Cada um corre os seus testes antes de dizer «pronto».**
- **Mensagens de *commit* com a tarefa**, e.g. `RNF2 T017 (TAT-07): serviço de edição`. Servem para preencher a
  «Implementação» da DA-2 no relatório.
- **Dúvida sobre o que fazer?** A resposta deve estar no `research.md` (R1–R10). Se não estiver, perguntar no grupo
  antes de decidir.
