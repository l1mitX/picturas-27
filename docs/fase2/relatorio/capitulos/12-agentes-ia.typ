#import "../template.typ": *

= Utilização de IA

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 7, e Exercício 7, secção 6.

  Obrigatório: documentar as ferramentas, os modelos e as _skills_ utilizadas, enumerar as tarefas apoiadas e comprovar a
  validação realizada pela equipa, tanto na análise e na escrita como no código e nas medições. A equipa é responsável
  por todo o conteúdo entregue, incluindo o gerado por IA.

  Valoriza-se evidência concreta (_commits_, ficheiros de configuração dos agentes) e reflexão crítica: o que a IA
  fez bem, onde errou, como o erro foi detetado e o que foi rejeitado e porquê. Não basta dizer que a IA foi usada; é preciso mostrar
  que o resultado foi verificado.
]

== Ferramentas, modelos e configuração

#tabela(
  colunas: (3.5cm, 1fr),
  [Ferramenta / modelo], [Configuração e utilização (_skills_, instruções de projeto, MCP, …)],
  [Claude Code (Claude Opus 5.5)], [Assistente de código no VS Code e no terminal, com acesso ao repositório. Seguiu o `AGENTS.md` da base (orientações para agentes) e as regras da equipa no `docs/fase2/medicoes/README.md`, secção «Antes de medir».],
  [GitHub Copilot, com o Spec Kit 1.2.0], [Spec Kit instalado com a integração do Copilot (`4368d1f`), com a configuração em `.specify/` e dez _skills_ em `.github/skills/` (`speckit-specify`, `speckit-plan`, `speckit-tasks`, `speckit-implement`, entre outras). Usado para gerar a especificação, o plano e a lista de tarefas de cada requisito (`specs/001-rnf2-modularidade/` e `specs/002-rnf1-capacidade/`).],
)

== Tarefas apoiadas e validação

#tab([Tarefas apoiadas por IA e validação],
  tabela(
    colunas: (2.4cm, 3cm, 2.8cm, 3.2cm, 1fr),
    tamanho: 8pt,
    [Ferramenta / modelo / _skill_], [Tarefa apoiada (capítulo)], [O que foi aceite], [O que foi rejeitado e porquê], [Como foi validado pela equipa],
    [Claude Code], [Rascunho do diagnóstico, das evidências, das hipóteses e da matriz (caps. 2 a 4)], [A estrutura, as evidências depois de conferidas e a unificação dos IDs dos planos iniciais, que colidiam (E1–E7)], [—], [Cada evidência foi conferida no _commit_ `0523102`, no ficheiro e nas linhas citadas],
    [Claude Code], [Cenários, candidatos e escolha da medida principal do CAND-1 (caps. 5 e 6)], [Os cenários e a quantificação, com os valores copiados dos ficheiros de medição], [A IA propôs mudar a medida principal do M6 para o M1. A equipa manteve o M6, porque o ganho do M1 vem sobretudo do CAND-2], [Valores conferidos em `resultados/base/*_resumo.json`. A leitura do REQ-VID-EDIT-009 foi corrigida depois de confrontada com o documento do PL1-G4],
    [Claude Code], [Táticas, decisões, vistas e plano de medição (caps. 7 a 10)], [As táticas e as duas decisões], [A primeira proposta punha os efeitos partilhados em `Tools/utils`, o que reconstruiria 16 serviços a cada mudança (EV-28). Ficaram em `Tools/effects/`, um ficheiro por efeito], [As evidências foram conferidas no código e as vistas foram revistas depois da implementação (T029)],
    [GitHub Copilot + Spec Kit], [Especificação, plano e tarefas dos dois requisitos], [As listas de tarefas (`tasks.md`), seguidas e marcadas tarefa a tarefa], [—], [Cada tarefa foi revista por um membro da equipa antes do _commit_, com o resultado registado no `quickstart.md` de cada requisito],
    [Claude Code], [Planos dos RNF, _scripts_ de medição e _baseline_ (`cd4c12d`, `af910b4`, `98be376`)], [Os _scripts_ `carga_rnf1.py`, `rnf2_estaticas.py` e `regressao_hashes.py`], [—], [Os _scripts_ têm testes (`docs/fase2/medicoes/tests`), e as medições oficiais foram corridas por um membro da equipa na máquina de referência],
    [Claude Code], [Implementação de tarefas do RNF1 (T009 a T013, T018, T020, T026) e verificações manuais (T014 e T023 do RNF1, T040 do RNF2)], [O código e os testes das tarefas], [Linhas de atribuição a IA nas mensagens de _commit_, que a equipa não pediu e retirou], [Testes automáticos (51 do `video_autoscaler`, testes de réplicas nos serviços), verificação na aplicação a correr e revisão antes de cada _commit_],
    [Claude Code], [Revisão de estilo e de verdade do relatório (caps. 1 a 11)], [As correções de estilo e de factos], [Explicações que não se confirmaram (ver a análise crítica)], [Cada afirmação foi conferida no código da base ou nos ficheiros de medição, e o PDF foi revisto página a página],
    [#preencher[outros usos da equipa]], [#preencher[…]], [#preencher[…]], [#preencher[…]], [#preencher[…]],
  ),
)

== Análise crítica

A IA foi útil para três coisas. A primeira foi organizar muito material com rastreabilidade, ligando evidências,
hipóteses, cenários, táticas e decisões por identificadores. A segunda foi escrever e testar código repetitivo, como os
testes de concorrência, o `video_autoscaler` e os _scripts_ de medição. A terceira foi confrontar o texto com o código e
com os dados, quando lhe era pedido explicitamente.

A IA também errou, e os erros só foram detetados porque a equipa verificou o resultado. Na revisão final do
relatório, por exemplo, encontraram-se afirmações que não batiam com o código. Uma contagem de serviços estava errada
(15 em vez de 16, EV-28), uma célula dizia que o `video_tool` só falava com o RabbitMQ, quando também descarrega o
modelo de legendas da internet, e uma hipótese aparecia como refutada quando os dados a confirmavam (H-06). Nas
verificações manuais, a IA atribuiu a um defeito do código um atraso que, afinal, era uma réplica ainda a legendar um
vídeo de 600 s. Também apresentou duas vezes uma causa errada para um conflito de versão no _Apply_, até a equipa
recolher a prova nas ferramentas de programador do browser. Houve ainda erros que só apareceram ao ver o PDF, como
símbolos soltos numa tabela e páginas quase vazias, e que a compilação sem erros não mostrava.

Estes casos levaram a equipa a adotar quatro práticas. Primeiro, nenhuma afirmação entra no relatório sem ser
conferida no código da base, no código entregue ou nos ficheiros de resultados. Segundo, uma explicação da IA é tratada
como hipótese até haver prova, e não como facto. Terceiro, os _commits_ são sempre feitos por um membro da equipa,
depois de rever as alterações. Quarto, cada capítulo é revisto no PDF, e não só no código. As decisões de fundo, como a
escolha dos requisitos, a medida principal e os valores-alvo, foram sempre da equipa.
