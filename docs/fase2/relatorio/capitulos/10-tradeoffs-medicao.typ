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
    [DA-1], [↑ capacidade (M6, M4); = trabalho isolado; ↓ utilização de recursos em pico], [↑ redundância: outra réplica retoma a mensagem; ↓ risco de vídeos recomeçados ao retirar réplicas (H-10)], [↓ o `video_autoscaler` acede ao _socket_ do Docker], [↑ menos espera com vários utilizadores], [↓ mais uma peça e mais parâmetros (mínimo, máximo, limiar); ↓ caminhos concorrentes a testar (H-05)], [A capacidade melhora à custa de memória (até 2 506 MiB por réplica de legendagem, EV-18) e de um componente com privilégios. Gestão: limites de memória por serviço, mínimo e máximo de réplicas, _socket_ montado só no `video_autoscaler`, e retirar só réplicas sem trabalho (TAT-13). *Recursos / custo ↓:* mais contentores em pico (até 2 506 MiB por réplica de legendagem) e um serviço novo sempre ligado; ↑ sem carga, as réplicas voltam ao mínimo],
    [DA-2], [↑ M1 (a legendagem deixa de bloquear a edição); ↓ possível no trabalho isolado (salto extra e MP4 intermédio, H-06)], [↓ mais pontos de falha e cancelamento entre serviços (H-08); = `ack` manual em cada serviço], [=], [\= (o utilizador vê os mesmos resultados)], [↑ modularidade (N1, N2, N3); ↑ cada serviço testa-se sozinho; ↓ o encadeamento no `projects` precisa de testes novos e o orquestrador pode crescer (H-09)], [O ganho em manutenibilidade pode custar desempenho por vídeo. Gestão: cortar só nos estágios que já existem (EV-15) e medir o trabalho isolado no momento `apos-rnf2` (N5: não piorar, mínimo p95 ≤ 19,6 s). *Recursos / custo:* ↑ imagens mais pequenas para a edição e a extração (sem os 457 MB do `faster-whisper`); ↓ três imagens e três serviços em vez de um; ↓ um MP4 intermédio por estágio em `image_data`],
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
    [DA-1], [DA-2], [*Conflito potencial*], [Ambas aumentam o número de contentores e de caminhos concorrentes: mais memória (EV-18) e mais casos de cancelamento a testar (H-05, H-08)],
  ),
)

#paisagem[
== Plano de medição

As medições fazem-se em três momentos, com o mesmo método e na mesma máquina: `base`, `apos-rnf2` e `apos-rnf1`
(`docs/fase2/medicoes/README.md`, «Antes de medir»). O ganho do CAND-2 é o que muda entre `base` e `apos-rnf2`; o do
CAND-1, entre `apos-rnf2` e `apos-rnf1` (secção 6.2).

#tab([Plano de medição],
  tabela(
    colunas: (2.6cm, 4.6cm, 3.6cm, 4.4cm, 3cm, 1fr),
    tamanho: 8pt,
    [Cenário], [Cenário de teste e carga], [Ambiente (máquina, recursos, versões)], [O que se regista], [Repetições e agregação], [Onde ficam os _scripts_ e os dados],
    [QS-03 (M6, principal do CAND-1)], [`carga_rnf1.py <etiqueta> paralelo`: 4 utilizadores Premium de teste aplicam brilho a `sample_10s_720p.mp4` ao mesmo tempo, um projeto por trabalho], [A mesma máquina da base (Ryzen 5 5600H, Docker com 12 CPUs e 7,7 GiB), `docker compose up -d --build`, sem outra carga], [Tempo de cada trabalho desde o _Apply_ até o resultado estar disponível (na `apos-rnf1`, o valor oficial é o do lado da aplicação: do `POST …/process` ao registo do resultado, nos _logs_ do `projects`); débito; CPU e memória por contentor (`docker stats`)], [5 repetições; p50, p95 e média; nos três momentos `base`, `apos-rnf2`, `apos-rnf1`. Na `apos-rnf1`, 120 s de pausa antes de cada repetição, para começar com as réplicas no mínimo (frias)], [`docs/fase2/medicoes/carga_rnf1.py`; `docs/fase2/medicoes/resultados/<etiqueta>/carga_paralelo*`],
    [QS-01 (M1, complementar) e trabalho isolado (N5)], [`carga_rnf1.py <etiqueta> m1` (legendagem de `speech_mandela_177s_1080p.webm`; 5 s depois, brilho no vídeo de 10 s) e `isolado`], [Igual], [Tempo do trabalho curto; tempo da legendagem; recursos], [5 repetições cada; p50 e p95; três momentos], [`resultados/<etiqueta>/carga_m1*`, `carga_isolado*`],
    [M4 (elasticidade, só `apos-rnf1`)], [Lançar o cenário `paralelo` com a fila vazia e as réplicas no mínimo], [Igual], [Instante em que a fila passa o limiar, instante em que a réplica nova consome a primeira mensagem, e instante em que as réplicas voltam ao mínimo (_logs_ do `video_autoscaler` + API de gestão do RabbitMQ)], [5 repetições; p50 e máximo], [`docs/fase2/medicoes/elasticidade_m4.py` (`specs/002-rnf1-capacidade`, R10); `resultados/apos-rnf1/elasticidade_m4.json`],
    [QS-02 (N2, principal do CAND-2) e QS-04 (N1)], [Análise estática dos cenários de mudança C1, C2 e C3], [O _commit_ em análise], [Ficheiros a alterar, serviços a reconstruir, tipos de trabalho reimplantados (N2); efeitos com duas implementações (N1); SLOC e complexidade (N4)], [Uma execução por momento (determinística)], [`docs/fase2/medicoes/rnf2_estaticas.py`; `resultados/<etiqueta>/rnf2_estaticas.json`],
    [QS-02 (N3)], [`docker compose build --no-cache` de cada serviço de vídeo e `docker image inspect`], [A mesma máquina; imagens de base e novas *construídas no mesmo dia* (o `apt-get` não fixa versões)], [Tamanho de cada imagem (GB) e tempo de _build_ (s)], [1 _build_ por imagem, sem outra carga], [{ficheiro de resultados a criar em `resultados/<etiqueta>/`}],
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
    colunas: (1.4cm, 1fr, 2.2cm, 2.2cm, 1.6cm, 2.2cm, 1.8cm),
    tamanho: 8pt,
    [Cenário], [Medição (o que se mede, unidade)], [Antes (_baseline_)], [Depois], [Valor-alvo], [Mínimo aceitável], [Atingido?],
    [QS-03], [M6: tempo por trabalho com 4 edições em paralelo, p95 (s); débito (vídeos/min)], [44,0 s; 5,54 vídeos/min (18/11, EV-26). Controlo de 25/11: 24,2 s; 9,95 vídeos/min], [Após CAND-2 (25/11): 21,8 s; 10,96 vídeos/min, ainda um trabalho de cada vez. Após CAND-1 (26/11, réplicas frias): *18,7 s*; *13,1 vídeos/min* (`apos-rnf2` do mesmo dia: 23,9 s; 10,0 vídeos/min). Réplicas quentes: 11,9 s; 20,8 vídeos/min], [≤ 30 s (equivalente a 25/11: ≤ 11 s, cap. 6)], [≥ 2 trabalhos em simultâneo], [Mínimo (3 em simultâneo); meta equivalente não (−22 % face ao mesmo dia)],
    [QS-03], [M4: tempo até acrescentar réplicas (s)], [n/a (sem ajuste)], [p50 *11,4 s*, máx. 12,0 s (decisão 10,1 s + arranque 1,3 s); volta ao mínimo: p50 62,6 s], [≤ 30 s], [≤ 60 s], [Alvo],
    [QS-01], [M1: trabalho curto durante uma legendagem, p95 (s) (complementar)], [322,6 s (18/11, EV-18). Controlo de 25/11: 190,6 s], [Após CAND-2 (25/11): 108,9 s. Após CAND-1 (26/11): *18,9 s* (`apos-rnf2` do mesmo dia: 116,3 s)], [≤ 36 s], [≤ 50 s], [Ainda não após o CAND-2; alvo após o CAND-1 (−84 % face ao mesmo dia)],
    [QS-02], [N2 (C2): tipos de trabalho de vídeo reimplantados], [3 (EV-17)], [1 (também 1 em C1 e em C3)], [1], [1], [Alvo],
    [QS-04], [N1: efeitos com duas implementações], [8 (EV-17)], [0], [0], [0], [Alvo],
    [QS-02], [N3: imagem do serviço de edição (GB)], [1,69 GB (EV-14). Reconstruída a 25/11: 1,66 GB], [0,86 GB (25/11, mesmo dia que a base reconstruída)], [≤ 1,23 GB], [< imagem da base do mesmo dia], [Alvo],
    [—], [Trabalho isolado, p95 (s) (efeito colateral, N5)], [17,8 s (18/11, EV-18). Controlo de 25/11: 6,40 s], [Após CAND-2 (25/11): 5,92 s. Após CAND-1 (26/11): 5,67 s (`apos-rnf2` do mesmo dia: 7,99 s no início da sessão, 6,28 s no fim)], [≤ 17,8 s], [≤ 19,6 s], [Alvo após o CAND-2 (−8 % face à base do mesmo dia) e após o CAND-1 (não piora)],
    [—], [N4: linhas do orquestrador `projects/routes/projects.js` (efeito colateral, H-09)], [2733], [2816 (+3 %)], [—], [≤ 2733 + 10 % (3006)], [Mínimo],
  ),
)

*Análise dos resultados* (por requisito não funcional):

*CAND-2 (modularidade, medido a 25/11 sobre o _commit_ `a3dcdac`).* Cumpre os valores-alvo de todas as medidas
estáticas: uma mudança na legendagem, na extração ou num efeito reimplanta só um tipo de trabalho de vídeo (N2, base: 3);
os 8 efeitos passam a ter uma única implementação, em `Tools/effects/` (N1, base: 8); a imagem da edição passa de 1,66 GB
para 0,86 GB (−48 %, N3), porque deixa de ter o `faster-whisper` e as fontes das legendas; o orquestrador cresce 3 %
(N4, mínimo +10 %). As saídas são iguais às da base: os _hashes_ de imagem (9 casos) e de vídeo (9 pipelines) coincidem,
e passam os testes de vídeo (101, base: 74) e do `projects` (68, base: 8).

*Comportamento temporal.* Comparando com a base medida no mesmo dia, o salto entre serviços e o MP4 intermédio por
estágio não pioraram o desempenho (H-06 refutada): o trabalho isolado passa de 6,40 s para 5,92 s (p95) e o M6 de 24,2 s
para 21,8 s (p95), com os 4 trabalhos ainda a acabar um de cada vez. No M1, o trabalho curto passa de 190,6 s para
108,9 s (p95; p50 de 165,0 s para 106,0 s, −36 %): deixa de esperar pela legendagem em si, mas continua a esperar
cerca de 100 s pelo estágio de edição sem efeitos com que a legendagem começa. Esse estágio recodifica o vídeo, como o
`process_video` fazia na base, e é o que mantém as saídas iguais às da base. A previsão da secção 6.2 (o CAND-2
resolveria a maior parte do M1) cumpriu-se, por isso, só em parte; o resto depende das réplicas do serviço de edição
(CAND-1). No M2 não há diferença (1,34 e 1,35 vídeos/min), porque a legendagem já não atrasava os curtos submetidos ao
mesmo tempo.

*Ameaças à validade.* A velocidade da máquina variou entre dias: a base, medida de novo a 25/11 com o mesmo _script_,
os mesmos parâmetros e o mesmo aquecimento, fez o trabalho isolado em 6,40 s, contra 17,8 s a 18/11 (e o M6 em 24,2 s,
contra 44,0 s). A causa é a alimentação do portátil: a base de 18/11 foi medida na aula, com o portátil a funcionar
na bateria e, segundo quem mediu, provavelmente em modo de poupança de energia; as medições de 25/11 foram feitas com o
portátil ligado à tomada. Para não atribuir ao _refactoring_ um ganho que é da máquina, os tempos comparam-se só entre medições do mesmo
dia: a base de 25/11 (`docs/fase2/medicoes/resultados/controlo-base-2026-11-25/`) e a `apos-rnf2`. Os valores de 18/11
mantêm-se nas tabelas, porque foram eles que fixaram os valores-alvo do capítulo 6, que não se alteram. As medidas
estáticas (N1, N2, N4) e os _hashes_ não dependem da velocidade da máquina; o N3 compara imagens construídas no mesmo
dia, porque o `apt-get` não fixa versões (a imagem da base tem 1,69 GB num dia e 1,66 GB noutro). Outras limitações:
5 repetições (3 no M2), uma só máquina e um só vídeo por cenário.

*CAND-1 (capacidade, medido a 26/11 sobre o _commit_ `dc37d4e` do ramo `rnf1-fase2`).* Com as réplicas e o
`video_autoscaler` ligados (edição 1–4, legendagem 1–1, extração 1–2; consulta a cada 5 s, espera de 60 s antes de
reduzir; T003), e comparando com a `apos-rnf2` medida no mesmo dia:

- *M6 (principal).* Com réplicas frias (todas as repetições começam com uma réplica de edição), o p95 passa de 23,9 s
  para 18,7 s (−22 %) e o débito de 10,0 para 13,1 vídeos/min (+31 %). Os 4 trabalhos deixam de acabar em escada (≈ 6,
  12, 18 e 24 s) e passam a acabar em ≈ 6, 13 e 18 s: a réplica que já existe faz 2 dos 4 e as réplicas novas fazem os
  outros, com pelo menos 3 trabalhos em simultâneo. O valor mínimo (≥ 2 em simultâneo, REQ-VID-EDIT-011) é cumprido e
  o alvo original (≤ 30 s) também, mas a meta equivalente (≤ 11 s) não, nem com as réplicas já ligadas (quentes: p95
  11,9 s, 20,8 vídeos/min). Há duas razões, ambas medidas. (1) Com 4 réplicas, cada trabalho demora ≈ 2,1 vezes o
  trabalho isolado (11,9 s contra 5,67 s), e não as 1,7 vezes em que a meta assentava: cada edição usa 2 a 3 CPUs e as
  4 juntas disputam os 12 CPUs da máquina. (2) Com réplicas frias, soma-se o tempo até a réplica nova consumir (M4,
  ≈ 11 s), que sozinho é quase a meta. A meta de 11 s era, portanto, otimista para esta máquina; o ganho das réplicas
  existe e é o que o padrão _Competing Consumers_ promete (capacidade e débito), limitado pelo CPU disponível.
- *M4 (elasticidade).* A réplica nova consome a primeira mensagem 11,4 s (p50; máx. 12,0 s) depois da submissão:
  ≈ 10,1 s até à decisão do `video_autoscaler` e ≈ 1,3 s de arranque
  do contentor (alvo ≤ 30 s ✓). Sobe até 4 réplicas em todas as repetições e volta ao mínimo 62,6 s (p50) depois do
  último trabalho, o que corresponde à espera de 60 s configurada.
- *M1 (complementar).* É o maior ganho: o trabalho curto passa de 116,3 s para 18,9 s (p95, −84 %; alvo ≤ 36 s ✓).
  Deixa de esperar, na fila da edição, pelo estágio de edição com que a legendagem começa, porque o `video_autoscaler`
  acrescenta uma réplica de edição. Completa assim o que o CAND-2 deixou por resolver (secção anterior). A legendagem
  demora o mesmo (165,7 s e 168,3 s, p50).
- *M2.* O débito não muda (1,34 e 1,37 vídeos/min), porque é limitado pela legendagem (≈ 170 s, uma só réplica). O
  p95 dos curtos sobe de 16,3 s para 19,3 s: os curtos chegam ao mesmo tempo que o estágio de edição da legendagem e
  esperam pela subida das réplicas.
- *Trabalho isolado (N5).* 5,67 s (p95), contra 7,99 s e 6,28 s da `apos-rnf2` no início e no fim da sessão: as
  réplicas não pioram o trabalho isolado.
- *Matriz de efeitos.* Confirma-se o custo em recursos: em pico, cada réplica de edição chegou a 1 793 MiB (limite
  2 150 MiB) e a réplica de legendagem chegou ao limite de 1 638 MiB no M1 e no M2, sem ser morta (0 `oom_kill`; o
  _kernel_ libertou _cache_ de ficheiros). Confirma-se também a fiabilidade: 0 reentregas nas filas de vídeo
  (107 mensagens da edição, 8 da legendagem) e as saídas iguais às da base (_hashes_ de imagem 9/9 e de vídeo 9/9, com
  o `video_autoscaler` ligado).

*Ameaças à validade (CAND-1).* A sentinela (trabalho isolado com o código da `apos-rnf2`) deu 7,0 s, contra 5,9 s a
25/11, por isso a `apos-rnf2` foi medida de novo no mesmo dia, antes e depois da `apos-rnf1`. A máquina acelerou ao
longo da tarde (trabalho isolado do lado da aplicação, p50: 6,78 s, 5,46 s com o RNF1 e 6,18 s no fim), e o M6
compara-se com o controlo do fim, o mais favorável à `apos-rnf2`; o M1 e o M2 só têm o controlo do início. Os tempos
do CAND-1 são medidos do lado da aplicação (registos do `projects`), porque, com 4 edições a ocupar os 12 CPUs, os
pedidos do cliente de medição (no Windows) deixaram de chegar ao Docker durante ≈ 30 s em algumas repetições: no M6
frio, 3 dos 20 trabalhos foram vistos pelo cliente ≈ 41 s, contra 12–18 s do lado da aplicação. Sem esta paragem, as
duas medidas diferem menos de 1 s; nas medições anteriores, com uma edição de cada vez, ela não aconteceu.

#paisagem[
== Preservação funcional

#tab([Preservação funcional e testes de regressão],
  tabela(
    colunas: (3.4cm, 4.4cm, 4cm, 1fr, 3cm),
    tamanho: 8pt,
    [Zona alterada], [Testes de regressão existentes (`Tools/video/tests`, `projects/tests`, …)], [Lacunas de teste], [Testes acrescentados], [Resultado (imagem e vídeo)],
    [DA-2: efeitos em `Tools/effects/`, usados por imagem e vídeo], [`regressao_hashes.py` (imagem e 9 pipelines de vídeo, base guardada em `resultados/base/`); `Tools/video/tests` (74 testes na base)], [Os testes de vídeo assumem um só serviço e importam `effects.py` desse serviço], [Adaptar os imports dos testes; correr `regressao_hashes.py` em `apos-rnf2` e exigir _hashes_ iguais aos da base (H-07)], [_Hashes_ iguais aos da base: imagem 9/9 e vídeo 9/9 (`apos-rnf2`, 25/11). Testes de vídeo repartidos pelos três serviços: 101 (base: 74), corridos com o repositório montado. H-07 confirmada.],
    [DA-2: encadeamento dos estágios no `projects` (edição → legendas → extração; pré-visualização)], [`projects/tests` (8 testes); `Tools/video/tests` cobre a divisão em estágios dentro do `process_video`], [Não há testes do encadeamento feito pelo `projects` nem da pré-visualização por estágios], [Teste de cada combinação de estágios (só edição, legendas + edição, edição + extração, as três), incluindo a regra «extração no fim» e a pré-visualização], [`videoStages.test.js` (32 planos de estágios tirados da base) e `videoDispatch.test.js` (encadeamento e pré-visualização): 68 testes no `projects` (base: 8). Na aplicação: V7 e V8 iguais à base, corte + extração e pré-visualização a funcionar.],
    [DA-2: cancelamento e quota com o pipeline repartido], [`projects/tests` (verificação do `activeToken`)], [Cancelamento a meio de um pipeline que passa por vários serviços (H-08)], [Cancelar a meio de legendas + filtro + extração e verificar que nenhum resultado é registado e que a quota é devolvida], [`videoStageEnd.test.js` (cancelar entre estágios, erro num estágio intermédio, limpeza dos intermédios) e `runCommit.test.js`. Na aplicação, cancelar a meio não envia o estágio seguinte nem deixa ficheiros. A devolução da quota não foi verificada à parte (H-08 confirmada em parte; falta a T040).],
    [DA-1: réplicas e `video_autoscaler`], [Nenhum], [Réplicas em simultâneo (H-01, H-02, H-03), cancelamento com várias réplicas (H-05), retirar réplicas a meio de um trabalho (H-10), legendagens longas (H-04, pouco provável: EV-35)], [Dois trabalhos do mesmo projeto em réplicas diferentes; arranque de 2 réplicas com o volume `whisper_models` vazio; cancelar com 2 réplicas ativas; reduzir réplicas com um vídeo em curso e verificar que ele termina na mesma réplica (TAT-13); suspender uma réplica (`docker pause`) e verificar que a mensagem passa a outra pelo _heartbeat_; legendagem do vídeo Premium mais longo (600 s, EV-35) sem reentrega nem a ligação cair], [Testes de concorrência nos serviços (`.part` com nome único, _lock_ do modelo Whisper, paragem ordenada) e da política do `video_autoscaler`. Na aplicação (`specs/002-rnf1-capacidade/quickstart.md`, «Registo»): H-01, H-02 e H-03 confirmadas (T014); H-10 confirmada, com `docker stop` e com redução pelo `video_autoscaler`: 0 vídeos recomeçados (T023); réplica suspensa: a mensagem passa a outra réplica ao fim de 168 s (T024); H-05 confirmada: cancelar com 2 réplicas não regista nada (T025); H-04: legendagem de 599 s sem reentrega, pior estágio 535 s na máquina de referência (T022). _Hashes_ com o `video_autoscaler` ligado: imagem 9/9 e vídeo 9/9 (T028).],
  ),
)

#tab([Riscos para a preservação funcional e mitigação],
  tabela(
    colunas: (5cm, 3.4cm, 1fr, 5cm),
    tamanho: 8pt,
    [Risco], [Funcionalidade afetada (imagem / vídeo)], [Mitigação], [Teste de regressão (e.g., `Tools/video/tests`, `projects/tests`)],
    [Efeitos com resultado diferente depois de passarem para o módulo partilhado], [Imagem e vídeo (8 efeitos)], [Mover o código sem o alterar; comparar _hashes_ antes e depois (H-07)], [`regressao_hashes.py` (imagem e 9 pipelines de vídeo); `Tools/video/tests`],
    [Cancelamento ou devolução de quota errados com o pipeline repartido ou com réplicas], [Vídeo], [Manter o controlo no `projects` (`activeToken`); testar H-05 e H-08], [`projects/tests` + testes novos de cancelamento a meio],
    [A pré-visualização de vídeo deixa de funcionar (hoje vai pela `video_queue`, EV-16)], [Vídeo], [Encaminhar a pré-visualização pelos mesmos estágios, com `preview: true`], [`Tools/video/tests`; teste manual na interface],
    [A extração após edição perde a ordem ou a divisão 70/30 do progresso], [Vídeo], [Manter a regra «extração no fim» ao encadear os estágios], [`Tools/video/tests` (74 testes na base)],
    [Réplicas colidem nos ficheiros temporários ou na _cache_ do Whisper], [Vídeo], [Nomes temporários únicos; descarregar o modelo uma vez (H-02, H-03)], [Dois trabalhos do mesmo projeto em simultâneo; arranque com o volume vazio],
  ),
)
]
