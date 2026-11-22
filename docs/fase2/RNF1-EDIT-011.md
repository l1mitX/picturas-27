# RNF 1 — REQ-VID-EDIT-011: vários vídeos processados em paralelo

| | |
|---|---|
| **Requisito de origem** | REQ-VID-EDIT-011 (PL1-G4, `doc-ext-requisitos-2627.pdf`, Tabela 30): "O sistema deve editar vários vídeos ao mesmo tempo quando há capacidade disponível." |
| **ISO/IEC 25010** | Eficiência de desempenho › Capacidade (elasticidade como objetivo) |
| **Estado na base (PL1-G4 §7.3)** | **Parcial**: "exige `--scale video_tool=2`, não testado" |
| **Alvos do PL1-G4** | Produção: "escalável" (sem número) · MVP: ≥ 2 vídeos em paralelo |
| **Commit de partida** | `0523102` (`upstream/main` de `picturas-um/picturas-27`) |
| **Relação com o RNF2** | Depende do RNF2 (`RNF2-modularidade-video.md`), que divide o `video_tool` em serviços por tipo de trabalho, cada um com a sua fila. Este RNF faz-se **depois** e trata só da capacidade: réplicas e ajuste automático de cada serviço à sua fila |
| **Estado deste documento** | Plano. Base medida (2026-11-18); alvos e mínimos fixados a 2026-11-22 (relatório, Tabela 18); medições após o refactoring por fazer |

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

> Formato das diretrizes da Fase 2 ("O que se espera para cada requisito não funcional", ponto 2): escala, método
> de medição, valor medido na base, valor-alvo e valor mínimo aceitável, com origem identificável. O alvo e o
> mínimo fixam-se depois da medição inicial.

### 2.1 Requisito

| Campo | RNF1 |
|---|---|
| **Requisito** | Eficiência de desempenho › Capacidade (ISO/IEC 25010): processar vários vídeos em paralelo (REQ-VID-EDIT-011, PL1-G4) |
| **Escala** | M6: segundos que cada um de 4 vídeos curtos, submetidos ao mesmo tempo, demora do *Apply* até ao resultado (p95), e débito (vídeos/min) |
| **Método** | `docs/fase2/medicoes/carga_rnf1.py`, cenário `paralelo` (M6): 4 utilizadores aplicam brilho a `sample_10s_720p.mp4` (10 s) ao mesmo tempo, sem legendagem; 5 repetições; mesma máquina e mesmos recursos do Docker (12 CPUs, 7,7 GiB) |
| **Valor na base** | **44,0 s** (p95; p50 28,8 s) e 5,54 vídeos/min, medido a 2026-11-18. Referência: o mesmo vídeo sozinho demora 17,8 s (p95) |
| **Valor-alvo** | M6 p95 ≤ 30 s — ver 2.4 |
| **Mínimo aceitável** | M6: pelo menos 2 trabalhos em simultâneo (REQ-VID-EDIT-011 no MVP) — ver 2.4 |
| **Medições complementares** | M1 (vídeo curto durante uma legendagem; base p95 322,6 s; ganho atribuído sobretudo ao RNF2), M2 (débito com 4 vídeos ao mesmo tempo; base 0,70 vídeos/min), M3 e M4 — ver 2.2 e 2.4 |

> **Decisão sobre a escala principal (equipa, 2026-11-22).** Problema: depois do RNF2, a legendagem corre num
> serviço próprio e deixa de bloquear a edição, por isso o M1 melhora quase todo **com o RNF2**, antes das réplicas.
> Se o M1 fosse a escala principal deste RNF, o seu ganho quase não mudaria com as réplicas, e este RNF não seria
> avaliado pelo que ele próprio faz. (O M2 também quase não pode subir: a legendagem sozinha demora cerca de 300 s,
> o que limita o débito a cerca de 0,79 vídeos/min, seja qual for o número de réplicas.) Foram consideradas duas
> soluções:
>
> - **(a) Manter o M1 como escala principal e medir em três momentos** (base, após RNF2, após RNF1). O ganho
>   atribuído a este RNF é só o que muda entre "Após RNF2" e "Após RNF1".
> - **(b) Trocar para o M6** (4 edições curtas em paralelo), que mede diretamente o efeito das réplicas, e deixar
>   o M1 como complementar.
>
> **Escolhida: (b).** É a mais correta: a escala principal mede o efeito das táticas deste RNF (réplicas e ajuste
> automático). Implicou mudar a priorização dos cenários no relatório (capítulo 5): o QS-03 (M6) passou a
> prioridade 1 e o QS-01 (M1) a prioridade 3, por ser resolvido sobretudo pela divisão do RNF2. Os três momentos de
> medição mantêm-se, para separar os ganhos dos dois RNF. Registado no relatório, secções 5.1 e 6.2, e em
> `medicoes/README.md` ("Antes de medir"). A opção (a) chegou a ser escolhida no mesmo dia e foi revista.

### 2.2 Métricas

| # | Métrica (escala) | Unidade | Papel |
|---|---|---|---|
| M1 | Tempo até à conclusão de um trabalho curto submetido durante uma legendagem (p50 e p95) | s | Complementar (decisão de 2026-11-22, ver 2.1): cenário QS-01; o ganho vem sobretudo do RNF2 |
| M2 | Débito com N trabalhos em simultâneo (carga mista) | vídeos concluídos / min | Principal (capacidade) |
| M3 | Tempo até à conclusão por trabalho com carga mista (p95) | s | Secundária |
| M4 | Tempo até o sistema acrescentar capacidade quando a fila passa o limiar, e até a retirar quando esvazia | s | Elasticidade (só depois do refactoring; na base não há ajuste: "n/a") |
| M6 | Tempo até à conclusão de N = 4 edições curtas submetidas ao mesmo tempo, sem legendagem (p50 e p95), e débito | s; vídeos concluídos / min | **Principal** (decisão de 2026-11-22, ver 2.1): cenário QS-03; é o que mostra o efeito das réplicas |

> Origem: M1, M2 e M3 vêm das notas da equipa (`analise-requisitos-fase2-v2.md`, "A melhor medição de
> todos") e do cenário de exemplo do Bloco 2 do Exercício 6. M4 foi proposta no rascunho e aceite pela equipa.
> Uma métrica M5 (pré-visualização durante uma legendagem) foi proposta e retirada no plano mínimo; o ID M5 não
> se reutiliza. O M6 foi acrescentado a 2026-11-18, ainda antes do refactoring, depois de a revisão do plano
> mostrar que o M1 e o M2 dependem sobretudo da legendagem. Corresponde ao RNF-A1/A4 das notas da equipa
> (`recomendacoes-requisitos-fase2.md`), que tinha ficado fora do plano mínimo.

### 2.3 Método de medição

> **Parâmetros fixados pela equipa a 2026-11-18, revistos no mesmo dia antes da baseline (plano mínimo, por
> causa do prazo):** 5 s de atraso; **5 repetições** do cenário isolado e do M1; M2 **só com N = 4** e
> **3 repetições**; sem medição de referência com `--scale 2`. Mistura de trabalhos e vídeos como abaixo. Não se
> mudam entre a baseline e as medições seguintes. Recursos do Docker na baseline: 12 CPUs, 7,7 GiB (ver
> `medicoes/README.md`).

- **Cenário isolado (referência sem carga):** o utilizador B aplica brilho a `sample_10s_720p.mp4`, sozinho.
  5 repetições.
- **Cenário M1:** o utilizador A lança a legendagem de `samples/video/speech_mandela_177s_1080p.webm`; 5 s
  depois, o utilizador B aplica brilho a `sample_10s_720p.mp4`. Mede-se de *Apply* de B até o resultado ficar
  disponível. 5 repetições.
- **Cenário M2/M3:** N = 4 trabalhos submetidos ao mesmo tempo: 1 legendagem + 3 edições de brilho de
  `sample_10s_720p.mp4`. 3 repetições.
- **Cenário M6:** N = 4 edições de brilho de `sample_10s_720p.mp4`, submetidas ao mesmo tempo por 4
  utilizadores, sem legendagem. 5 repetições (`carga_rnf1.py <etiqueta> paralelo --reps 5 --n 4`).
- **Instrumento:** `docs/fase2/medicoes/carga_rnf1.py`. Usa a aplicação pelo nginx/`apiGateway` como um
  utilizador (registo Premium, projeto, upload, pipeline, *Apply*) e considera o trabalho concluído quando
  `GET .../process/url` devolve resultados (consulta a cada 0,5 s). Guarda CSV com os dados brutos e um resumo
  JSON.
- **Recursos (efeito colateral):** `docker stats` durante os cenários: memória total e CPU dos serviços de vídeo.
- **Ambiente:** a mesma máquina e os mesmos recursos atribuídos ao Docker na baseline e na medição final
  (registar SO, CPU, RAM, versões do Docker e do Compose). O ganho de paralelismo está limitado pelos núcleos;
  os alvos têm de o ter em conta.

### 2.4 Valores

As medições fazem-se em três momentos, com o mesmo script: na base, depois do RNF2 (serviços separados, uma
réplica cada) e depois deste RNF1. A divisão do RNF2 já melhora parte do M1 (a legendagem deixa de bloquear a
edição); o ganho atribuído a este RNF é o que se mede **entre "Após RNF2" e "Após RNF1"**.

| Métrica | Baseline (base, 1 réplica) | Após RNF2 | Após RNF1 | Alvo | Mínimo aceitável | Origem do alvo |
|---|---|---|---|---|---|---|
| M1 p95 | **322,6 s** (p50 307,6 s; isolado: p50 14,8 s, p95 17,8 s) | {a medir} | {a medir} | ≤ 36 s | ≤ 50 s | Alvo: 2× o trabalho isolado (necessidade do utilizador). Mínimo: REQ-VID-EDIT-010 no MVP (5× a duração de 10 s). Relatório, Tabela 18 |
| M2 (N=4) | **0,70 vídeos/min** | {a medir} | {a medir} | {a fixar} | ≥ 2 vídeos em paralelo (critério MVP do PL1-G4) | PL1-G4 Tabela 30 |
| M3 p95 | 353,5 s (todos); 35,3 s (só curtos) | {a medir} | {a medir} | {a fixar} | {a fixar} | {…} |
| M4 | n/a | n/a | {a medir} | ≤ 30 s | ≤ 60 s | Período de consulta do ajuste + arranque do contentor. Relatório, Tabela 18 |
| M6 (N=4) | **p95 44,0 s** (p50 28,8 s); 5,54 vídeos/min | {a medir} | {a medir} | p95 ≤ 30 s | ≥ 2 trabalhos em simultâneo | Alvo: estimativa da equipa (4 em paralelo, perto dos 17,8 s de um isolado). Mínimo: REQ-VID-EDIT-011 no MVP. Relatório, Tabela 18 |
| Isolado p95 (efeito colateral) | 17,8 s | {a medir} | {a medir} | ≤ 17,8 s (não piorar) | ≤ 19,6 s (base + 10 %) | Relatório, Tabela 18 |

> Sem a medição de referência com `--scale 2`, o relatório separa o ganho de cada RNF pelos três momentos de
> medição: o que muda entre a base e "Após RNF2" vem da divisão em serviços; o que muda entre "Após RNF2" e
> "Após RNF1" vem das réplicas e do ajuste automático.

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

Pontos dentro de A2:

- **Mínimo, máximo e limiar por serviço (em aberto, a decidir antes de implementar):** a legendagem gasta mais
  CPU e memória por réplica do que a edição (baseline: até 2 506 MiB com legendagem, contra 605 MiB só com
  edição); os limites devem ser diferentes e caber nos núcleos e na memória da máquina de medição.
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

- [x] T1. Baseline: escrever o script de medição e correr isolado, M1, M2 e M3 na base (1 réplica) — 2026-11-18.
      M6 acrescentado e medido na base no mesmo dia, antes do refactoring.
- [ ] T2. Confirmar ou refutar H1–H5 na base; registar o que impede réplicas seguras.
- [ ] T3. (Depois do RNF2) Medir isolado, M1, M2 e M3 no ponto "Após RNF2".
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
| 2026-11-18 | Claude Code (Claude Opus 5.5) + equipa | Arrumação depois da baseline | Plano mínimo registado; M4 aceite; M5 e a referência `--scale 2` retiradas; método (2.3) alinhado com o script usado; valores da base preenchidos. Continuam [PROPOSTA], à espera de revisão: impacto nos stakeholders (1.3) e requisito reformulado (2.1) |
| 2026-11-18 | Claude Code (Claude Opus 5.5) + equipa | Formato do requisito (2.1) | A frase "O sistema deve…" foi substituída, a pedido da equipa, pelo formato das diretrizes da Fase 2 (escala, método, base, alvo, mínimo). Só o impacto nos stakeholders (1.3) continua [PROPOSTA] |
| 2026-11-18 | Claude Code (Claude Opus 5.5) + equipa | Revisão do plano face às diretrizes; novo cenário M6 | A revisão mostrou que o M1 é resolvido sobretudo pelo RNF2 e que o M2 está limitado pela duração da legendagem. A equipa pediu o cenário M6: acrescentado ao `carga_rnf1.py` (`paralelo`) e medido na base (código igual a `0523102`). Fica [PROPOSTA]: usar o M6 como escala principal (2.1) |
| 2026-11-22 | Claude Code (Claude Opus 5.5) + equipa | Revisão do relatório (caps. 2–6) e decisão sobre a escala principal | A equipa escolheu primeiro a opção (a) da secção 2.1 e, no mesmo dia, reviu-a para a (b): M6 principal, M1 complementar, três momentos de medição. Prioridades do capítulo 5 do relatório ajustadas (QS-03 → 1, QS-01 → 3). Marca [PROPOSTA] do M6 retirada. Alvos e mínimos copiados do relatório (Tabela 18). Cabeçalho e valores por omissão do `carga_rnf1.py` alinhados com o plano mínimo da baseline |
| {…} | {…} | {…} | {…} |
