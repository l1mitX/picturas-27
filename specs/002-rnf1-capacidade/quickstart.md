# Guia de validação: RNF1 — Capacidade e elasticidade do processamento de vídeo

Cenários para provar que a *spec* está cumprida. Mesma máquina e mesmos parâmetros da base e de `apos-rnf2`
(constituição, princípio IV).

## Pré-requisitos

- RNF2 concluído e medido (`docs/fase2/medicoes/resultados/apos-rnf2/`).
- Parâmetros da política de réplicas e limites de memória decididos pela equipa (`research.md`, R3 e R9) e registados
  em `docs/fase2/medicoes/README.md` antes de medir.
- `docker compose up -d --build`, com o projeto Compose `picturas`.

## 1. Preservação (SC-005)

1. Testes de todos os serviços e do `projects` (comandos da T028 do RNF2) → todos passam.
2. `regressao_hashes.py imagem apos-rnf1` e `video apos-rnf1` → *hashes* iguais à base.

## 2. Réplicas e disponibilidade (SC-006, H-01 a H-05, H-10)

1. **H-01/H-02**: `docker compose up -d --scale video_edit=2`; dois trabalhos do mesmo projeto em simultâneo e duas
   pré-visualizações do mesmo vídeo → sem erros, resultados corretos.
2. **H-03**: apagar o volume `whisper_models`; arrancar 2 réplicas de legendagem e pedir duas legendagens → o modelo é
   descarregado uma vez e as duas terminam.
3. **H-10**: com uma legendagem em curso, `docker stop` da réplica → o vídeo termina nessa réplica antes de ela sair;
   nenhum vídeo recomeça noutra (registos dos *workers*).
4. **Bloqueio**: `docker pause` de uma réplica a meio de um estágio → ao fim de ~2 intervalos de *heartbeat* (60 s por
   omissão, ~2 min), a mensagem passa para outra réplica.
5. **H-05**: cancelar um pipeline com várias réplicas ativas → nada é registado.
6. **H-04**: legendagem do vídeo Premium mais longo permitido (600 s), sozinha e com 2 em paralelo → duração medida
   abaixo do `consumer_timeout`, sem reentrega.

## 3. Capacidade e elasticidade (SC-001 a SC-004, SC-007)

1. `carga_rnf1.py apos-rnf1 paralelo` → M6 (p95 ≤ 30 s alvo; ≥ 2 em simultâneo mínimo).
2. `carga_rnf1.py apos-rnf1 m1`, `isolado` e `m2` → M1 não pior do que `apos-rnf2`; isolado ≤ 19,6 s.
3. `elasticidade_m4.py apos-rnf1` → M4 (≤ 30 s alvo; ≤ 60 s mínimo) e regresso ao mínimo.
4. Durante 1–3: `docker inspect` de cada contentor de vídeo → nenhum com `OOMKilled: true`.

## Registo

- **2026-11-25**: no ramo `fase2`, com RNF2 integrado, os testes passam: `projects/tests` 68/68; `video_edit`
  38/38; `video_subtitles` 21/21; `video_frames` 42/42 (101 testes de vídeo). Contudo,
  `docs/fase2/medicoes/resultados/apos-rnf2/` ainda não existe. Por isso, o ponto de partida está testado, mas a
  medição obrigatória do RNF2 não está completa e a T001 permanece pendente; não iniciar as medições `apos-rnf1`
  até os resultados `apos-rnf2` serem recolhidos conforme o quickstart do RNF2.
- **2026-11-25**: T006–T007 implementados. Os estágios correm numa *thread* de trabalho e encaminham progresso,
  respostas e `ack` pela thread Pika; `SIGTERM` cancela o consumo e aguarda o estágio em curso antes de fechar a
  ligação. O *heartbeat* volta à negociação por omissão do broker, e o *worker* regista a hora da primeira mensagem.
  Validação: `video_common/tests` e `video_edit/tests/test_worker_progress.py` 8/8; suites `video_edit` 38/38,
  `video_subtitles` 21/21 e `video_frames` 42/42. A regressão de hashes da T008 ainda não foi executada; T001
  continua pendente até existirem as medições `apos-rnf2`.
- **2026-11-25**: depois do merge de `origin/fase2`, confirmei que `apos-rnf2` contém os quatro cenários de carga
  (isolado ×5, M1 ×5, M2 ×3, paralelo ×5), sem falhas; os hashes de imagem e vídeo são 9/9 iguais aos de `base`.
  As suites atuais de vídeo passaram (38 + 21 + 42 testes) e `projects/tests` tinha passado 68/68. T001 concluída.
- **2026-11-25**: T008 executada. As suites dos três serviços passaram novamente (38/38, 21/21, 42/42), mas
  `regressao_hashes.py video dev-rnf1` não coincide com `base` em V1, V1p, V2, V7 e V8; os restantes quatro casos
  coincidem. O resultado está em `docs/fase2/medicoes/resultados/dev-rnf1/regressao_video.json`. A discrepância
  persistiu após reconstruir `video_subtitles`; não foi possível atribuí-la com segurança a uma alteração de código
  ou a diferenças de ambiente. T008 permanece pendente e não se deve iniciar a medição final `apos-rnf1` até a
  discrepância ser esclarecida.
- **2026-11-25 (atualização)**: um colega repetiu a T008 com `rnf1-fase2` na máquina usada para a baseline e obteve
  9/9 hashes iguais. A evidência `dev-rnf1-maquina-e/regressao_video.json` está noutro *worktree* e ainda não foi
  commitada. A execução Linux acima continua a divergir em cinco casos; a explicação provável é a diferença de
  ambiente (número de CPUs/threads do `libx264` ou versão do FFmpeg), ainda não confirmada. T008 concluída com a
  execução na máquina de referência; as medições finais `apos-rnf1` também devem usar essa máquina e configuração.
- **2026-11-26**: T014 executada (secção 2, passos 1 e 2) em Linux, com o autoscaler parado. É uma verificação de
  funcionamento, não uma medição, e por isso não precisa da máquina de referência.
  - **H-01 confirmada**: com `video_edit=2`, dois vídeos do mesmo projeto (`sample_10s_720p.mp4` e `sample_6s.mov`,
    brilho) foram consumidos um por cada réplica, no mesmo segundo. Os dois resultados chegaram em 34,6 s, com
    `status=success` e sem erros nos registos.
  - **H-02 confirmada**: duas pré-visualizações do mesmo vídeo, pedidas em simultâneo, foram processadas por réplicas
    diferentes ao mesmo tempo e escreveram o mesmo ficheiro (mesma chave de saída). O ficheiro final é um MP4 válido
    (h264 1280x720 + aac, 3 s) e não ficou nenhum `.part` na pasta do projeto (correção da T011).
  - **H-03 confirmada**: com o volume `whisper_models` apagado e `video_subtitles=2`, duas legendagens em simultâneo
    (uma por réplica) terminaram em 255,8 s e 257,8 s, com `status=success`. Só uma réplica descarregou o modelo; a
    outra esperou pelo cadeado `.download.lock` (correção da T012). A cache ficou com um único modelo
    (`faster-whisper-small`, 464 MB).
  - **Autoscaler (T020)**: arrancou e registou a linha `start` com as três políticas. A primeira chamada a
    `docker compose ps` dentro do contentor demorou mais de 30 s, e ficou registada como `{"event": "error"}` por tempo
    esgotado. O ciclo seguinte já correu bem (`hold` nos três serviços), e as chamadas seguintes demoram ~0,2 s. Ou
    seja, um atraso apenas no primeiro ciclo, recuperado sem intervenção.
- **2026-11-26**: T023, primeira parte (secção 2, passo 3), em Linux, com `video_subtitles=2` e o autoscaler parado.
  - **H-10 confirmada**: com uma legendagem do vídeo de 177 s em curso na réplica 2, `docker stop` às 01:03:20. A
    réplica deixou logo de consumir (a fila passou a ter só o consumidor da réplica 1). O vídeo terminou na própria
    réplica 2 e o resultado chegou ao utilizador às 01:09:36. A réplica saiu com código 0, sem ser morta pelo Docker. A
    mensagem aparece uma só vez nos registos e a fila tem 0 reentregas: 0 vídeos recomeçados.
  - **Observação (não reproduzida)**: depois de entregar o vídeo, a réplica ficou ~6,5 min ligada antes de sair. O
    `docker stop` demorou 767 s, abaixo dos 15 min do `stop_grace_period`. Nesse intervalo, o processo estava no ciclo
    de rede do `pika`, já sem consumidor no broker. Repetimos o cenário à parte, numa fila própria e com o worker real:
    um estágio falso de 5 s e de 150 s, o modelo Whisper descarregado no próprio processo, e a legendagem real do
    vídeo de 177 s (com e sem publicação real do progresso e da resposta). Em todos os casos o processo saiu menos de
    1 s depois da resposta. Causa não identificada. Impacto se se repetir: uma redução de réplicas demora mais, sem
    perder nem repetir trabalho; o pior caso é o Docker matar a réplica no fim do `stop_grace_period`, já depois do
    `ack`. A medição final (T027) e o M4 mostram se volta a acontecer.
- **2026-11-26**: T023, segunda parte: paragem durante uma redução feita pelo `video_autoscaler`. Uma legendagem do
  vídeo de 177 s começou na réplica 2 às 01:33:25. Ligámos a réplica 1 e o autoscaler, este com o máximo de 1 réplica
  de legendagem (T003). Às 01:34:35, passado o `COOLDOWN_SECONDS` (60 s), registou
  `{"service": "video_subtitles", "pending": 1, "current": 2, "target": 1, "action": "down"}`. O Compose escolheu
  remover a réplica 2, a que estava ocupada. Esta acabou o vídeo e saiu às 01:36:38, no mesmo segundo em que o
  resultado chegou ao utilizador (`status=success`). A réplica 1 não recebeu a mensagem, a fila tem 0 reentregas e o
  autoscaler não registou erros: 0 vídeos recomeçados. Desta vez a réplica saiu logo, sem o atraso da primeira parte.

Resultados em `docs/fase2/medicoes/resultados/apos-rnf1/`. O ganho do RNF1 é a diferença entre `apos-rnf2` e
`apos-rnf1`. Hipóteses H-01 a H-05 e H-10 atualizam o Exercício 6, Bloco 1; desvios face à DA-1 vão para o relatório
(cap. 8).
