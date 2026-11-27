#import "../template.typ": *

= Trade-offs, Medição e Preservação Funcional

#orientacao[
  *Origem:* Exercício 7, secção 5 do _template_ (e os riscos de preservação funcional do Bloco 2, secção 6).

  *Objetivo do capítulo:* mostrar que as decisões foram avaliadas além do atributo que melhoram (_trade-offs_), que a
  melhoria foi medida de forma comparável (antes e depois) e que o comportamento funcional foi preservado.

  A mesma medição é feita *antes e depois* do _refactoring_, no mesmo ambiente. *Não inventem valores* de _baseline_, alvo
  ou mínimo aceitável: fixam-se após a medição inicial. Guardem os _scripts_, os dados e o ambiente das medições para os
  reutilizar como _baseline_.
]

== Matriz de efeitos

#orientacao[
  Para cada decisão, indiquem se cada atributo *melhora* (↑), *degrada* (↓) ou fica *neutro* (=), e justifiquem. Incluam
  no mínimo quatro atributos, e entre eles a característica do outro cenário: uma melhoria num atributo costuma ter um
  custo noutro, e é isso que esta matriz deve revelar. Se uma decisão degradar um atributo, digam como a equipa vai
  gerir esse custo.
]

#paisagem[
#tab([Matriz de efeitos das decisões],
  tabela(
    colunas: (1.4cm, 3.2cm, 3.4cm, 2.4cm, 2.4cm, 3.6cm, 1fr),
    tamanho: 8pt,
    [Decisão], [Desempenho], [Disponibilidade / Fiabilidade], [Segurança], [Usabilidade], [Manutenibilidade / Testabilidade], [Justificação],
    [DA-1], [↑ capacidade (M6, M4) \ = trabalho isolado \ ↓ utilização de recursos em pico], [↑ redundância, porque outra réplica retoma a mensagem \ ↓ risco de vídeos recomeçados ao retirar réplicas (H-10)], [↓ o `video_autoscaler` acede ao _socket_ do Docker], [↑ menos espera com vários utilizadores], [↓ mais uma peça e mais parâmetros (mínimo, máximo, limiar) \ ↓ caminhos concorrentes a testar (H-05)], [A capacidade melhora à custa de memória (até 2 506 MiB por réplica de legendagem, EV-18) e de um componente com privilégios. A equipa gere este custo com limites de memória por serviço, um mínimo e um máximo de réplicas, o _socket_ montado só no `video_autoscaler` e a paragem ordenada das réplicas, que acabam o estágio antes de sair (TAT-13). Quanto a recursos, há mais contentores em pico e um serviço novo sempre ligado (↓), mas sem carga as réplicas voltam ao mínimo (↑)],
    [DA-2], [↑ M1 (a legendagem deixa de bloquear a edição) \ ↓ possível no trabalho isolado (salto extra e MP4 intermédio, H-06)], [↓ mais pontos de falha e cancelamento entre serviços (H-08) \ = `ack` manual em cada serviço], [=], [\= (o utilizador vê os mesmos resultados)], [↑ modularidade (N1, N2, N3) \ ↑ cada serviço testa-se sozinho \ ↓ o encadeamento no `projects` precisa de testes novos e o orquestrador pode crescer (H-09)], [O ganho em manutenibilidade pode custar desempenho por vídeo. A equipa gere este custo cortando só nos estágios que já existem (EV-15) e medindo o trabalho isolado no momento `apos-rnf2`, que não pode piorar (N5, mínimo p95 ≤ 19,6 s). Quanto a recursos, as imagens da edição e da extração ficam mais pequenas, sem os 457 MB do `faster-whisper` (↑), mas passa a haver três imagens e três serviços em vez de um e um MP4 intermédio por estágio em `image_data` (↓)],
  ),
)
]

== Interação entre DA-1 e DA-2

#tab([Interação entre as decisões],
  tabela(
    colunas: (2.6cm, 2.6cm, 3.2cm, 1fr),
    tamanho: 8.5pt,
    [Decisão A], [Decisão B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [DA-1 (TAT-01, TAT-02: desempenho)], [DA-1 (TAT-13: disponibilidade)], [*Pré-requisito*], [Réplicas que aparecem e desaparecem exigem que um vídeo em curso não seja interrompido (H-10) e que uma réplica bloqueada seja detetada (EV-33, EV-34). Sem a TAT-13, o ajuste automático piora o M6 em vez de o melhorar],
    [DA-1], [DA-2], [*Pré-requisito* (a DA-2 é condição da DA-1)], [A DA-1 escala cada serviço criado pela DA-2. Sem filas por tipo de trabalho, uma legendagem ocuparia uma réplica destinada às edições curtas (EV-10, EV-18)],
    [DA-1], [DA-2], [*Sinergia*], [As imagens da edição e da extração ficam sem `faster-whisper` (EV-14), mais pequenas e mais rápidas a arrancar, o que encurta o M4],
    [DA-1], [DA-2], [*Conflito potencial*], [Ambas aumentam o número de contentores e de caminhos concorrentes, com mais memória (EV-18) e mais casos de cancelamento a testar (H-05, H-08)],
  ),
)

#paisagem[
== Plano de medição

As medições fazem-se em três momentos, com o mesmo método e na mesma máquina: `base`, `apos-rnf2` e `apos-rnf1`
(`docs/fase2/medicoes/README.md`, «Antes de medir»). O ganho do CAND-2 é o que muda entre `base` e `apos-rnf2`, e o do
CAND-1 é o que muda entre `apos-rnf2` e `apos-rnf1` (secção 6.2).

#tab([Plano de medição],
  tabela(
    colunas: (2.6cm, 4.6cm, 3.6cm, 4.4cm, 3cm, 1fr),
    tamanho: 8pt,
    [Cenário], [Cenário de teste e carga], [Ambiente (máquina, recursos, versões)], [O que se regista], [Repetições e agregação], [Onde ficam os _scripts_ e os dados],
    [QS-03 (M6, principal do CAND-1)], [`carga_rnf1.py <etiqueta> paralelo`: 4 utilizadores Premium de teste aplicam brilho a `sample_10s_720p.mp4` ao mesmo tempo, um projeto por trabalho], [A mesma máquina da base (Ryzen 5 5600H, Docker com 12 CPUs e 7,7 GiB), `docker compose up -d --build`, sem outra carga], [Tempo de cada trabalho desde o _Apply_ até o resultado estar disponível. Na `apos-rnf1` vale o do lado da aplicação (registos do `projects`). Também o débito e a CPU e a memória por contentor], [5 repetições, com p50, p95 e média, nos três momentos. Na `apos-rnf1`, 120 s de pausa antes de cada repetição, para começar com as réplicas no mínimo (frias)], [`docs/fase2/medicoes/carga_rnf1.py` e `docs/fase2/medicoes/resultados/<etiqueta>/carga_paralelo*`],
    [QS-01 (M1, complementar) e trabalho isolado (N5)], [`carga_rnf1.py <etiqueta> m1` (legendagem de `speech_mandela_177s_1080p.webm` e, 5 s depois, brilho no vídeo de 10 s) e `isolado`], [Igual], [Tempo do trabalho curto, tempo da legendagem e recursos], [5 repetições cada, com p50 e p95, nos três momentos], [`resultados/<etiqueta>/carga_m1*`, `carga_isolado*`],
    [M4 (elasticidade, só `apos-rnf1`)], [Lançar o cenário `paralelo` com a fila vazia e as réplicas no mínimo], [Igual], [Instante em que a fila passa o limiar, instante em que a réplica nova consome a primeira mensagem, e instante em que as réplicas voltam ao mínimo (registos do `video_autoscaler` e dos _workers_)], [5 repetições, com p50 e máximo], [`docs/fase2/medicoes/elasticidade_m4.py` (`specs/002-rnf1-capacidade`, R10) e `resultados/apos-rnf1/elasticidade_m4.json`],
    [QS-02 (N2, principal do CAND-2) e QS-04 (N1)], [Análise estática dos cenários de mudança C1, C2 e C3], [O _commit_ em análise], [Ficheiros a alterar, serviços a reconstruir e tipos de trabalho reimplantados (N2). Efeitos com duas implementações (N1). SLOC e complexidade (N4)], [Uma execução por momento (determinística)], [`docs/fase2/medicoes/rnf2_estaticas.py` e `resultados/<etiqueta>/rnf2_estaticas.json`],
    [QS-02 (N3)], [`docker compose build --no-cache` de cada serviço de vídeo e `docker image inspect`], [A mesma máquina, com imagens da base e novas *construídas no mesmo dia* (o `apt-get` não fixa versões)], [Tamanho de cada imagem (GB) e tempo de construção (s)], [1 construção por imagem, sem outra carga], [`docs/fase2/medicoes/README.md`, secção «RNF2 — N3»],
  ),
)
]

== Resultados das medições

#orientacao[
  Para cada requisito não funcional, apresentem os valores medidos *antes* (_baseline_) e *depois* do _refactoring_, com o
  mesmo método e nas mesmas condições (plano acima), e comparem-nos com o valor-alvo e o valor mínimo aceitável fixados no
  capítulo 6. Os dados brutos e os _scripts_ ficam no repositório entregue.

  Na análise, sejam críticos: o que melhorou, o que não foi atingido e porquê, que outros atributos foram afetados
  (confirmando ou não a matriz de efeitos) e que ameaças à validade das medições existem.
]

#tab([Resultados das medições],
  tabela(
    colunas: (1.3cm, 2.8cm, 2.5cm, 1fr, 1.7cm, 1.9cm, 2.5cm),
    tamanho: 8pt,
    [Cenário], [Medição (o que se mede, unidade)], [Antes (_baseline_)], [Depois], [Valor-alvo], [Mínimo aceitável], [Atingido?],
    [QS-03], [M6: tempo por trabalho com 4 edições em paralelo, p95 (s), e débito (vídeos/min)], [44,0 s e 5,54 vídeos/min (18/11, EV-26). Controlo de 25/11: 24,2 s e 9,95 vídeos/min], [Após CAND-2 (25/11): 21,8 s e 10,96 vídeos/min, ainda um trabalho de cada vez. Após CAND-1 (26/11, réplicas frias): *18,7 s* e *13,1 vídeos/min* (`apos-rnf2` do mesmo dia: 23,9 s e 10,0 vídeos/min). Réplicas quentes: 11,9 s e 20,8 vídeos/min], [≤ 30 s (equivalente a 25/11: ≤ 11 s, cap. 6)], [≥ 2 trabalhos em simultâneo], [Alvo original (≤ 30 s) e mínimo (3 em simultâneo). Meta equivalente (≤ 11 s) não. Melhoria de 22 % face ao mesmo dia],
    [QS-03], [M4: tempo até acrescentar réplicas (s)], [n/a (sem ajuste)], [p50 *11,4 s*, máx. 12,0 s (decisão 10,1 s + arranque 1,3 s). Volta ao mínimo em 62,6 s (p50)], [≤ 30 s], [≤ 60 s], [Alvo],
    [QS-01], [M1: trabalho curto durante uma legendagem, p95 (s) (complementar)], [322,6 s (18/11, EV-18). Controlo de 25/11: 190,6 s], [Após CAND-2 (25/11): 108,9 s. Após CAND-1 (26/11): *18,9 s* (`apos-rnf2` do mesmo dia: 116,3 s)], [≤ 36 s], [≤ 50 s], [Não após o CAND-2. Alvo após o CAND-1 (−84 % face ao mesmo dia)],
    [QS-02], [N2 (C2): tipos de trabalho de vídeo reimplantados], [3 (EV-17)], [1 (também 1 em C1 e em C3)], [1], [1], [Alvo],
    [QS-04], [N1: efeitos com duas implementações], [8 (EV-17)], [0], [0], [0], [Alvo],
    [QS-02], [N3: imagem do serviço de edição (GB)], [1,69 GB (EV-14). Reconstruída a 25/11: 1,66 GB], [0,86 GB (25/11, mesmo dia que a base reconstruída)], [≤ 1,23 GB], [< imagem da base do mesmo dia], [Alvo],
    [—], [Trabalho isolado, p95 (s) (efeito colateral, N5)], [17,8 s (18/11, EV-18). Controlo de 25/11: 6,40 s], [Após CAND-2 (25/11): 5,92 s. Após CAND-1 (26/11): 5,67 s (`apos-rnf2` do mesmo dia: 7,99 s no início da sessão, 6,28 s no fim)], [≤ 17,8 s], [≤ 19,6 s], [Alvo após o CAND-2 (−8 % face à base do mesmo dia) e após o CAND-1 (não piora)],
    [—], [N4: linhas do orquestrador `projects/routes/projects.js` (efeito colateral, H-09)], [2733], [2816 (+3 %)], [—], [≤ 2733 + 10 % (3006)], [Mínimo],
  ),
)

Em resumo, o CAND-2 cumpre todos os valores-alvo e não piora o desempenho. O CAND-1 cumpre os alvos do M4 e do M1, e
o valor mínimo e o alvo original do M6, mas não a meta equivalente de 11 s, por falta de CPU na máquina de medição. As
subsecções seguintes analisam cada requisito. Como se explica no capítulo 6, os tempos comparam-se sempre com uma
medição feita no mesmo dia.

=== CAND-2 — modularidade

*Resultados.* Medido a 25/11 sobre o _commit_ `a3dcdac`, o CAND-2 cumpre os valores-alvo de todas as medidas
estáticas. Uma mudança na legendagem, na extração ou num efeito passa a reimplantar só um tipo de trabalho de vídeo, em
vez de três (N2). Os efeitos deixam de estar duplicados (N1), e a imagem da edição fica com quase metade do tamanho
(−48 %, N3), porque deixa de ter o `faster-whisper` e as fontes das legendas. As saídas são iguais às da base, com os
_hashes_ de imagem e de vídeo todos iguais e todos os testes a passar (secção 10.5).

*Efeito no tempo.* Separar o vídeo em serviços não o tornou mais lento, o que confirma a H-06. Face à base medida
no mesmo dia, o trabalho isolado passa de 6,40 s para 5,92 s e o M6 de 24,2 s para 21,8 s (p95). No M6, os 4 trabalhos
ainda acabam um de cada vez, porque só há uma réplica de edição. O M1 melhora, mas menos do que o previsto na secção
6.2. O trabalho curto passa de 190,6 s para 108,9 s (p95), porque deixa de esperar pela legendagem. Continua, no
entanto, a esperar cerca de 100 s pelo passo de preparação do vídeo, um estágio de edição com que cada legendagem
começa e que mantém as saídas iguais às da base. Esse resto só se resolve com mais réplicas de edição, ou seja, com o
CAND-1. O M2 não muda (1,34 e 1,35 vídeos/min).

*Matriz de efeitos.* Confirma-se o que a matriz da DA-2 previa. O desempenho não piorou (H-06 confirmada), o orquestrador cresceu
só 3 % (H-09, limite de 10 %) e as imagens da edição e da extração ficaram mais pequenas. O cancelamento entre serviços
funciona, mas a devolução da quota não foi verificada à parte (H-08 confirmada em parte, secção 10.5).

*Limitações.* A base de 18/11 foi medida com o portátil na bateria e saiu bastante mais lenta (17,8 s contra 6,40 s no
trabalho isolado, nota do capítulo 6). Por isso, os ganhos de tempo do CAND-2 medem-se contra a base medida de novo a
25/11, na mesma máquina e com o mesmo método (`docs/fase2/medicoes/resultados/controlo-base-2026-11-25/`). As medidas
estáticas e os _hashes_ não dependem da velocidade da máquina, e o N3 compara imagens construídas no mesmo dia, porque o
`apt-get` não fixa versões. Há ainda outras limitações, como as 5 repetições (3 no M2), uma só máquina e um só vídeo por
cenário.

=== CAND-1 — capacidade

O CAND-1 foi medido a 26/11 sobre o _commit_ `dc37d4e` do ramo `rnf1-fase2`, com o `video_autoscaler` ligado. A edição
pode ter 1 a 4 réplicas, a extração 1 a 2 e a legendagem 1, e o `video_autoscaler` consulta as filas a cada 5 s e
espera 60 s antes de reduzir (T003). Os resultados comparam-se com a `apos-rnf2` medida no mesmo dia. Os tempos são os
registados pela própria aplicação, desde o pedido de processamento até o `projects` guardar o resultado.

- *M6 (principal).* Cada repetição começa com uma só réplica de edição, o que chamamos réplicas frias. Nessas
  condições, o p95 passa de 23,9 s para 18,7 s (−22 %) e o débito de 10,0 para 13,1 vídeos/min (+31 %). Antes, os 4
  trabalhos acabavam um de cada vez, em escada (≈ 6, 12, 18 e 24 s). Agora acabam em ≈ 6, 13 e 18 s, com pelo menos 3
  em simultâneo. Cumprem-se o valor mínimo (≥ 2 em simultâneo, REQ-VID-EDIT-011) e o alvo original (≤ 30 s), mas não a
  meta equivalente de 11 s.
- *Porque não se atingiu a meta de 11 s.* Nem com as 4 réplicas já ligadas desde o início, o que chamamos réplicas
  quentes, se chega lá, porque o p95 fica em 11,9 s (20,8 vídeos/min). Há duas razões, ambas medidas. A primeira é o
  CPU. Com 4 réplicas, cada trabalho demora cerca de 2,1 vezes o trabalho isolado (11,9 s contra 5,67 s), e não as 1,7
  vezes em que a meta assentava, porque cada edição usa 2 a 3 CPUs e as 4 juntas disputam os 12 CPUs da máquina. A
  segunda, com réplicas frias, é o tempo até a réplica nova começar a trabalhar (M4, ≈ 11 s), que sozinho já é quase a
  meta. A meta de 11 s era, portanto, otimista para esta máquina. O ganho das réplicas existe e é o que o padrão
  _Competing Consumers_ promete, mais capacidade e débito, mas fica limitado pelo CPU disponível.
- *M4 (elasticidade).* Uma réplica nova começa a trabalhar 11,4 s (p50) depois de os trabalhos chegarem, com cerca de
  10,1 s até o `video_autoscaler` decidir e 1,3 s de arranque (alvo ≤ 30 s ✓). O número de réplicas sobe até 4 em todas
  as repetições e volta ao mínimo 62,6 s (p50) depois do último trabalho, o que corresponde à espera de 60 s
  configurada.
- *M1 (complementar).* É o maior ganho. O trabalho curto passa de 116,3 s para 18,9 s (p95, −84 %, alvo ≤ 36 s ✓),
  porque o `video_autoscaler` acrescenta uma réplica de edição e o trabalho deixa de esperar pelo passo de preparação
  da legendagem. Completa assim o que o CAND-2 deixou por resolver. A legendagem demora o mesmo.
- *M2.* O débito não muda (1,34 e 1,37 vídeos/min), porque é limitado pela legendagem, que tem uma só réplica. Os
  trabalhos curtos esperam um pouco mais (p95 de 16,3 s para 19,3 s), porque chegam ao mesmo tempo que o passo de
  preparação da legendagem e esperam que as réplicas subam.
- *Trabalho isolado.* Fica em 5,67 s (p95), contra 7,99 s e 6,28 s da `apos-rnf2`, por isso as réplicas não o pioram.

*Matriz de efeitos.* Confirma-se o custo em recursos previsto na matriz da DA-1. Em pico, uma réplica de edição chegou a
1 793 MiB, abaixo do limite de 2 150 MiB, e a de legendagem chegou ao limite de 1 638 MiB, sem ser terminada (0
`oom_kill`), porque o sistema libertou memória que usava como _cache_ de ficheiros. Confirma-se também a fiabilidade,
com 0 reentregas nas filas de vídeo e saídas iguais às da base (_hashes_ 9/9 de imagem e de vídeo, com o
`video_autoscaler` ligado).

*Limitações.* A máquina acelerou ao longo da tarde de 26/11. A primeira medição de controlo deu 7,0 s no trabalho
isolado, contra 5,9 s a 25/11, por isso a `apos-rnf2` foi medida de novo, antes e depois da `apos-rnf1`. Entre o início
e o fim da tarde, o trabalho isolado passou de 6,78 s para 6,18 s (p50). O M6 compara-se com a medição do fim, que é a
mais favorável à `apos-rnf2`, e o M1 e o M2 só têm a do início. Os tempos foram tirados dos registos da aplicação, e não
do cliente de medição, porque, com 4 edições a ocupar os 12 CPUs, o cliente (no Windows) deixou de comunicar com o
Docker durante cerca de 30 s em algumas repetições. Nesses casos, 3 dos 20 trabalhos foram vistos pelo cliente com
≈ 41 s, contra 12–18 s na aplicação. Nas restantes repetições, as duas medidas diferem menos de 1 s.

#paisagem[
== Preservação funcional

#tab([Preservação funcional e testes de regressão],
  tabela(
    colunas: (3cm, 3.6cm, 3.6cm, 5.4cm, 1fr),
    tamanho: 8pt,
    [Zona alterada], [Testes de regressão existentes (`Tools/video/tests`, `projects/tests`, …)], [Lacunas de teste], [Testes acrescentados], [Resultado (imagem e vídeo)],
    [DA-2: efeitos em `Tools/effects/`, usados por imagem e vídeo], [`regressao_hashes.py` (imagem e 9 pipelines de vídeo, base guardada em `resultados/base/`) e `Tools/video/tests` (74 testes na base)], [Os testes de vídeo assumem um só serviço e importam `effects.py` desse serviço], [Adaptar os imports dos testes e correr `regressao_hashes.py` em `apos-rnf2` e exigir _hashes_ iguais aos da base (H-07)], [_Hashes_ iguais aos da base: imagem 9/9 e vídeo 9/9 (`apos-rnf2`, 25/11). Testes de vídeo repartidos pelos três serviços: 101 (base: 74), corridos com o repositório montado. H-07 confirmada.],
    [DA-2: encadeamento dos estágios no `projects` (edição → legendas → extração; pré-visualização)], [`projects/tests` (8 testes). O `Tools/video/tests` cobre a divisão em estágios dentro do `process_video`], [Não há testes do encadeamento feito pelo `projects` nem da pré-visualização por estágios], [Teste de cada combinação de estágios (só edição, legendas + edição, edição + extração, as três), incluindo a regra «extração no fim» e a pré-visualização], [`videoStages.test.js` (32 planos de estágios tirados da base) e `videoDispatch.test.js` (encadeamento e pré-visualização), num total de 68 testes no `projects` (contra 8 na base). Na aplicação, V7 e V8 ficam iguais à base, e o corte + extração e a pré-visualização funcionam.],
    [DA-2: cancelamento e quota com o pipeline repartido], [`projects/tests` (verificação do `activeToken`)], [Cancelamento a meio de um pipeline que passa por vários serviços (H-08)], [Cancelar a meio de legendas + filtro + extração e verificar que nenhum resultado é registado e que a quota é devolvida], [`videoStageEnd.test.js` (cancelar entre estágios, erro num estágio intermédio, limpeza dos intermédios) e `runCommit.test.js`. Na aplicação, cancelar a meio não envia o estágio seguinte nem deixa ficheiros, e a T040 confirmou-o também na interface, sem nada registado. A devolução da quota não foi verificada à parte, por isso a H-08 fica confirmada em parte.],
    [DA-1: réplicas e `video_autoscaler`], [Nenhum], [Réplicas em simultâneo (H-01, H-02, H-03), cancelamento com várias réplicas (H-05), retirar réplicas a meio de um trabalho (H-10), legendagens longas (H-04, pouco provável, EV-35)], [Dois trabalhos do mesmo projeto em réplicas diferentes. Arranque de 2 réplicas com o volume `whisper_models` vazio. Cancelar com 2 réplicas ativas. Reduzir réplicas com um vídeo em curso e verificar que ele termina na mesma réplica (TAT-13). Suspender uma réplica (`docker pause`) e verificar que a mensagem passa a outra pelo _heartbeat_. Legendagem do vídeo Premium mais longo (600 s, EV-35) sem reentrega nem a ligação cair], [Testes de concorrência nos serviços (`.part` com nome único, _lock_ do modelo Whisper, paragem ordenada) e da política do `video_autoscaler`. No «Registo» de `specs/002-rnf1-capacidade/quickstart.md`, as H-01, H-02 e H-03 ficaram confirmadas (T014). A H-10 ficou confirmada, com `docker stop` e com redução pelo `video_autoscaler`, sem vídeos recomeçados (T023). Com uma réplica suspensa, a mensagem passa a outra réplica ao fim de 168 s (T024). A H-05 ficou confirmada, porque cancelar com 2 réplicas não regista nada (T025). Na H-04, a legendagem de 599 s não teve reentregas, com o pior estágio em 535 s na máquina de referência (T022). Os _hashes_ com o `video_autoscaler` ligado deram imagem 9/9 e vídeo 9/9 (T028).],
  ),
)

#pagebreak(weak: true)
#tab([Riscos para a preservação funcional e mitigação],
  tabela(
    colunas: (5cm, 3.4cm, 1fr, 5cm),
    tamanho: 8pt,
    [Risco], [Funcionalidade afetada (imagem / vídeo)], [Mitigação], [Teste de regressão (e.g., `Tools/video/tests`, `projects/tests`)],
    [Efeitos com resultado diferente depois de passarem para o módulo partilhado], [Imagem e vídeo (8 efeitos)], [Mover o código sem o alterar e comparar _hashes_ antes e depois (H-07)], [`regressao_hashes.py` (imagem e 9 pipelines de vídeo) e `Tools/video/tests`],
    [Cancelamento ou devolução de quota errados com o pipeline repartido ou com réplicas], [Vídeo], [Manter o controlo no `projects` (`activeToken`) e testar H-05 e H-08], [`projects/tests` + testes novos de cancelamento a meio],
    [A pré-visualização de vídeo deixa de funcionar (hoje vai pela `video_queue`, EV-16)], [Vídeo], [Encaminhar a pré-visualização pelos mesmos estágios, com `preview: true`], [`Tools/video/tests`; teste manual na interface],
    [A extração após edição perde a ordem ou a divisão 70/30 do progresso], [Vídeo], [Manter a regra «extração no fim» ao encadear os estágios], [`Tools/video/tests` (74 testes na base)],
    [Réplicas colidem nos ficheiros temporários ou na _cache_ do Whisper], [Vídeo], [Nomes temporários únicos e descarregar o modelo uma vez (H-02, H-03)], [Dois trabalhos do mesmo projeto em simultâneo e arranque com o volume vazio],
  ),
)
]
