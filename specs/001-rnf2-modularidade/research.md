# Pesquisa (fase 0): RNF2 — Modularidade do processamento de vídeo

Decisões técnicas que a DA-2 deixa em aberto, resolvidas a partir do código da base (`0523102`). Cada uma indica a
decisão, a razão e as alternativas. Nenhuma altera a DA-2; detalham como realizá-la.

## R1. Onde se decide a divisão em estágios

- **Decisão**: um planeador puro no `projects` (`projects/utils/videoStages.js`, função `planStages(tools, preview)`),
  que reproduz exatamente as regras de `process_video` (`Tools/video/video_processor.py:286-369`):
  1. se a última ferramenta for `extract_frames`: sem outras ferramentas → um só estágio de extração sobre o original;
     com outras → estágios de edição/legendagem para `tools[:-1]` **sem pré-visualização** e, no fim, o estágio de
     extração (com `preview` se for pré-visualização);
  2. sem `subtitles` → um só estágio de edição;
  3. com `subtitles` → partir à volta de cada `subtitles`; se a lista começar por `subtitles`, há um estágio de edição
     **vazio** antes (normaliza a entrada para MP4/H.264, como hoje);
  4. a pré-visualização só se aplica no estágio de edição «índice `preview_stage`» (o último estágio com `trim` ou
     `speed`; 0 se não houver).
- **Razão**: a DA-2 põe o encadeamento no `projects` (TAT-09). Um planeador puro testa-se sem RabbitMQ.
- **Alternativas**: encadeamento entre os serviços de vídeo (rejeitado na DA-2); o serviço de edição a coordenar os
  outros (recriava o monólito e acoplava os serviços).

## R2. Garantir que o planeador JS e as regras Python não divergem

- **Decisão**: um único ficheiro de casos, `projects/tests/fixtures/video_stage_plans.json`, com a lista de ferramentas
  de entrada e o plano esperado para os 9 pipelines de `regressao_hashes.py`, para **todos** os pipelines usados nos
  testes Python de `Tools/video/tests` e para os casos-limite da *spec*. É usado
  (a) pelo teste do planeador em `projects/tests/` e (b) pelo executor local de estágios dos testes Python e do
  `regressao_hashes.py` (R7).
- **Razão**: a regressão por *hash* (H-07, INV-001) só prova a preservação se os estágios executados forem os mesmos
  que o `projects` vai pedir.
- **Alternativas**: *hashes* ponta a ponta através da aplicação (mais fiel, mas lento e dependente do RabbitMQ; fica
  como verificação manual no `quickstart.md`); duplicar o planeador em Python (duas implementações a divergir).

## R3. Ficheiros intermédios entre estágios

- **Decisão**: cada estágio escreve no volume partilhado `image_data`, num caminho atribuído pelo `projects`:
  `…/projects/<projeto>/stages/<token>/<imgId>-<índice>.mp4`. O último estágio escreve no destino final com escrita
  atómica (`.part` + `os.replace`, EV-25). O `projects` apaga a pasta `stages/<token>/` quando o pipeline termina com
  sucesso, erro ou cancelamento.
- **Razão**: hoje os MP4 intermédios já existem, numa pasta temporária do mesmo volume (EV-15); muda só quem a gere.
- **Alternativas**: passar o vídeo pela fila (inviável pelo tamanho); cada serviço apagar a entrada que recebeu (falha
  se o estágio seguinte ainda não a leu ou se o pipeline for cancelado).

## R4. Progresso igual ao da base

- **Decisão**: cada mensagem de estágio leva `progress.range = [início, fim]`; o serviço converte a sua percentagem
  local para `início + (fim − início) × p/100`. As faixas reproduzem a base: com legendas, o estágio *i* de *n* fica
  em `[i·100/n, (i+1)·100/n]` com teto de 99 até ao fim; extração depois de edição fica com `[0, 70]` para a edição e
  `[70, 100]` para a extração. Só o último estágio envia 100.
- **Razão**: INV-002 (as mensagens de progresso mantêm-se).

## R5. Informação do vídeo editado para a extração

- **Decisão**: a resposta de cada estágio de edição já inclui a informação do vídeo (`video_info`, `Tools/video/video.py:76-92`);
  o `projects` passa-a ao estágio de extração em `parameters.sourceInfo`. Sem estágio anterior, o serviço de extração
  faz `probe(..., prefer_video_duration=True)`, como hoje.
- **Razão**: a base chama `extract_frames(edited, …, info)` com o `info` devolvido pela edição, não com um `probe` novo;
  sondar de novo podia mudar a duração e, com ela, os instantes amostrados (hashes diferentes).

## R6. Código partilhado entre os três serviços de vídeo

- **Decisão**: `Tools/video_common/` com o ciclo do *worker* (ligação, consumo com `prefetch=1` e `ack` manual no fim,
  respostas de sucesso e erro, progresso com faixas), `probe` e as exceções e códigos 2000–2005. É copiado pelos três
  serviços de vídeo e por nenhum de imagem.
- **Razão**: evita triplicar o ciclo do *worker*. Os cenários de mudança não lhe tocam (C1: `Tools/effects/brightness.py`;
  C2: `requirements` da legendagem; C3: `frame_extraction.py`), por isso o N2 não piora.
- **Alternativas**: pôr este código em `Tools/utils` (rejeitado: reconstrói 15 serviços, EV-28); duplicá-lo nos três
  serviços (contraria o objetivo do RNF2).
- **Nota**: o `heartbeat=0` mantém-se nesta *spec*; a *thread* separada é da TAT-13 (RNF1).

## R7. Testes de vídeo e `regressao_hashes.py` depois da divisão

- **Decisão**: um executor local, só para testes (`Tools/video_common/local_pipeline.py`), que lê o plano **só** do
  ficheiro de casos (R2), sem nunca o calcular em Python, e chama diretamente as funções dos três serviços, com caminhos temporários. Os testes de
  `Tools/video/tests` repartem-se pelos três serviços; os que testam combinações (e.g., `test_subtitles.py` com
  efeitos) usam o executor local. O `regressao_hashes.py` troca a chamada a `process_video` pelo executor local (o
  cabeçalho do *script* já prevê adaptar só as funções de chamada).
- **Razão**: mantém os 74 casos (INV-006) e permite comparar *hashes* com a base sem RabbitMQ.
- **Alternativa**: manter `process_video` como está para os testes (rejeitado: testaria código que deixa de correr).

## R8. Efeitos partilhados: forma do módulo

- **Decisão**: `Tools/effects/<efeito>.py` (8 ficheiros) com a função PIL pura de cada efeito, com a assinatura atual de
  `Tools/video/effects.py:11-41`. Cada ferramenta de imagem copia só o seu ficheiro (`COPY ./effects/brightness.py
  ./effects/brightness.py`) e chama a função em vez do código inline (e.g., `Tools/brightness/brightness.py`,
  `adjust_brightness`). O registo `apply_frame_effects` e a regra de efeitos não suportados ficam no serviço de edição,
  que copia a pasta toda.
- **Razão**: DA-2 e constituição, princípio V; com um ficheiro por efeito, mudar o brilho reconstrói só 2 serviços (SC-002).
- **Cuidado**: o código inline de cada ferramenta de imagem e a cópia do vídeo têm de ser **iguais** antes de os
  unificar; se não forem, prevalece o comportamento de cada caminho na base e regista-se (H-07).

## R9. Filas e nomes

- **Decisão**: `video_edit_queue`, `video_subtitles_queue`, `video_frames_queue`, declaradas em
  `rabbitMQ/definitions.json` e mapeadas em `projects/utils/project_msg.js` para as `procedure` `video_edit`,
  `video_subtitles`, `video_frames`. A `video_queue` deixa de ser usada e é retirada.
- **Razão**: segue a convenção `<ferramenta>_queue` das imagens (EV-22).

## R10. Métricas estáticas com a nova estrutura

- **Decisão**: antes de medir `apos-rnf2`, confirmar que o `rnf2_estaticas.py` (i) reconhece `Tools/video_*` como
  serviços de vídeo, (ii) não conta `Tools/effects/` como uma segunda implementação dos efeitos (N1) e (iii) encontra
  os serviços pelas linhas `COPY` novas (N2). Se for preciso adaptar, muda-se só a deteção, nunca a definição da
  métrica, e regista-se a alteração em `docs/fase2/medicoes/README.md`.
