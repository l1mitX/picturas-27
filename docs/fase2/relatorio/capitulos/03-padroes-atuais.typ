#import "../template.typ": *

= Padrões Arquiteturais Atuais

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secções 2.1 a 2.3 do _template_.

  *Objetivo do capítulo:* identificar o estilo (ou a combinação de estilos) arquitetural que organiza o PictuRAS como um
  todo, o padrão que o processamento de vídeo segue, e como os dois se relacionam. O padrão global é o *ponto de
  partida*: define o contexto e as restrições a que qualquer alternativa terá de responder (capítulo 4).

  *Rigor:* factos citam uma evidência (`EV-nn`, ver a explicação na secção 2.4); o que não tem evidência é uma hipótese
  (`H-nn`). Nunca reutilizem um ID eliminado. Benefícios e desafios classificam-se segundo a ISO/IEC 25010
  (característica e, quando aplicável, subcaracterística).
]

== Padrão global da solução

#orientacao[
  Nomeiem o estilo ou os estilos (e.g., microserviços, orientado a eventos, filas de mensagens) e descrevam-no em poucas
  linhas, com as vossas palavras. Depois, indiquem as *decisões globais* que condicionam o vídeo (e.g., comunicação
  assíncrona por filas, armazenamento partilhado) e o efeito que têm. Fechem com os benefícios e desafios do padrão,
  cada um ligado a um atributo de qualidade.
]

Evidências usadas pela primeira vez nesta secção:

- *EV-07*: `docker-compose.yaml:256-273` — há um único serviço `video_tool`, sem `deploy.replicas` nem limites de CPU ou memória, com `restart: on-failure`; `WHISPER_MODEL: small`, `WHISPER_CPU_THREADS: 2`.
- *EV-08*: `docker-compose.yaml` (todos os serviços `*_tool`) — todos os _workers_ montam o volume `image_data` (em `/app/images`; o `watermark_tool_ms`, que usa uma imagem pré-construída, em `/images`).
- *EV-09*: `Tools/utils/rabbit_mq.py:40` — `auto_ack=True` nas ferramentas de imagem.
- *EV-20*: `nginx/nginx.conf:17-35, 64-65, 95-96` — entrada única em HTTPS: `/` → `frontend`, `/api-gateway/` → `api_gateway`, `/socket.io` → `ws_gateway`, `/s3/` → SeaweedFS.
- *EV-21*: `docker-compose.yaml:112-126, 153-167, 186-197` — MongoDB próprio para `projects`, `users` e `subscriptions`, cada um com o seu volume; toda a solução é implantada com Docker Compose.
- *EV-22*: `rabbitMQ/definitions.json` — 20 filas declaradas: `project_queue`, `ws_queue`, `video_queue` e 17 filas de ferramentas de imagem.
- *EV-23*: `projects/utils/imageStorage.js:15-40` — o `projects` lê, carrega e apaga ficheiros no `img_storage` por pedidos HTTP síncronos.
- *EV-24*: `projects/`, `users/` e `subscriptions/` (pastas `routes/`, `controllers/`, `models/`) — organização em camadas dentro dos serviços Node; as ferramentas Python não seguem esta organização.
- *EV-28*: `Tools/<ferramenta>/Dockerfile:7` (`COPY ./utils ./utils`) — 15 Dockerfiles copiam a pasta partilhada `Tools/utils`: todas as ferramentas de imagem construídas no repositório, exceto `expand_ai`, e também o `video_tool`.
- *EV-17* (medição): `rnf2_estaticas.py base` (corre num contentor com `radon` 6.0.1; comando no cabeçalho do _script_) → `medicoes/resultados/base/rnf2_estaticas.json` — 8 efeitos com duas implementações (18 linhas copiadas); nos cenários de mudança C1, C2 e C3 os 3 tipos de trabalho de vídeo são reimplantados; 601 SLOC de Python no vídeo; orquestrador `projects/routes/projects.js` com 2733 linhas, 16 delas com ramificação imagem/vídeo.

#tabela-campos(
  [Nome(s) do padrão / estilo], [Microserviços com entrada única (_reverse proxy_ + _API Gateway_), comunicação assíncrona por mensagens (filas ponto-a-ponto num _broker_, RabbitMQ: cada mensagem é uma ordem para uma ferramenta; só a `ws_queue` leva eventos de progresso para a interface) e orquestração central pelo serviço `projects`; pedidos REST síncronos entre `apiGateway`, `projects` e `imageStorageService`; _Layered_ dentro dos serviços Node (`projects`, `users`, `subscriptions`).],
  [Descrição], [Cada ferramenta de imagem é um microserviço com a sua fila. O `projects` envia cada passo de um trabalho para a fila da ferramenta e recebe todos os resultados numa fila única (`project_queue`), a partir da qual decide o passo seguinte. O progresso segue por outra fila (`ws_queue`) até ao `ws_gateway`. Todo o tráfego entra pelo `nginx` (EV-20), cada serviço de domínio tem a sua base de dados e tudo é implantado com Docker Compose (EV-21). O padrão _Competing Consumers_ é possível, mas não é usado: cada fila tem um único consumidor.],
)

#tab([Decisões globais que condicionam o vídeo],
  tabela(
    colunas: (4.5cm, 2.6cm, 1fr),
    [Decisão global], [Evidência], [Efeito no vídeo],
    [Entrada única: `nginx` encaminha a interface, a API (`/api-gateway/`), o WebSocket (`/socket.io`) e o armazenamento (`/s3/`)], [EV-01, EV-20], [Os carregamentos de vídeo passam pelos mesmos saltos que os de imagem, com o limite de 1100 MB.],
    [Comunicação assíncrona por filas, declaradas centralmente, com resultados centralizados na `project_queue`], [EV-03, EV-06, EV-22], [O vídeo usa o mesmo contrato de mensagens (`messageId`, `procedure`, `parameters`) e a mesma fila de resultados; o cancelamento e o registo do resultado são decididos no `projects`.],
    [Um contentor por serviço, sem réplicas nem limites de recursos], [EV-07], [Todo o trabalho de vídeo é processado por uma única instância.],
    [Armazenamento de _media_ por pedidos REST síncronos ao `img_storage` (SeaweedFS)], [EV-23], [O `projects` descarrega e guarda vídeos inteiros pelo mesmo serviço de armazenamento das imagens.],
    [Base de dados própria por serviço de domínio; implantação com Docker Compose], [EV-21], [O vídeo não tem estado próprio: o estado do trabalho fica no `projects`; a capacidade define-se no `docker-compose.yaml`.],
    [Organização em camadas dentro dos serviços Node (rotas → controladores → modelos)], [EV-24], [A lógica de vídeo do orquestrador está nas rotas (`projects.js`), junto da de imagem.],
    [Armazenamento intermédio partilhado entre _workers_], [EV-08], [Os ficheiros intermédios do vídeo (MP4 por estágio, fotogramas) vivem no mesmo volume que os das imagens.],
    [_Workers_ de imagem confirmam as mensagens à receção], [EV-09], [O vídeo afasta-se: confirma só no fim (EV-04), por isso, se o `video_tool` falhar a meio, a mensagem volta à fila e não se perde.],
  ),
)

#tab([Benefícios e desafios do padrão global],
  tabela(
    colunas: (2cm, 1fr, 4.2cm, 2.4cm),
    tamanho: 8.5pt,
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [Cada ferramenta de imagem é um serviço com a sua fila: muda, reconstrói-se e reimplanta-se sozinha. Exceção: 14 das 16 ferramentas de imagem (e o `video_tool`) copiam a pasta partilhada `Tools/utils` no Dockerfile, por isso uma mudança em `utils` reconstrói-as todas.], [Manutenibilidade → modularidade], [EV-08, EV-22, EV-28],
    [Benefício], [O _broker_ desacopla o `projects` dos _workers_: um _worker_ lento não bloqueia o pedido HTTP do _Apply_.], [Eficiência de desempenho → comportamento temporal], [EV-03, EV-04],
    [Desafio], [Com um consumidor por fila, a capacidade de cada ferramenta é a de um único contentor.], [Eficiência de desempenho → capacidade], [EV-07],
    [Desafio], [Com `auto_ack=True`, uma falha de um _worker_ de imagem perde a mensagem.], [Fiabilidade → tolerância a falhas], [EV-09],
    [Desafio], [O orquestrador concentra a lógica de encadeamento, cancelamento e quota: `projects/routes/projects.js` tem 2733 linhas, 16 delas com ramificação imagem/vídeo.], [Manutenibilidade → modificabilidade], [EV-06, EV-17],
  ),
)

== Padrão do processamento de vídeo

#orientacao[
  Identifiquem o padrão que organiza o processamento de vídeo (que pode coincidir com o global ou ser diferente) e
  contrastem-no com o caminho de imagens. Se o padrão do vídeo for diferente do global, expliquem porquê e que custos
  isso traz. Indiquem benefícios e desafios, com o mesmo critério da secção anterior.
]

#tabela-campos(
  [Nome do padrão], [_Pipes and Filters_ em processo, concentrado num único serviço (`video_tool`) dentro de uma arquitetura de microserviços. Neste relatório chamamos-lhe, para abreviar, _pipeline monolith_.],
  [Descrição], [Um único serviço, `video_tool`, recebe o trabalho inteiro e executa todas as ferramentas num só processo. Um descodificador ffmpeg entrega fotogramas, os efeitos PIL são aplicados a cada um, e um codificador produz a saída. A legendagem (Faster-Whisper) e a extração de fotogramas correm no mesmo processo e na mesma imagem Docker.],
  [Contraste com o caminho de imagens], [Nas imagens, cada ferramenta é um serviço e o `projects` encadeia os passos. No vídeo, o encadeamento é interno ao `video_tool`. A decisão do PL1-G4 evita descodificar e recodificar o vídeo inteiro em cada passo, mas obriga a reimplementar no vídeo os efeitos que já existem nas imagens.],
)

Evidências usadas pela primeira vez nesta secção:

- *EV-10*: `Tools/video/video.py:126-170` — o `callback` corre `process_video` de forma síncrona e só faz `basic_ack` no fim (l. 170).
- *EV-11*: `Tools/video/` — edição (`video_processor.py`), legendagem (`subtitles.py`) e extração (`frame_extraction.py`) correm no mesmo processo; 807 linhas de Python no total (contando comentários e linhas em branco; só código, 601 SLOC, EV-17).
- *EV-12*: `Tools/video/effects.py:1-6, 11-41` — 8 efeitos (`brightness`, `contrast`, `saturation`, `rotate`, `resize`, `binarization`, `cut`, `border`) que, segundo o próprio ficheiro, «_mirror exactly_» os microserviços de imagem.
- *EV-13*: `Tools/video/video_processor.py:286-369` — `process_video` decide a extração no fim, os estágios à volta das legendas e a regra da pré-visualização; complexidade ciclomática 22, a maior do serviço.
- *EV-14*: `Tools/video/Dockerfile`, `Tools/video/requirements.txt` — uma só imagem de 1,69 GB, com ffmpeg e fontes CJK para as legendas (597 MB) e `faster-whisper` (457 MB); um trabalho de corte arranca num contentor com tudo isto.
- *EV-15*: `Tools/video/video_processor.py:321-366` — com legendas, o _pipeline_ já corre em estágios separados, cada um com um MP4 intermédio (`stage-N.mp4`).
- *EV-16*: `projects/routes/projects.js:1082-1150` — a pré-visualização de vídeo também é enviada como `procedure: "video"` (`preview: true`) para a `video_queue`.
- *EV-18* (medição): `python docs/fase2/medicoes/carga_rnf1.py base m1` → `medicoes/resultados/base/carga_m1_resumo.json` — um efeito de brilho num vídeo de 10 s, submetido 5 s depois de uma legendagem de 177 s, demora p95 322,6 s (p50 307,6 s; 5 repetições). Sozinho, o mesmo trabalho demora p95 17,8 s (`carga_isolado_resumo.json`). Durante o cenário, o `video_tool` chegou a 2 506 MiB (≈ 2,4 GiB) de memória (`docker stats`).
- *EV-25*: `Tools/video/video_processor.py:172, 198-241` — a saída é escrita em `.part.mp4` e só no fim é renomeada (`os.replace`); se falhar, o parcial é apagado.
- *EV-27*: `Tools/video/video_processor.py:201-217` — um único processo ffmpeg descodifica o vídeo, `apply_frame_effects` aplica todos os efeitos do _pipeline_ a cada fotograma e um único processo ffmpeg codifica a saída.

#tab([Benefícios e desafios do padrão do vídeo],
  tabela(
    colunas: (2cm, 1fr, 4.2cm, 2.4cm),
    tamanho: 8.5pt,
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [Uma só codificação por _pipeline_ (sem legendas), o que dá menos tempo e menos perda de qualidade.], [Eficiência de desempenho → comportamento temporal], [EV-27; exceção com legendas: EV-15],
    [Benefício], [Confirmação no fim (`ack` manual): se o processo morrer, o RabbitMQ volta a entregar a mensagem.], [Fiabilidade → recuperabilidade], [EV-04, EV-10],
    [Benefício], [Escrita atómica da saída: não ficam saídas parciais em caso de falha.], [Fiabilidade → tolerância a falhas], [EV-25],
    [Desafio], [Uma legendagem longa ocupa o único _worker_; trabalhos curtos que chegam depois ficam à espera.], [Eficiência de desempenho → capacidade], [EV-04, EV-07, EV-10, EV-18],
    [Desafio], [Os 8 efeitos estão implementados duas vezes (imagem e vídeo); uma correção tem de ser feita nos dois sítios.], [Manutenibilidade → modularidade, modificabilidade], [EV-12, EV-17],
    [Desafio], [Qualquer mudança (efeitos, legendas, extração) reconstrói e reimplanta o serviço que serve os três tipos de trabalho.], [Manutenibilidade → modularidade], [EV-11, EV-13, EV-14],
  ),
)

== Relação entre o padrão global e o padrão do vídeo

#orientacao[
  Esta secção responde a: em que pontos o vídeo *segue* o padrão global, em que pontos se *afasta* dele e com que
  consequências? Cada linha da tabela é um aspeto concreto (e.g., comunicação entre serviços, gestão de estado,
  tratamento de falhas, armazenamento). É aqui que costumam surgir as fragilidades que alimentam os cenários de
  qualidade do capítulo 5, por isso escrevam as consequências com cuidado e com evidência.

  Terminem com um parágrafo de síntese: o que o vídeo herda do padrão global, que restrições este lhe impõe e que
  fragilidades resultam do desvio.
]

#tab([Relação entre o padrão global e o padrão do vídeo],
  tabela(
    colunas: (2.4cm, 3cm, 3cm, 1.9cm, 2.6cm, 1.8cm),
    tamanho: 8pt,
    [Aspeto], [O que o padrão global prescreve], [O que o vídeo faz], [Segue / afasta-se], [Consequência], [Evidência],
    [Comunicação], [Mensagens assíncronas; resultados na `project_queue`], [Igual], [Segue], [O vídeo partilha o contrato e o cancelamento do `projects`], [EV-03, EV-06],
    [Granularidade], [Um serviço e uma fila por ferramenta], [Um serviço e uma fila para todas as ferramentas e tipos de trabalho], [Afasta-se], [Efeitos duplicados; uma mudança reimplanta tudo], [EV-11, EV-12],
    [Encadeamento], [Feito pelo `projects`, passo a passo], [Feito dentro do `video_tool` (`process_video`)], [Afasta-se], [O orquestrador conhece as ferramentas de vídeo mas não encadeia os passos; a lógica fica repartida], [EV-02, EV-13],
    [Capacidade], [Um consumidor por fila], [Um consumidor, `prefetch_count=1`, trabalhos longos], [Segue], [No vídeo, o efeito é muito maior: um trabalho de 5 min bloqueia todos os outros], [EV-04, EV-07],
    [Confirmação das mensagens], [`auto_ack=True`], [`ack` manual no fim], [Afasta-se], [Melhor recuperação no vídeo; com réplicas, é a base do _Competing Consumers_], [EV-09, EV-10],
    [Armazenamento intermédio], [Volume partilhado `image_data`], [Igual (MP4 intermédios no mesmo volume)], [Segue], [Com réplicas, os nomes temporários não podem colidir (H-02)], [EV-08, EV-15],
  ),
)

O vídeo herda do padrão global o contrato de mensagens, a fila de resultados e o controlo de cancelamento e quota no
`projects`. Herda também a restrição de capacidade: um consumidor por fila, sem réplicas (EV-07). Afasta-se na
granularidade, ao concentrar edição, legendagem e extração num só serviço, o que evita recodificações mas cria duas
fragilidades. A primeira é de *capacidade*: um trabalho longo ocupa o único _worker_ e bloqueia os outros (EV-04,
EV-10). A segunda é de *modularidade*: os efeitos estão duplicados e qualquer mudança reconstrói e reimplanta os três
tipos de trabalho (EV-11, EV-12, EV-14). São estas duas fragilidades que alimentam os cenários do capítulo 5.

*Hipóteses levantadas na análise* (a confirmar ou refutar durante o _refactoring_). Evidência nova usada nas hipóteses: *EV-19*: `rabbitMQ/Dockerfile:2`, `rabbitMQ/rabbitmq.conf` — RabbitMQ 4.0.5 sem `consumer_timeout` configurado (o valor por omissão é 30 min).

#tabela(
  colunas: (1.4cm, 1fr, 1fr),
  tamanho: 8.5pt,
  [ID], [Hipótese], [Como confirmar ou refutar],
  [H-01], [Com `docker compose up --scale video_tool=2`, a solução funciona sem erros (não há `container_name`; o `ack` é manual).], [Repetir a medição de base com 2 réplicas manuais.],
  [H-02], [Réplicas a escrever no mesmo `image_data` (EV-08) não colidem nos ficheiros temporários.], [Ler `video_processor.py`; dois trabalhos do mesmo projeto em simultâneo.],
  [H-03], [Duas réplicas a descarregar o modelo Whisper ao mesmo tempo corrompem a _cache_ `whisper_models`.], [Arrancar 2 réplicas com o volume vazio.],
  [H-04], [Uma legendagem de mais de 30 min ultrapassa o `consumer_timeout` do RabbitMQ e é reentregue em ciclo. (EV-19)], [Vídeo Premium longo com legendagem; observar os _logs_ do RabbitMQ.],
  [H-05], [O cancelamento (`activeToken`) continua correto com vários _workers_.], [Cancelar a meio com 2 réplicas ativas.],
  [H-06], [Partir o _pipeline_ nos limites dos estágios atuais (EV-15) não acrescenta recodificações.], [Contar as codificações nos _logs_ do ffmpeg, antes e depois.],
  [H-07], [Os efeitos partilhados entre imagem e vídeo dão o mesmo resultado que hoje.], [_Hash_ das saídas antes e depois (`regressao_hashes.py`).],
  [H-08], [O cancelamento e a devolução de quota funcionam com um _pipeline_ que passa por vários serviços.], [Cancelar a meio de um _pipeline_ legendas + filtro + extração.],
  [H-09], [A divisão do vídeo faz crescer o orquestrador.], [Medir N4 no `projects` antes e depois (EV-17).],
)
