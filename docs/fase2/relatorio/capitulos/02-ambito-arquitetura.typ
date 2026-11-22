#import "../template.typ": *

= Âmbito e Vista da Arquitetura

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secções 0 e 1 do _template_ (preparação, fontes, vista global e sequência).

  *Objetivo do capítulo:* situar o leitor. Mostra como a solução foi lançada, em que fontes se baseia a análise e como é
  a arquitetura da solução de base, com o caminho do vídeo em destaque. É a base factual dos capítulos seguintes.

  *Foco:* a *extensão de vídeo, enquadrada no padrão global* da solução. Não analisem o vídeo isoladamente: o que o vídeo
  faz só se percebe à luz do que a solução faz como um todo.

  *Rigor:* cada afirmação sobre o sistema atual cita uma evidência (`EV-nn`) ou é assumida como hipótese (`H-nn`). A
  secção 2.4 explica como se escreve uma evidência.
]

== Preparação e ambiente

#orientacao[
  Registem como a solução foi lançada, para que outra pessoa a consiga repetir e obtenha o mesmo resultado. Indiquem
  sempre o _commit_ de partida (o mesmo em todos os capítulos), os comandos exatos e o ambiente de execução. Se algum
  passo falhou ou exigiu um ajuste, escrevam-no: é informação útil para quem repetir o processo.

  A descrição do processamento em lote que se segue à tabela deve ser escrita pela equipa, com palavras próprias, e
  mostrar que perceberam o fluxo completo, do _Apply_ ao resultado, para imagens e vídeos.
]

#tab([Preparação e ambiente],
  tabela-campos(
    [Commit de partida], [`052310226c51fa57a17101c7bd1ad795674aac95` (`0523102`, ramo `main` de `picturas-um/picturas-27`). Todas as evidências deste relatório referem-se a este _commit_.],
    [Comando(s) de arranque], [`docker compose up -d --build`, na raiz do repositório. Testes: `docker compose exec -T projects sh -c "node --test tests/*.test.js"` e `docker compose run --rm --no-deps -T video_tool sh -c "pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"`.],
    [Ambiente (SO, CPU, RAM, versões de Docker e Compose)], [AMD Ryzen 5 5600H, 15,9 GB de RAM, Windows 11 Home; Docker Desktop (Engine 29.8.0, Compose 5.5.1) sobre WSL2 (_kernel_ 6.18.58.1), com 12 CPUs e 7,7 GiB atribuídos ao Docker.],
    [Ajustes e incidentes], [Na primeira tentativa, `docker compose up -d` (sem `--build`) reutilizou imagens antigas com o mesmo nome de projeto (`picturas-*`), construídas a partir do código da Fase 1 da equipa. O problema foi detetado porque os testes dentro do contentor `projects` não eram os do repositório. A solução foi reconstruída com `--build` antes de qualquer medição; desde então usa-se sempre `--build`.],
    [Resultado dos testes existentes], [`projects/tests`: 8 testes, 8 passam. `Tools/video/tests`: 74 testes, 74 passam (169 s).],
  ),
)

*Como é orquestrado o processamento em lote de imagens e de vídeos:*

// [PROPOSTA] Rascunho: o template pede que este parágrafo seja escrito pela equipa, com palavras próprias. Rever e reescrever.
Um projeto tem uma lista ordenada de ferramentas e um conjunto de ficheiros, que podem ser imagens ou vídeos. Quando o
utilizador carrega em _Apply_, o serviço `projects` cria um trabalho por ficheiro e só envia as mensagens depois de
registar o lote inteiro. O tipo de cada ficheiro (guardado no carregamento) decide o caminho. Uma *imagem* percorre a
cadeia de microserviços de imagem um passo de cada vez: cada ferramenta tem a sua fila, devolve o resultado na
`project_queue`, e é o `projects` que envia a saída para a fila da ferramenta seguinte. Um *vídeo* vai inteiro, com a
lista completa de ferramentas, para uma única fila, a `video_queue`. Aí, o serviço `video_tool` aplica todos os passos
de uma só vez: efeitos fotograma a fotograma, corte, velocidade, legendas e extração de fotogramas. Durante o
processamento, o progresso chega ao browser pelo `ws_gateway`. No fim, o `projects` regista o resultado da execução,
desde que esta não tenha sido cancelada entretanto.

== Fontes consultadas

#orientacao[
  Listem os documentos e o código que sustentam a análise, com a versão ou a data de cada um (_commit_, número de versão,
  data de acesso) e para que foram usados. Isto permite ao leitor perceber de onde vêm as afirmações e detetar
  fontes desatualizadas. Incluam os documentos de apoio da unidade curricular que influenciaram a análise.
]

#tab([Fontes consultadas],
  tabela(
    colunas: (5.5cm, 3cm, 1fr),
    [Fonte], [Versão / data], [Usada para],
    [`README.md`, `AGENTS.md`], [_commit_ `0523102`], [Arranque, organização dos serviços e convenções do repositório],
    [`doc-ext-requisitos-2627.pdf` (extensão de vídeo do PL1-G4)], [versão distribuída com a Fase 2], [Requisitos de origem dos RNF (REQ-VID-EDIT-009 a -014), decisões de qualidade DQ-01 a DQ-07 e decisões arquiteturais do PL1-G4 (secção 8.2, Tabela 37, DA-01 a DA-10)],
    [`doc-sol-arquitetural.pdf` (solução da base anterior)], [#preencher[versão]], [#preencher[confirmar se foi consultado e para quê; as decisões do PL1-G4 estão no documento de extensão]],
    [Código e configuração: `docker-compose.yaml`, `nginx/nginx.conf`, `apiGateway/`, `rabbitMQ/definitions.json`, `projects/`, `Tools/video/`, `Tools/utils/`, `imageStorageService/`, `wsGateway/`], [_commit_ `0523102`], [Evidências `EV-nn`],
    [Hohpe & Woolf, _Enterprise Integration Patterns_ (2003); Richards & Ford, _Fundamentals of Software Architecture_ (2020)], [—], [_Competing Consumers_; _pipeline_ e monólito modular],
    [Bass, Clements & Kazman, _Software Architecture in Practice_, 4.ª ed. (2021)], [—], [Modelo de seis elementos dos cenários de qualidade (cap. 5)],
    [Slides da aula 11 (_Arch. Styles_) e documento de apoio de padrões arquiteturais], [2026/2027], [Identificação dos padrões (cap. 3) e alternativas (cap. 4)],
    [Slides «Do cenário de qualidade à tática arquitetural» (aulas 6 e 7)], [2026/2027], [Cenários de qualidade (cap. 5) e táticas (cap. 7)],
    [Medições da equipa (`docs/fase2/medicoes/`)], [2026-11-18], [Valores de base (caps. 5, 6 e 10)],
  ),
)

== Vista da arquitetura global

#orientacao[
  A vista mostra o *padrão global* da solução (serviços, filas, armazenamento, fronteiras) com o *caminho do vídeo
  destacado*, de modo a que se veja onde o vídeo segue o resto do sistema e onde se afasta dele.

  Usem a notação e a ferramenta que preferirem (C4 de contentores, componentes UML, PlantUML, Mermaid, draw.io), mas
  incluam sempre uma *legenda* e indiquem a ferramenta. O diagrama tem de ser legível no documento impresso e
  consistente com o que foi observado na solução em execução, não apenas com a documentação.
]

// Diagrama dado pelos docentes com o Ex. 6 (arquitetura_global_plantuml.svg). Fonte em images/arquitetura_global.puml;
// para regenerar: java -jar plantuml.jar -charset UTF-8 -tsvg images/arquitetura_global.puml
// Acrescentos face ao original (verificados no commit 0523102): (1) seta ws_gateway → browser (progresso por
// Socket.IO, wsGateway/index.js); (2) nota: a pré-visualização também usa a video_queue (projects/routes/projects.js,
// procedure "video" com preview: true); (3) commit no título; (4) 17 filas de imagem (rabbitMQ/definitions.json), não 16.
// Página na horizontal para o diagrama ficar legível impresso.
#paisagem[
#figure(
  image("../images/arquitetura_global.svg", width: 100%, height: 15.5cm, fit: "contain"),
  caption: [Vista da arquitetura global com o caminho do vídeo destacado],
)
]

*Ferramenta / notação:* PlantUML, diagrama de componentes.

#tab([Legenda da vista da arquitetura],
  tabela(
    colunas: (5cm, 1fr),
    [Elemento (cor, forma ou estilo)], [Significado],
    [Seta laranja grossa], [Interações do processamento de vídeo: ficheiros (_upload_, escrita no volume, S3), mensagens (`projects` → `video_queue` → `video_tool` → `project_queue`) e avisos (`ws_queue` → `ws_gateway` → browser). As setas mostram quem comunica com quem, não o percurso do ficheiro de vídeo],
    [Componente], [Contentor Docker (um serviço do `docker-compose.yaml`)],
    [Fila], [Fila do RabbitMQ (17 filas de ferramentas de imagem, `video_queue`, `project_queue`, `ws_queue`)],
    [Base de dados / armazenamento], [MongoDB por serviço; SeaweedFS (_bucket_ único `users/<id>/`); volume partilhado `image_data`],
  ),
)

== Sequência de um pedido completo

#orientacao[
  Descrevam, passo a passo, o que acontece num pedido completo para um projeto com vídeos: carregamento → definição do
  _pipeline_ → _Apply_ → progresso → resultado. O diagrama de sequência mostra a ordem das interações; a tabela
  identifica, para cada passo, quem fala com quem e através de que mensagem, _endpoint_ ou fila.

  *O que é uma evidência (`EV-nn`).* Uma evidência é a referência *verificável* que sustenta uma afirmação sobre o
  sistema atual. Deve permitir que outra pessoa, no _commit_ de partida, confirme o que afirmam sem ter de adivinhar.
  Pode ser:
  - *código*, com ficheiro e linhas (e.g., `video.py:8-9`);
  - *configuração*, com ficheiro e linha (e.g., `docker-compose.yml`, definição de uma fila ou de um volume);
  - *mensagem* observada (e.g., conteúdo de uma mensagem na fila, resposta de um _endpoint_);
  - *medição* ou *registo de execução*, com o comando usado e o resultado;
  - *documento*, com a secção (e.g., `doc-sol-arquitetural.pdf`, secção 3).

  Regras: o ID é sequencial (`EV-01`, `EV-02`, …), único, e nunca se reutiliza. Como o relatório não tem um registo
  separado, *descrevam a evidência no sítio onde a usam pela primeira vez* (formato: `EV-nn`: localização — o que
  mostra); nas ocorrências seguintes basta o ID. Uma afirmação sem evidência não é um facto: marquem-na como
  *hipótese* (`H-nn`) e indiquem como a confirmar ou refutar.
]

// Diagrama de sequência em PlantUML, com os mesmos 6 passos da tabela (verificados no commit 0523102).
// Fonte: images/sequencia_pedido.puml. Dividido em duas partes (newpage) para ficar legível em A4; para regenerar:
// java -jar plantuml.jar -charset UTF-8 -tsvg images/sequencia_pedido.puml  (gera sequencia_pedido.svg e _001.svg)
#figure(
  image("../images/sequencia_pedido.svg", width: 100%),
  caption: [Sequência do processamento em lote de um projeto com vídeos (1/2: carregamento, _pipeline_ e _Apply_)],
)

#figure(
  image("../images/sequencia_pedido_001.svg", height: 21cm, fit: "contain"),
  caption: [Sequência do processamento em lote de um projeto com vídeos (2/2: processamento, progresso e resultado)],
)

#tab([Passos do pedido completo],
  tabela(
    colunas: (2.6cm, 3.4cm, 1fr, 4.6cm),
    tamanho: 8.5pt,
    [Passo], [Origem → Destino], [Mensagem / _endpoint_ / fila], [Evidência],
    [Carregamento do vídeo], [browser → `nginx` → `api_gateway` → `projects` → `img_storage` → SeaweedFS], [`POST /:user/:project/video` (`multipart`, campo `video`), até 1100 MB], [*EV-01*: `nginx/nginx.conf:13`, `apiGateway/routes/projects.js:23`, `projects/routes/projects.js:72, 1392`, `imageStorageService/route/upload.js:6` — o ficheiro inteiro é recebido em memória (`multer.memoryStorage`) em cada salto, com limite de 1100 MB],
    [Definição do _pipeline_], [browser → `api_gateway` → `projects`], [`POST /:user/:project/tool`; as ferramentas de vídeo são as de `VIDEO_TOOLS`], [*EV-02*: `projects/routes/projects.js:1397`, `projects/utils/video.js:16-25` — o orquestrador conhece as listas `VIDEO_TOOLS`, `VIDEO_ONLY_TOOLS` e `PER_VIDEO_TOOLS`],
    [_Apply_], [browser → `projects` → RabbitMQ], [`POST /:user/:project/process`; uma mensagem por ficheiro; para vídeo, `procedure: "video"` com a lista completa de ferramentas, publicada na `video_queue`], [*EV-03*: `projects/routes/projects.js:1521, 1665-1672` (regista o lote todo e só depois envia), `projects/utils/project_msg.js:21, 26-40` — todo o trabalho `video` vai para uma única fila, `video_queue`],
    [Processamento], [`video_queue` → `video_tool`], [consumo com `prefetch_count=1`, `auto_ack=False`; `process_video` corre o _pipeline_ ffmpeg de uma vez], [*EV-04*: `Tools/video/video.py:51-54, 172-175` — cada consumidor recebe uma mensagem de cada vez e confirma-a manualmente],
    [Progresso], [`video_tool` → `ws_queue` → `ws_gateway` → browser], [mensagens de progresso em percentagem (WebSocket)], [*EV-05*: `Tools/video/video.py:112-124` — o progresso é publicado na `ws_queue`],
    [Resultado], [`video_tool` → `project_queue` → `projects` → browser], [sucesso ou erro (códigos 2000–2005); o `projects` só regista a execução se o `activeToken` não tiver mudado (cancelamento)], [*EV-06*: `Tools/video/video.py:76-110` (respostas na `project_queue`), `projects/routes/projects.js:232-233, 440` (verificação do `activeToken`)],
  ),
)
