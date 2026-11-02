# Pesquisa: analytics, mapa de calor, rastreabilidade e status para a fase 2

Sem ticket; pedido direto do Ângelo em 02/11/2026. Todas as fontes foram lidas em 02/11/2026. Preços e planos mudam: confira de novo antes de decidir.

Neste arquivo, **fato** é o que está escrito numa fonte primária, com o número da fonte entre colchetes. **Estimativa** é conta minha a partir de premissas declaradas. **Opinião** é minha e vem marcada. Algumas fontes só foram consultadas pelo resultado de busca, sem abrir a página inteira; elas estão marcadas assim na lista de fontes, e o que vem delas merece uma conferida antes de virar decisão.

Conversão de moeda: a mesma PTAX de [custos-fase-2.md](custos-fase-2.md), **US$ 1 = R$ 5,4212** (30/10/2026).

## Pergunta

Quais ferramentas usar para entender o uso do app (visitas, funil, retenção) e a saúde do sistema (erros, rastreio, disponibilidade) na fase 2, quanto custam nos cenários de 1.000, 5.000 e 20.000 identificações por dia, e o que exigem de privacidade (LGPD e formulário "Segurança dos dados" da Play Store)?

## O que já existe no repositório

Conferido no código em 02/11/2026:

- **App (`app/pubspec.yaml`):** nenhum SDK de analytics, crash ou monitoramento. Nenhum Firebase. O app manda `X-App-Version` em toda requisição.
- **API (`api/package.json`):** nenhum SDK de erro ou tracing. O log é o `Logger` do NestJS. O `RequestLoggerMiddleware` escreve uma linha por requisição (método, URL, status, tempo e cabeçalhos), com `authorization`, `cookie` e `x-search-location` redigidos, e nunca o corpo. No Lambda isso vai para o CloudWatch Logs.
- **Não há id de requisição.** A resposta de erro é RFC 9457 com `code` estável (`problem-details.filter.ts`), mas sem nenhum id que ligue o erro visto no app à linha de log da API.
- **`GET /v1/health`** já existe, é público e lê `postgis_lib_version()` do banco, então uma resposta 200 prova API + banco no ar.
- **Identificações não guardam localização.** A tabela `identifications` tem usuário, foto, candidatos, espécie escolhida e data. A linha fica mesmo depois de a foto ser apagada, porque conta o uso do Pl@ntNet. Só `users.donation_location` e `listings.location` têm ponto, ambos já arredondados ao centro de uma célula de ~1 km ([ADR 0002](../adr/0002-localizacao-de-doacao-arredondada-antes-de-salvar.md)). A localização de quem procura mudas por perto (`X-Search-Location`) não é guardada nem logada.
- **O gasto do Claude não é registrado.** `care-guide.service.ts` não guarda `usage` (tokens) da resposta.
- **Achado de privacidade (opinião, conferir):** a lista `REDACTED_HEADERS` não inclui `x-forwarded-for`. Atrás do CloudFront ([ADR 0004](../adr/0004-api-no-aws-lambda-com-function-url.md)), esse cabeçalho costuma levar o IP do usuário, que então iria para o CloudWatch Logs em toda requisição. Não verifiquei num log real do Lambda.

## Resumo

Premissas (estimativa minha, sobre as de [custos-fase-2.md](custos-fase-2.md)): DAU 500 / 2.500 / 10.000 e MAU 2.000 / 10.000 / 40.000; **20 eventos de analytics por DAU por dia** (≈ 10 telas + 10 eventos do funil) = 300 mil / 1,5 milhão / 6 milhões de eventos por mês; **2 sessões por DAU por dia** = 30 mil / 150 mil / 600 mil sessões por mês; requisições ao Lambda de 450 mil / 2,25 milhões / 9 milhões por mês.

| Ferramenta | Para quê | SDK Flutter oficial | A: 1.000 id/dia | B: 5.000 id/dia | C: 20.000 id/dia |
|---|---|---|---|---|---|
| **Google Play Console** (estatísticas, aquisição, Android vitals) | Instalações, aquisição, taxa de crash e ANR | Não precisa de SDK | US$ 0 | US$ 0 | US$ 0 |
| **Google Analytics for Firebase** | Usuários ativos, retenção, funil, eventos | Sim, `firebase_analytics` (Google) [1][2] | US$ 0 | US$ 0 | US$ 0 |
| **Firebase Crashlytics** | Crashes e erros não fatais do app | Sim, `firebase_crashlytics` [1][3] | US$ 0 | US$ 0 | US$ 0 |
| Firebase Performance Monitoring | Tempo de abertura, latência de rede no app | Sim, `firebase_performance` [1][4] | US$ 0 | US$ 0 | US$ 0 |
| PostHog (product analytics, eventos anônimos) | Funil, retenção, eventos; também replay e erros | Sim, `posthog_flutter` [14] | US$ 0 | US$ 25 | US$ 187 |
| Mixpanel | Funil, retenção | Sim, `mixpanel_flutter` (da Mixpanel, mas "unverified uploader") [18] | US$ 0 | US$ 100–140 (Growth) | pago; faixa não publicada |
| Amplitude | Funil, retenção | Sim, `amplitude_flutter` [21] | US$ 0 | US$ 0 | pago (Plus); preço por evento não publicado |
| **Microsoft Clarity** | Mapa de calor de toque e gravação de sessão | Sim, `clarity_flutter`, Android e iOS [23] | US$ 0 | US$ 0 | US$ 0 |
| PostHog session replay (100% das sessões) | Gravação de sessão | Sim, no `posthog_flutter` [15] | US$ 230 | US$ 770 | US$ 2.260 |
| PostHog session replay (amostra de 2.500/mês) | idem | idem | US$ 0 | US$ 0 | US$ 0 |
| Sentry | Erros app + API, tracing ponta a ponta | Sim, `sentry_flutter` [31]; `@sentry/nestjs` [34] | US$ 0 (Developer) | US$ 26–29 (Team) | US$ 26–29 + excedente |
| CloudWatch Logs + alarmes + métricas | Logs e alertas da API | Lado da API | US$ 0 | US$ 0 | ~US$ 2 (logs, já em custos-fase-2) |
| CloudWatch Synthetics (2 canários a cada 15 min) | Disponibilidade da API e do Pl@ntNet | — | ~US$ 7 | ~US$ 7 | ~US$ 7 |
| X-Ray (Lambda, amostragem padrão) | Rastreio dentro da API | — | ~US$ 2 | ~US$ 11 | ~US$ 14 |
| **UptimeRobot Free** | Disponibilidade + página de status | — | US$ 0 | US$ 0 | US$ 0 |
| Grafana Cloud Free | Painel interno (negócio, mapa de calor geográfico) | — | US$ 0 | US$ 0 | US$ 0 |
| Google Maps SDK (heatmap no app) | Mapa de calor geográfico | Sim, `google_maps_flutter` (flutter.dev) [46] | US$ 0 | US$ 0 | US$ 0 |

Em negrito, a pilha que recomendo para começar (ver [Recomendação](#recomendação)). Somada, ela custa **US$ 0 nos três cenários**, fora o que já está em [custos-fase-2.md](custos-fase-2.md).

O que se tira da tabela:

- **O Google cobre de graça o essencial do app:** Analytics, Crashlytics e Performance não cobram em nenhum plano do Firebase [1], e o Play Console já mostra instalações e Android vitals sem SDK [11].
- **O que custa caro é gravação de sessão em volume.** Gravar 100% das sessões no PostHog vai de US$ 230 a US$ 2.260 por mês (estimativa). O Clarity é grátis sem limite de tráfego [26], e o PostHog fica grátis com amostra.
- **Mapa de calor geográfico de identificações não existe hoje**, porque a identificação não guarda lugar. O de doações dá para fazer já, a partir do PostGIS, com dados que o ADR 0002 já arredondou.
- **O que falta de verdade é o id de requisição** ligando o erro no app ao log da API. Isso é código nosso, não ferramenta.

## 1. Visitas e uso (analytics de produto)

### Google Play Console (já vem de graça)

- **Fatos:** o Android vitals mostra taxa de crash e de ANR percebidos pelo usuário. Os limites de "mau comportamento" são 1,09% dos usuários diários com crash e 0,47% com ANR no geral, ou 8% num único modelo de aparelho, avaliados nos últimos 28 dias; passar deles reduz a visibilidade na Play [11]. Os dados vêm de usuários que aceitaram compartilhar diagnóstico com o Google, não de um SDK do app [11].
- **Opinião:** o Play Console responde "quantos instalaram, de onde vieram e quantos desinstalaram", mas não diz o que a pessoa fez dentro do app. Não substitui o analytics.

### Google Analytics for Firebase (`firebase_analytics`)

- **Fatos:** sem custo nos planos Spark e Blaze [1]. O pacote é do publisher verificado `firebase.google.com`, versão 13.0.1, publicado há 10 dias, para Android, iOS, macOS e web [2]. Limites: 500 nomes de evento distintos por usuário de app, 25 parâmetros por evento, 25 propriedades de usuário, nome de evento com até 40 caracteres [5]. A retenção dos dados no nível de evento é de 2 ou 14 meses em propriedades padrão e **não afeta os relatórios agregados**, só as explorações e os funis [6].
- **Funil do PlantAí (opinião):** eventos customizados como `identification_started`, `identification_candidate_chosen`, `plant_saved`, `listing_created`, `interest_sent`. Os funis "abrir → identificar → salvar no Meu jardim" e "anunciar → tenho interesse" são feitos nas explorações do GA4. Com retenção de 2 meses, o funil só olha os últimos 2 meses; use 14.
- **Ressalva (opinião):** as explorações do GA4 são menos práticas que as do PostHog/Mixpanel, mas dão conta de um app pequeno.

### PostHog, Mixpanel e Amplitude

| | PostHog | Mixpanel | Amplitude |
|---|---|---|---|
| SDK Flutter | `posthog_flutter` 5.58.4, publisher verificado posthog.com, Android/iOS/web/desktop [14] | `mixpanel_flutter` 3.2.0, "unverified uploader", descrito como "maintained by Mixpanel, Inc." [18] | `amplitude_flutter` 4.8.1, publisher verificado amplitude.com [21] |
| Grátis | 1 milhão de eventos/mês [13] | 1 milhão de eventos/mês; retenção padrão de 2 anos [17] | 2 milhões de eventos/mês [20] |
| Depois | US$ 0,00005/evento de 1 a 2 mi, US$ 0,0000343 de 2 a 15 mi [13]. Eventos "identificados" (com perfil de pessoa) são um add-on bem mais caro: US$ 0,000198/evento de 1 a 2 mi [13] | Growth: 1,5 mi de eventos/mês por US$ 100 (anual) ou US$ 140 (mensal); 20 mi por US$ 1.635 (anual) [17] | Plus "a partir de US$ 0", cobrado por evento, sem preço publicado na página [20] |
| Replay em Flutter | Sim (ver seção 2) | Pacote separado `mixpanel_flutter_session_replay` [19] | `amplitude_session_replay`, em Early Access/beta [22] |

- **Estimativa de custo:** com 300 mil / 1,5 mi / 6 mi de eventos por mês, o PostHog com eventos anônimos custa US$ 0 / US$ 25 / US$ 187,20 (R$ 0 / R$ 135,53 / R$ 1.014,85). O Mixpanel fica no Free em A e no Growth em B e C. O Amplitude fica no Free em A e B.
- **Opinião:** um terceiro de analytics só se paga se o GA4 não der conta. O PostHog é o que melhor junta analytics, replay, flags e erros num lugar, mas, se for adotado, mande eventos anônimos (sem `identify`) para não cair na tabela dos eventos identificados.

## 2. Mapa de calor

### 2a. De toque e tela, com gravação de sessão

| Ferramenta | Flutter Android de fato? | Custo | Observações |
|---|---|---|---|
| **Microsoft Clarity** | **Sim.** `clarity_flutter` 1.10.1, publisher verificado microsoft.com, Android e iOS; **não suporta Flutter web** [23]. Heatmaps listados entre os recursos [23] | Grátis, "you never encounter traffic limits" [26] | Sem Smart Events, Funis e Components no Flutter; não sobe sessão gravada offline; views nativas aparecem como áreas cobertas [23][24]. Gravações ficam 30 dias; heatmaps e sessões marcadas, 13 meses [26][27] |
| PostHog session replay | **Sim**, Android com `posthog_flutter` ≥ 4.7.0, também Flutter web (com captura de canvas) [15] | 2.500 gravações mobile/mês grátis; depois US$ 0,01 a US$ 0,003 por gravação [13] | `maskAllTexts` e `maskAllImages` ligados por padrão; captura onde o toque cai, a menos que `captureTouches = false` [15]. Não li se o PostHog gera mapa de calor de toque para mobile |
| Sentry session replay | **Sim**, iOS e Android com `sentry_flutter` ≥ 9.0.0 [32] | 50 replays no plano (Developer e Team) [30] | Mascara texto, entrada e imagens que não são assets por padrão; `onErrorSampleRate` grava só quando dá erro, com até 30 s antes [32]. Serve para depurar erro, não para mapa de calor |
| Mixpanel replay | Sim, pacote próprio; havia linha beta e linha 1.x [19] | 10 mil replays/mês no Free [17] | `MixpanelMask`/`MixpanelUnmask` [19] |
| Amplitude replay | Android e iOS, sem web; Early Access, "expect significant changes" [22] | 10 mil sessões/mês no Free [20] | Amostragem padrão 0% [22] |
| UXCam | `flutter_uxcam` 2.10.3, "unverified uploader", Android/iOS/web [28] | Página de preços não abriu (404) | Não consegui confirmar no pub.dev o que o SDK grava |
| Smartlook | `flutter_smartlook` existe | — | **Em fim de vida:** a Cisco encerrou a venda em 31/05/2026 e as renovações em 31/08/2026 [29]. Descartar |

- **Estimativa do replay do PostHog com 100% das sessões:** 30 mil / 150 mil / 600 mil gravações dão US$ 230 / US$ 770 / US$ 2.260 por mês. Com amostra de ~8% / ~1,7% / ~0,4% das sessões, cabe nas 2.500 grátis.
- **Opinião:** para mapa de calor de toque, o Clarity é a escolha: é grátis sem teto, tem SDK oficial e mantido, e mascara por padrão. Para "ver o que aconteceu antes do erro", o replay `onError` do Sentry é mais útil, se o Sentry for adotado.

### 2b. Geográfico: onde se identifica e onde há doações

**Doações (dá para fazer já).** `listings.location` e `users.donation_location` já estão no centro de uma célula de ~1 km (ADR 0002). Agregar de novo, numa grade maior, não expõe nada que a lista de mudas por perto já não mostre.

- **Fatos:** `ST_HexagonGrid(size, bounds)` existe no PostGIS desde a 3.1.0, e a documentação traz o exemplo de contar pontos por hexágono com `ST_Intersects` e `GROUP BY` [43]. O Neon tem `postgis` (3.3.10 a 3.6.4, conforme o Postgres) e também `h3`/`h3_postgis` [45]. No H3, a resolução 7 tem hexágonos de ~5,2 km² e a 6, de ~36 km² [44].
- **Opinião:** usar H3 resolução 7 (ou 6 em cidades pequenas) e **suprimir células com menos de 5 anúncios**, para que uma célula com um doador só não vire "aqui mora alguém". Nada de mapa de pinos, que o ADR 0002 já descartou.

**Identificações (não dá hoje).** A tabela não tem lugar. Para ter esse mapa seria preciso:

1. pedir localização no momento da identificação, com consentimento próprio, porque hoje o app só pede localização para doar e para buscar mudas;
2. guardar só a célula grossa (H3 resolução 6 ou 7), calculada antes de salvar, no mesmo espírito do ADR 0002;
3. declarar "Localização aproximada" no formulário da Play [12].

Opinião: não vale abrir isso na fase 2. O país e a cidade que o GA4 já mostra por usuário (derivados do IP; não reli essa parte da documentação do GA) respondem "onde estão os usuários" sem pedir permissão nova.

**Como mostrar:**

| Opção | Fato | Opinião |
|---|---|---|
| **Painel interno** no Grafana Cloud Free ou Metabase | Grafana Cloud Free: 3 usuários ativos, 10 mil séries de métricas, 50 GB de logs, 14 dias de retenção [51]. Metabase open source é grátis para self-host; o Metabase Cloud Starter custa US$ 100/mês [52] | Grafana Cloud lendo o Neon direto (usuário só leitura) basta. Self-host do Metabase pede um servidor sempre ligado, que o projeto não tem |
| Google Maps no app com heatmap | O Maps SDK (Android) não tem limite nem preço por mil na tabela [48]. `google_maps_flutter` 2.19.0 (flutter.dev) [46]; no Android, o heatmap suporta só `maxIntensity` e `colorMapSize` [47] | Só se o mapa de calor for **público**, no app. Exige uma tela nova e uma chave do Maps restrita ao app |
| `flutter_map` com OpenStreetMap | `flutter_map` 8.3.2 (fleaflet.dev) [49]. Os tiles do OSM não têm SLA, exigem atribuição e User-Agent próprio, e proíbem baixar em massa [50] | Bom para um mapa simples sem conta no Google, mas os tiles públicos do OSM não são para tráfego de app em escala |

## 3. Rastreabilidade e erros

### No app

- **Crashlytics (fatos):** grátis [1]; `firebase_crashlytics` 6.0.1, publisher verificado, Android/iOS/macOS [3]. Aceita até 64 chaves customizadas de até 1 kB, log de até 64 kB por sessão e `setUserIdentifier`, que deve ser "an ID number, token, or hashed value" [9]. Dá para desligar a coleta no `AndroidManifest.xml` (`firebase_crashlytics_collection_enabled = false`) e ligar em tempo de execução com `setCrashlyticsCollectionEnabled(true)`. Enquanto está desligada, os dados ficam no aparelho [9].
- **Performance Monitoring (fatos):** grátis [1]; `firebase_performance` 0.12.1 [4]. Coleta tempo de abertura, latência de rede, CPU e memória, dados do aparelho **e o IP**, este "to map performance events to the countries they originate from" [7]. Opinião: a API é pequena e o gargalo conhecido é o Pl@ntNet (~1,8 s, `teste-plantnet.md`); dá para deixar para depois.
- **Sentry no app (fatos):** `sentry_flutter` 10.3.0, publisher verificado sentry.io [31]. Propaga o trace pelos cabeçalhos `sentry-trace` e `baggage` [33]. Plano Developer grátis: 1 usuário, 5 mil erros, 5 milhões de spans, 50 replays, 30 dias. Team: US$ 26/mês (anual) ou US$ 29 (mensal), 50 mil erros e até 90 dias [30].

### Na API (Lambda)

- **CloudWatch (fatos):** franquia mensal de 5 GB de logs, 10 métricas customizadas, 10 alarmes, 3 dashboards e 100 execuções de canário. Depois: US$ 0,30 por métrica/mês, US$ 0,10 por alarme/mês, US$ 0,0012 por execução de canário [37].
- **X-Ray (fatos):** grátis até 100 mil traces gravados e 1 milhão lidos por mês; depois, US$ 5 por milhão gravado [37]. No Lambda, a amostragem é de 1 requisição por segundo mais 5% do resto e "you can't configure the X-Ray sampling rate" [38]. A AWS oferece dois caminhos: o ADOT (OpenTelemetry), em camada do Lambda sem mexer no código, e o X-Ray SDK [38].
- **Estimativa X-Ray:** com 0,17 / 0,87 / 3,5 requisições por segundo em média, a cota de 1 por segundo pega quase tudo em A e B. São ~450 mil / ~2,2 mi / ~2,9 mi traces por mês, ou ~US$ 2 / ~US$ 11 / ~US$ 14.
- **Sentry na API (fatos):** existe o `@sentry/nestjs` oficial, com `instrument.ts`, `SentryModule.forRoot()` e `SentryGlobalFilter` [34], e um guia separado para Lambda (`@sentry/aws-serverless` ou camada) [35]. O guia do NestJS não fala de Lambda [34]. Opinião: a combinação NestJS + `serverless-express` + Sentry no Lambda precisa de um teste antes de virar decisão, em especial o flush dos eventos antes de a função congelar.

### Ligar o erro no app à requisição na API

Duas formas, que não se excluem:

1. **Id de requisição próprio (recomendo começar por aqui, opinião).** Um middleware da API aceita um `X-Request-Id` vindo do app, ou gera um UUID, e:
   - devolve o id no cabeçalho da resposta e num campo `requestId` do problem details;
   - inclui o id na linha do `RequestLoggerMiddleware` e nos logs de erro.

   O `ApiClient` do app gera o id por requisição e, quando dá erro, grava esse id numa chave do Crashlytics (`setCustomKey('request_id', …)` [9]). Para achar o log, basta buscar o id no CloudWatch Logs Insights. Não depende de fornecedor. Antes de mexer no `ApiClient`, ler `docs/agents/gotchas.md`.
2. **Tracing distribuído do Sentry.** O app manda `sentry-trace`/`baggage` [33], e o `@sentry/nestjs` continua o trace. Assim se vê, numa só tela, o toque, a requisição, o tempo no Pl@ntNet e o erro. Restrinja a propagação ao domínio da API, para não mandar esses cabeçalhos ao Pl@ntNet ou ao GBIF. Há uma ressalva: o guia diz que o modo de trace padrão do Flutter ("stream mode") ainda não continua um trace recebido [33]. Isso vale para o lado que recebe, mas confira na hora de implementar.

## 4. Status e métricas de negócio

### Disponibilidade

| Opção | Fato | Custo estimado |
|---|---|---|
| **UptimeRobot Free** | 50 monitores, intervalo de 5 min, 1 página de status básica; uso comercial permitido [39][40]. Solo: US$ 9/mês (anual), intervalo de 60 s [39] | US$ 0 |
| Better Stack Free | 10 monitores e heartbeats, 1 página de status, alertas por e-mail e Slack [41] | US$ 0 |
| CloudWatch Synthetics | 100 execuções/mês grátis, depois US$ 0,0012 cada [37] | 2 canários a cada 15 min ≈ 5.760 execuções ≈ US$ 6,79; a cada 5 min ≈ US$ 20,62. Não incluí o Lambda e o S3 que o canário usa |

- **O que monitorar (opinião):** `GET /v1/health` (API + banco) e o Pl@ntNet.
- **Cuidado com o Pl@ntNet (fato):** cada `identify` conta na cota diária e no Pro custa € 0,005 ([custos-fase-2.md](custos-fase-2.md)). O Pl@ntNet tem `/v2/quota/daily`, com o uso e o que resta no dia (UTC); `/languages` e `/projects` não têm limite. Toda resposta traz os cabeçalhos `RateLimit` (restante) e `RateLimit-Policy`, e a cota estourada devolve **429** [42]. Opinião: o monitor de status do Pl@ntNet deve bater em `/v2/projects` ou `/v2/quota/daily`, nunca em `identify`. Não confirmei se o próprio `/v2/quota/daily` conta em alguma cota.
- **Alertas (fatos e lacunas):** o UptimeRobot avisa por e-mail; SMS e ligação exigem créditos pagos. Não consegui confirmar Telegram no plano grátis, e a página não fala de WhatsApp [39]. O Better Stack Free avisa por e-mail e Slack, sem menção a Telegram [41]. Alarmes do CloudWatch avisam pelo SNS; não achei na página do SNS o preço por e-mail [37]. Opinião: e-mail basta no começo. Para Telegram, um bot próprio chamado por um Lambda assinante do SNS é simples, mas não verifiquei os termos da API do Telegram. WhatsApp para alerta não vale o esforço.
- **Página de status pública (opinião):** a página grátis do UptimeRobot resolve. Para um app de portfólio, é mais vitrine que necessidade.

### Métricas de negócio

| Métrica | De onde sai | Como acompanhar (opinião) |
|---|---|---|
| Identificações por dia × cota do Pl@ntNet | `COUNT(*)` em `identifications` por dia; e `/v2/quota/daily` ou o cabeçalho `RateLimit` do Pl@ntNet [42] | Painel no Grafana. A API pode logar o `RateLimit` de cada resposta e um alarme do CloudWatch avisa a 80% da cota (métrica filtrada de log: cabe nas 10 grátis [37]) |
| Gasto do Claude | **Não é registrado hoje.** O Console da Anthropic mostra uso e custo (não verifiquei a página) | Gravar `usage.input_tokens`/`output_tokens` em `care_guides` na geração; o custo por espécie é de ~US$ 0,008 ([custos-fase-2.md](custos-fase-2.md)). Também dá para pôr um limite de gasto mensal no Console |
| Doações ativas | `listings` com `status = 'active'` | Painel no Grafana, com o mapa de calor por H3 da seção 2b |
| Interesses por anúncio, plantas salvas por identificação | `interests`, `plants`, `identifications.chosen_species_id` | Painel. Esses números, que o banco já tem, valem mais que o funil do GA4 para doação |
| 429 e 5xx da API, duração do Lambda | CloudWatch (métricas automáticas do Lambda) | 2 a 4 alarmes, dentro dos 10 grátis [37] |

## 5. Privacidade e LGPD

### Base legal e consentimento

- **Fatos (LGPD):** o consentimento (art. 7º, I) e o legítimo interesse (art. 7º, IX) são bases distintas; no legítimo interesse, o controlador "deverá adotar medidas para garantir a transparência", e a ANPD pode pedir relatório de impacto (art. 10, §§ 2º e 3º) [53]. Dado anonimizado não é dado pessoal (art. 12) [53]. Transferência internacional exige uma das hipóteses do art. 33, como cláusulas-padrão contratuais [53]. Pela Resolução CD/ANPD nº 19/2024, o prazo para incorporar as cláusulas-padrão da ANPD terminou em 23/08/2025 (fonte secundária) [54]. Firebase, Clarity, PostHog e Sentry processam fora do Brasil.
- **Opinião:**
  - **Crash e diagnóstico** (Crashlytics, Sentry sem replay): legítimo interesse, com aviso na política de privacidade.
  - **Analytics de produto:** legítimo interesse também é defensável, mas o caminho mais seguro é um aviso na primeira abertura com opção de recusar.
  - **Gravação de sessão** (Clarity, replay): **consentimento**, desligada até a pessoa aceitar, porque grava a tela.
  - Os SDKs têm a chave para isso: `setAnalyticsCollectionEnabled(true)` depois do consentimento [10]; Crashlytics desligado no manifesto e ligado em tempo de execução [9]; `Clarity.consent(adsStorage, analyticsStorage)` e `Clarity.pause()` [24].
  - Antes de decidir, confira os termos de transferência internacional (DPA) de cada fornecedor. Não li nenhum DPA nesta pesquisa.
- **Clarity e consentimento (fato):** o Clarity passou a exigir sinal de consentimento para visitas do EEE, Reino Unido e Suíça em 31/10/2025, e uma página localizada diz que apps móveis não precisam de ação imediata (consultado via busca) [26]. O Brasil não está nessa regra do Clarity, mas a LGPD vale do mesmo jeito.

### Gravação de sessão: o que pode vazar e como mascarar

Telas sensíveis do PlantAí: login e cadastro (e-mail, senha, código), perfil de doação (**telefone**, bairro), detalhe do anúncio (bairro) e as **fotos** (identificação, jardim, anúncio). A foto de uma planta pode mostrar o interior da casa ou o rosto de alguém.

- **Clarity (fatos):** o conteúdo de campos de entrada é mascarado "in all modes and can't be customized". O modo padrão é **Balanced**: mascara entradas, números e e-mails, mas **não as imagens**. **Strict** mascara todo texto e toda imagem. O modo é escolhido no painel e vale para o app inteiro. No Flutter, as regras por id, classe ou tela do painel **não se aplicam** (todas marcadas ✗); só os widgets `ClarityMask`/`ClarityUnmask` [25].
- **PostHog (fato):** `maskAllTexts` e `maskAllImages` vêm ligados; dá para pausar a gravação nas telas sensíveis e desligar a captura de toques [15].
- **Sentry (fato):** mascara texto, entrada e imagens que não são assets; widgets de terceiros, como mapas, precisam de configuração manual [32].
- **Opinião:** usar o Clarity em **Strict** e desmascarar só o que for chrome da interface (abas, botões, títulos) com `ClarityUnmask`; pausar a gravação (`Clarity.pause()`) no perfil de doação e nas telas de auth. Nunca chamar `setCustomUserId` com e-mail; o próprio guia desaconselha PII nesses campos [24]. Use o id interno do usuário com hash, ou nada.

### Formulário "Segurança dos dados" da Play

Regras (fatos): "coletar" é qualquer dado que sai do aparelho, inclusive por SDKs. O desenvolvedor responde pelo que os SDKs coletam. Prestador de serviço que processa "on behalf of the developer" não conta como compartilhamento. "Localização aproximada" é a de área ≥ 3 km², e **a inferida do IP também precisa ser declarada** [12].

| Ferramenta | O que declarar (fato onde há fonte; o resto é leitura minha) |
|---|---|
| Firebase Analytics | Interações no app; IDs do dispositivo ou outros (id da instância). Propósito: análise. Não li a página de divulgação do GA, que o Firebase remete para outro lugar [7] |
| Crashlytics | Registros de falhas; IDs do dispositivo (UUID de instalação do Crashlytics) [7]. Propósito: análise/diagnóstico |
| Performance Monitoring | Diagnóstico; IP usado para país [7]. Pela regra do IP [12], avaliar se declara localização aproximada |
| Clarity / replay | Interações no app (toques, telas) [12]. Se o mascaramento falhar, também fotos e informações pessoais, por isso o modo Strict |
| Sentry | Registros de falhas, diagnóstico; com replay, interações no app |
| Logs da API (CloudWatch) | Não é SDK, mas é coleta do próprio app. Se o IP for parar no log (ver `x-forwarded-for`), declarar ou redigir |

A Firebase criptografa em trânsito e não repassa a terceiros, salvo subprocessadores ou por instrução do desenvolvedor [7]. Todos os fornecedores da tabela entram como prestadores de serviço, então nada aqui vira "compartilhado" (leitura minha de [12]).

### Política de privacidade e retenção

- A política de privacidade precisa citar cada SDK, a finalidade, a base legal, a transferência internacional e o prazo de guarda (opinião; a política em si é outro ticket).
- **Retenções que dá para configurar (fatos):**
  - GA4: 2 ou 14 meses no nível de evento [6];
  - Clarity: gravações por 30 dias, heatmaps e sessões marcadas por 13 meses [26][27];
  - Sentry: 30 dias no Developer, até 90 no Team [30];
  - PostHog: 1 ano no plano grátis [13];
  - Grafana Cloud Free: 14 dias [51];
  - CloudWatch Logs: sem prazo até alguém definir um ([custos-fase-2.md](custos-fase-2.md)).
- **Opinião:** CloudWatch Logs com 30 dias; GA4 com 14 meses (o funil precisa de histórico, e o agregado não é afetado [6]).
- **Direito de eliminação (art. 18, VI [53]):** a exclusão de conta precisa também pedir a exclusão do usuário nos fornecedores que guardam id de usuário, ou então não mandar id de usuário para eles.

### Repositório público: o que pode e o que não pode ficar no código

| Pode ficar no código | Fonte |
|---|---|
| `google-services.json` e a chave de API do Firebase, **desde que restrita às APIs do Firebase** | "do not need to be treated as secrets, and it's safe to include them in your code" [8] |
| DSN do Sentry | "DSNs are safe to keep public because they only allow submission of new events" [36] |
| Project token do PostHog (só eventos e flags) | Usado só nos endpoints públicos de escrita [16]. A página não diz com todas as letras que é seguro expor (o SDK precisa dele no app) |
| Project ID do Clarity | Vai no `ClarityConfig` do app [24] (opinião: não é segredo) |
| Chave do Maps SDK restrita ao pacote e ao certificado do app | Opinião, pelo mesmo raciocínio do Firebase; não li a página de chaves do Maps |

| Nunca no código (só em `.env`/segredos do deploy) | Fonte |
|---|---|
| Personal API key do PostHog (`phx_`) | Dá acesso equivalente a estar logado [16] |
| Auth token do Sentry (upload de símbolos/source maps no CI) | Opinião |
| Chave da Anthropic, do Pl@ntNet, do Resend, credenciais da AWS | Já é a regra do projeto (CLAUDE.md) |
| Qualquer chave Google com a API do Gemini/Generative Language liberada | "never include the Gemini Developer API in the allowlist for a publicly accessible API key" [8] |

Atenção (opinião): o projeto do Google Cloud do login com Google (ADR 0004) é o candidato natural a virar o projeto Firebase. Se virar, confira as restrições da chave criada automaticamente, que deve liberar só APIs do Firebase [8].

## Recomendação

### Pilha mínima para abrir a fase 2 (adotar primeiro)

1. **Id de requisição** na API e no `ApiClient` (`X-Request-Id`, no log e no problem details). Custa zero e é o que mais ajuda a depurar.
2. **Crashlytics** no app, com o id de requisição numa chave customizada nos erros de API. É grátis, do Google e com SDK oficial.
3. **Google Analytics for Firebase** com 5 a 8 eventos do funil, retenção de 14 meses e aviso na primeira abertura com opção de recusar.
4. **UptimeRobot Free** em `GET /v1/health` e em `/v2/projects` do Pl@ntNet, com alerta por e-mail e página de status grátis.
5. **CloudWatch:** retenção dos logs em 30 dias; alarmes de 5xx, de duração do Lambda e de cota do Pl@ntNet a 80% (logando o cabeçalho `RateLimit`); redigir `x-forwarded-for` no log.
6. **Painel interno no Grafana Cloud Free**, lendo o Neon com usuário só leitura: identificações por dia × cota, doações ativas, interesses, e o mapa de calor de doações em H3 resolução 7 com supressão de células com menos de 5 anúncios.
7. **Gravar os tokens do Claude** em `care_guides`, para somar o gasto por mês no mesmo painel.

Custo: **US$ 0 nos três cenários**, fora o CloudWatch já orçado em [custos-fase-2.md](custos-fase-2.md).

### Deixar para depois

- **Clarity** (mapa de calor de toque): quando houver uma pergunta de UX que os números não respondam. Entra em Strict, com consentimento próprio e pausa nas telas de auth e perfil. É grátis, mas é o item que mais pesa em privacidade.
- **Sentry** (app + NestJS, tracing ponta a ponta e replay `onError`): quando o id de requisição deixar de bastar, ou se o Ângelo quiser mostrar tracing distribuído no portfólio. O Developer grátis aguenta o cenário A.
- **Firebase Performance** e **X-Ray**: só se a latência virar problema, além do Pl@ntNet, que já é conhecido.
- **PostHog/Mixpanel/Amplitude:** só se as explorações do GA4 não derem conta.
- **Mapa de calor geográfico de identificações:** exige nova permissão, consentimento e declaração na Play. Não vale na fase 2.
- **Mapa público de doações no app** (Google Maps heatmap): pede um ADR novo, que revise o ADR 0002 (hoje "o MVP não tem mapa").
- **Descartar:** Smartlook (fim de vida [29]) e UXCam (SDK sem publisher verificado e preço não encontrado).

### Decisões em aberto (cada uma vira um ticket)

1. Adotar o Firebase (Analytics + Crashlytics) no app e decidir se o projeto Firebase é o mesmo projeto Google Cloud do login com Google.
2. Base legal do analytics: aviso com opção de recusar (legítimo interesse) ou consentimento explícito antes de coletar.
3. Formato do id de requisição: quem gera (app ou API), o nome do cabeçalho e se vai no corpo do problem details.
4. Retenção dos logs do CloudWatch (sugestão: 30 dias) e redigir ou não `x-forwarded-for` no `RequestLoggerMiddleware`.
5. Lista de eventos do funil e os nomes no GA4 (até 40 caracteres, 25 parâmetros).
6. Monitor de status: UptimeRobot ou CloudWatch Synthetics, e se a página de status fica pública.
7. Canal de alerta: só e-mail, ou um bot de Telegram via SNS.
8. Ferramenta do painel interno: Grafana Cloud Free ou outra, e o usuário só leitura no Neon.
9. Resolução H3 e o mínimo de anúncios por célula no mapa de calor de doações.
10. Gravar o uso de tokens do Claude em `care_guides` e pôr um limite de gasto no Console da Anthropic.
11. Adotar ou não o Clarity, com que modo de mascaramento, e em quais telas pausar.
12. Adotar ou não o Sentry (app + API) e testar o flush no Lambda com `serverless-express`.
13. Retenção do GA4 (2 ou 14 meses).
14. Texto da política de privacidade e do formulário "Segurança dos dados", depois de escolher as ferramentas.
15. Exclusão de conta: propagar a exclusão aos fornecedores ou não mandar id de usuário para eles.

## Fontes

Todas lidas em 02/11/2026.

1. Firebase, preços (produtos sem custo; Remote Config): https://firebase.google.com/pricing
2. pub.dev, `firebase_analytics` 13.0.1: https://pub.dev/packages/firebase_analytics
3. pub.dev, `firebase_crashlytics` 6.0.1: https://pub.dev/packages/firebase_crashlytics
4. pub.dev, `firebase_performance` 0.12.1: https://pub.dev/packages/firebase_performance
5. Google Analytics, limites de coleta: https://support.google.com/analytics/answer/9267744?hl=en
6. Google Analytics, retenção de dados: https://support.google.com/analytics/answer/7667196?hl=en
7. Firebase, dados coletados para o formulário da Play: https://firebase.google.com/docs/android/play-data-disclosure
8. Firebase, chaves de API: https://firebase.google.com/docs/projects/api-keys
9. Firebase Crashlytics (Flutter), personalizar relatórios e opt-in: https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports
10. Firebase Analytics, configurar a coleta de dados (a página aberta mostrou só iOS; as chaves do manifesto Android não foram lidas): https://firebase.google.com/docs/analytics/configure-data-collection
11. Google Play Console, Android vitals: https://support.google.com/googleplay/android-developer/answer/9844486?hl=en
12. Google Play Console, formulário Segurança dos dados: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
13. PostHog, preços (versão Markdown da página): https://posthog.com/pricing.md
14. pub.dev, `posthog_flutter` 5.58.4: https://pub.dev/packages/posthog_flutter
15. PostHog, session replay em Flutter: https://posthog.com/docs/session-replay/installation/flutter
16. PostHog, API (project token × personal API key): https://posthog.com/docs/api
17. Mixpanel, preços: https://mixpanel.com/pricing/
18. pub.dev, `mixpanel_flutter` 3.2.0: https://pub.dev/packages/mixpanel_flutter
19. Mixpanel, Session Replay em Flutter (consultada via busca): https://docs.mixpanel.com/docs/tracking-methods/sdks/flutter/flutter-replay
20. Amplitude, preços: https://amplitude.com/pricing
21. pub.dev, `amplitude_flutter` 4.8.1: https://pub.dev/packages/amplitude_flutter
22. Amplitude, Session Replay Flutter Standalone SDK (consultada via busca): https://www.amplitude.com/docs/sdks/session-replay/session-replay-flutter-standalone-sdk
23. pub.dev, `clarity_flutter` 1.10.1: https://pub.dev/packages/clarity_flutter
24. Microsoft Learn, Clarity Flutter SDK (atualizada em 29/09/2026): https://learn.microsoft.com/en-us/clarity/mobile-sdk/flutter-sdk
25. Microsoft Learn, mascaramento do Clarity em apps (atualizada em 11/09/2026): https://learn.microsoft.com/en-us/clarity/mobile-sdk/clarity-sdk-masking
26. Microsoft Clarity, preços e FAQ; gestão de consentimento (consultadas via busca): https://clarity.microsoft.com/pricing, https://learn.microsoft.com/clarity/faq
27. Microsoft Learn, retenção de dados do Clarity (consultada via busca): https://learn.microsoft.com/en-gb/clarity/data-retention
28. pub.dev, `flutter_uxcam` 2.10.3: https://pub.dev/packages/flutter_uxcam
29. Cisco, fim de venda e de vida do Smartlook.com (consultada via busca): https://www.cisco.com/c/en/us/products/collateral/software/smartlook-com-eol.html
30. Sentry, preços: https://sentry.io/pricing/
31. pub.dev, `sentry_flutter` 10.3.0: https://pub.dev/packages/sentry_flutter
32. Sentry, Session Replay em Flutter: https://docs.sentry.io/platforms/dart/guides/flutter/session-replay/
33. Sentry, propagação de trace em Flutter: https://docs.sentry.io/platforms/dart/guides/flutter/tracing/trace-propagation/
34. Sentry, guia do NestJS: https://docs.sentry.io/platforms/javascript/guides/nestjs/
35. Sentry, guia do AWS Lambda: https://docs.sentry.io/platforms/javascript/guides/aws-lambda/
36. Sentry, o que é o DSN: https://docs.sentry.io/concepts/key-terms/dsn-explainer/
37. Amazon CloudWatch, preços (franquia, métricas, alarmes, Synthetics, X-Ray): https://aws.amazon.com/cloudwatch/pricing/
38. AWS Lambda, tracing de funções Node.js: https://docs.aws.amazon.com/lambda/latest/dg/nodejs-tracing.html
39. UptimeRobot, preços: https://uptimerobot.com/pricing/
40. UptimeRobot, uso para clientes e uso comercial (consultada via busca): https://uptimerobot.com/knowledge-hub/monitoring/uptimerobot-for-client-work/
41. Better Stack, preços: https://betterstack.com/pricing
42. Pl@ntNet, gestão de cota da API: https://my.plantnet.org/doc/api/quota
43. PostGIS, `ST_HexagonGrid`: https://postgis.net/docs/ST_HexagonGrid.html
44. H3, tabela de resoluções: https://h3geo.org/docs/core-library/restable/
45. Neon, extensões suportadas: https://neon.com/docs/extensions/pg-extensions
46. pub.dev, `google_maps_flutter` 2.19.0: https://pub.dev/packages/google_maps_flutter
47. pub.dev, `google_maps_flutter_android` (opções de heatmap): https://pub.dev/packages/google_maps_flutter_android
48. Google Maps Platform, preços: https://developers.google.com/maps/billing-and-pricing/pricing
49. pub.dev, `flutter_map` 8.3.2: https://pub.dev/packages/flutter_map
50. OpenStreetMap Foundation, política de uso dos tiles: https://operations.osmfoundation.org/policies/tiles/
51. Grafana Cloud, preços: https://grafana.com/pricing/
52. Metabase, preços: https://www.metabase.com/pricing/
53. Lei nº 13.709/2018 (LGPD), arts. 7º, 10, 12, 18 e 33: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
54. Mattos Filho, "ANPD regulamenta transferência internacional de dados" (fonte secundária, consultada via busca): https://www.mattosfilho.com.br/unico/regulamentacao-transferencia-internacional-dados/
