#import "../template.typ": *

= Decisões Arquiteturais

#orientacao[
  *Origem:* Exercício 7, secção 3 do _template_.

  Uma decisão por cenário (`DA-1` para `QS-01`, `DA-2` para `QS-02`). Cada decisão é um pequeno registo, ao estilo ADR: o
  contexto, a tática escolhida, a estrutura ou padrão que a realiza, as alternativas consideradas e a razão da sua
  rejeição, as consequências positivas e negativas, e os elementos arquiteturais afetados.

  Só vale a pena registar uma decisão se havia *alternativas reais* (as táticas do capítulo 7 que não foram escolhidas).
  Justifiquem a escolha pelo cenário e pelas restrições da fase: rejeitem as táticas de classe C, porque a fase é de
  _refactoring_, e avaliem o risco de regressão do âmbito da alteração.

  *Depois de implementada*, completem cada decisão com as referências da implementação (_commits_ ou _pull requests_ no
  repositório entregue) e com os desvios face ao que foi decidido, explicando porquê. A vista «depois» do capítulo 9
  deve corresponder ao que foi efetivamente implementado.
]

As duas decisões realizam a ALT-2 (capítulo 4). Implementam-se pela ordem inversa da numeração: primeiro a DA-2 (modularidade), que é pré-requisito, e depois a DA-1 (capacidade). Mede-se nos três momentos combinados pela equipa: `base`, `apos-rnf2` e `apos-rnf1` (`docs/fase2/medicoes/README.md`, «Antes de medir»).

== DA-1 — Réplicas por serviço de vídeo com ajuste automático pelo tamanho da fila (cenário QS-03)

#tab([Decisão arquitetural DA-1],
  tabela-campos(
    [Contexto], [Todo o vídeo é processado por um único _worker_, que trata uma mensagem de cada vez (EV-04, EV-07, EV-10). No QS-03, 4 edições curtas simultâneas demoram p95 44,0 s, contra 17,8 s de uma sozinha (EV-26). Depois da DA-2, cada tipo de trabalho tem a sua fila, mas cada fila continua com um só consumidor. Restrição da fase: _refactoring_; o utilizador obtém os mesmos resultados.],
    [Tática(s) escolhida(s)], [TAT-01 (replicar computação) e TAT-02 (aumentar recursos de forma elástica), com a TAT-13 (retirar réplicas só sem trabalho e _heartbeat_ numa _thread_ separada) como tática de disponibilidade pré-requisito.],
    [Estrutura / padrão que a realiza], [_Competing Consumers_ em cada fila de vídeo. Um serviço novo, `video_autoscaler`, consulta periodicamente o tamanho de cada fila na API de gestão do RabbitMQ e ajusta, através da API do Docker, o número de réplicas de `video_edit`, `video_subtitles` e `video_frames`, entre um mínimo e um máximo por serviço. Para a TAT-13, cada _worker_ trata o sinal de paragem (deixa de consumir, termina o vídeo em curso, confirma e sai), o `docker stop` dá-lhe tempo suficiente para isso, e o processamento passa para uma _thread_ separada da ligação, com o _heartbeat_ ativo.],
    [Alternativas consideradas e razão de rejeição], [*TAT-01 sozinha* (réplicas fixas): melhora o M6, mas a capacidade não acompanha a carga (sem M4) e gasta memória sem trabalho: uma réplica com Whisper chegou a 2 506 MiB (EV-18). · *TAT-03* (concorrência no _worker_): a ligação ao RabbitMQ e o processamento estão na mesma _thread_ (EV-33, EV-34), o cliente `pika` não é seguro entre _threads_, e várias legendagens no mesmo contentor disputam CPU e memória. · *TAT-04* (prioridades): não acrescenta capacidade; com 4 trabalhos iguais, a ordem não muda o p95. · *TAT-05* (_throttling_): classe C, o utilizador passa a ver pedidos recusados. · *TAT-06* (mais recursos por contentor): encurta cada trabalho, mas os 4 continuam em fila.],
    [Consequências positivas], [Vários pedidos em paralelo (M6) e cumprimento do critério do REQ-VID-EDIT-011 (≥ 2 vídeos em paralelo). A capacidade acompanha a carga e volta ao mínimo sem carga (M4). Se uma réplica falhar, outra continua a consumir a fila (o `ack` manual reentrega a mensagem, EV-10).],
    [Consequências negativas / riscos], [Mais memória e CPU em pico; o limite passa a ser a máquina (12 CPUs, 7,7 GiB). O `video_autoscaler` precisa de acesso ao _socket_ do Docker (segurança ↓). Retirar uma réplica a meio de um vídeo obrigaria a recomeçá-lo (H-10) e, sem _heartbeat_, uma réplica bloqueada reteria a mensagem até ao `consumer_timeout` (EV-19, EV-33); ambos ficam mitigados pela TAT-13, que por sua vez acrescenta concorrência entre _threads_ a testar. Hipóteses a confirmar antes de ligar o ajuste: H-01 (réplicas sem erros), H-02 (ficheiros temporários no mesmo volume), H-03 (_cache_ do Whisper), H-04 (`consumer_timeout`), H-05 (cancelamento com vários _workers_).],
    [Elementos arquiteturais afetados], [Ligação ao RabbitMQ e tratamento do sinal de paragem nos _workers_ de vídeo (hoje em `Tools/video/video.py:57-64`, TAT-13); `docker-compose.yaml` (réplicas, limites e tempo de paragem dos serviços de vídeo; serviço novo `video_autoscaler` com o _socket_ do Docker); RabbitMQ (API de gestão; `consumer_timeout` em `rabbitMQ/rabbitmq.conf`); volume `whisper_models`.],
    [Origem e âmbito do _refactoring_], [Interação entre o padrão do vídeo e o global: passa a usar o _Competing Consumers_ que o padrão global permite mas não usa. Risco de regressão médio, concentrado no cancelamento e na concorrência no volume partilhado.],
    [Classe (A/B/C)], [A — o utilizador não vê diferença funcional, apenas tempos de espera menores.],
    [Implementação (_commits_ / _pull requests_)], [#preencher[referências no repositório entregue]],
    [Desvios face à decisão], [#preencher[o que mudou na implementação e porquê, ou «nenhum»]],
  ),
)

== DA-2 — Um serviço por tipo de trabalho de vídeo e efeitos num módulo partilhado (cenário QS-02)

#tab([Decisão arquitetural DA-2],
  tabela-campos(
    [Contexto], [Edição, legendagem e extração correm no mesmo processo e na mesma imagem de 1,69 GB (EV-11, EV-14); `process_video` concentra a lógica dos três (EV-13); os 8 efeitos estão copiados das ferramentas de imagem (EV-12), uma duplicação que o próprio PL1-G4 deixou para a Fase 2 (EV-32). Nos três cenários de mudança, os 3 tipos de trabalho são reimplantados (EV-17). Com legendas, o pipeline já corre em estágios com um MP4 intermédio (EV-15). Restrição da fase: as saídas têm de ser iguais às da base.],
    [Tática(s) escolhida(s)], [TAT-07 (dividir o módulo por tipo de trabalho), TAT-08 (efeitos num módulo partilhado) e TAT-09 (comunicação só por filas, com o encadeamento no `projects`).],
    [Estrutura / padrão que a realiza], [Microserviços por tipo de trabalho: `video_edit` (efeitos por fotograma, corte, velocidade), `video_subtitles` (Faster-Whisper e fontes das legendas) e `video_frames` (extração), cada um com a sua fila e o seu Dockerfile. O `projects` divide a lista de ferramentas de cada vídeo em estágios, nos mesmos pontos em que `process_video` já a divide (EV-15), e envia cada estágio para a fila do serviço respetivo, como faz com as imagens; a pré-visualização segue o mesmo encadeamento, com `preview: true` (EV-16). Os efeitos passam para uma pasta própria, `Tools/effects/`, *com um ficheiro por efeito e fora de `Tools/utils`*: cada ferramenta de imagem copia só o seu ficheiro e o `video_edit` copia os oito, de modo que mudar o brilho reconstrói apenas `brightness_tool` e `video_edit` (EV-28).],
    [Alternativas consideradas e razão de rejeição], [*TAT-10* (monólito modular): organiza o código, mas a imagem e a implantação continuam únicas, por isso não melhora o QS-02. · *TAT-12* (serviço por efeito): cada serviço recodifica o vídeo (EV-27); um pipeline de 3 filtros passaria de 1 para 3 codificações, e as saídas deixariam de ser iguais às da base. É o desenho que o PL1-G4 rejeitou na DA-01 (EV-29). · *TAT-11*: já existe para o modelo (EV-07), mas não cobre a atualização da biblioteca. · *Encadeamento entre os próprios serviços de vídeo* (em vez de no `projects`): os serviços passariam a conhecer-se, e o cancelamento e o registo do resultado, que estão no `projects` (EV-06), teriam de ser duplicados.],
    [Consequências positivas], [Uma mudança na legendagem só reconstrói e reimplanta `video_subtitles` (N2). A edição e a extração ficam sem `faster-whisper` (N3). Os efeitos têm uma única implementação (N1). Cada serviço pode escalar sozinho (pré-requisito da DA-1). A legendagem deixa de bloquear as edições curtas (M1).],
    [Consequências negativas / riscos], [Mais um salto entre serviços e um MP4 intermédio por estágio podem aumentar o tempo de cada vídeo (H-06). O `projects` passa a encadear estágios de vídeo e pode crescer (H-09). O cancelamento e a devolução de quota passam a atravessar vários serviços (H-08). As 8 ferramentas de imagem também mudam, por passarem a importar o módulo partilhado (H-07). Mais serviços e imagens para operar.],
    [Elementos arquiteturais afetados], [`Tools/video/` (dividido em três serviços); `Tools/effects/` (novo); as 8 ferramentas de imagem com efeitos e os respetivos Dockerfiles; `projects/utils/project_msg.js` (filas novas); `projects/routes/projects.js` (encadeamento dos estágios); `docker-compose.yaml`; `rabbitMQ/definitions.json` (filas novas).],
    [Origem e âmbito do _refactoring_], [Padrão do vídeo, que passa a seguir o padrão global (um serviço por unidade de trabalho, com fila própria). Risco de regressão médio: efeitos verificados por _hash_ (H-07); encadeamento, pré-visualização e cancelamento verificados pelos testes de `Tools/video/tests` e `projects/tests` e por testes novos (H-08).],
    [Classe (A/B/C)], [A — _refactoring_ puro; as saídas são as mesmas da base.],
    [Implementação (_commits_ / _pull requests_)], [Ramo `fase2`. Planeador e encadeamento no `projects` (TAT-09): `f698432`, `0b1b2be`, `dce1682` (cancelamento, erros e limpeza). Serviços `video_edit`, `video_subtitles` e `video_frames` com a base comum `Tools/video_common/` (TAT-07): `a18bda4`, `4c85508`, `d621389`, `ccf8277`. Filas e `docker-compose.yaml`: `82e148b`, `d146707`. Efeitos em `Tools/effects/` (TAT-08): `e322332` (ferramentas de imagem), `e2c802c` (`video_edit`). Comandos de verificação e métricas: `1a67702`, `34409f2`. Remoção do `video_tool` e da `video_queue`: `077b2b6`. Verificação: _hashes_ de imagem e de vídeo iguais aos da base, 64 testes do `projects` e 101 de vídeo.],
    [Desvios face à decisão], [Nenhum na estrutura decidida (três serviços com fila própria, encadeamento no `projects`, `Tools/effects/` com um ficheiro por efeito); a vista «depois» mantém-se. Desvios de pormenor, registados no `research.md` do RNF2: (1) as funções de `Tools/effects/` têm opções (`coerce`, `output_mode`) para manter as diferenças que a base tinha entre imagem e vídeo (conversão dos parâmetros, saída `L` ou `RGB` da binarização), em vez de uniformizar o comportamento (R8); (2) no fim de cada vídeo apagam-se só os seus ficheiros intermédios, porque a pasta `stages/<token>/` é partilhada pelos vídeos da execução, e o cancelamento também os apaga, porque os estágios em curso acabam depois de o `projects` ter apagado os seus registos (R3); (3) os testes dos serviços e o `regressao_hashes.py` correm com o repositório montado, e os _hashes_ de vídeo na imagem do `video_subtitles`, a única com o Faster-Whisper (R7); (4) a deteção do `rnf2_estaticas.py` foi ajustada à nova estrutura, com o mesmo resultado na base (R10).],
  ),
)
