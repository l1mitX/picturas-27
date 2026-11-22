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
    [QS-03 (M6, principal do CAND-1)], [`carga_rnf1.py <etiqueta> paralelo`: 4 utilizadores Premium de teste aplicam brilho a `sample_10s_720p.mp4` ao mesmo tempo, um projeto por trabalho], [A mesma máquina da base (Ryzen 5 5600H, Docker com 12 CPUs e 7,7 GiB), `docker compose up -d --build`, sem outra carga], [Tempo de cada trabalho desde o _Apply_ até o resultado estar disponível; débito; CPU e memória por contentor (`docker stats`)], [5 repetições; p50, p95 e média; nos três momentos `base`, `apos-rnf2`, `apos-rnf1`], [`docs/fase2/medicoes/carga_rnf1.py`; `docs/fase2/medicoes/resultados/<etiqueta>/carga_paralelo*`],
    [QS-01 (M1, complementar) e trabalho isolado (N5)], [`carga_rnf1.py <etiqueta> m1` (legendagem de `speech_mandela_177s_1080p.webm`; 5 s depois, brilho no vídeo de 10 s) e `isolado`], [Igual], [Tempo do trabalho curto; tempo da legendagem; recursos], [5 repetições cada; p50 e p95; três momentos], [`resultados/<etiqueta>/carga_m1*`, `carga_isolado*`],
    [M4 (elasticidade, só `apos-rnf1`)], [Lançar o cenário `paralelo` com a fila vazia e as réplicas no mínimo], [Igual], [Instante em que a fila passa o limiar, instante em que a réplica nova consome a primeira mensagem, e instante em que as réplicas voltam ao mínimo (_logs_ do `video_autoscaler` + API de gestão do RabbitMQ)], [5 repetições; p50 e máximo], [`docs/fase2/medicoes/elasticidade_m4.py` (a criar, `specs/002-rnf1-capacidade`, R10); `resultados/apos-rnf1/elasticidade_m4.json`],
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
    [QS-03], [M6: tempo por trabalho com 4 edições em paralelo, p95 (s); débito (vídeos/min)], [44,0 s; 5,54 vídeos/min (EV-26)], [#preencher[apos-rnf2 / apos-rnf1]], [≤ 30 s], [≥ 2 trabalhos em simultâneo], [#preencher[Alvo / Mínimo / Não]],
    [QS-03], [M4: tempo até acrescentar réplicas (s)], [n/a (sem ajuste)], [#preencher[apos-rnf1]], [≤ 30 s], [≤ 60 s], [#preencher[…]],
    [QS-01], [M1: trabalho curto durante uma legendagem, p95 (s) (complementar)], [322,6 s (EV-18)], [#preencher[apos-rnf2 / apos-rnf1]], [≤ 36 s], [≤ 50 s], [#preencher[…]],
    [QS-02], [N2 (C2): tipos de trabalho de vídeo reimplantados], [3 (EV-17)], [#preencher[apos-rnf2]], [1], [1], [#preencher[…]],
    [QS-04], [N1: efeitos com duas implementações], [8 (EV-17)], [#preencher[apos-rnf2]], [0], [0], [#preencher[…]],
    [QS-02], [N3: imagem do serviço de edição (GB)], [1,69 GB (EV-14)], [#preencher[apos-rnf2, mesmo dia]], [≤ 1,23 GB], [< imagem da base do mesmo dia], [#preencher[…]],
    [—], [Trabalho isolado, p95 (s) (efeito colateral, N5)], [17,8 s (EV-18)], [#preencher[apos-rnf2 / apos-rnf1]], [≤ 17,8 s], [≤ 19,6 s], [#preencher[…]],
  ),
)

*Análise dos resultados* (por requisito não funcional):

#preencher[O que melhorou, o que não foi atingido e porquê, efeitos noutros atributos de qualidade e ameaças à validade das medições (e.g., 5 repetições, uma só máquina, variação das imagens Docker entre dias).]

#paisagem[
== Preservação funcional

#tab([Preservação funcional e testes de regressão],
  tabela(
    colunas: (3.4cm, 4.4cm, 4cm, 1fr, 3cm),
    tamanho: 8pt,
    [Zona alterada], [Testes de regressão existentes (`Tools/video/tests`, `projects/tests`, …)], [Lacunas de teste], [Testes acrescentados], [Resultado (imagem e vídeo)],
    [DA-2: efeitos em `Tools/effects/`, usados por imagem e vídeo], [`regressao_hashes.py` (imagem e 9 pipelines de vídeo, base guardada em `resultados/base/`); `Tools/video/tests` (74 testes na base)], [Os testes de vídeo assumem um só serviço e importam `effects.py` desse serviço], [Adaptar os imports dos testes; correr `regressao_hashes.py` em `apos-rnf2` e exigir _hashes_ iguais aos da base (H-07)], [#preencher[após a implementação]],
    [DA-2: encadeamento dos estágios no `projects` (edição → legendas → extração; pré-visualização)], [`projects/tests` (8 testes); `Tools/video/tests` cobre a divisão em estágios dentro do `process_video`], [Não há testes do encadeamento feito pelo `projects` nem da pré-visualização por estágios], [Teste de cada combinação de estágios (só edição, legendas + edição, edição + extração, as três), incluindo a regra «extração no fim» e a pré-visualização], [#preencher[após a implementação]],
    [DA-2: cancelamento e quota com o pipeline repartido], [`projects/tests` (verificação do `activeToken`)], [Cancelamento a meio de um pipeline que passa por vários serviços (H-08)], [Cancelar a meio de legendas + filtro + extração e verificar que nenhum resultado é registado e que a quota é devolvida], [#preencher[após a implementação]],
    [DA-1: réplicas e `video_autoscaler`], [Nenhum], [Réplicas em simultâneo (H-01, H-02, H-03), cancelamento com várias réplicas (H-05), retirar réplicas a meio de um trabalho (H-10), legendagens longas (H-04, pouco provável: EV-35)], [Dois trabalhos do mesmo projeto em réplicas diferentes; arranque de 2 réplicas com o volume `whisper_models` vazio; cancelar com 2 réplicas ativas; reduzir réplicas com um vídeo em curso e verificar que ele termina na mesma réplica (TAT-13); suspender uma réplica (`docker pause`) e verificar que a mensagem passa a outra pelo _heartbeat_; legendagem do vídeo Premium mais longo (600 s, EV-35) sem reentrega nem a ligação cair], [#preencher[após a implementação]],
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
