#import "../template.typ": *

= Alternativas e Matriz de Comparação

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secção 3 do _template_.

  *Objetivo do capítulo:* comparar o padrão atual com alternativas relevantes *para o processamento de vídeo*, de forma
  fundamentada, e concluir se o padrão atual é adequado. Entre duas e três alternativas. O padrão global é o contexto da
  comparação: indiquem sempre se cada alternativa o *mantém* ou o *altera*.

  *Restrição da fase:* é de _refactoring_. As alternativas têm de preservar o comportamento funcional; por isso, o
  custo e o risco de migração têm de ser analisados para cada uma. Consultem os slides da aula 11 e o documento de apoio
  de padrões arquiteturais; se for relevante, incluam uma alternativa ao próprio padrão global como termo de comparação.
]

== Alternativas consideradas

#tab([Alternativas consideradas],
  tabela(
    colunas: (1.6cm, 3.4cm, 1fr, 3cm, 2.4cm),
    tamanho: 8.5pt,
    [ID], [Nome / padrão], [Descrição breve], [Mantém ou altera o padrão global?], [Fonte],
    [ALT-1], [Um microserviço por efeito de vídeo (Microserviços + _Pipes and Filters_ distribuído)], [Cada ferramenta de vídeo passa a ser um serviço com a sua fila, como nas imagens; o `projects` encadeia os passos.], [Mantém (é o caminho das imagens)], [Documento de apoio de padrões; caminho de imagens (EV-03)],
    [ALT-2], [Um serviço por tipo de trabalho, com consumidores concorrentes (Microserviços + _Competing Consumers_)], [Três serviços (edição, legendagem, extração), cada um com a sua fila e réplicas ajustadas pelo tamanho da fila. Os efeitos passam para um módulo partilhado com as ferramentas de imagem. O `projects` encadeia os estágios.], [Mantém], [Documento de apoio de padrões (_Competing Consumers_); estágios existentes (EV-15)],
    [ALT-3], [Monólito modular com réplicas fixas], [O `video_tool` mantém-se como um serviço, organizado internamente em módulos (registo de efeitos, legendagem, extração), e corre com N réplicas fixas.], [Afasta-se (como hoje)], [Slides da aula 11 (monólito modular)],
  ),
)

Foi ainda considerada, e afastada logo à partida, uma alternativa com um _job_ efémero por vídeo, lançado por um
orquestrador de _workflows_ (e.g., Kubernetes Jobs). Daria isolamento total e elasticidade natural, mas exige outra
plataforma de execução, o que está fora do âmbito de um _refactoring_ e do prazo da fase.

== Análise de cada alternativa

#orientacao[
  Copiem o bloco abaixo para cada alternativa. Para cada uma, descrevam a coerência com o padrão global, o efeito nos
  atributos de qualidade, as vantagens, as desvantagens ou riscos, e o custo e risco de migração. Evitem listas
  genéricas: cada ponto deve referir algo concreto da solução do PictuRAS (e citar evidência `EV-nn` ou hipótese `H-nn`).
]

*ALT-1 — Um microserviço por efeito de vídeo*

#tabela-campos(
  [Coerência com o padrão global], [Total: o vídeo passa a seguir o mesmo desenho das imagens (EV-03).],
  [Efeito nos atributos de qualidade], [Modularidade ↑ (cada efeito muda sozinho). Comportamento temporal ↓↓: cada serviço descodifica e recodifica o vídeo inteiro. Capacidade ↑ (cada efeito escala sozinho).],
  [Vantagens potenciais], [Uniformidade; os efeitos podem ser os mesmos serviços das imagens, o que elimina a duplicação de EV-12.],
  [Desvantagens ou riscos], [Um _pipeline_ de 3 filtros passa de 1 para 3 codificações: mais tempo e perda de qualidade (é a razão pela qual o PL1-G4 rejeitou este desenho). Muitos MP4 intermédios em `image_data` (EV-08).],
  [Custo e risco de migração (a funcionalidade existente tem de ser preservada)], [Alto: o encadeamento passa todo para o `projects` (cresce o orquestrador, H-09); as saídas deixam de ser iguais bit a bit (mais codificações), o que torna a regressão por _hash_ (H-07) impossível.],
)

*ALT-2 — Um serviço por tipo de trabalho, com consumidores concorrentes*

#tabela-campos(
  [Coerência com o padrão global], [Alta: serviços com filas próprias e encadeamento pelo `projects`. Usa o _Competing Consumers_, que o padrão global permite mas não usa.],
  [Efeito nos atributos de qualidade], [Capacidade ↑↑ (cada tipo de trabalho tem a sua fila e as suas réplicas; a legendagem deixa de bloquear a edição). Modularidade ↑↑ (dependências separadas; efeitos num só módulo). Comportamento temporal ≈ (corta só nos estágios que já produzem um MP4 intermédio, EV-15; H-06).],
  [Vantagens potenciais], [Imagens Docker mais pequenas para a edição e a extração (sem `faster-whisper`, EV-14). A mudança do motor de legendas só reimplanta a legendagem.],
  [Desvantagens ou riscos], [Mais serviços e filas para operar; o ajuste automático de réplicas é uma peça nova. O cancelamento passa a atravessar vários serviços (H-05, H-08). O orquestrador pode crescer (H-09).],
  [Custo e risco de migração], [Médio: o código de cada tipo de trabalho já está em ficheiros separados (EV-11); o maior risco está no encadeamento e no cancelamento, cobertos pelos testes existentes (`Tools/video/tests`, `projects/tests`) e por testes novos para H-05 e H-08.],
)

*ALT-3 — Monólito modular com réplicas fixas*

#tabela-campos(
  [Coerência com o padrão global], [Baixa, como hoje: um serviço para todos os tipos de trabalho.],
  [Efeito nos atributos de qualidade], [Capacidade ↑ (N trabalhos em paralelo), mas fixa e partilhada: uma legendagem ocupa sempre uma réplica inteira. Modularidade ↑ apenas no código; a implantação continua única.],
  [Vantagens potenciais], [Barata e com pouco risco: quase só configuração (`--scale`) e reorganização interna.],
  [Desvantagens ou riscos], [Não resolve EV-14 (imagem única de 1,69 GB) nem os cenários de mudança (EV-17: os 3 tipos são reimplantados). Réplicas fixas gastam recursos sem carga e não chegam em pico. Depende de H-01 a H-03.],
  [Custo e risco de migração], [Baixo.],
)

== Matriz de comparação de padrões

#orientacao[
  Atribuam um nível a cada atributo para o padrão global (referência), para o padrão atual do vídeo e para cada
  alternativa. A escala é à vossa escolha (e.g., Alto / Médio / Baixo) e deve ser a mesma em toda a matriz.

  *Justifiquem cada célula* com evidência da solução (`EV-nn` ou `H-nn`) numa frase curta, logo na própria célula: as
  avaliações sem fundamento não são valorizadas. A matriz inclui o padrão global como referência para se ver o que
  cada alternativa ganha ou perde em relação a ele. Os atributos e subcaracterísticas seguem a ISO/IEC 25010; podem
  acrescentar linhas para outros atributos relevantes.
]

#paisagem[
#tab([Matriz de comparação de padrões (escala: Alto / Médio / Baixo)],
  tabela(
    colunas: (4cm, 4cm, 4cm, 4cm, 4cm, 4cm),
    tamanho: 8pt,
    [Atributo de qualidade (ISO/IEC 25010)], [Padrão global atual (referência)], [Padrão atual do vídeo], [ALT-1 (serviço por efeito)], [ALT-2 (serviço por tipo de trabalho + _Competing Consumers_)], [ALT-3 (monólito modular + réplicas fixas)],
    [Relação com o padrão global], [—], [Afasta-se], [Mantém], [Mantém], [Afasta-se],
    [Eficiência de desempenho: comportamento temporal], [Alto — passos curtos de imagem, sem bloqueio no _Apply_ (EV-03)], [Alto — uma codificação por _pipeline_ (EV-10)], [Baixo — uma recodificação por efeito], [Alto — corta nos estágios existentes (EV-15, H-06)], [Alto — igual ao atual],
    [Eficiência de desempenho: capacidade / elasticidade], [Médio — um consumidor por fila, mas trabalhos curtos (EV-07)], [Baixo — um _worker_, `prefetch=1`, M1 p95 322,6 s (EV-04, EV-18)], [Médio — cada efeito escala, mas mais trabalho por vídeo], [Alto — réplicas por tipo de trabalho, ajustadas à fila], [Médio — N réplicas fixas; a legendagem ocupa uma (H-01)],
    [Fiabilidade: tolerância a falhas / recuperabilidade], [Baixo — `auto_ack=True` perde mensagens (EV-09)], [Médio — `ack` manual no fim (EV-10)], [Médio — mais saltos, cada um com `ack`], [Médio — `ack` manual; com réplicas, outra instância continua (H-05)], [Médio — igual ao atual, com réplicas],
    [Manutenibilidade: modularidade / modificabilidade], [Alto — um serviço por ferramenta (EV-03)], [Baixo — 8 efeitos duplicados; uma mudança reimplanta 3 tipos (EV-12, EV-17)], [Alto — mas o orquestrador cresce (H-09)], [Alto — dependências separadas; efeitos num módulo (EV-14)], [Médio — módulos internos, uma só implantação],
    [Segurança], [Médio — sem alteração], [Médio — sem alteração], [Médio — sem alteração], [Médio — o ajuste automático precisa de acesso à API do Docker], [Médio — sem alteração],
    [Usabilidade: operabilidade], [Alto — progresso por WebSocket (EV-05)], [Médio — espera longa sem explicação (EV-18)], [Médio — mais lento por vídeo], [Alto — espera curta mesmo com legendagens em curso], [Médio — depende do número de réplicas],
  ),
)
]

== Adequação do padrão atual

O padrão global (microserviços com filas) é adequado e é o contexto que se mantém: dá modularidade no caminho das
imagens e desacopla o _Apply_ do processamento. O padrão atual do vídeo foi uma escolha consciente do PL1-G4 para evitar
recodificações, e nesse ponto continua certo: a ALT-1 confirma que um serviço por efeito piora muito o comportamento
temporal. Mas o _pipeline monolith_ é *pouco adequado* aos requisitos de capacidade (REQ-VID-EDIT-011) e de modificabilidade
(REQ-VID-EDIT-013): um trabalho curto espera 5 min atrás de uma legendagem (EV-18) e qualquer mudança reimplanta os
três tipos de trabalho (EV-17). A ALT-3 é a mais barata mas só melhora parcialmente a capacidade e mantém a implantação
única. A *ALT-2* é a única que melhora as duas qualidades sem recodificações extra, porque corta nos estágios que já
existem (EV-15), e mantém a coerência com o padrão global. É a alternativa adotada nos capítulos seguintes, a realizar
em duas etapas: primeiro a divisão por tipo de trabalho (modularidade), depois as réplicas com ajuste automático
(capacidade).
