#import "../template.typ": *

= Vista Arquitetural Antes e Depois

#orientacao[
  *Origem:* Exercício 7, secção 4 do _template_.

  Duas vistas do mesmo diagrama: *antes* e *depois* das decisões. Usem o tipo de diagrama que melhor mostrar a alteração
  (componentes, implantação ou sequência). Destaquem os elementos ou as interações introduzidos ou alterados pelas
  táticas (com um estereótipo `«tática: …»` ou uma cor) e incluam uma *legenda*.

  As duas vistas devem ser comparáveis: mesma notação, mesma escala e os mesmos elementos de contexto, de modo a que a
  diferença se perceba a olho. A legenda e as notas explicam o que mudou entre elas e porquê.
]

// Fontes: images/vista_antes.puml e images/vista_depois.puml (estilo comum em images/_estilo.iuml).
// Gerar com PlantUML ≥ 1.2023: java -jar plantuml.jar -charset UTF-8 -tsvg vista_antes.puml vista_depois.puml
Diagramas de componentes em PlantUML, com a mesma notação, a mesma escala e os mesmos elementos de contexto nas duas
vistas, com as filas de trabalho em cima, os _workers_ no meio e as filas de resposta em baixo.

== Antes

#figure(
  image("../images/vista_antes.svg", width: 54%),
  caption: [Vista arquitetural antes das decisões DA-1 e DA-2],
)

== Depois

#figure(
  image("../images/vista_depois.svg", width: 100%),
  caption: [Vista arquitetural depois das decisões DA-1 e DA-2],
)

== Legenda e notas

- *Laranja (antes).* São os elementos que as decisões vão alterar, ou seja, a `video_queue` única e o `video_tool` com os três tipos de trabalho e os efeitos copiados.
- *Verde (depois).* São os elementos novos ou alterados, marcados com o estereótipo da tática que os realiza.
  - Três filas e três serviços de vídeo, com 1 a 4 réplicas na edição, 1 a 2 na extração e 1 na legendagem («tática: dividir o módulo», DA-2).
  - `Tools/effects/`, usado pelo `video_edit` e pelas 8 ferramentas de imagem com efeitos («tática: abstrair serviços comuns», DA-2).
  - O `projects`, que encadeia os estágios do vídeo («tática: intermediário», DA-2).
  - O `video_autoscaler`, que lê o tamanho das filas e acrescenta ou retira réplicas com o `docker compose --scale`, através do _socket_ do Docker («tática: replicar computação + aumentar recursos (elástico)», DA-1).
  - Nos _workers_ de vídeo, a paragem ordenada e o _heartbeat_ numa _thread_ separada («tática: reintrodução ordenada e heartbeat», DA-1, TAT-13).
- *Cinzento.* É o que se mantém, ou seja, as ferramentas de imagem, a `project_queue`, a `ws_queue` e o volume `image_data`.
- A vista «depois» foi revista depois da implementação (T029, `db5507b`) e corresponde ao código entregue, incluindo o máximo de 1 réplica na legendagem.
