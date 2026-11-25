# Pesquisa (fase 0): RNF1 — Capacidade e elasticidade do processamento de vídeo

Decisões técnicas que a DA-1 e a TAT-13 deixam em aberto, resolvidas a partir do código (base `0523102` e estrutura do
RNF2). Cada uma indica a decisão, a razão e as alternativas.

## R1. Como o `video_autoscaler` muda o número de réplicas

- **Decisão**: o `video_autoscaler` corre num contentor com o cliente Docker e o *plugin* Compose, o *socket* do Docker
  montado e o `docker-compose.yaml` montado só para leitura, e ajusta cada serviço com
  `docker compose -p <projeto> up -d --no-build --no-recreate --scale <serviço>=<N> <serviço>`.
- **Razão**: é a forma suportada pelo Compose de mudar réplicas, mantém a configuração de cada réplica igual à do
  `docker-compose.yaml` e não obriga a reconstruir contentores à mão pela API do Docker.
- **Alternativas**: criar e remover contentores diretamente pela API do Docker (copiar a configuração do serviço à mão,
  mais código e mais erros); Docker Swarm ou Kubernetes (outra plataforma, rejeitado na constituição); arrancar sempre
  o máximo e só pausar o consumo (não liberta memória, que é o recurso limitado, EV-18).
- **Cuidado 1**: o nome do projeto Compose tem de ser o mesmo do arranque (`picturas`), senão o `video_autoscaler` cria
  um segundo conjunto de serviços.
- **Cuidado 2**: ao retirar réplicas, o comando fica à espera da paragem ordenada (R4), que pode durar minutos numa
  legendagem. O `video_autoscaler` corre o comando de cada serviço em segundo plano (no máximo um em curso por
  serviço) e continua a consultar as filas, para não atrasar o ajuste dos outros serviços (M4).
- **Cuidado 3**: dentro do contentor, o Compose resolve os caminhos relativos do `docker-compose.yaml` a partir do
  sítio onde está montado. Os serviços de vídeo só usam volumes com nome (`image_data`, `whisper_models`), o que evita
  o problema; isto tem de se manter, ou então o repositório é montado no mesmo caminho absoluto do anfitrião e o
  comando usa `--project-directory` com esse caminho.

## R2. Como se lê o tamanho de cada fila

- **Decisão**: `GET /api/queues/%2F/<fila>` na API de gestão do RabbitMQ (já ativa: `rabbitmq:4.0.5-management`,
  porta 15672), usando `messages_ready + messages_unacknowledged` como trabalho pendente.
- **Razão**: dá o trabalho à espera e o que está a ser processado, sem consumir mensagens.
- **Alternativas**: `queue_declare(passive=True)` pelo AMQP (só dá as mensagens prontas, não as que estão a ser
  processadas).

## R3. Política de réplicas

- **Decisão**: para cada serviço, `alvo = limitar(teto(pendentes / limiar_por_réplica), mínimo, máximo)`. Sobe logo; só
  desce depois de o alvo ficar abaixo do número atual durante o período de espera. Consulta a intervalos fixos.
- **Razão**: subir depressa favorece o M6 e o M4; descer devagar evita oscilar (história 2, cenário 3) e reduz as
  paragens ordenadas (TAT-13).
- **Parâmetros**: configuráveis por variáveis de ambiente do `video_autoscaler`. **[PROPOSTA]** a decidir pela equipa
  antes de medir `apos-rnf1` (constituição, princípio IV): edição 1–4, legendagem 1–2 (cada réplica pode chegar a
  2 506 MiB, EV-18; 7,7 GiB para o Docker), extração 1–2; limiar de 1 mensagem pendente por réplica; consulta a cada 5 s;
  espera de 30 s antes de descer. **Decidido em T003 (2026-11-25):** como proposto, exceto legendagem 1–1 e espera de
  60 s (ver `docs/fase2/T003-decisao-equipa.md`).
- **Alternativas**: ajustar pela utilização de CPU (mede mal o trabalho à espera de trabalhos longos e não é o estímulo
  do QS-03).

## R4. Paragem ordenada (TAT-13, H-10)

- **Decisão**: o *worker* (`Tools/video_common/worker.py`) trata o `SIGTERM`: cancela o consumo (`basic_cancel`), deixa
  terminar o estágio em curso, confirma-o, fecha a ligação e sai. Sem estágio em curso, sai de imediato. No
  `docker-compose.yaml`, `stop_grace_period` de cada serviço de vídeo maior do que o seu estágio mais longo.
- **Razão**: o Compose, ao reduzir réplicas, para contentores com `SIGTERM` e espera o `stop_grace_period`; com este
  tratamento, o vídeo em curso termina na mesma réplica em vez de recomeçar noutra.
- **Alternativa**: o `video_autoscaler` escolher só réplicas sem trabalho (o Compose não deixa escolher qual réplica para).

## R5. *Heartbeat* ativo com processamento longo (TAT-13, EV-33, EV-34)

- **Decisão**: o processamento de cada estágio corre numa *thread* de trabalho; a *thread* da ligação continua no ciclo do
  `pika` (que responde aos *heartbeats*), e o `ack`, as respostas e o progresso são publicados através de
  `connection.add_callback_threadsafe`. O `heartbeat` volta ao valor por omissão do broker (deixa de ser 0).
- **Razão**: é a alternativa que o PL1-G4 adiou na DA-08 (EV-34); com ela, o broker deteta uma réplica bloqueada e
  entrega a mensagem a outra.
- **Alternativa**: manter `heartbeat=0` e confiar no `consumer_timeout` (deteta só ao fim de 30 min; slide 18: o
  *timeout* deteta mas não recupera a tempo).

## R6. `consumer_timeout` (H-04)

- **Facto**: o `projects` limita os vídeos Premium a 600 s (`projects/utils/video.js:42-43`, EV-35). Pelo M1, uma
  legendagem de 177 s de vídeo demora ~300 s (EV-18); um vídeo de 600 s deve ficar perto de 17 min, abaixo dos 30 min do
  `consumer_timeout` por omissão. A H-04 é, por isso, pouco provável com a configuração atual.
- **Decisão**: medir a legendagem do vídeo Premium mais longo permitido (600 s), também com várias legendagens em
  paralelo (as réplicas disputam CPU e o tempo cresce), e fixar `consumer_timeout` em `rabbitMQ/rabbitmq.conf` acima
  da duração medida, com margem (e.g., o dobro). Se a margem já existir com o valor por omissão, regista-se e mantém-se.
- **Razão**: o `consumer_timeout` conta o tempo de uma mensagem sem `ack`, mesmo com *heartbeat* ativo; tem de ficar
  acima do pior caso **medido**, não de um valor inventado.

## R7. Ficheiros temporários e pré-visualizações com várias réplicas (H-02)

- **Decisão**: confirmar que todos os temporários têm nomes únicos. Na base, `tempfile.TemporaryDirectory` e os nomes
  com `uuid` já são únicos; os caminhos dos estágios do RNF2 são únicos por *token*, vídeo e índice; o único nome
  derivado é `<saída>.part.mp4`. Risco: duas pré-visualizações do mesmo vídeo em simultâneo escrevem na mesma saída.
  Tornar o `.part` único (sufixo `uuid`) mantendo o `os.replace` final.
- **Razão**: na base nunca havia dois estágios ao mesmo tempo; com réplicas pode haver.

## R8. Carregamento do modelo Whisper com várias réplicas (H-03)

- **Decisão**: proteger a primeira carga de `speech_model()` (`Tools/video_subtitles/subtitles.py`) com um *lock* de
  ficheiro no `WHISPER_CACHE_DIR` (`fcntl.flock`), para que só uma réplica descarregue o modelo de cada vez.
- **Alternativa**: incluir o modelo na imagem (aumenta a imagem da legendagem em ~0,5 GB e piora o N3).

## R9. Limites de memória

- **Decisão**: `deploy.resources.limits.memory` em cada serviço de vídeo, compatível com o máximo de réplicas e com os
  7,7 GiB do Docker na máquina de medição. **[PROPOSTA]**: legendagem 2,75 GiB por réplica (máximo medido 2 506 MiB,
  EV-18), edição e extração conforme a medição `apos-rnf2` (`docker stats`). **Decidido em T003 (2026-11-25)**, com os
  máximos da `apos-rnf2` + ~10 %: edição 2,1 GiB (1 888 MiB medidos), legendagem 1,6 GiB (1 451 MiB medidos; os
  2 506 MiB eram do serviço único da base), extração 512 MiB (não usada nos cenários; a confirmar).

## R10. Medição do M4

- **Decisão**: o `video_autoscaler` regista eventos com data e hora (limiar ultrapassado, comando de escala, réplicas
  pedidas); cada *worker* regista a hora da primeira mensagem consumida. Um *script* novo,
  `docs/fase2/medicoes/elasticidade_m4.py`, lança o cenário `paralelo` com as réplicas no mínimo, junta os registos e
  calcula o tempo até haver réplicas novas a consumir e até voltarem ao mínimo, com 5 repetições (p50 e máximo).
