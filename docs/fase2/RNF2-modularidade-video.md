# RNF 2 — Modularidade do processamento de vídeo

| | |
|---|---|
| **Requisitos de origem** | REQ-VID-EDIT-013 (PL1-G4, Tabela 30): acrescentar um efeito de vídeo sem alterar os existentes · REQ-VID-EDIT-014: componentes isolados |
| **ISO/IEC 25010** | Manutenibilidade › Modularidade (e Modificabilidade, Reutilização) |
| **Estado na base (PL1-G4 §7.3)** | EDIT-013 "Implementado", mas só demonstrado para `trim` e `speed`; as legendas e a extração de fotogramas foram acrescentadas depois pelos docentes, no mesmo serviço |
| **Ideia dos docentes** | Diretrizes da Fase 2: "Dividir o processamento de vídeo em vários microserviços, à semelhança do que já acontece com as ferramentas de imagem" |
| **Commit de partida** | `0523102` |
| **Relação com o RNF1** | Este RNF faz-se **primeiro** e é pré-requisito do RNF1 (`RNF1-EDIT-011.md`): o RNF1 escala cada serviço criado aqui. Cada um é medido por si (ver 2.4) |
| **Estado deste documento** | Plano. Base medida (2026-11-18); alvos e mínimos fixados a 2026-11-22 (relatório, Tabela 18); medições após o refactoring por fazer |

> **Legenda:** as partes marcadas com **[PROPOSTA]** foram sugeridas no rascunho assistido por IA e não têm
> fonte nos enunciados, nas notas da equipa ou no relatório do PL1-G4. Têm de ser validadas pela equipa;
> depois de validadas, retirar a marca e registar a decisão na secção 6.

---

## 1. Diagnóstico

### 1.1 Fragilidade

Todo o processamento de vídeo vive num único serviço, `video_tool`: edição (filtros por fotograma, corte,
velocidade), legendagem automática (Faster-Whisper) e extração de fotogramas. As três partes têm dependências,
recursos e ritmos de mudança muito diferentes, mas são construídas, implantadas e escaladas como uma só. Além
disso, os filtros de vídeo são uma **cópia** dos filtros das ferramentas de imagem, mantida à mão.

### 1.2 Evidência (commit `0523102`)

| ID | Onde | O que mostra |
|---|---|---|
| E1 | `docker-compose.yaml:256-273` | Um único serviço `video_tool` para todos os trabalhos de vídeo |
| E2 | `Tools/video/` | 807 linhas de Python num só serviço: `video_processor.py` (369), `video.py` (180), `frame_extraction.py` (97), `subtitles.py` (82), `effects.py` (79) |
| E3 | `Tools/video/effects.py:1-6` | O próprio ficheiro diz que cada função "mirrors exactly the PIL operation of the matching image microservice (`Tools/<tool>/<tool>.py`)": 8 efeitos duplicados (e.g., `brightness` = `Tools/brightness/brightness.py:38-39`) |
| E4 | `Tools/video/video_processor.py:286-369` | `process_video` decide tudo: extração no fim, divisão do pipeline em estágios à volta das legendas, regra da pré-visualização. Mudar uma destas partes obriga a mexer na função que serve todas |
| E5 | `Tools/video/requirements.txt`, `Tools/video/Dockerfile` | A imagem única inclui `faster-whisper` e as fontes CJK das legendas; um trabalho de edição simples arranca num contentor com tudo isso |
| E6 | `projects/utils/video.js:16-25` | O orquestrador conhece as listas de ferramentas de vídeo (`VIDEO_TOOLS`, `VIDEO_ONLY_TOOLS`, `PER_VIDEO_TOOLS`), mas envia tudo para um só destino (`project_msg.js:21`) |
| E7 | `Tools/video/video_processor.py:321-366` | Com legendas, o pipeline **já** é executado em estágios separados, com um MP4 intermédio por estágio (`stage-N.mp4`) |

### 1.3 Impacto nos stakeholders

> **[PROPOSTA]** Escrito a partir da evidência acima e das diretrizes, não de medições.

- **Equipa de desenvolvimento:** corrigir um filtro implica mudá-lo em dois sítios (imagem e vídeo) e reconstruir
  e reimplantar também a legendagem. Atualizar o Whisper obriga a reimplantar a edição de vídeo.
- **Operação:** não se pode dar recursos diferentes à legendagem (CPU intensiva, modelo em memória) e à edição.
  É também o que impede o RNF1 de escalar cada tipo de trabalho à sua carga.
- **Utilizador:** risco de os efeitos de imagem e de vídeo divergirem com o tempo (a cópia manual de E3).

### 1.4 Hipóteses a confirmar

| ID | Hipótese | Como confirmar |
|---|---|---|
| H6 | Partir o pipeline nos limites dos estágios atuais (E7) não acrescenta recodificações face à base | Contar codificações por cenário antes/depois (logs do ffmpeg) |
| H7 | Os efeitos partilhados entre imagem e vídeo dão o mesmo resultado que hoje | *Hash* de fotogramas e de imagens antes/depois (REQ-VID-EDIT-009) |
| H8 | O cancelamento (`activeToken`/`cancelToken`) e a devolução de quota funcionam com um pipeline que passa por vários serviços | Teste: cancelar a meio de um pipeline legendas + filtro + extração |
| H9 | A divisão faz crescer o orquestrador (`projects/routes/projects.js`, 2732 linhas) | Medir N4 no `projects` antes/depois |

---

## 2. Quantificação

> Formato das diretrizes da Fase 2 ("O que se espera para cada requisito não funcional", ponto 2): escala, método
> de medição, valor medido na base, valor-alvo e valor mínimo aceitável, com origem identificável. O alvo e o
> mínimo fixam-se depois da medição inicial.

### 2.1 Requisito

| Campo | RNF2 |
|---|---|
| **Requisito** | Manutenibilidade › Modularidade (ISO/IEC 25010): dividir o processamento de vídeo em serviços independentes (REQ-VID-EDIT-013 e EDIT-014, PL1-G4; ideia das diretrizes) |
| **Escala** | Nº de tipos de trabalho de vídeo (edição, legendagem, extração de fotogramas) que têm de ser reconstruídos e reimplantados para atualizar a legendagem (cenário C2) |
| **Método** | `docs/fase2/medicoes/rnf2_estaticas.py` (N2, cenário C2): encontra os ficheiros a alterar pelo conteúdo e os serviços a reconstruir pelos Dockerfiles do `docker-compose.yaml` |
| **Valor na base** | **3** (os 3 tipos de trabalho estão no mesmo serviço `video_tool`), medido a 2026-11-18 |
| **Valor-alvo** | C2 reimplanta 1 tipo de trabalho (só a legendagem) — ver 2.4 |
| **Mínimo aceitável** | C2 reimplanta 1 tipo de trabalho (sem isto o QS-02 não é cumprido) — ver 2.4 |
| **Medições complementares** | N1 (efeitos com duas implementações; base 8), N2 C1 e C3, N3, N4, e N5 (desempenho não pode piorar) — ver 2.2 e 2.4 |

### 2.2 Métricas

> Origem: as notas da equipa já indicavam "métricas estáticas + custo de mudança" e "nº de ficheiros e
> serviços" (`recomendacoes-requisitos-fase2.md`, `analise-requisitos-fase2-v2.md`). As métricas concretas
> foram propostas no rascunho e aceites pela equipa ao usá-las na baseline (2026-11-18). N1, N2 e N4 são
> calculadas por `docs/fase2/medicoes/rnf2_estaticas.py`.

| # | Métrica (escala) | Unidade | Instrumento |
|---|---|---|---|
| N1 | Efeitos com duas implementações (imagem e vídeo) | nº de efeitos; linhas das cópias no vídeo | `rnf2_estaticas.py`: funções dos módulos de vídeo com o mesmo nome de uma ferramenta de imagem `Tools/<efeito>/<efeito>.py` |
| N2 | Impacto de mudança, em cenários fixos (2.3) | nº de ficheiros a alterar; serviços a reconstruir; tipos de trabalho de vídeo reimplantados | `rnf2_estaticas.py`: encontra os ficheiros pelo conteúdo e os serviços pelas instruções `COPY` dos Dockerfiles do `docker-compose.yaml` |
| N3 | Independência de implantação | tempo de build e tamanho da imagem Docker de cada serviço de vídeo | `docker compose build --no-cache`; `docker image inspect` |
| N4 | Tamanho e complexidade por módulo | SLOC e complexidade ciclomática (máx. e média) de `Tools/video*`; linhas do orquestrador | `rnf2_estaticas.py` (`radon` 6.0.1) |
| N5 | Desempenho não pode piorar (efeito colateral) | isolado, M1 e M2 do RNF1 | `carga_rnf1.py` |

### 2.3 Cenários de mudança para N2

> Os cenários não são aplicados ao código: o script determina, a partir do código e dos Dockerfiles, que
> ficheiros e que serviços uma mudança desse tipo obrigaria a alterar e reconstruir. Não acrescentam
> funcionalidades ao produto.

| Cenário | Mudança simulada |
|---|---|
| C1 | Alterar o comportamento de um filtro comum (e.g., `brightness`) para imagem e vídeo |
| C2 | Atualizar a versão do `faster-whisper` ou o modelo usado nas legendas |
| C3 | Alterar a forma como a extração de fotogramas escolhe os instantes |

### 2.4 Valores e pontos de medição

As medições fazem-se em **três momentos**, com o mesmo método: na base, depois deste RNF2 e depois do RNF1.
Assim, o ganho do RNF2 (modularidade) e o do RNF1 (capacidade) avaliam-se cada um por si.

| Métrica | Base | Após RNF2 | Alvo | Mínimo aceitável | Origem do alvo |
|---|---|---|---|---|---|
| N1 | **8** efeitos; 18 linhas copiadas em `Tools/video/effects.py` | {a medir} | 0 efeitos com duas implementações | 0 | Objetivo do QS-04; relatório, Tabela 18 |
| N2 — C1 (filtro de brilho) | 2 ficheiros; `brightness_tool` + `video_tool`; **3** tipos de trabalho de vídeo reimplantados | {a medir} | Reimplanta 1 tipo de vídeo (a edição) e a ferramenta de imagem | — | Relatório, Tabela 18; exige o módulo de efeitos fora de `Tools/utils` (EV-28) |
| N2 — C2 (Faster-Whisper) | 2 ficheiros; `video_tool`; **3** tipos de trabalho reimplantados | {a medir} | Reimplanta 1 tipo de trabalho (só a legendagem) | 1 tipo de trabalho | Objetivo do QS-02; relatório, Tabela 18 |
| N2 — C3 (amostragem de fotogramas) | 1 ficheiro; `video_tool`; **3** tipos de trabalho reimplantados | {a medir} | Reimplanta 1 tipo de trabalho (só a extração) | — | Relatório, Tabela 18 |
| N3 | 1 imagem de 1,69 GB (ffmpeg + fontes 597 MB; `faster-whisper` 457 MB); build sem cache 240 s | {a medir} | Imagem da edição ≤ 1,23 GB (1,69 GB sem os 457 MB do `faster-whisper`) | Imagem da edição menor que a atual, construída no mesmo dia | Relatório, Tabela 18; o `apt-get` não fixa versões |
| N4 | 1 serviço; 601 SLOC; CC máx. 22 (`process_video`); orquestrador 2733 linhas, 16 com ramificação imagem/vídeo | {a medir} | — | Orquestrador ≤ 2733 + 10 % linhas (H9) | Relatório, Tabela 18 |
| N5 | isolado p50 14,8 s; M1 p95 322,6 s; M2 0,70 vídeos/min (baseline do RNF1) | {a medir} | Não piorar | {a fixar} | Diretrizes: avaliar se a melhoria de um RNF degrada outro |

> Valores da base: `docs/fase2/medicoes/resultados/base/` e `docs/fase2/medicoes/README.md`.

---

## 3. Decisões arquiteturais

### 3.1 Alternativas consideradas

| # | Alternativa | Mantém o padrão global? | Prós | Contras |
|---|---|---|---|---|
| B0 | Ficar como está (um `video_tool`) | Afasta-se (pipeline monolith dentro de microserviços) | Sem risco | Mantém E1–E5 |
| B1 | **Um microserviço por efeito**, como nas imagens | Mantém | Igual ao caminho das imagens; máxima granularidade | Cada serviço descodifica e recodifica o vídeo inteiro: um pipeline de 3 filtros passa de 1 para 3 codificações (mais tempo e perda de qualidade); muitos serviços com o mesmo `ffmpeg` |
| B2 | **Um microserviço por tipo de trabalho**: edição (filtros, corte, velocidade), legendagem, extração de fotogramas; efeitos comuns num módulo partilhado com as ferramentas de imagem | Mantém | Separa dependências e ritmos de mudança; corta pelos estágios que já existem (E7), sem recodificações novas; remove a duplicação E3; permite escalar cada um (RNF1) | Encadear estágios entre serviços; mais contentores; o orquestrador pode crescer (H9) |
| B3 | **Monólito modular**: registo de efeitos e módulos separados dentro do mesmo `video_tool` | Afasta-se (como hoje) | Barato e sem risco de rede | Continua uma imagem e uma implantação; não resolve E5 nem ajuda o RNF1 |

### 3.2 Decisão

**B2** (decidido pela equipa a 2026-11-18). A equipa divide o `video_tool` em microserviços (ideia dos
docentes), por tipo de trabalho e não por efeito: B1 piora o desempenho e a qualidade do vídeo, e o relatório
deve dizer que foi considerada e porque foi rejeitada.

Decisões e restrições dentro de B2:

- **Quem encadeia os estágios** de um pipeline com, por exemplo, legendas + filtro + extração:
  (a) o `projects`, como já faz com as imagens (resposta em `project_queue` → envia o estágio seguinte); segue o
  padrão global, mas faz crescer o orquestrador (H9);
  (b) cada serviço envia o resultado para a fila do serviço seguinte (coreografia).
  **Decidido: (a)** (equipa, 2026-11-18), por coerência com o caminho das imagens. O crescimento do
  orquestrador é medido (H9, N4).
- **Corte do pipeline:** nos mesmos limites que `process_video` usa hoje (estágios à volta de `subtitles`;
  `extract_frames` sempre no fim). Os filtros, o corte e a velocidade seguidos continuam num só estágio, com uma
  única descodificação e codificação.
- **Efeitos partilhados — decidido** (equipa, 2026-11-18): mover as operações PIL para um módulo comum
  (e.g., `Tools/utils/effects.py`) usado pelas ferramentas de imagem e pelo serviço de edição de vídeo. Risco
  aceite: mexe também nas ferramentas de imagem, por isso a regressão cobre imagem (H7).
- **Progresso e pré-visualização:** a percentagem global tem de continuar a avançar de 0 a 100 num pipeline com
  vários estágios, e a regra do estágio da pré-visualização (`video_processor.py:339-344`) tem de se manter.
- **Ficheiros intermédios:** ficam no volume partilhado `image_data` e apagam-se no fim ou em caso de falha,
  sem saídas parciais visíveis.

### 3.3 Consequências e efeitos colaterais a medir

| Atributo | Efeito esperado | Como verificar |
|---|---|---|
| Desempenho | Neutro se H6 se confirmar; com legendas já havia estágios. Latência extra por mensagem entre serviços | N5 (testes do RNF1) |
| Capacidade | Melhora sozinha em parte: uma legendagem deixa de bloquear edições, mesmo sem réplicas | M1 do RNF1 no ponto "Após RNF2" |
| Utilização de recursos | Mais contentores, mas a edição deixa de carregar o Whisper | `docker stats`; N3 |
| Fiabilidade | Mais pontos de falha entre estágios; o pedido não se pode perder a meio | Matar um serviço a meio de um pipeline com vários estágios |
| Manutenibilidade do orquestrador | Pode piorar (H9) | N4 no `projects` |

---

## 4. Tarefas do refactoring

- [x] T1. Medir N1–N4 (com C1–C3) na base; correr a baseline do RNF1 (dá N5) — 2026-11-18.
- [x] T2. Guardar a referência de regressão: testes existentes (8 + 74 passam) e *hash* das saídas (imagem e
      vídeo, determinismo confirmado) — 2026-11-18.
- [ ] T3. Extrair os efeitos PIL para o módulo partilhado e pôr as ferramentas de imagem e o vídeo a usá-lo.
- [ ] T4. Criar os serviços de edição, legendagem e extração (Dockerfiles e `requirements` próprios), com filas
      próprias em `rabbitMQ/definitions.json` e entradas no `docker-compose.yaml`.
- [ ] T5. Encaminhar e encadear os estágios no `projects` (decisão 3.2), mantendo progresso, pré-visualização,
      cancelamento e quota.
- [ ] T6. Testes de regressão e confirmação de H6–H9.
- [ ] T7. Medir N1–N5 no ponto "Após RNF2" e preencher a secção 2.4.

---

## 5. Preservação funcional

- Mesmos efeitos, mesmas saídas (*hash* de fotogramas e de imagens), mesmo progresso, mesma quota e devolução no
  cancelamento.
- Testes a correr antes e depois: `Tools/video/tests/` (repartidos pelos novos serviços), `projects/tests/`, e os
  casos TST-* do PL1-G4 que tocam em vídeo e em imagem (os efeitos de imagem passam a usar o módulo partilhado).
- Regras sem requisito explícito a manter: `extract_frames` é sempre o último passo; extração sem edições anteriores
  lê diretamente o original, sem recodificar (`video_processor.py:296-304`); a pré-visualização processa só os
  primeiros `VIDEO_PREVIEW_SECONDS` da linha temporal final.

---

## 6. Registo de utilização de IA

| Data | Ferramenta / modelo | Tarefa apoiada | O que a equipa validou e como |
|---|---|---|---|
| 2026-11-18 | Claude Code (Claude Opus 5.5) | Rascunho deste documento a partir das notas da equipa, das diretrizes e da leitura do código (evidências E1–E7 verificadas no commit `0523102`) | {quem reviu; o que foi alterado} |
| 2026-11-18 | — (decisão da equipa) | Validação das propostas do rascunho | Aprovadas: divisão B2 por tipo de trabalho; encadeamento pelo `projects` (opção a); módulo de efeitos partilhado. Marcas [PROPOSTA] retiradas destes pontos |
| 2026-11-18 | Claude Code (Claude Opus 5.5) + equipa | Arrumação depois da baseline | Métricas N1–N5 e cenários C1–C3 aceites (usados na baseline); descrição dos instrumentos alinhada com os scripts usados; valores da base preenchidos. Continuam [PROPOSTA], à espera de revisão: impacto nos stakeholders (1.3) e requisito reformulado (2.1) |
| 2026-11-18 | Claude Code (Claude Opus 5.5) + equipa | Formato do requisito (2.1) | A frase "O sistema deve…" foi substituída, a pedido da equipa, pelo formato das diretrizes da Fase 2 (escala, método, base, alvo, mínimo). Só o impacto nos stakeholders (1.3) continua [PROPOSTA] |
| {…} | {…} | {…} | {…} |
