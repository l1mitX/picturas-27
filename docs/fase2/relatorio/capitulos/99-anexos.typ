#import "../template.typ": *

#set heading(numbering: "A.1.")
#counter(heading).update(0)

= Instruções de execução

#orientacao[
  Indiquem os passos mínimos para lançar a solução a partir do repositório (pré-requisitos, comandos, projeto de teste) e
  para repetir as medições (antes e depois do _refactoring_) (_scripts_, dados, ambiente). Quem avalia, ou a equipa na fase seguinte, deve
  conseguir repetir o que descrevem sem ajuda. No glossário, definam os termos específicos do projeto ou da disciplina
  usados no relatório.
]

Todos os comandos correm na raiz do repositório, no ramo `main`.

*Pré-requisitos.* Docker e Docker Compose. A máquina de referência tinha 12 CPUs e 7,7 GiB atribuídos ao Docker. As
portas expostas no `docker-compose.yaml` têm de estar livres, entre elas a 8080 (aplicação) e a 9090 (SeaweedFS), que
outros programas instalados podem estar a usar. Para os _scripts_ de medição
basta Python 3, sem bibliotecas extra.

*Lançar a solução.* O comando seguinte constrói e arranca todos os serviços, incluindo os três serviços de vídeo e o
`video_autoscaler`. A primeira construção demora vários minutos.

```
docker compose up -d --build
```

A aplicação fica em `https://localhost:8080`, com um certificado próprio que o browser pede para aceitar. Os utilizadores
anónimos não editam vídeo, e os Premium têm os limites maiores (vídeos até 600 s). Há vídeos de teste em
`samples/video/`.

*Correr os testes.* Os testes do `projects` correm dentro do contentor. Os de cada serviço de vídeo correm num
contentor do próprio serviço, com o repositório montado (o comando exato está no `README.md` de cada serviço, em
`Tools/video_edit/`, `Tools/video_subtitles/` e `Tools/video_frames/`). Os do `video_autoscaler` não precisam da
aplicação.

```
docker compose exec -T projects sh -c "node --test tests/*.test.js"
cd Tools/video_autoscaler && python3 -m pip install -r requirements.txt pytest \
  && python3 -m pytest -q tests
```

*Repetir as medições.* Antes de medir, convém ler a secção «Antes de medir» de `docs/fase2/medicoes/README.md`, que
fixa os três momentos de medição e os parâmetros. Cada _script_ tem o seu uso descrito no cabeçalho, e os resultados
ficam em `docs/fase2/medicoes/resultados/<etiqueta>/`. Para comparar tempos, a medição de antes e a de depois devem
ser feitas no mesmo dia e na mesma máquina, ligada à corrente.

```
python docs/fase2/medicoes/carga_rnf1.py <etiqueta> isolado
python docs/fase2/medicoes/carga_rnf1.py <etiqueta> m1
python docs/fase2/medicoes/carga_rnf1.py <etiqueta> m2
python docs/fase2/medicoes/carga_rnf1.py <etiqueta> paralelo [--pausa 120]
python docs/fase2/medicoes/elasticidade_m4.py apos-rnf1
```

A `<etiqueta>` é o momento da medição: `base`, `apos-rnf2` ou `apos-rnf1` (secção 10.3). Cada momento mede o código
de um _commit_ diferente, que é o `0523102` na base, o `a3dcdac` depois do RNF2 e o `dc37d4e` depois do RNF1. Para
repetir a base ou a `apos-rnf2`, repõe-se o código desse _commit_ numa cópia do repositório, copia-se para lá a pasta
`docs/fase2/medicoes/` do ramo `main` e corre-se tudo na raiz dessa cópia. A opção `--pausa 120` usa-se só na
`apos-rnf1`, porque só aí as réplicas sobem e descem. A pausa dá tempo ao `video_autoscaler` para voltar ao mínimo
antes de cada repetição. As medidas estáticas (`rnf2_estaticas.py`) e a regressão por _hash_ (`regressao_hashes.py`,
de imagem e de vídeo) correm em contentores, com os comandos indicados no cabeçalho de cada _script_.

= Glossário

#tabela(
  colunas: (4cm, 1fr),
  [Termo], [Definição],
  [_Apply_], [Ação do utilizador que aplica o _pipeline_ de um projeto a todos os seus ficheiros.],
  [_Baseline_ (base)], [Medição feita na solução de partida (_commit_ `0523102`), antes de qualquer alteração. Serve de termo de comparação.],
  [Cenário de qualidade (QS)], [Descrição verificável de um requisito de qualidade, com seis elementos: fonte, estímulo, artefacto, ambiente, resposta e medida da resposta.],
  [_Competing Consumers_], [Padrão em que várias réplicas de um serviço consomem da mesma fila, cada mensagem tratada por uma só delas.],
  [`consumer_timeout`], [Tempo máximo que o RabbitMQ espera pela confirmação de uma mensagem antes de a entregar a outro consumidor.],
  [Débito], [Número de vídeos processados por minuto.],
  [Decisão arquitetural (DA)], [Registo de uma escolha de arquitetura, com o contexto, as alternativas, as consequências e a implementação.],
  [Estágio], [Parte do _pipeline_ de um vídeo tratada por um único serviço (edição, legendagem ou extração).],
  [Evidência (EV)], [Facto verificável sobre a solução, com a localização exata (ficheiro e linhas, medição ou documento).],
  [_Hash_ de regressão], [Impressão digital de um ficheiro de saída. Saídas com o mesmo _hash_ que a base são exatamente iguais.],
  [_Heartbeat_], [Sinal periódico entre um serviço e o RabbitMQ que permite detetar uma ligação bloqueada.],
  [Hipótese (H)], [Afirmação ainda sem evidência, com o modo de a confirmar ou refutar.],
  [p50 / p95], [Valores abaixo dos quais ficam 50 % e 95 % das medições. O p95 mostra os casos mais lentos.],
  [Paragem ordenada], [Saída de uma réplica que deixa de aceitar trabalho, acaba o estágio em curso, confirma-o e só depois termina.],
  [_Pipeline_], [Lista ordenada de ferramentas que um projeto aplica aos seus ficheiros.],
  [Réplica], [Cópia de um serviço que corre em paralelo com as outras e consome da mesma fila.],
  [Réplicas frias / quentes], [Medição que começa com o número mínimo de réplicas (frias) ou com as réplicas já todas ligadas (quentes).],
  [Requisito não funcional (RNF)], [Requisito sobre a qualidade do sistema (por exemplo, capacidade ou modularidade), e não sobre o que o sistema faz.],
  [Tática], [Técnica de arquitetura que melhora um atributo de qualidade (por exemplo, replicar computação).],
  [`video_autoscaler`], [Serviço que ajusta o número de réplicas de cada serviço de vídeo ao tamanho da sua fila.],
)
