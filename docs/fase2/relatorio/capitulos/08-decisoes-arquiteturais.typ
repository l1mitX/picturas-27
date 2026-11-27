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

As duas decisões realizam a ALT-2 (capítulo 4). Implementam-se pela ordem inversa da numeração, primeiro a DA-2 (modularidade), que é pré-requisito, e depois a DA-1 (capacidade). As medições fazem-se nos três momentos combinados pela equipa, `base`, `apos-rnf2` e `apos-rnf1` (`docs/fase2/medicoes/README.md`, «Antes de medir»).

== DA-1 — Réplicas por serviço de vídeo com ajuste automático pelo tamanho da fila (cenário QS-03)

#tab([Decisão arquitetural DA-1],
  tabela-campos(
    [Contexto], [Todo o vídeo é processado por um único _worker_, que trata uma mensagem de cada vez (EV-04, EV-07, EV-10). No QS-03, 4 edições curtas simultâneas demoram p95 44,0 s, contra 17,8 s de uma sozinha (EV-26). Depois da DA-2, cada tipo de trabalho tem a sua fila, mas cada fila continua com um só consumidor. A fase é de _refactoring_, por isso o utilizador tem de obter os mesmos resultados.],
    [Tática(s) escolhida(s)], [TAT-01 (replicar computação) e TAT-02 (aumentar recursos de forma elástica), com a TAT-13 (retirar réplicas só sem trabalho e _heartbeat_ numa _thread_ separada) como tática de disponibilidade pré-requisito.],
    [Estrutura / padrão que a realiza], [_Competing Consumers_ em cada fila de vídeo. Um serviço novo, `video_autoscaler`, consulta periodicamente o tamanho de cada fila na API de gestão do RabbitMQ. Com esse valor, ajusta através da API do Docker o número de réplicas de `video_edit`, `video_subtitles` e `video_frames`, entre um mínimo e um máximo por serviço. Para a TAT-13, cada _worker_ trata o sinal de paragem, ou seja, deixa de consumir, termina o vídeo em curso, confirma-o e sai. O `docker stop` dá-lhe tempo suficiente para isso. Além disso, o processamento passa para uma _thread_ separada da ligação, com o _heartbeat_ ativo.],
    [Alternativas consideradas e razão de rejeição], [*TAT-01 sozinha* (réplicas fixas). Melhora o M6, mas a capacidade não acompanha a carga (sem M4) e gasta memória sem trabalho, porque uma réplica com Whisper chegou a 2 506 MiB (EV-18). · *TAT-03* (concorrência no _worker_). A ligação ao RabbitMQ e o processamento estão na mesma _thread_ (EV-33, EV-34), o cliente `pika` não é seguro entre _threads_, e várias legendagens no mesmo contentor disputam CPU e memória. · *TAT-04* (prioridades). Não acrescenta capacidade, porque com 4 trabalhos iguais a ordem não muda o p95. · *TAT-05* (_throttling_). É de classe C, porque o utilizador passaria a ver pedidos recusados. · *TAT-06* (mais recursos por contentor). Encurta cada trabalho, mas os 4 continuam em fila.],
    [Consequências positivas], [Vários pedidos em paralelo (M6) e cumprimento do critério do REQ-VID-EDIT-011 (≥ 2 vídeos em paralelo). A capacidade acompanha a carga e volta ao mínimo sem carga (M4). Se uma réplica falhar, outra continua a consumir a fila (o `ack` manual reentrega a mensagem, EV-10).],
    [Consequências negativas / riscos], [Gasta mais memória e CPU em pico, e o limite passa a ser a máquina (12 CPUs, 7,7 GiB). O `video_autoscaler` precisa de acesso ao _socket_ do Docker, o que piora a segurança. Retirar uma réplica a meio de um vídeo obrigaria a recomeçá-lo (H-10). Sem _heartbeat_, uma réplica bloqueada reteria a mensagem até ao `consumer_timeout` (EV-19, EV-33). Os dois riscos ficam mitigados pela TAT-13, que por sua vez acrescenta concorrência entre _threads_ a testar. Antes de ligar o ajuste, é preciso confirmar as hipóteses H-01 (réplicas sem erros), H-02 (ficheiros temporários no mesmo volume), H-03 (_cache_ do Whisper), H-04 (`consumer_timeout`) e H-05 (cancelamento com vários _workers_).],
    [Elementos arquiteturais afetados], [A ligação ao RabbitMQ e o tratamento do sinal de paragem nos _workers_ de vídeo (na base, em `Tools/video/video.py:57-64`, TAT-13). O `docker-compose.yaml`, com as réplicas, os limites e o tempo de paragem dos serviços de vídeo, e o serviço novo `video_autoscaler`, com o _socket_ do Docker. O RabbitMQ, com a API de gestão e o `consumer_timeout` em `rabbitMQ/rabbitmq.conf`. E o volume `whisper_models`.],
    [Origem e âmbito do _refactoring_], [Interação entre o padrão do vídeo e o global, que passa a usar o _Competing Consumers_ que o padrão global permite mas não usa. O risco de regressão é médio e concentra-se no cancelamento e na concorrência no volume partilhado.],
    [Classe (A/B/C)], [A — o utilizador não vê diferença funcional, apenas tempos de espera menores.],
    [Implementação (_commits_ / _pull requests_)], [Ramo `rnf1-fase2`, integrado no `fase2`. Os parâmetros das réplicas e os limites de memória (T003) estão em `e2c88b2`. A TAT-13 nos _workers_ está em `6390016` (testes) e `86c3379`. Em `Tools/video_common/worker.py`, o estágio corre numa _thread_ de trabalho, o `ack`, as respostas e o progresso passam pela _thread_ da ligação, o _heartbeat_ é negociado com o _broker_ e o `SIGTERM` provoca uma paragem ordenada. As réplicas sem colisões (TAT-01, H-02, H-03) estão em `b391ec7` (ficheiro `.part` com nome único) e `b6519d7` (_lock_ na primeira carga do modelo Whisper). O `stop_grace_period` e os limites de memória no `docker-compose.yaml` estão em `d21df69`. O `video_autoscaler` (TAT-02) está em `59eda23` e `3640496` (política e testes), `a15b9e5` (ciclo), `901b899` (Dockerfile), `db819e2` (serviço no Compose) e `853947e` (README). A medição do M4 (`elasticidade_m4.py`) está em `ac8c0a6`, e o `consumer_timeout` fixado em 30 min em `rabbitMQ/rabbitmq.conf` (T022, H-04) está em `0c4396b`. As hipóteses H-01 a H-05 e H-10 foram verificadas no «Registo» de `specs/002-rnf1-capacidade/quickstart.md` (`788ceb1`, `0168f8b`, T022, T024 e T025). Os _hashes_ do código do RNF1 são iguais aos do código da base no mesmo ambiente. Na máquina de referência foram feitos a T022 e o limite de memória da extração (`fc28040`), o `stop_grace_period` da edição a 20 min e a medição exploratória com réplicas manuais (T015, `828b59b`), a latência do lado da aplicação no `carga_rnf1.py` (`dc37d4e`) e a medição `apos-rnf1` com os _hashes_ oficiais (T027 e T028, `d2c22ef`). Os resultados estão no capítulo 10.],
    [Desvios face à decisão], [Não há desvios na estrutura decidida, com _Competing Consumers_ em cada fila, o `video_autoscaler` a seguir o tamanho das filas e a TAT-13 nos _workers_. Há cinco desvios de pormenor.

(1) A legendagem tem no máximo 1 réplica (T003), porque cada réplica com o Whisper chega a ~2,5 GiB (EV-18) e a máquina de medição dá 7,7 GiB ao Docker. A legendagem continua isolada na sua fila, mas sem elasticidade, e a vista «depois» foi atualizada (`db5507b`).

(2) A TAT-13 previa «retirar réplicas só sem trabalho», mas ao reduzir é o Compose que escolhe a réplica, e essa réplica pode estar ocupada, como aconteceu na T023. Quem protege o vídeo é a paragem ordenada, em que a réplica deixa de consumir, acaba o estágio e só depois sai. Isto obriga o `stop_grace_period` a ser maior do que o estágio mais longo. A edição de um vídeo de 599 s em 1080p, com 2 em paralelo, chegou a 895 s numa máquina mais lenta e a 535 s na de referência, acima ou perto dos 10 min previstos. Por isso, o `stop_grace_period` da edição subiu para 20 min.

(3) O `video_autoscaler` não fala diretamente com a API do Docker. Corre `docker compose up --scale` através do _socket_, para respeitar a configuração do Compose, como os limites, os volumes e a rede (R1).

(4) O _heartbeat_ usa o valor negociado com o _broker_ (60 s), e uma réplica bloqueada é detetada ao fim de 2 a 3 intervalos (168 s na T024).

(5) O `consumer_timeout` manteve o valor por omissão (30 min), agora fixado explicitamente, porque deixa uma margem de 2× sobre o pior estágio medido (895 s).],
  ),
)

== DA-2 — Um serviço por tipo de trabalho de vídeo e efeitos num módulo partilhado (cenário QS-02)

#tab([Decisão arquitetural DA-2],
  tabela-campos(
    [Contexto], [Edição, legendagem e extração correm no mesmo processo e na mesma imagem de 1,69 GB (EV-11, EV-14), e `process_video` concentra a lógica dos três (EV-13). Os 8 efeitos estão copiados das ferramentas de imagem (EV-12), uma duplicação que o próprio PL1-G4 deixou para a Fase 2 (EV-32). Nos três cenários de mudança, os 3 tipos de trabalho são reimplantados (EV-17). Com legendas, o _pipeline_ já corre em estágios com um MP4 intermédio (EV-15). A fase é de _refactoring_, por isso as saídas têm de ser iguais às da base.],
    [Tática(s) escolhida(s)], [TAT-07 (dividir o módulo por tipo de trabalho), TAT-08 (efeitos num módulo partilhado) e TAT-09 (comunicação só por filas, com o encadeamento no `projects`).],
    [Estrutura / padrão que a realiza], [Microserviços por tipo de trabalho, cada um com a sua fila e o seu Dockerfile. São o `video_edit` (efeitos por fotograma, corte, velocidade), o `video_subtitles` (Faster-Whisper e fontes das legendas) e o `video_frames` (extração). O `projects` divide a lista de ferramentas de cada vídeo em estágios, nos mesmos pontos em que `process_video` já a divide (EV-15), e envia cada estágio para a fila do serviço respetivo, como faz com as imagens. A pré-visualização segue o mesmo encadeamento, com `preview: true` (EV-16). Os efeitos passam para uma pasta própria, `Tools/effects/`, *com um ficheiro por efeito e fora de `Tools/utils`*. Cada ferramenta de imagem copia só o seu ficheiro e o `video_edit` copia os oito, de modo que mudar o brilho reconstrói apenas `brightness_tool` e `video_edit` (EV-28).],
    [Alternativas consideradas e razão de rejeição], [*TAT-10* (monólito modular). Organiza o código, mas a imagem e a implantação continuam únicas, por isso não melhora o QS-02. · *TAT-12* (serviço por efeito). Cada serviço recodifica o vídeo (EV-27), e um _pipeline_ de 3 filtros passaria de 1 para 3 codificações, com saídas diferentes das da base. É o desenho que o PL1-G4 rejeitou na DA-01 (EV-29). · *TAT-11*. Já existe para o modelo (EV-07), mas não cobre a atualização da biblioteca. · *Encadeamento entre os próprios serviços de vídeo*, em vez de no `projects`. Os serviços passariam a conhecer-se, e o cancelamento e o registo do resultado, que estão no `projects` (EV-06), teriam de ser duplicados.],
    [Consequências positivas], [Uma mudança na legendagem só reconstrói e reimplanta `video_subtitles` (N2). A edição e a extração ficam sem `faster-whisper` (N3). Os efeitos têm uma única implementação (N1). Cada serviço pode escalar sozinho (pré-requisito da DA-1). A legendagem deixa de bloquear as edições curtas (M1).],
    [Consequências negativas / riscos], [Mais um salto entre serviços e um MP4 intermédio por estágio podem aumentar o tempo de cada vídeo (H-06). O `projects` passa a encadear estágios de vídeo e pode crescer (H-09). O cancelamento e a devolução de quota passam a atravessar vários serviços (H-08). As 8 ferramentas de imagem também mudam, por passarem a importar o módulo partilhado (H-07). Mais serviços e imagens para operar.],
    [Elementos arquiteturais afetados], [`Tools/video/`, dividido em três serviços, e `Tools/effects/`, que é novo. As 8 ferramentas de imagem com efeitos e os respetivos Dockerfiles. No `projects`, o `utils/project_msg.js` (filas novas) e o `routes/projects.js` (encadeamento dos estágios). E ainda o `docker-compose.yaml` e o `rabbitMQ/definitions.json` (filas novas).],
    [Origem e âmbito do _refactoring_], [Padrão do vídeo, que passa a seguir o padrão global, com um serviço por unidade de trabalho e fila própria. O risco de regressão é médio. Os efeitos são verificados por _hash_ (H-07), e o encadeamento, a pré-visualização e o cancelamento pelos testes de `Tools/video/tests` e `projects/tests` e por testes novos (H-08).],
    [Classe (A/B/C)], [A — _refactoring_ puro, com as mesmas saídas da base. Inclui uma alteração de classe B, fora da decisão, que é a correção de um erro herdado da base que o RNF2 tornava mais provável. Um _Apply_ que acabasse com uma pré-visualização a meio nunca era confirmado (desvio 6, R12).],
    [Implementação (_commits_ / _pull requests_)], [Ramo `fase2`. O planeador e o encadeamento no `projects` (TAT-09) estão em `f698432`, `0b1b2be` e `dce1682` (cancelamento, erros e limpeza). Os serviços `video_edit`, `video_subtitles` e `video_frames`, com a base comum `Tools/video_common/` (TAT-07), estão em `a18bda4`, `4c85508`, `d621389` e `ccf8277`. As filas e o `docker-compose.yaml` estão em `82e148b` e `d146707`. Os efeitos em `Tools/effects/` (TAT-08) estão em `e322332` (ferramentas de imagem) e `e2c802c` (`video_edit`). Os comandos de verificação e as métricas estão em `1a67702` e `34409f2`, e a remoção do `video_tool` e da `video_queue` em `077b2b6`. A pré-visualização com pasta própria e a correção de classe B (R12) estão em `637bbd5` e `e18380b`, e a medição `apos-rnf2` em `ab862c6`, `63ae616` e `ff20fa4`. Na verificação, os _hashes_ de imagem e de vídeo ficaram iguais aos da base, e passaram 68 testes do `projects` e 101 de vídeo.],
    [Desvios face à decisão], [Não há desvios na estrutura decidida, com três serviços com fila própria, o encadeamento no `projects` e `Tools/effects/` com um ficheiro por efeito, por isso a vista «depois» mantém-se. Há seis desvios de pormenor, registados no `research.md` do RNF2.

(1) As funções de `Tools/effects/` têm opções (`coerce`, `output_mode`) para manter as diferenças que a base tinha entre imagem e vídeo, como a conversão dos parâmetros e a saída `L` ou `RGB` da binarização, em vez de uniformizar o comportamento (R8).

(2) No fim de cada vídeo apagam-se só os seus ficheiros intermédios, porque a pasta `stages/<token>/` é partilhada pelos vídeos da execução. O cancelamento também os apaga, porque os estágios em curso acabam depois de o `projects` ter apagado os seus registos (R3).

(3) Os testes dos serviços e o `regressao_hashes.py` correm com o repositório montado, e os _hashes_ de vídeo correm na imagem do `video_subtitles`, a única com o Faster-Whisper (R7).

(4) A deteção do `rnf2_estaticas.py` foi ajustada à nova estrutura, com o mesmo resultado na base (R10).

(5) Os intermédios da pré-visualização ficam numa pasta à parte, porque usam o _token_ da execução em curso (R3).

(6) Corrigiu-se um erro herdado da base, que o RNF2 tornava mais provável. Um _Apply_ que acabasse com uma pré-visualização a meio nunca era confirmado (R12).],
  ),
)
