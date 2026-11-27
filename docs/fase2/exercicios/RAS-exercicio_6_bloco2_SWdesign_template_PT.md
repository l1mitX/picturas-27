# 📝 Exercício 6 (Bloco 2) — Trade-offs, Cenários de Qualidade e Candidatos a RNF
### Fase 2: Melhoria de Requisitos Não Funcionais do PictuRAS

**Equipa:** {PL1-G1}  
**Elementos:** pg63924 Beatriz Miranda · pg63944 Diogo Machado · pg63990 José Cação · pg63975 Inês Ribeiro · pg64020 Pedro Braz  
**Commit de partida:** `0523102` (o mesmo do Bloco 1)  
**Data da análise:** 2026-11-21  
**Versão deste documento:** v1.1 (revista a 2026-11-22)  
**Versões usadas:** enunciado 1.1 · template 1.1  
**Versão do Bloco 1 usada como entrada:** v1.1 (`RAS-exercicio_6_bloco1_SWdesign_template_PT.md`)

---

## 4. Trade-offs, cenários de qualidade e prioridades

### 4.1 Justificação detalhada das avaliações da matriz

A matriz do Bloco 1 (secção 3.3) compara o padrão global (referência), o padrão atual do vídeo e as alternativas ALT-1
(serviço por efeito), ALT-2 (serviço por tipo de trabalho + *Competing Consumers*) e ALT-3 (monólito modular com réplicas
fixas). Abaixo justificam-se as avaliações por subcaracterística, incluindo as que o enunciado pede como mínimo e que
não estavam na matriz (utilização de recursos, disponibilidade, reutilização, testabilidade).

| **Atributo** | **Justificação** | **Depende sobretudo de** (padrão global / padrão do vídeo / ambos) | **Evidência** |
|--------------|------------------|---------------------------------------------------------------------|---------------|
| Eficiência de desempenho — comportamento temporal | **Global (Alto):** passos curtos de imagem e *Apply* assíncrono, que não espera pelo processamento. **Vídeo (Alto):** um só processo ffmpeg descodifica, os efeitos aplicam-se a cada fotograma e um só processo codifica; sozinho, um vídeo de 10 s demora p95 17,8 s. **ALT-1 (Baixo):** cada serviço recodifica o vídeo inteiro. **ALT-2 (Alto):** só corta nos estágios que já produzem um MP4 intermédio (H-06). **ALT-3 (Alto):** igual ao atual | Padrão do vídeo | EV-03, EV-15, EV-18, EV-27 |
| Eficiência de desempenho — utilização de recursos | **Global:** um contentor sempre ligado por ferramenta; os carregamentos são guardados em memória em cada salto. **Vídeo:** uma imagem de 1,69 GB para qualquer trabalho; o `video_tool` chegou a 2 506 MiB (≈ 2,4 GiB) durante uma legendagem. **ALT-1:** muitos serviços e MP4 intermédios em disco. **ALT-2:** imagens mais pequenas para a edição e a extração; réplicas só quando há fila (mais recursos em pico). **ALT-3:** cada réplica fixa carrega o Whisper, mesmo sem trabalho | Ambos | EV-01, EV-14, EV-18 |
| Eficiência de desempenho — capacidade / elasticidade | **Global (Médio):** um consumidor por fila; aceitável porque os passos de imagem são curtos. **Vídeo (Baixo):** um *worker*, `prefetch=1`: um efeito curto espera p95 322,6 s atrás de uma legendagem e 4 edições simultâneas demoram p95 44,0 s. **ALT-1 (Médio):** cada efeito escala, mas há mais trabalho por vídeo. **ALT-2 (Alto):** réplicas por tipo de trabalho, ajustadas ao tamanho da fila. **ALT-3 (Médio):** N réplicas fixas, mas uma legendagem ocupa sempre uma inteira | Ambos (o global define um consumidor por fila; o vídeo junta nesse consumidor todos os tipos de trabalho) | EV-04, EV-07, EV-18, EV-26 |
| Fiabilidade — disponibilidade | **Global e vídeo:** uma instância por serviço; se o `video_tool` cair, o vídeo pára até ao reinício automático (`restart: on-failure`). **ALT-2 e ALT-3:** com réplicas, outra instância continua a consumir a fila. **ALT-1:** igual ao atual, mas com mais serviços que podem falhar | Ambos | EV-07, EV-10 |
| Fiabilidade — tolerância a falhas / recuperabilidade | **Global (Baixo):** `auto_ack=True` nas imagens perde a mensagem se o *worker* falhar. **Vídeo (Médio):** `ack` no fim (reentrega se o processo morrer) e escrita atómica (sem saídas parciais); mas uma exceção é respondida como erro e não se repete. **ALT-1/ALT-2/ALT-3 (Médio):** mantêm o `ack` manual; na ALT-2 o cancelamento passa por vários serviços (H-05, H-08) e as legendagens longas podem esbarrar no `consumer_timeout` (H-04) | Ambos | EV-09, EV-10, EV-19, EV-25 |
| Manutenibilidade — modularidade / modificabilidade | **Global (Alto):** um serviço por ferramenta, exceto mudanças na pasta partilhada `Tools/utils`, que reconstroem 16 serviços. **Vídeo (Baixo):** três tipos de trabalho num processo e numa imagem; nos cenários de mudança C1, C2 e C3 os 3 tipos são reimplantados. **ALT-1 (Alto):** cada efeito muda sozinho, mas o orquestrador cresce (H-09). **ALT-2 (Alto):** dependências e implantações separadas. **ALT-3 (Médio):** organiza o código, mas a implantação continua única | Padrão do vídeo | EV-11, EV-13, EV-14, EV-17, EV-28 |
| Manutenibilidade — reutilização | **Vídeo:** os 8 efeitos são cópias das ferramentas de imagem, não são reutilizados. **ALT-1:** reutiliza os serviços de imagem, à custa de recodificações. **ALT-2 e ALT-3:** um módulo de efeitos partilhado por imagem e vídeo, como a DA-06 do PL1-G4 deixou previsto para a Fase 2; fora de `Tools/utils`, para não reconstruir 16 serviços | Padrão do vídeo | EV-12, EV-17, EV-28, EV-32 |
| Manutenibilidade — testabilidade | **Vídeo:** 74 testes, todos sobre o mesmo serviço; `process_video` (CC 22) concentra os caminhos de edição, legendas, extração e pré-visualização. **ALT-2:** cada serviço testa-se sozinho, mas o encadeamento no `projects` e as réplicas acrescentam caminhos concorrentes a testar (H-05, H-08). **ALT-1:** muitos serviços pequenos, mas o encadeamento fica todo no orquestrador | Padrão do vídeo | EV-13; `Tools/video/tests` |
| Segurança | **Global (Médio):** entrada única em HTTPS pelo `nginx` e validação do JWT no API Gateway, mas as ligações internas não validam certificados; nenhuma alternativa muda a autenticação nem o acesso aos ficheiros. **ALT-2:** baixa ligeiramente, porque o ajuste automático de réplicas precisa de acesso à API do Docker | Padrão global | EV-20, EV-30, EV-31 |
| Usabilidade — operabilidade (trabalho em segundo plano) | **Global (Alto):** o processamento é assíncrono (o *Apply* responde logo e o trabalho continua em segundo plano) e o progresso chega por WebSocket. **Vídeo (Médio):** a espera atrás de uma legendagem é de minutos e o utilizador não sabe porquê. **ALT-2 (Alto):** espera curta mesmo com legendagens em curso. **ALT-1 e ALT-3 (Médio)** | Ambos (o global dá o segundo plano; o vídeo determina a espera) | EV-03, EV-05, EV-18 |

**Influência do padrão global nos resultados do vídeo.** O padrão global dá ao vídeo o processamento em segundo plano,
o progresso em tempo real e a reentrega das mensagens. Também lhe impõe a regra de um consumidor por fila, que, somada à
decisão do vídeo de juntar tudo num serviço, explica o pior resultado da base: a capacidade. Na modularidade é o
contrário: o padrão global é bom, e o mau resultado vem do desvio do vídeo.

### 4.2 Cenários de qualidade para a extensão de vídeo

Cenários escritos segundo o modelo de seis elementos de Bass, Clements & Kazman, *Software Architecture in Practice* (4.ª ed.).

| **ID** | **Característica (ISO/IEC 25010)** | **Fonte do estímulo** | **Estímulo** | **Artefacto** | **Ambiente** | **Resposta** | **Medida da resposta** |
|--------|------------------------------------|-----------------------|--------------|---------------|--------------|--------------|------------------------|
| QS-01 | Eficiência de desempenho → capacidade | Dois utilizadores Premium, em simultâneo | O utilizador A pede a legendagem de um vídeo de 177 s; 5 s depois, o utilizador B aplica um efeito de brilho a um vídeo de 10 s | Serviços de processamento de vídeo e respetivas filas | Operação normal; uma legendagem de outro utilizador em curso e nenhum outro trabalho | O trabalho de B é processado sem esperar pelo fim da legendagem de A; os dois terminam corretamente | Tempo desde o *Apply* de B até o resultado estar disponível (s; p50 e p95) |
| QS-02 | Manutenibilidade → modularidade | Um programador da equipa | Atualizar a versão do `faster-whisper` ou o modelo de legendas | Código e imagens Docker dos serviços de vídeo | Tempo de desenvolvimento e implantação, com o sistema em funcionamento | A mudança fica contida na legendagem: a edição e a extração não são alteradas, reconstruídas nem reimplantadas | Número de tipos de trabalho de vídeo reimplantados; ficheiros alterados; serviços reconstruídos (contagens) |
| QS-03 | Eficiência de desempenho → capacidade | Quatro utilizadores Premium, em simultâneo | Submetem ao mesmo tempo 4 edições de brilho a vídeos de 10 s | Serviços de processamento de vídeo e respetivas filas | Operação normal; sem legendagens | Os 4 trabalhos são processados em paralelo | Tempo por trabalho (s; p50 e p95) e débito (vídeos concluídos por minuto) |
| QS-04 | Manutenibilidade → modificabilidade | Um programador da equipa | Alterar o comportamento do filtro de brilho, de forma igual para imagem e vídeo | Código dos efeitos e serviços que os usam | Tempo de desenvolvimento | A alteração é feita num único sítio e vale para imagem e vídeo | Número de implementações do efeito alteradas; serviços reconstruídos (contagens) |
| QS-05 | Eficiência de desempenho → utilização de recursos | Três utilizadores Premium, em simultâneo | Carregam, cada um, um vídeo de 1 GB | `api_gateway`, `projects`, `img_storage` | Operação normal | Os três carregamentos terminam sem esgotar a memória dos serviços | Memória máxima de cada serviço durante o carregamento (MiB) |

Fragilidade e evidência de cada cenário (secção 2.6 do Bloco 1):

- **QS-01**: um único *worker* de vídeo, com `prefetch=1` e uma só fila; um trabalho curto espera pelo fim de uma legendagem (EV-03, EV-04, EV-07, EV-10, EV-18).
- **QS-02**: edição, legendagem e extração no mesmo processo e na mesma imagem Docker; qualquer mudança reimplanta os 3 tipos de trabalho (EV-11, EV-13, EV-14, EV-17).
- **QS-03**: o mesmo *worker* único serve vários pedidos curtos, um a um (EV-04, EV-07, EV-26).
- **QS-04**: 8 efeitos implementados duas vezes, uma para imagem e outra para vídeo (EV-12, EV-17).
- **QS-05**: os carregamentos são recebidos inteiros em memória em cada salto, até 1100 MB (EV-01).

Evidência nova acrescentada ao registo do Bloco 1 (secção 2.6): **EV-26**, a medição das 4 edições simultâneas.

**Priorização dos cenários**

| **ID** | **Importância para os stakeholders** | **Dificuldade / risco técnico** | **Prioridade** |
|--------|--------------------------------------|---------------------------------|----------------|
| QS-01 | Alta — o utilizador espera mais de 5 min por um efeito que demora 15 s (EV-18); o REQ-VID-EDIT-011 pede, no MVP, pelo menos 2 vídeos em paralelo | Média — resolvido sobretudo pela divisão em serviços por tipo de trabalho do QS-02 (pré-requisito, secção 4.4): a legendagem passa a ter a sua fila e deixa de bloquear a edição, sem tática própria | 3 |
| QS-02 | Média-alta — para a equipa, cada mudança nas legendas reconstrói uma imagem de 1,69 GB e reimplanta todo o vídeo (EV-14, EV-17); REQ-VID-EDIT-013 | Média — divisão do serviço; o cancelamento passa a atravessar vários serviços (H-08) | 2 |
| QS-03 | Alta — é o caso mais comum (vários utilizadores a editar ao mesmo tempo): com 4 edições curtas em simultâneo, o p95 passa de 17,8 s para 44,0 s (EV-26) | Alta — réplicas por serviço de vídeo e ajuste automático pelo tamanho da fila; hipóteses H-01 a H-05 | 1 |
| QS-04 | Média — risco de imagem e vídeo divergirem (regra sem requisito explícito, hoje garantida por cópia) e REQ-VID-EDIT-013 (acrescentar um efeito sem alterar os existentes) | Média — extrair um módulo comum mexe também nas 8 ferramentas de imagem (regressão por *hash*, H-07); se o módulo ficar em `Tools/utils`, passa a reconstruir 16 serviços (EV-28) | 4 |
| QS-05 | Média — só afeta carregamentos grandes e simultâneos: cada ficheiro, até 1100 MB, fica inteiro em memória em cada salto (EV-01), e o Docker da máquina de medição tem 7,7 GiB | Alta — mexe no carregamento de imagens e vídeos, em três serviços; risco de regressão alto | 5 |

O QS-01 é o cenário com a fragilidade mais grave para o utilizador, mas não fica no topo da priorização porque não
precisa de uma tática própria: a divisão em serviços por tipo de trabalho, exigida pelo QS-02, dá à legendagem a sua
fila e deixa de a pôr à frente das edições curtas (secção 4.4). Por isso, os dois cenários que dão origem aos candidatos
da secção 5 são o **QS-03** (capacidade: vários pedidos curtos em simultâneo, que só as réplicas resolvem) e o **QS-02**
(modularidade). O QS-01 continua a ser medido, como efeito da divisão do QS-02.

### 4.3 Atributos de qualidade por ordem de prioridade

1. **Eficiência de desempenho → capacidade** — QS-03 e QS-01: a fragilidade é visível para todos os utilizadores e é o requisito de vídeo que a base não cumpre (EV-18, EV-26).
2. **Manutenibilidade → modularidade e modificabilidade** — QS-02 e QS-04: afeta a equipa em cada mudança e é condição para resolver a capacidade por tipo de trabalho (secção 4.4).
3. **Eficiência de desempenho → utilização de recursos** — QS-05: risco real, mas localizado nos carregamentos grandes e fora do caminho de processamento do vídeo.

### 4.4 Pré-requisitos e efeitos colaterais entre atributos

| **Atributo A** | **Atributo B** | **Efeito** (pré-requisito, sinergia ou conflito) | **Razão / evidência** |
|----------------|----------------|--------------------------------------------------|-----------------------|
| Modularidade (QS-02) | Capacidade (QS-03, QS-01) | Pré-requisito | Só com serviços e filas por tipo de trabalho é possível escalar a edição sem que uma legendagem ocupe a réplica de uma edição curta (EV-03, EV-10). A divisão sozinha resolve a maior parte do QS-01; as réplicas por serviço resolvem o QS-03. Com o serviço único, as réplicas (ALT-3) melhoram o QS-03 mas pouco o QS-01 |
| Modularidade (QS-02) | Capacidade / elasticidade | Sinergia | Imagens mais pequenas para a edição (sem `faster-whisper`, EV-14) arrancam réplicas mais depressa |
| Modularidade (QS-02) | Comportamento temporal | Conflito potencial | Mais um salto entre serviços e um MP4 intermédio por estágio podem aumentar o tempo de cada vídeo (H-06); vigia-se com o tempo isolado em cada medição |
| Capacidade (QS-03) | Utilização de recursos | Conflito | Durante uma legendagem, o `video_tool` (uma só instância) chegou a 2 506 MiB (≈ 2,4 GiB) de memória na medição do QS-01 (EV-18); com N réplicas de legendagem a memória cresce na mesma proporção, e a máquina de medição tem 7,7 GiB para o Docker |
| Capacidade (QS-03) | Segurança | Conflito | O ajuste automático de réplicas precisa de acesso à API do Docker, que dá controlo sobre todos os contentores |
| Capacidade (QS-03) | Fiabilidade → disponibilidade | Sinergia | Com várias réplicas e `ack` manual (EV-10), a queda de uma instância não para o processamento de vídeo. Ainda não testado: a base nunca correu com réplicas (H-01) |

### 4.5 Recomendações de melhoria à solução atual

| **Recomendação** | **Atributo(s)** | **Padrão a que se refere** (global / vídeo) | **Esforço** | **Risco de regressão** |
|------------------|-----------------|----------------------------------------------|-------------|------------------------|
| Dividir o `video_tool` em serviços por tipo de trabalho (edição, legendagem, extração), cada um com a sua fila, encadeados pelo `projects` (ALT-2, etapa 1) | Modularidade; modificabilidade | Vídeo (aproxima-o do global) | Médio | Médio |
| Extrair os 8 efeitos para um módulo partilhado entre imagem e vídeo, fora de `Tools/utils` para não reconstruir 16 serviços a cada mudança (EV-28) | Modificabilidade | Vídeo e global | Médio | Médio: mexe também nas 8 ferramentas de imagem (verificável por *hash*, H-07) |
| Réplicas por serviço de vídeo, com ajuste automático pelo tamanho da fila (ALT-2, etapa 2) | Capacidade; elasticidade | Vídeo | Médio | Médio (H-01 a H-05) |
| Configurar o `consumer_timeout` do RabbitMQ para a duração máxima de uma legendagem Premium | Fiabilidade | Global | Baixo | Baixo (H-04) |
| Receber os carregamentos em disco ou em *stream* em vez de memória (registado; fora do âmbito desta fase) | Utilização de recursos | Global | Alto | Alto |
| Passar as ferramentas de imagem a `ack` manual (registado; fora do âmbito desta fase) | Fiabilidade | Global | Baixo | Médio |

---

## 5. Candidatos a requisitos não funcionais da Fase 2

| **#** | **Característica / subcaracterística (ISO/IEC 25010)** | **Fragilidade na base (evidência)** | **Origem** (padrão global / padrão do vídeo / interação) | **Impacto nos stakeholders (pertinência)** | **Exigência técnica (complexidade)** | **Escala e método de medição (esboço)** | **Pré-requisitos / efeitos colaterais** |
|-------|---------------------------------------------------------|--------------------------------------|-----------------------------------------------------------|---------------------------------------------|---------------------------------------|------------------------------------------|----------------------------------------|
| CAND-1 — o processamento de vídeo atende vários pedidos em paralelo, com capacidade ajustada à carga (REQ-VID-EDIT-011); cenário QS-03 (principal; QS-01 complementar, resolvido sobretudo pelo CAND-2) | Eficiência de desempenho → capacidade | Um único *worker* de vídeo processa os pedidos um a um: 4 edições curtas em simultâneo demoram p95 44,0 s, contra 17,8 s de uma sozinha (EV-04, EV-07, EV-26) | Interação: padrão do vídeo (*worker* único) sobre a restrição global de um consumidor por fila | Utilizadores: com vários a editar ao mesmo tempo, cada um espera pelos outros; o critério do REQ-VID-EDIT-011 (≥ 2 vídeos em paralelo no MVP) não se cumpre | Alta: réplicas por serviço de vídeo e componente de ajuste automático | Segundos por trabalho (p95) e vídeos/min com 4 edições em paralelo, com `carga_rnf1.py` | Pré-requisito: CAND-2. Efeitos: mais memória e CPU; acesso à API do Docker (segurança) |
| CAND-2 — os tipos de trabalho de vídeo mudam e implantam-se de forma independente (REQ-VID-EDIT-013; mantém o REQ-VID-EDIT-014); cenário QS-02 (QS-04 complementar) | Manutenibilidade → modularidade (e modificabilidade) | Três tipos de trabalho num serviço e numa imagem; efeitos duplicados (EV-11, EV-12, EV-14, EV-17) | Padrão do vídeo (*pipeline monolith*) | Equipa: uma mudança nas legendas reconstrói 1,69 GB e reimplanta todo o vídeo; risco de imagem e vídeo divergirem | Média: divisão do serviço; cancelamento entre serviços (H-08) | Contagens de tipos de trabalho reimplantados e de serviços reconstruídos por cenário de mudança, com `rnf2_estaticas.py` | É pré-requisito do CAND-1. Efeito: possível aumento do tempo por vídeo (H-06) e do orquestrador (H-09) |

Os dois candidatos são **distintos** (características ISO/IEC 25010 diferentes) e nenhum acrescenta funcionalidade: com o
CAND-1, o utilizador obtém os mesmos resultados, apenas mais depressa; com o CAND-2, não vê diferença nenhuma.

### 5.1 Esboço de quantificação

| | **CAND-1** | **CAND-2** |
|---|---|---|
| **Escala** (o que se mede e em que unidade) | **M6** (principal): tempo por trabalho, desde o *Apply* até o resultado estar disponível, com 4 edições curtas em paralelo, em segundos (p50 e p95), e débito (vídeos/min). **M1** (complementar, efeito sobretudo do CAND-2): tempo do trabalho curto submetido durante uma legendagem, em segundos (p50 e p95). **M4** (elasticidade): segundos até o sistema acrescentar réplicas quando a fila cresce, e até as retirar quando esvazia | **N2** (principal): por cenário de mudança, número de tipos de trabalho de vídeo reimplantados, de ficheiros alterados e de serviços reconstruídos. Complementares: **N1** (efeitos com duas implementações), **N3** (tamanho, em GB, e tempo de *build*, em s, de cada imagem de vídeo), **N4** (SLOC, complexidade ciclomática máxima, linhas do orquestrador) |
| **Cenário de medição** | M6: cenário do QS-03 (4 utilizadores aplicam brilho a `sample_10s_720p.mp4` ao mesmo tempo, sem legendagem). M1: cenário do QS-01 (legendagem de `speech_mandela_177s_1080p.webm`; 5 s depois, brilho em `sample_10s_720p.mp4`) | N2: três cenários de mudança fixos — C1 (filtro de brilho, imagem e vídeo), C2 (versão do `faster-whisper`; é o QS-02), C3 (escolha dos instantes na extração de fotogramas) |
| **Carga** | M6: 4 edições curtas simultâneas, 5 repetições. M1: 1 legendagem + 1 edição curta, 5 repetições. Utilizadores Premium de teste, um projeto por trabalho | n/a (análise estática do repositório e das imagens Docker) |
| **Ambiente** | A mesma máquina em todas as medições (secção 0 do Bloco 1), aplicação arrancada com `--build`, sem outra carga | O mesmo *commit* em análise; *build* sem *cache* para N3. Como o Dockerfile não fixa as versões dos pacotes do sistema, o tamanho da mesma imagem varia entre dias (1,692 GB e 1,708 GB): a imagem de base e a nova constroem-se no mesmo dia antes de serem comparadas |
| **Instrumento** | `docs/fase2/medicoes/carga_rnf1.py` (cliente HTTP que imita o utilizador; consulta a cada 0,5 s; recolhe `docker stats`). M4: *logs* do componente de ajuste e API de gestão do RabbitMQ | `docs/fase2/medicoes/rnf2_estaticas.py` (encontra os ficheiros pelo conteúdo e os serviços pelos `COPY` dos Dockerfiles; `radon` 6.0.1 para N4); `docker compose build --no-cache` e `docker image inspect` para N3 |
| **Valor medido na base / valor-alvo / valor mínimo aceitável** | Base (medida a 2026-11-18): M6 p95 **44,0 s** (p50 28,8 s), **5,54 vídeos/min** (EV-26); M1 p95 **322,6 s** (p50 307,6 s) (EV-18); M4 n/a. **Alvo:** **M6** p95 ≤ **30 s** com 4 edições em paralelo (estimativa da equipa: se os 4 trabalhos correrem em simultâneo, cada um demora perto dos 17,8 s de um trabalho sozinho; os 30 s deixam margem para disputarem os 12 CPUs da máquina). **M1** (complementar) p95 ≤ **36 s** (2× o trabalho isolado, p95 17,8 s): um efeito curto não deve demorar mais do dobro por haver uma legendagem em curso (necessidade do utilizador). **M4**: réplicas acrescentadas ≤ **30 s** depois de a fila passar o limiar (período de consulta do ajuste + arranque do contentor). **Isolado** (efeito colateral): não piorar, p95 ≤ 17,8 s. **Mínimo:** **M6**: pelo menos **2** trabalhos processados em simultâneo (critério de aceitação do REQ-VID-EDIT-011 no MVP). **M1** (complementar) p95 ≤ **50 s** (critério de aceitação do REQ-VID-EDIT-010 no MVP: editar em até 5× a duração do vídeo, 5 × 10 s). **M4**: ≤ **60 s**. **Isolado**: p95 ≤ **19,6 s** (base + 10 %, margem para o ruído da medição) | Base (medida a 2026-11-18): N2 (C2) **3** tipos reimplantados, 2 ficheiros, 1 serviço; C1 e C3: 3 tipos; N1 **8** efeitos; N3 **1,69 GB**, 240 s; N4 601 SLOC, CC máx. 22, orquestrador 2733 linhas (EV-14, EV-17). **Alvo:** **N2**: C2 reimplanta **1** tipo de trabalho (só a legendagem); C1 reimplanta **1** tipo de vídeo (a edição) e a ferramenta de imagem; C3 reimplanta **1** (só a extração) (objetivo do QS-02). **N1**: **0** efeitos com duas implementações. **N3**: imagem da edição ≤ **1,23 GB** (1,69 GB sem os 457 MB do `faster-whisper`). **Mínimo:** **N2**: C2 reimplanta **1** tipo de trabalho — sem isto o QS-02 não é cumprido. **N1**: **0** (uma única implementação por efeito). **N3**: imagem da edição menor que a imagem atual do vídeo, construída no mesmo dia. **N4** (efeito colateral, H-09): orquestrador com ≤ 2733 + 10 % linhas |

### 5.2 Relação entre os dois candidatos

O CAND-2 é **pré-requisito** do CAND-1: o CAND-1 escala cada serviço criado pelo CAND-2, com réplicas ajustadas à fila de
cada tipo de trabalho (ALT-2). A própria divisão do CAND-2 já dá à legendagem a sua fila e deixa de a pôr à frente das
edições curtas, por isso resolve a maior parte do QS-01 (M1) antes de haver réplicas. Por esta razão, a escala principal
do CAND-1 é o **M6** (QS-03), que mede o que só as réplicas melhoram, e o M1 fica como medida complementar, cujo ganho se
atribui sobretudo ao CAND-2. Para que cada candidato seja avaliado por si, as medições fazem-se em **três momentos**, com o
mesmo método: na base, após o CAND-2 e após o CAND-1. O ganho atribuído ao CAND-2 é o que muda entre a base e o segundo
momento; o atribuído ao CAND-1 é o que muda entre o segundo e o terceiro. Há também **sinergia**: as imagens de edição e de extração ficam sem
`faster-whisper`, mais pequenas e mais rápidas a arrancar, o que ajuda a elasticidade (M4). Há um **conflito potencial**
no comportamento temporal: o CAND-2 acrescenta um salto entre serviços e um MP4 intermédio por estágio (H-06), que se
vigia medindo o trabalho isolado após cada etapa. Outros RNF afetados: utilização de recursos (mais contentores),
segurança (o ajuste automático acede à API do Docker) e testabilidade (mais caminhos concorrentes a testar).

### 5.3 Evidência exploratória (se existir)

| **Descrição** | **Localização** (scripts, dados, resultados) | **Como repetir** |
|---------------|----------------------------------------------|------------------|
| Medições de base do CAND-1 (isolado, M1, M2/M3, M6) com amostras de CPU e memória | `docs/fase2/medicoes/carga_rnf1.py`; `docs/fase2/medicoes/resultados/base/carga_*.csv` e `*_resumo.json` | `python docs/fase2/medicoes/carga_rnf1.py base <cenario> --reps R` (comandos no cabeçalho do *script*) |
| Métricas estáticas do CAND-2 (N1, N2, N4) | `docs/fase2/medicoes/rnf2_estaticas.py`; `resultados/base/rnf2_estaticas.json` | Ver o cabeçalho do *script* (corre num contentor com `radon` 6.0.1) |
| Referência de preservação funcional (*hash* das saídas de imagem e de 9 pipelines de vídeo) | `docs/fase2/medicoes/regressao_hashes.py`; `resultados/base/regressao_*.json` | `regressao_hashes.py imagem base` e `regressao_hashes.py video base` (comandos no cabeçalho do *script*) |

---

## 6. Conclusões e recomendações

**Adequação do padrão atual (global e do vídeo):**

O padrão global (microserviços com filas e orquestração no `projects`) é adequado e mantém-se. O padrão do vídeo
(*pipeline monolith*) é adequado ao comportamento temporal de cada vídeo, mas pouco adequado à capacidade e à
modificabilidade: um trabalho curto espera mais de 5 min atrás de uma legendagem (EV-18) e qualquer mudança reimplanta
os três tipos de trabalho (EV-17). As duas fragilidades têm a mesma origem: o `video_tool` concentra tudo.

**Sugestões de otimização:**

Seguir a ALT-2 em duas etapas: primeiro o CAND-2 (serviços por tipo de trabalho e efeitos num módulo partilhado), depois
o CAND-1 (réplicas com ajuste automático). Medir em três momentos (base, após o CAND-2, após o CAND-1) para separar o
efeito de cada um. Aumentar para 10 as repetições do M1, do M6 e do trabalho isolado (com 5, o p95 é praticamente o
máximo) e fazer as medições finais na mesma máquina, com `--build`.

**Considerações para evolução futura:**

Ficam registadas, fora do âmbito desta fase, a receção dos carregamentos em disco ou em *stream* (QS-05, EV-01), o `ack`
manual nas ferramentas de imagem (EV-09) e a configuração do `consumer_timeout` (H-04, EV-19). Com serviços por tipo de
trabalho, um novo tipo de trabalho de vídeo na Fase 3 passa a ser um serviço novo, sem tocar nos existentes.

**Riscos para a preservação funcional e mitigação**

| **Risco** | **Funcionalidade afetada** (imagem / vídeo) | **Mitigação** | **Teste de regressão** (e.g., `Tools/video/tests`, `projects/tests`) |
|-----------|---------------------------------------------|---------------|-----------------------------------------------------------------------|
| Efeitos com resultado diferente depois de passarem para o módulo partilhado | Imagem e vídeo (8 efeitos) | Mover o código sem o alterar; comparar *hashes* antes e depois (H-07) | `regressao_hashes.py` (imagem e 9 pipelines de vídeo); `Tools/video/tests` |
| Cancelamento ou devolução de quota errados com o pipeline repartido ou com réplicas | Vídeo | Manter o controlo no `projects` (`activeToken`); testar H-05 e H-08 | `projects/tests` + testes novos de cancelamento a meio |
| A pré-visualização de vídeo deixa de funcionar (hoje vai pela `video_queue`, EV-16) | Vídeo | Encaminhar a pré-visualização pelos mesmos estágios, com `preview: true` | `Tools/video/tests`; teste manual na interface |
| A extração após edição perde a ordem ou a divisão 70/30 do progresso | Vídeo | Manter a regra «extração no fim» ao encadear os estágios | `Tools/video/tests` (74 testes na base) |
| Réplicas colidem nos ficheiros temporários ou na *cache* do Whisper | Vídeo | Nomes temporários únicos; descarregar o modelo uma vez (H-02, H-03) | Dois trabalhos do mesmo projeto em simultâneo; arranque com o volume vazio |

---

## 7. Utilização de IA

> [PROPOSTA] A completar pela equipa com os restantes usos.

| **Ferramenta / skill** | **Tarefa apoiada** | **Validação feita pela equipa** | **Onde está documentado** |
|------------------------|--------------------|----------------------------------|---------------------------|
| Claude Code (Claude Opus 5.5) | Rascunho do registo de evidências e hipóteses e da matriz (Bloco 1); unificação dos IDs dos planos iniciais, que colidiam (E1–E7 nos dois planos) | Cada evidência citada foi conferida no *commit* `0523102` (leitura do ficheiro e das linhas) | Bloco 1, secção 2.6; `docs/fase2/` |
| Claude Code (Claude Opus 5.5) | Escolha da medida principal do CAND-1 | A IA sugeriu primeiro o M6 e depois recuou para o M1, por ser o cenário de exemplo do enunciado e dos slides. A equipa decidiu manter o **M6** como principal (o ganho do M1 vem sobretudo do CAND-2, a medir em três momentos) e o M1 como complementar | Secções 4.2 e 5 |
| Claude Code (Claude Opus 5.5) | Rascunho dos cenários QS-01 a QS-05 e dos candidatos | {aceite / alterado: preencher}; os valores de base foram copiados de `resultados/base/*_resumo.json`; a interpretação do REQ-VID-EDIT-009 foi corrigida depois de confrontada com `doc-ext-requisitos-2627.pdf` | Secções 4 e 5 |
| {outros usos da equipa} | {…} | {…} | {…} |
