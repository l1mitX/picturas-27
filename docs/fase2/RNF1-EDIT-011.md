# RNF 1 — REQ-VID-EDIT-011: vários vídeos processados em paralelo

| | |
|---|---|
| **Requisito de origem** | REQ-VID-EDIT-011 (PL1-G4, `doc-ext-requisitos-2627.pdf`, Tabela 30): "O sistema deve editar vários vídeos ao mesmo tempo quando há capacidade disponível." |
| **ISO/IEC 25010** | Eficiência de desempenho › Capacidade (elasticidade como objetivo) |
| **Estado na base (PL1-G4 §7.3)** | **Parcial**: "exige `--scale video_tool=2`, não testado" |
| **Alvos do PL1-G4** | Produção: "escalável" (sem número) · MVP: ≥ 2 vídeos em paralelo |
| **Commit de partida** | `0523102` (`upstream/main` de `picturas-um/picturas-27`) |
| **Relação com o RNF2** | Depende do RNF2 (`RNF2-modularidade-video.md`), que divide o `video_tool` em serviços por tipo de trabalho, cada um com a sua fila. Este RNF faz-se **depois** e trata só da capacidade: réplicas e ajuste automático de cada serviço à sua fila |
| **Estado deste documento** | Rascunho. Valores de baseline, alvo e mínimo **por medir** |

> Este ficheiro junta o requisito, a decisão, as tarefas e o registo de IA deste RNF. O relatório da Fase 2
> cita-o. Atualizar sempre que uma decisão mudar ou uma medição for feita.
>
> **Legenda:** as partes marcadas com **[PROPOSTA]** foram sugeridas no rascunho assistido por IA e não têm
> fonte nos enunciados, nas notas da equipa ou no relatório do PL1-G4. Têm de ser validadas (ou alteradas) pela
> equipa; depois de validadas, retirar a marca e registar a decisão na secção 6.

---

## 1. Diagnóstico

### 1.1 Fragilidade

Há **um único worker de vídeo** e ele consome **um trabalho de cada vez**. Todos os trabalhos de vídeo de
todos os utilizadores (edição, legendagem, extração de fotogramas e até a **pré-visualização de 3 s**) passam
pela mesma fila e são processados em série. Uma legendagem longa (Whisper em CPU) bloqueia tudo o resto.

### 1.2 Evidência (commit `0523102`)

| ID | Onde | O que mostra |
|---|---|---|
| E1 | `docker-compose.yaml:256-273` (serviço `video_tool`) | Um só serviço, sem `deploy.replicas` nem limites de recursos; `WHISPER_MODEL: small`, `WHISPER_CPU_THREADS: 2` |
| E2 | `Tools/video/video.py:54` | `basic_qos(prefetch_count=1)`: cada worker trata uma mensagem de cada vez |
| E3 | `Tools/video/video.py:126-171` | O `callback` corre o pipeline inteiro (`process_video`) de forma síncrona e só faz `basic_ack` no fim |
| E4 | `projects/utils/project_msg.js:21` | Todo o trabalho com `procedure: "video"` vai para uma única fila, `video_queue` |
| E5 | `projects/routes/projects.js:1109-1122` | A pré-visualização de vídeo também é enviada como `procedure: "video"` (`preview: true`), para a mesma fila |
| E6 | `Tools/video/` (`video_processor.py`, `subtitles.py`, `frame_extraction.py`) | Edição, legendas e extração de fotogramas correm no mesmo processo |
| E7 | `Tools/video/video.py:56-63` | `heartbeat=0`: a ligação ao broker não cai durante um trabalho longo (relevante para réplicas e reentregas) |

### 1.3 Impacto nos stakeholders

> **[PROPOSTA]** Escrito a partir do modelo de negócio descrito no enunciado base (SaaS com perfis e
> subscrição Premium), não de dados medidos. Confirmar com o cenário M1 da baseline.

- **Utilizador (sobretudo Premium):** um vídeo curto, ou só a pré-visualização, pode esperar minutos atrás da
  legendagem de outra pessoa. O tempo de resposta depende da carga dos outros, não do seu próprio trabalho.
- **Negócio (SaaS com subscrição Premium):** não é possível dar mais capacidade a quem paga; o serviço degrada
  para todos ao mesmo tempo.
- **Operação:** a capacidade não acompanha a carga. Com a fila cheia não se pode fazer nada além de um
  `--scale` manual, que nunca foi testado (o PL1-G4 contava com ele na DA-01).

### 1.4 Hipóteses a confirmar

| ID | Hipótese | Como confirmar |
|---|---|---|
| H1 | Com `--scale video_tool=2` funciona sem erros (sem `container_name`, ack manual) | Correr a baseline com 2 réplicas manuais |
| H2 | Réplicas a escrever no mesmo volume `image_data` não colidem em ficheiros temporários | Ler `video_processor.py` e testar 2 trabalhos do mesmo projeto em simultâneo |
| H3 | Duas réplicas a descarregar o modelo Whisper ao mesmo tempo para `whisper_models` corrompem a cache | Arrancar 2 réplicas com o volume vazio |
| H4 | Uma legendagem com mais de 30 min ultrapassa o `consumer_timeout` do RabbitMQ e é reentregue em ciclo | Ver a versão do RabbitMQ e o `consumer_timeout`; testar com um vídeo Premium longo |
| H5 | O cancelamento (`activeToken`/`cancelToken`) continua correto com vários workers | Teste: cancelar a meio com 2 réplicas ativas |

---

## 2. Quantificação

> Os valores de baseline, o alvo e o mínimo aceitável **fixam-se depois da medição inicial**, como pedem as
> diretrizes. As métricas e o método ficam já definidos.

### 2.1 Requisito reformulado (verificável)

**[PROPOSTA]** Redação nova, segundo o padrão do Exercício 2 ("O sistema deve [ação] [objeto] [condição]").

> O sistema deve concluir um trabalho de vídeo curto, submetido enquanto decorre uma legendagem automática de
> outro utilizador, em ≤ **{alvo}** s (p95), e deve aumentar o número de vídeos concluídos por minuto quando há
> vários trabalhos em fila, ajustando automaticamente os recursos do processamento de vídeo à carga.

### 2.2 Métricas

| # | Métrica (escala) | Unidade | Papel |
|---|---|---|---|
| M1 | Tempo até à conclusão de um trabalho curto submetido durante uma legendagem (p50 e p95) | s | **Principal**: é o cenário de qualidade do Exercício 6 |
| M2 | Débito com N trabalhos em simultâneo (carga mista) | vídeos concluídos / min | Principal (capacidade) |
| M3 | Tempo até à conclusão por trabalho com carga mista (p95) | s | Secundária |
| M4 | Tempo até o sistema acrescentar capacidade quando a fila passa o limiar, e até a retirar quando esvazia | s | **[PROPOSTA]** Elasticidade (só depois do refactoring; na base não há ajuste: "n/a") |
| M5 | Pré-visualização de 3 s durante uma legendagem | s | **[PROPOSTA]** Secundária (usabilidade visível) |

> Origem: M1, M2 e M3 vêm das notas da equipa (`analise-requisitos-fase2-v2.md`, "A melhor medição de
> todos") e do cenário de exemplo do Bloco 2 do Exercício 6. M4 e M5 são propostas.

### 2.3 Método de medição

> **Parâmetros fixados pela equipa a 2026-11-18** (5 s de atraso, 10 e 5 repetições, N ∈ {1, 4, 8}, a mistura
> de trabalhos e os vídeos abaixo). Não se mudam entre a baseline e as medições seguintes. Falta registar os
> recursos dados ao Docker (CPU e RAM) no momento da baseline.

- **Cenário M1/M5:** utilizador A lança a legendagem de `samples/video/speech_mandela_177s_1080p.webm`; 5 s
  depois, o utilizador B aplica um efeito simples (e.g., brilho) a `sample_10s_720p.mp4`, ou pede a
  pré-visualização. Mede-se de *Apply* de B até ao evento de conclusão. 10 repetições.
- **Cenário M2/M3:** N ∈ {1, 4, 8} trabalhos submetidos ao mesmo tempo, com a mistura fixa
  {1 legendagem + (N−1) edições de `sample_10s_720p.mp4`}. 5 repetições por N.
- **Instrumento:** script versionado em `docs/fase2/medicoes/` (a criar). Submete pelo `apiGateway` e regista
  os tempos a partir dos eventos `video-progress`/conclusão no WebSocket ou a partir do estado do projeto no
  `projects`. Guarda CSV com os dados brutos.
- **Recursos (efeito colateral):** `docker stats` durante os cenários: memória total e CPU dos serviços de vídeo.
- **Ambiente:** a mesma máquina e os mesmos recursos atribuídos ao Docker na baseline e na medição final
  (registar SO, CPU, RAM, versões do Docker e do Compose). O ganho de paralelismo está limitado pelos núcleos;
  os alvos têm de o ter em conta.

### 2.4 Valores

As medições fazem-se em três momentos, com o mesmo script: na base, depois do RNF2 (serviços separados, uma
réplica cada) e depois deste RNF1. A divisão do RNF2 já melhora parte do M1 (a legendagem deixa de bloquear a
edição); o ganho atribuído a este RNF é o que se mede **entre "Após RNF2" e "Após RNF1"**.

| Métrica | Baseline (base, 1 réplica) | Referência (base + `--scale 2` manual) | Após RNF2 | Após RNF1 | Alvo | Mínimo aceitável | Origem do alvo |
|---|---|---|---|---|---|---|---|
| M1 p95 | {a medir} | {a medir} | {a medir} | {a medir} | {a fixar} | {a fixar} | {e.g., ≤ tempo do mesmo trabalho sem carga + X %} |
| M2 (N=4) | {a medir} | {a medir} | {a medir} | {a medir} | {a fixar} | ≥ 2 vídeos em paralelo (critério MVP do PL1-G4) | PL1-G4 Tabela 30 |
| M2 (N=8) | {a medir} | {a medir} | {a medir} | {a medir} | {a fixar} | {a fixar} | {…} |
| M3 p95 | {a medir} | {a medir} | {a medir} | {a medir} | {a fixar} | {a fixar} | {…} |
| M4 | n/a | n/a | n/a | {a medir} | {a fixar} | {a fixar} | {…} |
| M5 | {a medir} | {a medir} | {a medir} | {a medir} | {a fixar} | {a fixar} | PL1-G4 REQ-VID-PREVIEW-005 ("poucos segundos") |

> **[PROPOSTA]** Medir também a coluna "Referência": mostra quanto se ganha só com réplicas e separa esse ganho do que vem
> da divisão em serviços (RNF2) e do ajuste automático (este RNF). Sem isto, o trabalho parece "só pusemos
> réplicas".

---

## 3. Decisões arquiteturais

### 3.1 Alternativas consideradas

| # | Alternativa | Mantém o padrão global? | Prós | Contras |
|---|---|---|---|---|
| A0 | Ficar como está (1 worker, 1 fila) | — | Nenhum risco | Não cumpre nem o critério do MVP |
| A1 | Réplicas fixas do `video_tool` (`--scale`) | Mantém | Quase sem código | Uma legendagem continua a ocupar uma réplica; capacidade fixa, sem elasticidade; complexidade baixa |
| A2 | **Réplicas de cada serviço de vídeo com ajuste automático** pelo tamanho da sua fila (Competing Consumers), sobre os serviços e filas por tipo de trabalho criados no RNF2 | Mantém | Capacidade acompanha a carga de cada tipo de trabalho; legendas e edição escalam em separado | Mais peças (autoscaler); problemas de concorrência a resolver (H2–H5); depende do RNF2 |
| A3 | Divisão em serviços (por efeito ou por tipo de trabalho) | Mantém | Separa os tipos de trabalho | É tratada no RNF2 (manutenibilidade), que é pré-requisito deste |
| A4 | Um *job* efémero por vídeo, com orquestrador de *workflow* | Afasta-se parcialmente | Isolamento total e elasticidade natural | Exige outra plataforma (e.g., Kubernetes Jobs); fora do alcance do prazo |

### 3.2 Decisão

**A2.** Com os serviços por tipo de trabalho já separados no RNF2 (edição, legendagem, extração), o número de
réplicas de cada um ajusta-se ao tamanho da sua fila entre um mínimo e um máximo configurados. A separação das
filas, que neste documento era proposta como parte do RNF1, passou para o RNF2.

Pontos em aberto dentro de A2 (decidir e registar aqui). **[PROPOSTA]** As preferências indicadas em cada
ponto são sugestões, não decisões da equipa:

- **Mínimo, máximo e limiar por serviço:** a legendagem gasta mais CPU e memória por réplica do que a edição;
  os limites devem ser diferentes e caber nos núcleos da máquina de medição.
- **Mecanismo de ajuste automático:** o Docker Compose não tem autoscaler. Opções: (a) um pequeno serviço
  `video_autoscaler` que lê o tamanho das filas pela API de gestão do RabbitMQ e ajusta as réplicas pela API do
  Docker; (b) Docker Swarm. **Decidido: (a)** (equipa, 2026-11-18). O acesso ao socket do Docker alarga a
  superfície de ataque: é um efeito colateral a registar (ver 3.3).
- **Limites de recursos** por réplica (`deploy.resources.limits`), para que a medição seja controlada.

### 3.3 Consequências e efeitos colaterais a medir

| Atributo | Efeito esperado | Como verificar |
|---|---|---|
| Utilização de recursos | Mais memória: cada réplica de legendagem carrega o modelo Whisper | `docker stats` (M-recursos) |
| Fiabilidade (REQ-VID-FAIL-004, EDIT-012) | Reentregas entre réplicas não podem duplicar resultados nem perder pedidos | Matar uma réplica a meio; taxa de sucesso sob carga |
| Correção (REQ-VID-EDIT-009) | Saídas idênticas às da base | *Hash* dos fotogramas antes/depois |
| Segurança | O autoscaler com acesso ao Docker alarga a superfície de ataque | Registar a decisão e a mitigação |
| Manutenibilidade | Tratada no RNF2; aqui só se verifica que o autoscaler não acopla os serviços entre si | Revisão do código do autoscaler |

---

## 4. Tarefas do refactoring

- [ ] T1. Baseline: escrever o script de medição e correr M1, M2, M3, M5 na base (1 réplica) e com `--scale 2`.
- [ ] T2. Confirmar ou refutar H1–H5 na base; registar o que impede réplicas seguras.
- [ ] T3. (Depois do RNF2) Medir M1, M2, M3, M5 no ponto "Após RNF2".
- [ ] T4. Corrigir nos serviços de vídeo o que impedir réplicas seguras (temporários por mensagem, cache do
      Whisper, `consumer_timeout`).
- [ ] T5. Ajuste automático de réplicas por serviço (mínimo, máximo, limiar por fila).
- [ ] T6. Testes de regressão: testes de vídeo e do `projects`, *hash* de fotogramas, cancelamento com várias
      réplicas, pipeline imagem + vídeo.
- [ ] T7. Medição final com o mesmo script e o mesmo ambiente; preencher a secção 2.4 e analisar.

---

## 5. Preservação funcional

- O utilizador vê o mesmo comportamento: mesmos efeitos, mesmas saídas, mesmo progresso, mesma quota e
  devolução no cancelamento. Só muda o tempo de espera.
- Testes a correr antes e depois: `projects/tests/{frame-extraction,process-batch,video-pipeline}.test.js`,
  `Tools/video/tests/test_{frame_extraction,subtitles,video_processor}.py`, e os casos manuais TST-* do PL1-G4
  que tocam em vídeo.
- Regras sem requisito explícito a manter: `extract_frames` é sempre o último passo; a pré-visualização processa
  só os primeiros `VIDEO_PREVIEW_SECONDS`.

---

## 6. Registo de utilização de IA

| Data | Ferramenta / modelo | Tarefa apoiada | O que a equipa validou e como |
|---|---|---|---|
| 2026-11-18 | Claude Code (Claude Opus 5.5) | Rascunho deste documento a partir das notas da equipa (`Fase2-notas/`) e da leitura do código (evidências E1–E7 verificadas no commit `0523102`) | {quem reviu; o que foi alterado} |
| 2026-11-18 | — (decisão da equipa) | Validação das propostas do rascunho | Aprovados: ajuste automático por um serviço `video_autoscaler` (opção a); parâmetros do método de medição (2.3). Marcas [PROPOSTA] retiradas destes pontos |
| {…} | {…} | {…} | {…} |
