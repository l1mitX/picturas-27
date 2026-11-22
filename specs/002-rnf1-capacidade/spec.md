# Especificação: RNF1 — Capacidade e elasticidade do processamento de vídeo

**Pasta da feature**: `specs/002-rnf1-capacidade` (sem ramo próprio; trabalho no ramo `fase2`)

**Criada**: 2026-11-22

**Estado**: Rascunho para revisão da equipa

**Entrada**: CAND-1 (Exercício 6, Bloco 2, secção 5) e DA-1 (Exercício 7, secção 3), com as táticas TAT-01, TAT-02 e
TAT-13. Depende do RNF2 (`specs/001-rnf2-modularidade`): parte dos três serviços de vídeo e das suas filas. Esta *spec*
cita os IDs; o texto de referência está em `docs/fase2/exercicios/`. Se esta *spec* e a DA-1 divergirem, prevalece a
DA-1 (constituição, princípio III).

> Nota sobre o modelo: como na *spec* do RNF2, os «requisitos funcionais» do modelo estão escritos como **invariantes**
> e **requisitos estruturais**, porque a Fase 2 é só *refactoring* (constituição, princípio I).

## Cenários e testes *(obrigatório)*

### História 1 — Vários pedidos curtos processados em paralelo (Prioridade: P1)

Quatro utilizadores aplicam, ao mesmo tempo, um efeito de brilho a vídeos de 10 s (cenário QS-03). Na base, o único
*worker* trata-os um a um: p95 de 44,0 s por trabalho, contra 17,8 s de um trabalho sozinho (EV-26).

**Porquê esta prioridade**: é o cenário principal do CAND-1 (escala M6) e o que o REQ-VID-EDIT-011 pede (≥ 2 vídeos em
paralelo no MVP).

**Teste independente**: `carga_rnf1.py apos-rnf1 paralelo` (4 edições simultâneas, 5 repetições), comparado com
`apos-rnf2`.

**Cenários de aceitação**:

1. **Dado** o sistema após o RNF1 e a fila de edição vazia, **quando** chegam 4 edições curtas ao mesmo tempo, **então**
   pelo menos 2 são processadas em simultâneo e o p95 por trabalho desce face ao momento `apos-rnf2`.
2. **Dado** várias réplicas do serviço de edição, **quando** processam trabalhos do mesmo projeto, **então** não há
   colisões de ficheiros e os resultados são iguais aos de uma só réplica (H-01, H-02).

---

### História 2 — A capacidade acompanha a carga (Prioridade: P2)

Quando a fila de um serviço de vídeo cresce, o sistema acrescenta réplicas; quando esvazia, volta ao mínimo, sem
intervenção de ninguém (elasticidade, M4).

**Porquê esta prioridade**: sem ajuste automático, as réplicas seriam fixas (TAT-01 sozinha, rejeitada na DA-1):
gastariam memória sem trabalho (até 2 506 MiB por réplica de legendagem, EV-18) e não chegariam em pico.

**Teste independente**: medição do M4 (tempo até acrescentar réplicas e até as retirar) no momento `apos-rnf1`.

**Cenários de aceitação**:

1. **Dado** um serviço no número mínimo de réplicas, **quando** a sua fila passa o limiar, **então** são acrescentadas
   réplicas até ao máximo configurado, e o tempo até a réplica nova consumir a primeira mensagem é medido (M4).
2. **Dado** um serviço com réplicas extra e a fila vazia durante o período de espera configurado, **quando** o ajuste
   corre, **então** as réplicas extra são retiradas até ao mínimo.
3. **Dado** o ajuste automático, **quando** a carga oscila perto do limiar, **então** o número de réplicas não oscila a
   cada consulta (há um período de espera antes de retirar).

---

### História 3 — Réplicas entram e saem sem perder nem repetir trabalho (Prioridade: P3)

As réplicas que aparecem e desaparecem não podem interromper um vídeo a meio nem ficar presas sem que ninguém dê por
isso (TAT-13; H-10, EV-33, EV-34). É a tática de disponibilidade que a tática de desempenho exige (Ex. 7, secção 5.2).

**Porquê esta prioridade**: sem ela, retirar réplicas obriga a recomeçar vídeos e pode piorar o M6 em vez de o melhorar.

**Teste independente**: testes de paragem ordenada, de bloqueio de uma réplica e de cancelamento com várias réplicas.

**Cenários de aceitação**:

1. **Dado** uma réplica a meio de um vídeo, **quando** é mandada parar (pelo ajuste ou por `docker stop`), **então**
   deixa de aceitar mensagens novas, termina o vídeo em curso, confirma-o e só depois sai; o vídeo não recomeça noutra
   réplica (H-10).
2. **Dado** uma réplica bloqueada sem morrer (`docker pause`), **quando** passa o intervalo de *heartbeat*, **então** o
   broker fecha a ligação e a mensagem é entregue a outra réplica, em vez de ficar presa até ao `consumer_timeout`
   (EV-33, EV-34).
3. **Dado** um pipeline em curso com várias réplicas ativas, **quando** o utilizador cancela, **então** nada é registado,
   como na base (H-05).
4. **Dado** a legendagem do vídeo Premium mais longo permitido (600 s, EV-35), **quando** é processada, **então** termina
   sem ser reentregue, com o `consumer_timeout` acima da sua duração medida (H-04).

### Casos-limite

- Duas réplicas de legendagem a arrancar ao mesmo tempo com o volume `whisper_models` vazio (H-03).
- Pedido de paragem enquanto a réplica ainda não recebeu nenhuma mensagem (sai de imediato).
- Mensagens a chegar durante a paragem ordenada de uma réplica (vão para outra réplica).
- O ajuste perde a ligação à API de gestão do RabbitMQ ou à API do Docker (não altera réplicas; tenta de novo).
- Memória da máquina perto do limite com o máximo de réplicas (limites de memória por serviço).
- Pré-visualizações e trabalhos finais na mesma fila (continuam a competir, como na base).

## Requisitos *(obrigatório)*

### Invariantes (o que tem de ficar igual)

- **INV-001**: As saídas de imagem e de vídeo são idênticas às da base (`regressao_hashes.py`), com uma ou várias réplicas.
- **INV-002**: O contrato das mensagens e os códigos de erro 2000–2005 mantêm-se; o `ack` continua manual e só no fim
  do processamento de cada estágio (EV-10).
- **INV-003**: O `projects` continua a ser o único dono do cancelamento, da quota e do registo dos resultados (EV-06).
- **INV-004**: A interface do utilizador, as interfaces HTTP e as regras de negócio não mudam; o utilizador só nota
  tempos de espera menores.
- **INV-005**: Os testes do RNF2 e os existentes continuam a passar.

### Requisitos estruturais (o que muda)

- **RE-001** (TAT-01): Cada serviço de vídeo (edição, legendagem, extração) pode correr com várias réplicas a consumir
  a mesma fila (*Competing Consumers*), com `prefetch_count=1` e sem `container_name`.
- **RE-002** (TAT-02): Um serviço novo, `video_autoscaler`, consulta periodicamente o tamanho de cada fila de vídeo na
  API de gestão do RabbitMQ e ajusta o número de réplicas de cada serviço entre um mínimo e um máximo configurados,
  com um período de espera antes de retirar réplicas.
- **RE-003** (TAT-13): Cada *worker* de vídeo trata o pedido de paragem de forma ordenada: deixa de consumir, termina o
  estágio em curso, confirma-o e sai; o tempo de paragem permitido pelo Docker chega para o estágio mais longo.
- **RE-004** (TAT-13): Cada *worker* de vídeo processa o estágio numa *thread* separada da ligação ao RabbitMQ, com o
  *heartbeat* ativo, e confirma a mensagem a partir da *thread* da ligação.
- **RE-005** (H-04): O `consumer_timeout` do RabbitMQ é configurado acima da duração **medida** da legendagem do vídeo
  Premium mais longo permitido (600 s, EV-35), com margem.
- **RE-006**: Cada serviço de vídeo tem um limite de memória, para que o máximo de réplicas caiba na máquina de medição.
- **RE-007** (H-02, H-03): Os ficheiros temporários têm nomes únicos entre réplicas, e o carregamento do modelo Whisper
  é seguro com várias réplicas a arrancar ao mesmo tempo.
- **RE-008**: Testes novos para H-01, H-02, H-03, H-05 e H-10, para a paragem ordenada e para o *heartbeat* com uma
  réplica bloqueada.

### Entidades principais

- **Política de réplicas** (por serviço de vídeo): mínimo, máximo, limiar de fila por réplica, intervalo de consulta e
  período de espera antes de retirar.
- **Réplica**: uma instância de um serviço de vídeo; estados «a aguardar», «a processar», «a parar» e «parada».

## Critérios de sucesso *(obrigatório)*

Valores da Tabela 18 do relatório. O ganho do RNF1 mede-se entre `apos-rnf2` e `apos-rnf1` (constituição, princípio IV).

### Resultados mensuráveis

- **SC-001** (M6, principal): 4 edições simultâneas com p95 por trabalho ≤ **30 s** (alvo); pelo menos **2** trabalhos
  processados em simultâneo (mínimo, REQ-VID-EDIT-011). Base: 44,0 s.
- **SC-002** (M4): réplicas acrescentadas ≤ **30 s** depois de a fila passar o limiar (alvo); ≤ **60 s** (mínimo); e
  retiradas depois de a fila esvaziar e passar o período de espera.
- **SC-003** (M1, complementar): p95 ≤ **36 s** (alvo); ≤ **50 s** (mínimo, REQ-VID-EDIT-010); não pior do que em `apos-rnf2`.
- **SC-004** (trabalho isolado, efeito colateral): p95 ≤ 17,8 s (alvo); ≤ 19,6 s (mínimo).
- **SC-005** (preservação): *hashes* iguais aos da base; testes existentes, do RNF2 e novos (RE-008) a passar.
- **SC-006** (disponibilidade, TAT-13): 0 vídeos recomeçados ao retirar réplicas e 0 mensagens presas até ao
  `consumer_timeout` nos testes de paragem e de bloqueio.
- **SC-007** (recursos): nenhum contentor morto por falta de memória (`OOMKilled`) nos cenários `paralelo` e `m1` com o
  máximo de réplicas.

## Pressupostos

- O RNF2 está concluído e medido (`apos-rnf2`): três serviços de vídeo com filas próprias.
- A plataforma mantém-se: Docker Compose (Docker Desktop/WSL2 na máquina de medição) e RabbitMQ 4.0.5 com a API de gestão
  (`rabbitmq:4.0.5-management`, porta 15672).
- O `video_autoscaler` precisa de acesso à API do Docker (*socket* montado), o que piora a segurança (Ex. 7, secção 5.1);
  o risco fica limitado a este serviço e está registado.
- Os parâmetros da política de réplicas (mínimo, máximo, limiar, intervalo e espera) são configuração, decidida pela
  equipa antes da medição `apos-rnf1` e não alterada depois de ver os resultados.
