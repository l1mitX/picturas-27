#import "../template.typ": *

= Conclusões e Recomendações

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 6 do _template_.

  Sintetizem os contributos do relatório, sem repetir o conteúdo dos capítulos anteriores: o que o diagnóstico concluiu
  sobre a adequação do padrão atual, que otimizações sugerem e que considerações ficam para a evolução futura.

  Terminem com o que ficou por fazer e porquê (e.g., valores-alvo não atingidos, hipóteses por confirmar) e com a
  ligação à Fase 3: de que forma o _refactoring_ facilita, ou não, a integração de novas funcionalidades. Sejam realistas e honestos quanto às limitações da
  análise e às hipóteses que ficaram por confirmar.
]

== Adequação do padrão atual (global e do vídeo)

O padrão global da solução, com microserviços, filas de mensagens e orquestração no `projects`, mostrou-se adequado e
manteve-se. O padrão do vídeo na base, um único serviço que fazia todo o processamento, era uma escolha razoável para
evitar recodificações, mas não servia os requisitos de capacidade e de modificabilidade. Um trabalho curto esperava
minutos atrás de uma legendagem, e qualquer mudança reconstruía e reimplantava todo o vídeo.

Com a ALT-2, o vídeo passou a seguir o padrão global, com um serviço e uma fila por tipo de trabalho e réplicas
ajustadas à carga. Manteve a vantagem da base, porque continua a codificar o vídeo o mesmo número de vezes, e as saídas
são iguais às da base. A modularidade cumpre todos os valores-alvo, e a capacidade cumpre todos menos a meta
equivalente do M6 (capítulo 10).

== Sugestões de otimização

- *Mais réplicas de legendagem.* A legendagem tem no máximo uma réplica, porque cada uma usa cerca de 1,6 GiB de
  memória, e por isso o débito com várias legendagens (M2) não mudou. Numa máquina com mais memória, basta subir o
  máximo em `SCALE_VIDEO_SUBTITLES` e o limite de memória do serviço.
- *Uma réplica de edição de reserva.* Com um mínimo de duas réplicas de edição, um pico de trabalhos não esperaria os
  cerca de 11 s que uma réplica nova demora a começar (M4). O custo é mais memória ocupada sem carga.
- *Evitar o passo de preparação antes da legendagem.* Hoje, cada legendagem começa com um estágio de edição que
  recodifica o vídeo, para as saídas serem iguais às da base. Fora de uma fase de _refactoring_, este passo podia ser
  dispensado quando não há efeitos, o que encurtaria a legendagem e o M1, mas mudaria as saídas.
- *Carregamentos em disco.* Receber os ficheiros em disco ou aos poucos, em vez de inteiros em memória em cada serviço
  por onde passam (QS-05).
- *Confirmação manual nas ferramentas de imagem.* Como o vídeo já faz, as ferramentas de imagem deviam confirmar cada
  mensagem só no fim, para não perderem trabalho quando falham (EV-09).

== Considerações para evolução futura

- *Uma plataforma de orquestração em produção.* O `video_autoscaler` serve uma só máquina e precisa de acesso ao
  _socket_ do Docker, um risco que ficou documentado. Em produção, o ajuste automático deve passar para uma plataforma
  de orquestração (por exemplo, Kubernetes), que escala por vários servidores sem esse acesso.
- *Versões fixas nos Dockerfiles.* O `apt-get` não fixa as versões dos pacotes do sistema, por isso a mesma imagem muda
  de tamanho de um dia para o outro. Isto dificultou a medição do N3 e pode mudar o comportamento sem aviso.
- *Medir noutras máquinas.* Todas as medições foram feitas num só portátil, e o M6 mostrou que o ganho das réplicas
  depende do CPU disponível.
- *A `scale_queue`.* Esta fila está declarada no RabbitMQ, mas nenhum serviço a consome. Convém retirá-la ou criar o
  serviço que lhe corresponde.

== Trabalho futuro

Ficou por fazer o seguinte.

- A meta equivalente do M6 (p95 ≤ 11 s) não foi atingida, porque o CPU da máquina de medição não chega para quatro
  edições ao mesmo ritmo de uma sozinha. O alvo original e o valor mínimo foram cumpridos.
- O débito com várias legendagens (M2) não melhorou, pela limitação de memória descrita na secção anterior.
- A devolução da quota depois de um cancelamento a meio não foi verificada à parte, por isso a H-08 está confirmada só
  em parte.
- Na verificação manual (T040) encontraram-se duas fragilidades da base, que não foram corrigidas para não alterar a
  interface nesta fase. A primeira é que o botão de criar projeto não fica bloqueado enquanto os ficheiros carregam, e
  cliques repetidos criam projetos duplicados. A segunda é que, depois de guardar uma ferramenta, um _Apply_ imediato
  pode ser recusado por conflito de versão do projeto e só volta a funcionar depois de recarregar a página. A causa são
  dois pedidos do browser cujas respostas chegam por ordem variável. A correção é pequena, porque a barra de
  ferramentas já trata este conflito e basta o _Apply_ fazer o mesmo.

Para a Fase 3, o _refactoring_ facilita a integração de novas funcionalidades de vídeo. Um efeito novo passa a ser um
ficheiro em `Tools/effects/`, usado ao mesmo tempo pela imagem e pelo vídeo (REQ-VID-EDIT-013). Um tipo de trabalho novo
passa a ser um serviço com a sua fila, que se constrói, implanta e escala sozinho, sem tocar nos outros. A integração
continua, no entanto, a passar pelo `projects`, que planeia e encadeia os estágios e tem agora 2816 linhas. Por isso, uma
funcionalidade nova obriga a mexer no planeador de estágios, embora este esteja coberto por testes (68 no `projects`,
incluindo 32 planos de estágios tirados da base).
