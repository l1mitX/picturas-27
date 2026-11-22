# Especificação: RNF2 — Modularidade do processamento de vídeo

**Pasta da feature**: `specs/001-rnf2-modularidade` (sem ramo próprio; trabalho no ramo `fase2`)

**Criada**: 2026-11-22

**Estado**: Rascunho para revisão da equipa

**Entrada**: CAND-2 (Exercício 6, Bloco 2, secção 5) e DA-2 (Exercício 7, secção 3), com as táticas TAT-07, TAT-08 e
TAT-09. Esta *spec* cita os IDs; o texto de referência está em `docs/fase2/exercicios/`. Se esta *spec* e a DA-2
divergirem, prevalece a DA-2 (constituição, princípio III).

> Nota sobre o modelo: como a Fase 2 é só *refactoring* (constituição, princípio I), os «requisitos funcionais» do
> modelo do Spec Kit estão escritos como **invariantes** (o que tem de ficar igual) e **requisitos estruturais** (o
> que muda na arquitetura). As «histórias de utilizador» são as dos *stakeholders* dos cenários: a equipa que mantém o
> código (QS-02, QS-04) e o utilizador final, que não pode notar diferença.

## Cenários e testes *(obrigatório)*

### História 1 — Atualizar o motor de legendagem sem tocar no resto (Prioridade: P1)

Um programador atualiza a versão do `faster-whisper` ou o modelo de legendas (cenário QS-02, cenário de mudança C2).
Hoje isso reconstrói a imagem única de 1,69 GB e reimplanta os três tipos de trabalho de vídeo (EV-14, EV-17).

**Porquê esta prioridade**: é o cenário principal do CAND-2 (escala N2) e a condição para a DA-1 poder escalar cada
tipo de trabalho em separado (pré-requisito, Ex. 7, secção 5.2).

**Teste independente**: correr `rnf2_estaticas.py` no momento `apos-rnf2` e verificar o N2 do cenário C2.

**Cenários de aceitação**:

1. **Dado** o código após o RNF2, **quando** se altera a versão do `faster-whisper` em `requirements`, **então** só a
   imagem do serviço de legendagem é reconstruída e só esse tipo de trabalho é reimplantado.
2. **Dado** o código após o RNF2, **quando** se constrói a imagem do serviço de edição, **então** ela não contém o
   `faster-whisper` nem as fontes das legendas.

---

### História 2 — Alterar um efeito num único sítio, para imagem e vídeo (Prioridade: P2)

Um programador altera o filtro de brilho, de forma igual para imagem e vídeo (cenário QS-04, cenário de mudança C1).
Hoje os 8 efeitos estão implementados duas vezes (EV-12), uma duplicação que o PL1-G4 deixou para a Fase 2 (EV-32).

**Porquê esta prioridade**: cenário complementar do CAND-2 (escala N1); mexe também nas ferramentas de imagem, por
isso tem mais risco de regressão.

**Teste independente**: `rnf2_estaticas.py` (N1 e N2 do cenário C1) e `regressao_hashes.py` (imagem e vídeo).

**Cenários de aceitação**:

1. **Dado** o código após o RNF2, **quando** se procura uma segunda implementação de qualquer dos 8 efeitos, **então**
   não existe nenhuma (N1 = 0).
2. **Dado** o código após o RNF2, **quando** se altera o ficheiro do efeito de brilho, **então** só são reconstruídos o
   `brightness_tool` e o serviço de edição de vídeo (EV-28).
3. **Dado** as mesmas entradas da base, **quando** se aplicam os efeitos a imagens e vídeos, **então** os *hashes* são
   iguais aos de `resultados/base/` (H-07).

---

### História 3 — O utilizador não nota diferença, exceto esperar menos atrás de uma legendagem (Prioridade: P3)

Um utilizador edita, legenda, extrai fotogramas, pré-visualiza e cancela trabalhos de vídeo como na base. Como a
legendagem passa a ter a sua fila, uma edição curta deixa de esperar por ela (QS-01, efeito sobretudo do CAND-2).

**Porquê esta prioridade**: é a preservação funcional exigida pela constituição (princípio II); o ganho no M1 é um
efeito positivo, não o objetivo do CAND-2.

**Teste independente**: testes existentes e novos (secção «Requisitos»), `regressao_hashes.py` e `carga_rnf1.py` nos
cenários `isolado` e `m1`, no momento `apos-rnf2`.

**Cenários de aceitação**:

1. **Dado** um projeto com vídeos, **quando** o utilizador aplica qualquer combinação de ferramentas suportada na base,
   **então** obtém os mesmos ficheiros, mensagens de progresso e erros que na base.
2. **Dado** uma legendagem em curso, **quando** outro utilizador aplica um efeito curto, **então** este não espera pelo
   fim da legendagem (M1).
3. **Dado** um pipeline a meio (legendas + filtro + extração), **quando** o utilizador cancela, **então** nenhum
   resultado é registado e a quota é tratada como na base (H-08).

### Casos-limite

- Pipeline só com legendas; só com extração; edição + extração (a extração tem de ser sempre o último passo, EV-13;
  o progresso mantém a divisão 70/30).
- Legendas no meio de efeitos (hoje partidas em estágios com um MP4 intermédio cada, EV-15): a divisão em serviços tem
  de cortar nos mesmos pontos, sem codificações a mais (H-06).
- Pré-visualização de cada combinação, incluindo a folha de contactos da extração (EV-16).
- Erro num estágio intermédio: o erro chega ao utilizador com os mesmos códigos (2000–2005) e o pipeline não continua.
- Mensagem inválida ou `procedure` desconhecida num dos serviços novos.
- Cancelamento entre dois estágios (a mensagem do estágio seguinte já pode estar na fila).

## Requisitos *(obrigatório)*

### Invariantes (o que tem de ficar igual)

- **INV-001**: Para as mesmas entradas e ferramentas, as saídas de imagem e de vídeo são idênticas às da base
  (`regressao_hashes.py`, REQ-VID-EDIT-009).
- **INV-002**: O contrato das mensagens (`messageId`, `timestamp`, `procedure`, `parameters`) e os códigos de erro
  2000–2005 mantêm-se; as respostas continuam a chegar ao `projects` pela `project_queue` e o progresso pela
  `ws_queue`.
- **INV-003**: O `projects` continua a ser o único dono do cancelamento (`activeToken`), da quota e do registo dos
  resultados (EV-06).
- **INV-004**: As regras sem requisito explícito mantêm-se: extração sempre no fim (EV-13); pré-visualização só dos
  primeiros segundos; resultado de uma execução cancelada não é registado.
- **INV-005**: As interfaces HTTP (`/process`, `/preview`, `/tool`, carregamentos) e a interface do utilizador não mudam.
- **INV-006**: Os testes existentes (`projects/tests`, `Tools/video/tests`) continuam a passar, adaptados aos novos
  serviços sem perder casos.

### Requisitos estruturais (o que muda)

- **RE-001** (TAT-07): O processamento de vídeo divide-se em três serviços — edição (efeitos por fotograma, corte,
  velocidade), legendagem e extração de fotogramas —, cada um com o seu Dockerfile e a sua fila.
- **RE-002** (TAT-07): Só a imagem do serviço de legendagem inclui o `faster-whisper` e as fontes das legendas.
- **RE-003** (TAT-09): O `projects` divide a lista de ferramentas de cada vídeo em estágios, nos mesmos pontos em que
  `process_video` a divide hoje (EV-15), e envia cada estágio para a fila do serviço respetivo; os serviços de vídeo
  não comunicam entre si. A pré-visualização segue o mesmo encadeamento, com `preview: true`.
- **RE-004** (TAT-08): Os 8 efeitos passam para `Tools/effects/`, um ficheiro por efeito, fora de `Tools/utils`;
  cada ferramenta de imagem copia e usa só o seu ficheiro, e o serviço de edição de vídeo copia e usa os oito.
- **RE-005**: As filas novas são declaradas como as existentes (`rabbitMQ/definitions.json`) e mapeadas em
  `projects/utils/project_msg.js`.
- **RE-006**: Testes novos: encadeamento dos estágios (cada combinação de ferramentas), pré-visualização por estágios
  e cancelamento a meio de um pipeline repartido (H-08).

### Entidades principais

- **Trabalho de vídeo**: um vídeo com a sua lista ordenada de ferramentas, criado no *Apply* (como na base).
- **Estágio**: parte contígua da lista de ferramentas que um único serviço de vídeo executa de uma vez, com uma
  descodificação e uma codificação.
- **Módulo de efeitos**: um ficheiro por efeito em `Tools/effects/`, usado pelas ferramentas de imagem e pelo serviço
  de edição de vídeo.

## Critérios de sucesso *(obrigatório)*

Valores da Tabela 18 do relatório, medidos no momento `apos-rnf2` e comparados com `base` (constituição, princípio IV).

### Resultados mensuráveis

- **SC-001** (N2, cenário C2, principal): alterar o `faster-whisper` reimplanta **1** tipo de trabalho de vídeo (base: 3).
  Alvo e mínimo: 1.
- **SC-002** (N2, cenários C1 e C3): mudar o brilho reconstrói 2 serviços (`brightness_tool` e edição de vídeo) e
  reimplanta 1 tipo de trabalho de vídeo; mudar a extração reimplanta só a extração (base: 3 tipos em ambos).
- **SC-003** (N1): **0** efeitos com duas implementações (base: 8).
- **SC-004** (N3): imagem do serviço de edição ≤ **1,23 GB** (alvo); menor que a imagem atual do vídeo construída no
  mesmo dia (mínimo). Base: 1,69 GB.
- **SC-005** (N4, efeito colateral, H-09): orquestrador com ≤ 2733 + 10 % linhas.
- **SC-006** (N5, efeito colateral, H-06): trabalho isolado p95 ≤ 17,8 s (alvo, não piorar); ≤ 19,6 s (mínimo).
- **SC-007** (preservação): `regressao_hashes.py` com *hashes* iguais aos da base; todos os testes a passar.
- **SC-008** (M1, complementar do CAND-1, observado): registar o M1 em `apos-rnf2`; o ganho face à base atribui-se ao
  RNF2 (relatório, secção 6.2).

## Pressupostos

- A plataforma mantém-se: Docker Compose, RabbitMQ 4.0.5, *workers* Python com `pika` (constituição, restrições).
- Nesta *spec* cada serviço de vídeo tem **uma** instância; as réplicas e o ajuste automático são o RNF1
  (`specs/002-rnf1-capacidade`, DA-1).
- As medições usam os *scripts* e as amostras de `docs/fase2/medicoes/`, sem alterar os parâmetros; se os pontos de
  entrada mudarem de nome, só se adaptam as funções de chamada dos *scripts* (ver o cabeçalho de `regressao_hashes.py`).
- Os nomes dos serviços (`video_edit`, `video_subtitles`, `video_frames`) e das filas são os da DA-2; podem mudar na
  implementação, registando o desvio.
