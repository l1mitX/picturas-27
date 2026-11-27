#import "../template.typ": *

= Introdução

#orientacao[
  Uma a duas páginas, no máximo. O leitor deve perceber, sem ler o resto, o que é este documento e em que se baseia.
  Respondam a:
  - *Propósito da fase*: que requisitos não funcionais do PictuRAS se pretende melhorar, por _refactoring_ e sem novas
    funcionalidades, e porquê.
  - *_Baseline_*: em que versão do sistema se basearam (_commit_ de partida), a mesma em todos os exercícios. Este
    relatório *estende* os documentos de base; não os reescreve.
  - *Âmbito do que é apresentado*: este relatório reúne os contributos dos Exercícios 6 (Blocos 1 e 2) e 7. Reutiliza
    os respetivos _templates_: copiem o conteúdo já preenchido, *mantendo os IDs* (`EV`, `H`, `ALT`, `QS`, `CAND`,
    `TAT`, `DA`), porque é através deles que os capítulos se encadeiam.
  - *Organização do documento*: Partes II (diagnóstico), III (qualidade), IV (táticas, decisões, medição e resultados)
    e V (síntese).
]

== Propósito e âmbito
Na Fase 1, o PictuRAS passou a aceitar vídeo, com o objetivo de validar as funcionalidades e sem exigir a qualidade
de um produto final. Nesta fase, a equipa melhora dois requisitos não funcionais do processamento de vídeo sem
acrescentar funcionalidades, pelo que o utilizador obtém os mesmos resultados que antes.

O primeiro requisito é a modularidade (CAND-2, RNF2). Na base, todo o vídeo é tratado por um único serviço, e uma
simples mudança nas legendas obriga a reconstruir e a voltar a instalar todo o processamento de vídeo. Isto torna
cada alteração lenta e arriscada para a equipa, que reconstrói uma imagem de 1,69 GB e mantém vários efeitos
implementados duas vezes, uma para imagem e outra para vídeo. Por isso, a
equipa dividiu esse serviço em três, um para cada tipo de trabalho: edição, legendas e extração de fotogramas.

O segundo requisito é a capacidade (CAND-1, RNF1). Na base, os vídeos são tratados um de cada vez, o que faz com que
cada utilizador espere pelos outros e com que uma legendagem longa atrase todos os vídeos que chegam depois. Com
quatro edições ao mesmo tempo, cada uma demora 44,0 s em vez de 17,8 s, e o requisito da Fase 1 que pede pelo menos
dois vídeos em paralelo (REQ-VID-EDIT-011) não é cumprido. A equipa
passou a correr várias cópias de cada serviço de vídeo e acrescentou um componente que ajusta o número de cópias ao
trabalho em espera.

O primeiro requisito é condição para o segundo, porque só depois de separar os serviços faz sentido ter mais cópias de
cada um. Mesmo assim, cada requisito é especificado, implementado e medido em separado.

O tratamento de imagens não muda. As alterações seguem o padrão do resto da solução, em que cada ferramenta é um
serviço próprio que recebe trabalho através de uma fila de mensagens.

== _Baseline_ e repositório
#tab([Artefactos de partida],
  tabela(
    colunas: (5cm, 1fr),
    [Artefacto], [Versão / referência],
    [Documento de requisitos de base], [doc-ext-requisitos-2627.pdf],
    [Documento de solução arquitetural de base], [doc-sol-arquitetural.pdf],
    [Repositório de partida], [`https://github.com/picturas-um/picturas-27`, ramo `main`, _commit_ `0523102` (`052310226c51fa57a17101c7bd1ad795674aac95`)],
    [Repositório entregue], [`https://github.com/l1mitX/picturas-27`, ramo `main`, _commit_ #preencher[último _commit_ antes da entrega]],
    [Diretrizes da Fase 2], [Versão 1, de 4 de novembro de 2026],
  ),
)

Todo o trabalho parte do mesmo _commit_ do repositório oficial. As evidências e as medições iniciais foram recolhidas
nessa versão. Este relatório acrescenta aos documentos de base o que mudou nesta fase. Não os reescreve.

== Exercícios e versões usadas

#orientacao[
  Indiquem, para cada exercício, a versão do enunciado e do _template_ que usaram, e a versão do vosso documento que
  serviu de entrada ao exercício seguinte (Bloco 1 → Bloco 2 → Exercício 7). Isto garante que quem avalia consegue
  perceber a que regras o trabalho respondeu, caso os enunciados tenham sido atualizados durante a fase.
]

#tab([Exercícios que alimentam este relatório],
  tabela(
    colunas: (3.6cm, 2.2cm, 2cm, 2cm, 1fr),
    [Exercício], [Capítulos], [Enunciado], [Template], [Versão do documento da equipa],
    [Exercício 6, Bloco 1: padrões arquiteturais], [2, 3 e 4], [1.1], [1.1], [v1.1],
    [Exercício 6, Bloco 2: trade-offs, cenários e candidatos a RNF], [5 e 6], [1.1], [1.1], [v1.1],
    [Exercício 7: táticas arquiteturais], [7 a 10], [3.0], [3.0], [v1.0],
  ),
)

== Organização do documento
O relatório tem cinco partes. A Parte I é esta introdução. A Parte II descreve a arquitetura da base e as suas
fragilidades (capítulos 2 a 4). A Parte III define os cenários de qualidade e escolhe os dois requisitos a melhorar
(capítulos 5 e 6). A Parte IV apresenta as táticas, as decisões, a arquitetura antes e depois, e os resultados das
medições (capítulos 7 a 10). A Parte V reúne as conclusões e o uso de inteligência artificial (capítulos 11 e 12).

Cada elemento do relatório tem um identificador. Por exemplo, `EV-04` é uma evidência e `DA-1` é uma decisão. Os
capítulos usam estes identificadores para se referirem uns aos outros. Assim, é possível seguir cada decisão até à
evidência que a justifica, passando pelas hipóteses (`H`), pelas alternativas (`ALT`), pelos cenários (`QS`), pelos
candidatos a requisito (`CAND`) e pelas táticas (`TAT`).
