#import "../template.typ": *

// Capítulo inteiro na horizontal (tabelas largas). Para voltar ao vertical, retirar o #paisagem[ ].
#paisagem[
= Cenários de Entrada e Táticas Candidatas

#orientacao[
  *Origem:* Exercício 7, secções 1 e 2 do _template_.

  *Objetivo do capítulo:* partir dos dois cenários já caracterizados e identificar as táticas arquiteturais que os podem
  melhorar. Os cenários vêm do capítulo 5 e os candidatos do capítulo 6 (`QS-nn`, `CAND-n`) e *não são reescritos*: o
  capítulo 5 é o único sítio onde os cenários se caracterizam. Se tiverem de corrigir uma medida da resposta, corrijam-na
  no capítulo 5 e registem a alteração na secção 7.2.

  Nas tabelas seguintes, `QS-01` e `QS-02` designam os cenários de `CAND-1` e `CAND-2`: substituam-nos pelos IDs reais.
]

== Candidatos e cenários de entrada

#tab([Candidatos e cenários de entrada],
  tabela(
    colunas: (1.6cm, 2.4cm, 2.8cm, 2.2cm, 2.8cm, 3cm, 3.4cm, 3.4cm),
    tamanho: 8pt,
    [Candidato], [Cenário (`QS-nn`, cap. 5)], [Característica / subcaracterística (ISO/IEC 25010)], [Evidência], [Origem (padrão global / padrão do vídeo / interação)], [Estímulo a que a tática reage], [Resposta e medida (resumo)], [Escala e método (cap. 6)],
    [CAND-1], [QS-03 (principal); QS-01 (complementar)], [Eficiência de desempenho → capacidade], [EV-04, EV-07, EV-10, EV-26 (QS-01: EV-18)], [Interação entre o padrão do vídeo (_worker_ único) e a restrição global de um consumidor por fila], [Quatro utilizadores submetem ao mesmo tempo 4 edições de brilho a vídeos de 10 s], [Os 4 trabalhos são processados em paralelo. Mede-se o tempo por trabalho (s, p50 e p95) e o débito (vídeos/min)], [M6 com `carga_rnf1.py paralelo` (4 edições simultâneas, 5 repetições). Complementares M1 (`m1`) e M4 (`elasticidade_m4.py`, com os registos do `video_autoscaler`)],
    [CAND-2], [QS-02 (principal); QS-04 (complementar)], [Manutenibilidade → modularidade], [EV-11, EV-13, EV-14, EV-17], [Padrão do vídeo (_pipeline monolith_)], [Um programador atualiza a versão do `faster-whisper` ou o modelo de legendas], [A mudança fica contida na legendagem. Mede-se o número de tipos de trabalho de vídeo reimplantados (contagem)], [N2 (cenário C2) com `rnf2_estaticas.py`. Complementares N1, N3 e N4],
  ),
)

== Alterações feitas ao capítulo 5 (se existirem)

Nenhuma feita durante este exercício. Os cenários entram tal como estão no capítulo 5, onde a equipa já tinha passado o
QS-03 a prioridade 1 e o M6 a escala principal do CAND-1 (secções 5.1 e 6.2).

== Táticas candidatas

#orientacao[
  Identifiquem *pelo menos três táticas por cenário*, de categorias de atributo adequadas (e.g., Desempenho → gerir
  recursos; Disponibilidade → recuperar de falhas). Para cada tática, expliquem como produz a resposta pretendida
  (estímulo → tática → resposta) e se já existe, total ou parcialmente, na base (com evidência).

  Classifiquem cada tática: *A* = _refactoring_ puro; *B* = alteração visível que é o objeto da melhoria; *C* =
  funcionalidade nova, a *rejeitar* nesta fase. Táticas de classe C podem constar da lista, mas não podem ser escolhidas.
]

As táticas seguem os mapas de Bass, Clements & Kazman (_Software Architecture in Practice_, 4.ª ed.). Para o QS-03 usam-se táticas de desempenho, que controlam a procura e gerem os recursos. Para o QS-02 usam-se táticas de modificabilidade, que aumentam a coesão, reduzem o acoplamento e adiam a ligação. A TAT-13 é de disponibilidade. Como nos slides da aula 7, uma tática de desempenho, neste caso réplicas que aparecem e desaparecem, cria a necessidade de uma tática de disponibilidade, que passa a ser o seu pré-requisito.

#tab([Táticas candidatas],
  tabela(
    colunas: (1.4cm, 1.4cm, 3.2cm, 4cm, 5.2cm, 4.2cm, 1.4cm),
    tamanho: 7.5pt,
    [ID], [Cenário], [Atributo → categoria], [Tática], [Como produz a resposta (estímulo → tática → resposta)], [Já existe na base? (evidência)], [Classe (A/B/C)],
    [TAT-01], [QS-03], [Desempenho → gerir recursos], [Replicar computação, com várias instâncias de cada _worker_ de vídeo a consumir da mesma fila (_Competing Consumers_)], [4 edições chegam → cada réplica livre consome uma mensagem → os 4 trabalhos correm em paralelo], [Parcial — o `ack` manual (EV-10) e a ausência de `container_name` permitem réplicas (H-01), mas há uma só instância (EV-07)], [A],
    [TAT-02], [QS-03], [Desempenho → gerir recursos], [Aumentar recursos de forma elástica, ajustando o número de réplicas ao tamanho de cada fila], [A fila cresce → o ajuste acrescenta réplicas → o tempo de espera desce; a fila esvazia → as réplicas extra são retiradas], [Não — não há ajuste nem réplicas (EV-07)], [A],
    [TAT-03], [QS-03], [Desempenho → gerir recursos], [Introduzir concorrência dentro do _worker_, com `prefetch` > 1 e várias _threads_ no mesmo contentor], [4 edições chegam → o mesmo contentor processa-as em _threads_ paralelas], [Não — `prefetch_count=1` e processamento na _thread_ da ligação (EV-04, EV-10, EV-33)], [A],
    [TAT-04], [QS-03], [Desempenho → controlar a procura], [Priorizar eventos, com uma fila que dá prioridade aos trabalhos curtos], [Um trabalho curto chega → passa à frente dos longos *em espera* → mas não à frente do que está em curso], [Não — a `video_queue` não tem prioridades (EV-22)], [A],
    [TAT-05], [QS-03], [Desempenho → controlar a procura], [Gerir pedidos de trabalho, recusando ou adiando pedidos quando a fila passa um limite (_throttling_)], [Muitos pedidos chegam → os excedentes são recusados com uma mensagem → os aceites esperam menos], [Não], [C],
    [TAT-06], [QS-03], [Desempenho → gerir recursos], [Aumentar recursos de cada contentor (mais CPU ou _threads_ do ffmpeg por trabalho)], [4 edições chegam → cada uma termina um pouco mais depressa → mas continuam a ser feitas uma de cada vez], [Parcial — `WHISPER_CPU_THREADS: 2` e ffmpeg com o número de _threads_ por omissão (EV-07)], [A],
    [TAT-13], [QS-03], [Disponibilidade → recuperar (reintrodução ordenada) e detetar falhas (_heartbeat_)], [Retirar uma réplica só depois de acabar o trabalho em curso. Ao receber o sinal de paragem, a réplica deixa de consumir, termina, confirma e sai. Além disso, o vídeo é processado numa _thread_ separada da ligação, para o _heartbeat_ voltar a estar ativo], [O ajuste retira uma réplica ou uma réplica bloqueia → a réplica termina o vídeo antes de sair, ou o broker deteta o bloqueio pelo _heartbeat_ e entrega a mensagem a outra → nenhum vídeo recomeça do zero nem fica preso 30 min], [Parcial — o `ack` manual devolve a mensagem à fila se o processo morrer (EV-10), mas o _heartbeat_ está desligado (EV-33) e a _thread_ separada foi adiada pelo PL1-G4 (EV-34)], [A],
    [TAT-07], [QS-02], [Modificabilidade → aumentar a coesão], [Dividir o módulo, com um serviço por tipo de trabalho (edição, legendagem, extração), cada um com o seu Dockerfile], [Mudança no `faster-whisper` → só o serviço de legendagem muda e é reconstruído → edição e extração não são reimplantadas], [Parcial — o código já está em ficheiros separados (EV-11), mas o serviço, o processo e a imagem são únicos (EV-13, EV-14)], [A],
    [TAT-08], [QS-02], [Modificabilidade → reduzir o acoplamento (abstrair serviços comuns)], [Extrair os 8 efeitos para um módulo partilhado entre as ferramentas de imagem e o vídeo, com um ficheiro por efeito], [Mudança num efeito (QS-04) → altera-se um só ficheiro → imagem e vídeo usam a mesma implementação], [Não — 8 efeitos copiados (EV-12). A DA-06 do PL1-G4 deixou a extração para a Fase 2 (EV-32)], [A],
    [TAT-09], [QS-02], [Modificabilidade → reduzir o acoplamento (usar um intermediário)], [Os serviços de vídeo só comunicam por filas, e o encadeamento dos estágios fica no `projects`], [Os serviços de vídeo não se conhecem entre si → mudar um não obriga a mudar os outros], [Parcial — o _broker_ já é o intermediário entre o `projects` e os _workers_ (EV-03), mas o encadeamento do vídeo é interno ao `video_tool` (EV-13)], [A],
    [TAT-10], [QS-02], [Modificabilidade → aumentar a coesão], [Monólito modular, com um registo de efeitos e módulos internos no mesmo `video_tool` (ALT-3)], [Mudança no `faster-whisper` → fica num módulo → mas a imagem e a implantação continuam únicas], [Parcial — ficheiros separados (EV-11)], [A],
    [TAT-11], [QS-02], [Modificabilidade → adiar a ligação], [Escolher o modelo de legendas por configuração], [Trocar de modelo → muda-se uma variável de ambiente, sem alterar código], [Sim — `WHISPER_MODEL` (EV-07), mas atualizar a biblioteca continua a reconstruir tudo], [A],
    [TAT-12], [QS-02], [Modificabilidade → aumentar a coesão], [Dividir o módulo ao nível do efeito, com um serviço por efeito de vídeo (ALT-1)], [Mudança num efeito → só esse serviço muda → mas cada serviço descodifica e recodifica o vídeo], [Não — um só serviço trata todos os tipos de trabalho (EV-11)], [A],
  ),
)
]
