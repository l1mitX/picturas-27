---

description: "Lista de tarefas do RNF1 — capacidade e elasticidade do processamento de vídeo (DA-1, TAT-13)"
---

# Tarefas: RNF1 — Capacidade e elasticidade do processamento de vídeo

**Entrada**: documentos de `specs/002-rnf1-capacidade/` e a constituição v1.0.0. **Pré-requisito**: RNF2 concluído e
medido (`specs/001-rnf2-modularidade`, T044).

**Testes**: incluídos (constituição, princípio II; *spec*, RE-008). Escrevem-se antes da implementação.

**Organização**: por história da *spec* (US1 = P1, US2 = P2, US3 = P3). O núcleo da TAT-13 (paragem ordenada e
*heartbeat*) está nas fundações porque é pré-requisito de qualquer réplica que entre e saia (Ex. 7, secção 5.2); a US3
prova-o com os cenários de falha.

## Formato: `[ID] [P?] [História] Descrição`

- **[P]**: pode correr em paralelo (ficheiros diferentes, sem dependências por concluir)
- **[US1]/[US2]/[US3]**: história a que a tarefa pertence
- Caminhos relativos à raiz do repositório

---

## Fase 1: Preparação

- [X] T001 Confirmar o ponto de partida: RNF2 concluído, testes verdes e `docs/fase2/medicoes/resultados/apos-rnf2/` completo; registar em `specs/002-rnf1-capacidade/quickstart.md` («Registo»)
- [ ] T002 Criar a pasta `Tools/video_autoscaler/tests/`
- [ ] T003 Decidir em equipa os parâmetros da política de réplicas e os limites de memória (`research.md`, R3 e R9, **[PROPOSTA]**) e registá-los em `docs/fase2/medicoes/README.md` antes de qualquer medição `apos-rnf1` (constituição, princípio IV)

---

## Fase 2: Fundações (bloqueia todas as histórias)

**Objetivo**: *workers* que podem entrar e sair sem perder nem repetir trabalho (TAT-13).

### Testes primeiro

- [X] T004 [P] Teste em `Tools/video_common/tests/test_worker.py`: com um estágio a correr numa *thread* de trabalho (função de processamento falsa e lenta), o `SIGTERM` cancela o consumo, deixa terminar o estágio, publica o `ack` e a resposta, e só depois sai; sem estágio em curso, sai de imediato (R4)
- [X] T005 [P] Teste em `Tools/video_common/tests/test_worker.py`: o `ack`, a resposta e o progresso são publicados pela *thread* da ligação (`add_callback_threadsafe`), e a ligação é aberta com *heartbeat* diferente de 0 (R5)

### Implementação

- [X] T006 Em `Tools/video_common/worker.py`: processar cada estágio numa *thread* de trabalho; publicar `ack`, respostas e progresso com `connection.add_callback_threadsafe`; abrir a ligação com o *heartbeat* por omissão do broker em vez de `heartbeat=0` (R5, EV-33, EV-34). T005 passa
- [X] T007 Em `Tools/video_common/worker.py`: tratar o `SIGTERM` com paragem ordenada (`basic_cancel`, terminar o estágio em curso, `ack`, fechar a ligação, sair) e registar a hora da primeira mensagem consumida depois de arrancar (R4, R10). T004 passa
- [X] T008 Correr os testes dos três serviços de vídeo (comandos da T028 do RNF2) e `regressao_hashes.py video dev-rnf1` (etiqueta de desenvolvimento, não a da medição final) → tudo igual (INV-001, INV-005)

**Checkpoint**: *workers* com *heartbeat* ativo e paragem ordenada; comportamento inalterado.

---

## Fase 3: História 1 — Vários pedidos curtos em paralelo (P1) 🎯 MVP

**Objetivo**: réplicas de cada serviço de vídeo a consumir a mesma fila, sem colisões (TAT-01).

**Teste independente**: `carga_rnf1.py apos-rnf1 paralelo` com `--scale video_edit=4` manual → pelo menos 2 trabalhos em
simultâneo e p95 abaixo de `apos-rnf2`.

### Testes primeiro

- [X] T009 [P] [US1] Teste em `Tools/video_edit/tests/`: duas execuções de `_process_video` para a mesma saída em simultâneo não colidem no ficheiro `.part` e terminam com uma saída válida (R7, H-02)
- [X] T010 [P] [US1] Teste em `Tools/video_subtitles/tests/`: duas chamadas concorrentes à primeira carga de `speech_model()` com um diretório de *cache* vazio (modelo falso) fazem uma só descarga (R8, H-03)

### Implementação

- [X] T011 [P] [US1] Em `Tools/video_edit/video_processor.py`, dar ao ficheiro `.part` um nome único (sufixo `uuid`), mantendo o `os.replace` final e a remoção em caso de erro (R7). T009 passa
- [X] T012 [P] [US1] Em `Tools/video_subtitles/subtitles.py`, proteger a primeira carga de `speech_model()` com `fcntl.flock` num ficheiro de *lock* em `WHISPER_CACHE_DIR` (R8). T010 passa
- [ ] T013 [US1] Em `docker-compose.yaml`, confirmar que os três serviços de vídeo não têm `container_name` nem portas fixas que impeçam réplicas, e acrescentar `stop_grace_period` (maior do que o estágio mais longo de cada serviço) e `deploy.resources.limits.memory` com os valores decididos em T003 (R4, R9); confirmar que os serviços de vídeo só usam volumes com nome, sem caminhos relativos (R1, cuidado 3)
- [ ] T014 [US1] Verificar H-01 e H-02 com réplicas manuais (`quickstart.md`, secção 2, passo 1) e H-03 (passo 2); registar o resultado no estado das hipóteses (T030)
- [ ] T015 [US1] Medição exploratória com `--scale video_edit=4` manual e `carga_rnf1.py apos-rnf1-manual paralelo` (pasta separada, não conta como medição final), para confirmar o ganho antes do ajuste automático

**Checkpoint**: réplicas manuais funcionam e melhoram o M6.

---

## Fase 4: História 2 — A capacidade acompanha a carga (P2)

**Objetivo**: o `video_autoscaler` ajusta as réplicas pelo tamanho de cada fila (TAT-02).

**Teste independente**: `elasticidade_m4.py apos-rnf1` → M4 ≤ 30 s (alvo) e regresso ao mínimo depois da espera.

### Testes primeiro

- [ ] T016 [P] [US2] Testes em `Tools/video_autoscaler/tests/test_policy.py` para `target_replicas(pending, current, policy, below_since, now)`: sobe logo até ao máximo; nunca abaixo do mínimo; só desce depois de `cooldown_s` com o alvo abaixo do atual; `per_replica` respeitado (R3, `data-model.md`, «Política de réplicas»: `min ≥ 1`, `max ≥ min`, `per_replica ≥ 1`)

### Implementação

- [ ] T017 [US2] Implementar a política em `Tools/video_autoscaler/policy.py` (função pura, sem Docker nem RabbitMQ). T016 passa
- [ ] T018 [US2] Implementar `Tools/video_autoscaler/autoscaler.py`: ler a configuração das variáveis de ambiente (`contracts/autoscaler-e-workers.md`); a cada `POLL_SECONDS`, ler `messages_ready + messages_unacknowledged` de cada fila (`GET /api/queues/%2F/<fila>`, R2), contar as réplicas atuais, aplicar `policy.py` e, quando muda, correr `docker compose -p $COMPOSE_PROJECT_NAME up -d --no-build --no-recreate --scale <serviço>=<N> <serviço>` (R1); correr o comando de cada serviço em segundo plano, no máximo um em curso por serviço, sem bloquear a consulta das outras filas (R1, cuidado 2); registar cada decisão numa linha JSON (`data-model.md`, «Evento»); em falha da API do RabbitMQ ou do Docker, não mudar nada e tentar de novo
- [ ] T019 [P] [US2] Criar `Tools/video_autoscaler/Dockerfile` (Python 3.11, cliente Docker e *plugin* Compose) e `Tools/video_autoscaler/requirements.txt` (`requests`)
- [ ] T020 [US2] Acrescentar o serviço `video_autoscaler` ao `docker-compose.yaml`: *socket* do Docker e `docker-compose.yaml` montados (este só para leitura; se algum serviço de vídeo vier a ter caminhos relativos, montar o repositório no mesmo caminho absoluto do anfitrião e usar `--project-directory`, R1, cuidado 3), variáveis de ambiente com os parâmetros de T003, `COMPOSE_PROJECT_NAME=picturas`, dependência do `rabbitmq`
- [ ] T021 [US2] Criar `docs/fase2/medicoes/elasticidade_m4.py` (R10): lança o cenário `paralelo` com as réplicas no mínimo, junta os registos do `video_autoscaler` e dos *workers* e calcula o tempo até haver réplicas novas a consumir e até voltarem ao mínimo; 5 repetições; resultado em `resultados/<etiqueta>/elasticidade_m4.json`

**Checkpoint**: as réplicas sobem e descem sozinhas; M4 medível.

---

## Fase 5: História 3 — Réplicas entram e saem sem perder nem repetir trabalho (P3)

**Objetivo**: provar a TAT-13 com os cenários de falha e fechar o risco da H-04.

**Teste independente**: `quickstart.md`, secção 2, passos 3 a 6 → SC-006.

- [ ] T022 [US3] Medir a legendagem do vídeo Premium mais longo permitido (600 s, EV-35), sozinha e com 2 legendagens em paralelo; em `rabbitMQ/rabbitmq.conf`, fixar `consumer_timeout` acima da maior duração medida, com margem (e.g., o dobro), ou registar que o valor por omissão (30 min) já tem essa margem (R6, H-04)
- [ ] T023 [US3] Verificar a H-10 (`docker stop` de uma réplica a meio de uma legendagem: o vídeo termina nessa réplica) e a paragem durante uma redução feita pelo `video_autoscaler`; contar vídeos recomeçados nos registos (SC-006)
- [ ] T024 [US3] Verificar o bloqueio (`docker pause` de uma réplica a meio de um estágio: a mensagem passa para outra réplica depois de o broker detetar a falta de *heartbeat* — intervalo por omissão de 60 s, deteção ao fim de ~2 intervalos, ~2 min); contar mensagens presas (SC-006)
- [ ] T025 [US3] Verificar a H-05 (cancelar um pipeline com várias réplicas ativas: nada é registado) e a H-04 (a legendagem de T022 termina sem reentrega)

**Checkpoint**: 0 vídeos recomeçados e 0 mensagens presas; cancelamento correto com réplicas.

---

## Fase final: Acabamento e transversal

- [ ] T026 [P] README curto em `Tools/video_autoscaler/` (o que faz, variáveis, risco do *socket* do Docker)
- [ ] T027 Medição completa `apos-rnf1` (`quickstart.md`, secção 3): `carga_rnf1.py` (`paralelo`, `m1`, `isolado`, `m2`), `elasticidade_m4.py`, verificação de `OOMKilled` → `docs/fase2/medicoes/resultados/apos-rnf1/`
- [ ] T028 `regressao_hashes.py imagem` e `video` com o ajuste automático ligado → *hashes* iguais à base (SC-005)
- [ ] T029 Atualizar a vista «depois» (`docs/fase2/relatorio/images/vista_depois.puml`) se a implementação se afastou da DA-1, e regenerar o SVG
- [ ] T030 Atualizar o estado de H-01 a H-05 e H-10 em `docs/fase2/exercicios/RAS-exercicio_6_bloco1_SWdesign_template_PT.md` (secção 2.6) e preencher «Implementação» e «Desvios face à decisão» da DA-1 no relatório (cap. 8)

---

## Dependências e ordem

- **RNF2 concluído → Fase 1 → Fase 2 → histórias.** A T003 (parâmetros) tem de estar feita antes de T013, T020 e de
  qualquer medição `apos-rnf1`.
- **US1** depende da Fase 2. **US2** depende da US1 (réplicas a funcionar) e da Fase 2 (paragem ordenada, para descer
  réplicas sem recomeçar vídeos). **US3** depende da US2 (T023 usa o `video_autoscaler`).
- **Acabamento**: T027 e T028 só com tudo verde; T030 no fim.

## Paralelismo

- Fase 2: T004 ∥ T005.
- US1: T009 ∥ T010; T011 ∥ T012.
- US2: T016 e T019 em paralelo; T017 → T018 → T020.
- Pode correr em paralelo com o fim do RNF2: T002, T016, T017, T019 (não dependem dos serviços novos).

## Estratégia

1. **MVP (US1)**: Fundações e réplicas manuais → o M6 já melhora sem ajuste automático.
2. **US2**: ajuste automático → elasticidade (M4) sem gastar memória sem carga.
3. **US3**: cenários de falha → disponibilidade provada (SC-006).
4. **Medição `apos-rnf1`** e atualização das hipóteses e da DA-1.
