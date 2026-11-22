#import "../template.typ": *

// Capítulo inteiro na horizontal (tabelas largas). Para voltar ao vertical, retirar o #paisagem[ ].
#paisagem[
= Candidatos a Requisitos Não Funcionais

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 5 do _template_.

  *Objetivo do capítulo:* escolher *dois* requisitos não funcionais *distintos* a melhorar nesta fase, a partir dos
  cenários de qualidade mais prioritários do capítulo 5. Cada um é classificado segundo a ISO/IEC 25010 (característica e,
  quando aplicável, subcaracterística) e parte de uma fragilidade concreta da solução de base, com evidência.

  Cada candidato é depois especificado, implementado e avaliado por si, ainda que os dois possam estar relacionados.
  A coluna do cenário liga o candidato ao `QS-nn` do capítulo 5, que é a entrada do Exercício 7 (capítulo 7).
]

- *CAND-1* — o processamento de vídeo atende vários pedidos em paralelo, com capacidade ajustada à carga (REQ-VID-EDIT-011).
- *CAND-2* — os tipos de trabalho de vídeo mudam e implantam-se de forma independente (REQ-VID-EDIT-013; mantém o REQ-VID-EDIT-014).

#tab([Candidatos a requisitos não funcionais da Fase 2],
  tabela(
    colunas: (1.6cm, 2.6cm, 3cm, 2.4cm, 2.8cm, 2.6cm, 2cm, 3cm, 2.8cm),
    tamanho: 7.5pt,
    [\#], [Característica / subcaracterística (ISO/IEC 25010)], [Fragilidade na base (evidência)], [Origem (padrão global / vídeo / interação)], [Impacto nos stakeholders (pertinência)], [Exigência técnica (complexidade)], [Cenário (`QS-nn`, cap. 5)], [Escala e método de medição (esboço)], [Pré-requisitos / efeitos colaterais],
    [CAND-1], [Eficiência de desempenho → capacidade], [Um único _worker_ de vídeo processa os pedidos um a um: 4 edições curtas em simultâneo demoram p95 44,0 s, contra 17,8 s de uma sozinha (EV-04, EV-07, EV-26)], [Interação: padrão do vídeo (_worker_ único) sobre a restrição global de um consumidor por fila], [Utilizadores: com vários a editar ao mesmo tempo, cada um espera pelos outros; o critério do REQ-VID-EDIT-011 (≥ 2 vídeos em paralelo no MVP) não se cumpre], [Alta: réplicas por serviço de vídeo e componente de ajuste automático], [QS-03 (principal); QS-01 (complementar, resolvido sobretudo pelo CAND-2)], [Segundos por trabalho (p95) e vídeos/min com 4 edições em paralelo, com `carga_rnf1.py`], [Pré-requisito: CAND-2. Efeitos: mais memória e CPU; acesso à API do Docker (segurança)],
    [CAND-2], [Manutenibilidade → modularidade (e modificabilidade)], [Três tipos de trabalho num serviço e numa imagem; efeitos duplicados (EV-11, EV-12, EV-14, EV-17)], [Padrão do vídeo (_pipeline monolith_)], [Equipa: uma mudança nas legendas reconstrói 1,69 GB e reimplanta todo o vídeo; risco de imagem e vídeo divergirem], [Média: divisão do serviço; cancelamento entre serviços (H-08)], [QS-02 (principal); QS-04 (complementar)], [Contagens de tipos de trabalho reimplantados e de serviços reconstruídos por cenário de mudança, com `rnf2_estaticas.py`], [É pré-requisito do CAND-1. Efeito: possível aumento do tempo por vídeo (H-06) e do orquestrador (H-09)],
  ),
)

Os dois candidatos são *distintos* (características ISO/IEC 25010 diferentes) e nenhum acrescenta funcionalidade: com o
CAND-1, o utilizador obtém os mesmos resultados, apenas mais depressa; com o CAND-2, não vê diferença nenhuma.

== Quantificação

#orientacao[
  Indiquem a *escala* (o que se mede e em que unidade) e o *método de medição* (cenário, carga, ambiente e instrumento) de
  cada candidato. O objetivo é mostrar que o requisito é mensurável e que sabem como o medir.

  Os valores medidos na base, os valores-alvo e os valores mínimos aceitáveis *só são fixados após a medição inicial
  (_baseline_, capítulo 10)*. Não os inventem: preencham as três últimas linhas da tabela só depois de medir a base,
  indicando a origem de cada valor (e.g., medição, referência externa, necessidade de um _stakeholder_).
]

#tab([Quantificação dos requisitos não funcionais],
  tabela(
    colunas: (4.2cm, 1fr, 1fr),
    tamanho: 8.5pt,
    [], [CAND-1], [CAND-2],
    [Escala (o que se mede e em que unidade)], [*M6* (principal): tempo por trabalho, desde o _Apply_ até o resultado estar disponível, com 4 edições curtas em paralelo, em segundos (p50 e p95), e débito (vídeos/min). *M1* (complementar, efeito sobretudo do CAND-2): tempo do trabalho curto submetido durante uma legendagem, em segundos (p50 e p95). *M4* (elasticidade): segundos até o sistema acrescentar réplicas quando a fila cresce, e até as retirar quando esvazia.], [*N2* (principal): por cenário de mudança, número de tipos de trabalho de vídeo reimplantados, de ficheiros alterados e de serviços reconstruídos. Complementares: *N1* (efeitos com duas implementações), *N3* (tamanho, em GB, e tempo de _build_, em s, de cada imagem de vídeo), *N4* (SLOC, complexidade ciclomática máxima, linhas do orquestrador).],
    [Cenário de medição], [M6: cenário do QS-03 (4 utilizadores aplicam brilho a `sample_10s_720p.mp4` ao mesmo tempo, sem legendagem). M1: cenário do QS-01 (legendagem de `speech_mandela_177s_1080p.webm`; 5 s depois, brilho em `sample_10s_720p.mp4`).], [N2: três cenários de mudança fixos — C1 (filtro de brilho, imagem e vídeo), C2 (versão do `faster-whisper`; é o QS-02), C3 (escolha dos instantes na extração de fotogramas).],
    [Carga], [M6: 4 edições curtas simultâneas, 5 repetições. M1: 1 legendagem + 1 edição curta, 5 repetições. Utilizadores Premium de teste, um projeto por trabalho.], [n/a (análise estática do repositório e das imagens Docker).],
    [Ambiente], [A mesma máquina em todas as medições (cap. 2.1), aplicação arrancada com `--build`, sem outra carga.], [O mesmo _commit_ em análise; _build_ sem _cache_ para N3. Como o Dockerfile não fixa as versões dos pacotes do sistema, o tamanho da mesma imagem varia entre dias (1,692 GB e 1,708 GB): a imagem de base e a nova constroem-se no mesmo dia antes de serem comparadas.],
    [Instrumento], [`docs/fase2/medicoes/carga_rnf1.py` (cliente HTTP que imita o utilizador; consulta a cada 0,5 s; recolhe `docker stats`). M4: _logs_ do componente de ajuste e API de gestão do RabbitMQ.], [`docs/fase2/medicoes/rnf2_estaticas.py` (encontra os ficheiros pelo conteúdo e os serviços pelos `COPY` dos Dockerfiles; `radon` 6.0.1 para N4); `docker compose build --no-cache` e `docker image inspect` para N3.],
    [Valor medido na base], [M6: p95 *44,0 s* (p50 28,8 s), *5,54 vídeos/min* (EV-26). M1: p95 *322,6 s* (p50 307,6 s) (EV-18). M4: n/a (não há ajuste). Referência: trabalho isolado p95 17,8 s.], [N2 (C2): *3* tipos reimplantados, 2 ficheiros, 1 serviço reconstruído. C1 e C3: 3 tipos reimplantados. N1: *8* efeitos. N3: *1,69 GB*, 240 s. N4: 601 SLOC, CC máx. 22, orquestrador 2733 linhas (EV-14, EV-17).],
    [Valor-alvo (e origem)], [*M6* p95 ≤ *30 s* com 4 edições em paralelo (estimativa da equipa: se os 4 trabalhos correrem em simultâneo, cada um demora perto dos 17,8 s de um trabalho sozinho; os 30 s deixam margem para disputarem os 12 CPUs da máquina). *M1* (complementar) p95 ≤ *36 s* (2× o trabalho isolado, p95 17,8 s): um efeito curto não deve demorar mais do dobro por haver uma legendagem em curso (necessidade do utilizador). *M4*: réplicas acrescentadas ≤ *30 s* depois de a fila passar o limiar (período de consulta do ajuste + arranque do contentor). *Isolado* (efeito colateral): não piorar, p95 ≤ 17,8 s], [*N2*: C2 reimplanta *1* tipo de trabalho (só a legendagem); C1 reimplanta *1* tipo de vídeo (a edição) e a ferramenta de imagem; C3 reimplanta *1* (só a extração) (objetivo do QS-02). *N1*: *0* efeitos com duas implementações. *N3*: imagem da edição ≤ *1,23 GB* (1,69 GB sem os 457 MB do `faster-whisper`)],
    [Valor mínimo aceitável (e origem)], [*M6*: pelo menos *2* trabalhos processados em simultâneo (critério de aceitação do REQ-VID-EDIT-011 no MVP). *M1* (complementar) p95 ≤ *50 s* (critério de aceitação do REQ-VID-EDIT-010 no MVP: editar em até 5× a duração do vídeo, 5 × 10 s). *M4*: ≤ *60 s*. *Isolado*: p95 ≤ *19,6 s* (base + 10 %, margem para o ruído da medição)], [*N2*: C2 reimplanta *1* tipo de trabalho — sem isto o QS-02 não é cumprido. *N1*: *0* (uma única implementação por efeito). *N3*: imagem da edição menor que a imagem atual do vídeo, construída no mesmo dia. *N4* (efeito colateral, H-09): orquestrador com ≤ 2733 + 10 % linhas],
  ),
)

== Relação entre os dois candidatos

O CAND-2 é *pré-requisito* do CAND-1: o CAND-1 escala cada serviço criado pelo CAND-2, com réplicas ajustadas à fila de
cada tipo de trabalho (ALT-2). A própria divisão do CAND-2 já dá à legendagem a sua fila e deixa de a pôr à frente das
edições curtas, por isso resolve a maior parte do QS-01 (M1) antes de haver réplicas. Por esta razão, a escala principal
do CAND-1 é o *M6* (QS-03), que mede o que só as réplicas melhoram, e o M1 fica como medida complementar, cujo ganho se
atribui sobretudo ao CAND-2. Para que cada candidato seja avaliado por si, as medições fazem-se em *três momentos*, com o
mesmo método: na base, após o CAND-2 e após o CAND-1. O ganho atribuído ao CAND-2 é o que muda entre a base e o segundo
momento; o atribuído ao CAND-1 é o que muda entre o segundo e o terceiro. Há também *sinergia*: as imagens de edição e de extração ficam sem
`faster-whisper`, mais pequenas e mais rápidas a arrancar, o que ajuda a elasticidade (M4). Há um *conflito potencial*
no comportamento temporal: o CAND-2 acrescenta um salto entre serviços e um MP4 intermédio por estágio (H-06), que se
vigia medindo o trabalho isolado após cada etapa. Outros RNF afetados: utilização de recursos (mais contentores),
segurança (o ajuste automático acede à API do Docker) e testabilidade (mais caminhos concorrentes a testar).

== Evidência exploratória (se existir)

#tab([Evidência exploratória],
  tabela(
    colunas: (4cm, 5cm, 1fr),
    tamanho: 8.5pt,
    [Descrição], [Localização (_scripts_, dados, resultados)], [Como repetir],
    [Medições de base do CAND-1 (isolado, M1, M2/M3, M6) com amostras de CPU e memória], [`docs/fase2/medicoes/carga_rnf1.py`; `docs/fase2/medicoes/resultados/base/carga_*.csv` e `*_resumo.json`], [`python docs/fase2/medicoes/carga_rnf1.py base <cenario> --reps R` (comandos no cabeçalho do _script_)],
    [Métricas estáticas do CAND-2 (N1, N2, N4)], [`docs/fase2/medicoes/rnf2_estaticas.py`; `resultados/base/rnf2_estaticas.json`], [ver o cabeçalho do _script_ (corre num contentor com `radon` 6.0.1)],
    [Referência de preservação funcional (_hash_ das saídas de imagem e de 9 _pipelines_ de vídeo)], [`docs/fase2/medicoes/regressao_hashes.py`; `resultados/base/regressao_*.json`], [`regressao_hashes.py imagem base` e `regressao_hashes.py video base` (comandos no cabeçalho do _script_)],
  ),
)
]
