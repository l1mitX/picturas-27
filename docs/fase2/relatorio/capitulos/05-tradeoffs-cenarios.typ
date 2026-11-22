#import "../template.typ": *

= Trade-offs, Cenários de Qualidade e Prioridades

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 4 do _template_ (sem a justificação detalhada da matriz, que não faz parte
  deste relatório).

  *Objetivo do capítulo:* transformar o diagnóstico dos capítulos 2 a 4 em cenários de qualidade concretos e
  verificáveis, priorizá-los e perceber como os atributos se afetam uns aos outros.

  *Princípio central:* a caracterização dos cenários de qualidade *deve basear-se na identificação de fragilidades do
  sistema atual*. Cada cenário parte de uma fragilidade concreta, com evidência (`EV-nn`), observada na solução de
  base (e.g., uma falha sem recuperação, um ponto de contenção, uma dependência rígida). Um cenário sem fragilidade
  identificada é uma preferência, não uma necessidade. Reutilizem os `EV`, `H` e `ALT` já usados, sem os alterar.

  *Este é o único sítio onde os cenários de qualidade se caracterizam:* os capítulos 6 a 10 usam-nos sem os reescrever.
]

== Cenários de qualidade para a extensão de vídeo

#orientacao[
  Para cada fragilidade relevante, escrevam um cenário com os *seis elementos*:
  - *fonte do estímulo*: quem ou o que o origina (utilizador, serviço, falha de infraestrutura);
  - *estímulo*: o evento a que o sistema tem de reagir;
  - *artefacto*: a parte do sistema afetada;
  - *ambiente*: em que condições (carga normal, pico, degradado);
  - *resposta*: o que o sistema deve fazer;
  - *medida da resposta*: como se verifica, com métrica e escala. Definem-na vocês e tem de ser *verificável*.

  A coluna *Fragilidade* liga o cenário à evidência que o justifica. Não inventem valores de _baseline_, alvo ou
  mínimo: esses fixam-se após a medição inicial. A medida da resposta indica o que se mede, não o valor a atingir.
]

Evidência usada pela primeira vez neste capítulo:

- *EV-26* (medição): `python docs/fase2/medicoes/carga_rnf1.py base paralelo --n 4` → `medicoes/resultados/base/carga_paralelo_resumo.json` — 4 edições curtas (brilho em `sample_10s_720p.mp4`) submetidas ao mesmo tempo, sem legendagem, demoram p95 44,0 s (p50 28,8 s), para 17,8 s de um trabalho sozinho; débito de 5,54 vídeos/min (5 repetições). O `docker stats` recolhido em paralelo regista uma única réplica (`picturas-video_tool-1`).

#paisagem[
#tab([Cenários de qualidade],
  tabela(
    colunas: (1.2cm, 3.4cm, 2.6cm, 2.2cm, 2.6cm, 2.4cm, 2.2cm, 2.8cm, 3.2cm),
    tamanho: 7.5pt,
    [ID], [Fragilidade na base (EV-nn)], [Característica (ISO/IEC 25010)], [Fonte do estímulo], [Estímulo], [Artefacto], [Ambiente], [Resposta], [Medida da resposta],
    [QS-01], [Um único _worker_ de vídeo, com `prefetch=1` e uma só fila: um trabalho curto espera pelo fim de uma legendagem (EV-03, EV-04, EV-07, EV-10, EV-18)], [Eficiência de desempenho → capacidade], [Dois utilizadores Premium, em simultâneo], [O utilizador A pede a legendagem de um vídeo de 177 s; 5 s depois, o utilizador B aplica um efeito de brilho a um vídeo de 10 s], [Serviços de processamento de vídeo e respetivas filas], [Operação normal; uma legendagem de outro utilizador em curso e nenhum outro trabalho], [O trabalho de B é processado sem esperar pelo fim da legendagem de A; os dois terminam corretamente], [Tempo desde o _Apply_ de B até o resultado estar disponível (s; p50 e p95)],
    [QS-02], [Edição, legendagem e extração no mesmo processo e na mesma imagem Docker; qualquer mudança reimplanta os 3 tipos de trabalho (EV-11, EV-13, EV-14, EV-17)], [Manutenibilidade → modularidade], [Um programador da equipa], [Atualizar a versão do `faster-whisper` ou o modelo de legendas], [Código e imagens Docker dos serviços de vídeo], [Tempo de desenvolvimento e implantação, com o sistema em funcionamento], [A mudança fica contida na legendagem: a edição e a extração não são alteradas, reconstruídas nem reimplantadas], [Número de tipos de trabalho de vídeo reimplantados; ficheiros alterados; serviços reconstruídos (contagens)],
    [QS-03], [O mesmo _worker_ único serve vários pedidos curtos um a um (EV-04, EV-07, EV-26)], [Eficiência de desempenho → capacidade], [Quatro utilizadores Premium, em simultâneo], [Submetem ao mesmo tempo 4 edições de brilho a vídeos de 10 s], [Serviços de processamento de vídeo e respetivas filas], [Operação normal; sem legendagens], [Os 4 trabalhos são processados em paralelo], [Tempo por trabalho (s; p50 e p95) e débito (vídeos concluídos por minuto)],
    [QS-04], [8 efeitos implementados duas vezes, uma para imagem e outra para vídeo (EV-12, EV-17)], [Manutenibilidade → modificabilidade], [Um programador da equipa], [Alterar o comportamento do filtro de brilho, de forma igual para imagem e vídeo], [Código dos efeitos e serviços que os usam], [Tempo de desenvolvimento], [A alteração é feita num único sítio e vale para imagem e vídeo], [Número de implementações do efeito alteradas; serviços reconstruídos (contagens)],
    [QS-05], [Os carregamentos são recebidos inteiros em memória em cada salto, até 1100 MB (EV-01)], [Eficiência de desempenho → utilização de recursos], [Três utilizadores Premium, em simultâneo], [Carregam, cada um, um vídeo de 1 GB], [`api_gateway`, `projects`, `img_storage`], [Operação normal], [Os três carregamentos terminam sem esgotar a memória dos serviços], [Memória máxima de cada serviço durante o carregamento (MiB)],
  ),
)
]

#orientacao[
  *Priorização.* Avaliem cada cenário em duas dimensões: a *importância para os stakeholders* (quem sofre com a
  fragilidade e quanto) e a *dificuldade ou risco técnico* de a resolver. Justifiquem cada avaliação em poucas palavras
  e atribuam uma ordem de prioridade (1 = mais prioritário). Os dois cenários mais prioritários, e que dão origem aos
  candidatos a RNF do capítulo 6, são os mais importantes e viáveis, não necessariamente os mais fáceis.
]

#tab([Priorização dos cenários],
  tabela(
    colunas: (1.6cm, 5.2cm, 5.2cm, 1.8cm),
    tamanho: 8.5pt,
    [ID], [Importância para os stakeholders], [Dificuldade / risco técnico], [Prioridade],
    [QS-01], [Alta — o utilizador espera mais de 5 min por um efeito que demora 15 s (EV-18); o REQ-VID-EDIT-011 pede, no MVP, pelo menos 2 vídeos em paralelo], [Média — resolvido sobretudo pela divisão em serviços por tipo de trabalho do QS-02 (pré-requisito, Tabela 15): a legendagem passa a ter a sua fila e deixa de bloquear a edição, sem tática própria], [3],
    [QS-02], [Média-alta — para a equipa, cada mudança nas legendas reconstrói uma imagem de 1,69 GB e reimplanta todo o vídeo (EV-14, EV-17); REQ-VID-EDIT-013], [Média — divisão do serviço; o cancelamento passa a atravessar vários serviços (H-08)], [2],
    [QS-03], [Alta — é o caso mais comum (vários utilizadores a editar ao mesmo tempo): com 4 edições curtas em simultâneo, o p95 passa de 17,8 s para 44,0 s (EV-26)], [Alta — réplicas por serviço de vídeo e ajuste automático pelo tamanho da fila; hipóteses H-01 a H-05], [1],
    [QS-04], [Média — risco de imagem e vídeo divergirem (regra sem requisito explícito, hoje garantida por cópia) e REQ-VID-EDIT-013 (acrescentar um efeito sem alterar os existentes)], [Média — extrair um módulo comum mexe também nas 8 ferramentas de imagem (regressão por _hash_, H-07); se o módulo ficar em `Tools/utils`, passa a reconstruir 15 serviços (EV-28)], [4],
    [QS-05], [Média — só afeta carregamentos grandes e simultâneos: cada ficheiro, até 1100 MB, fica inteiro em memória em cada salto (EV-01), e o Docker da máquina de medição tem 7,7 GiB], [Alta — mexe no carregamento de imagens e vídeos, em três serviços; risco de regressão alto], [5],
  ),
)

O QS-01 é o cenário com a fragilidade mais grave para o utilizador, mas não fica no topo da priorização porque não
precisa de uma tática própria: a divisão em serviços por tipo de trabalho, exigida pelo QS-02, dá à legendagem a sua
fila e deixa de a pôr à frente das edições curtas (Tabela 15). Por isso, os dois cenários que dão origem aos candidatos
do capítulo 6 são o *QS-03* (capacidade: vários pedidos curtos em simultâneo, que só as réplicas resolvem) e o *QS-02*
(modularidade). O QS-01 continua a ser medido, como efeito da divisão do QS-02.

== Atributos de qualidade por ordem de prioridade

+ *Eficiência de desempenho → capacidade* — QS-03 e QS-01: a fragilidade é visível para todos os utilizadores e é o requisito de vídeo que a base não cumpre (EV-18, EV-26).
+ *Manutenibilidade → modularidade e modificabilidade* — QS-02 e QS-04: afeta a equipa em cada mudança, e é condição para resolver a capacidade por tipo de trabalho (secção 5.3).
+ *Eficiência de desempenho → utilização de recursos* — QS-05: risco real, mas localizado nos carregamentos grandes e fora do caminho de processamento do vídeo.

== Pré-requisitos e efeitos colaterais entre atributos

#tab([Pré-requisitos e efeitos colaterais entre atributos],
  tabela(
    colunas: (2.8cm, 2.8cm, 3.4cm, 1fr),
    tamanho: 8.5pt,
    [Atributo A], [Atributo B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [Modularidade (QS-02)], [Capacidade (QS-03, QS-01)], [Pré-requisito], [Só com serviços e filas por tipo de trabalho é possível escalar a edição sem que uma legendagem ocupe a réplica de uma edição curta (EV-03, EV-10). A divisão sozinha resolve a maior parte do QS-01; as réplicas por serviço resolvem o QS-03. Com o serviço único, as réplicas (ALT-3) melhoram o QS-03 mas pouco o QS-01.],
    [Modularidade (QS-02)], [Capacidade / elasticidade], [Sinergia], [Imagens mais pequenas para a edição (sem `faster-whisper`, EV-14) arrancam réplicas mais depressa.],
    [Modularidade (QS-02)], [Comportamento temporal], [Conflito potencial], [Mais um salto entre serviços e um MP4 intermédio por estágio podem aumentar o tempo de cada vídeo (H-06). Vigia-se com o tempo isolado em cada medição.],
    [Capacidade (QS-03)], [Utilização de recursos], [Conflito], [Durante uma legendagem, o `video_tool` (uma só instância) chegou a 2 506 MiB (≈ 2,4 GiB) de memória na medição do QS-01 (EV-18); com N réplicas de legendagem a memória cresce na mesma proporção, e a máquina de medição tem 7,7 GiB para o Docker.],
    [Capacidade (QS-03)], [Segurança], [Conflito], [O ajuste automático de réplicas precisa de acesso à API do Docker, que dá controlo sobre todos os contentores.],
    [Capacidade (QS-03)], [Fiabilidade → disponibilidade], [Sinergia], [Com várias réplicas e `ack` manual (EV-10), a queda de uma instância não para o processamento de vídeo. Ainda não testado: a base nunca correu com réplicas (H-01).],
  ),
)

== Recomendações de melhoria à solução atual

#tab([Recomendações de melhoria],
  tabela(
    colunas: (1fr, 2.6cm, 3cm, 1.8cm, 2.2cm),
    tamanho: 8.5pt,
    [Recomendação], [Atributo(s)], [Padrão a que se refere (global / vídeo)], [Esforço], [Risco de regressão],
    [Dividir o `video_tool` em serviços por tipo de trabalho (edição, legendagem, extração), cada um com a sua fila, encadeados pelo `projects` (ALT-2, etapa 1)], [Modularidade; modificabilidade], [Vídeo (aproxima-o do global)], [Médio], [Médio],
    [Extrair os 8 efeitos para um módulo partilhado entre imagem e vídeo, fora de `Tools/utils` para não reconstruir 15 serviços a cada mudança (EV-28)], [Modificabilidade], [Vídeo e global], [Médio], [Médio: mexe também nas 8 ferramentas de imagem (verificável por _hash_, H-07)],
    [Réplicas por serviço de vídeo, com ajuste automático pelo tamanho da fila (ALT-2, etapa 2)], [Capacidade; elasticidade], [Vídeo], [Médio], [Médio (H-01 a H-05)],
    [Configurar o `consumer_timeout` do RabbitMQ para a duração máxima de uma legendagem Premium], [Fiabilidade], [Global], [Baixo], [Baixo (H-04)],
    [Receber os carregamentos em disco ou em _stream_ em vez de memória (registado; fora do âmbito desta fase)], [Utilização de recursos], [Global], [Alto], [Alto],
    [Passar as ferramentas de imagem a `ack` manual (registado; fora do âmbito desta fase)], [Fiabilidade], [Global], [Baixo], [Médio],
  ),
)
