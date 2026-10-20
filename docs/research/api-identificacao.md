# Pesquisa: API de identificação de plantas

Ticket: [#5](https://github.com/angelobez/plantai/issues/5). Pesquisado em 20/10/2026.

**Pergunta.** Qual API usar para identificar a planta pela foto no MVP: Pl@ntNet, Plant.id (Kindwise) ou a visão do Claude (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`)? E como encadear com o Claude para gerar as dicas de cuidado (rega, luz, como fazer muda)?

**Restrições do projeto.** Repositório público, app de portfólio sem fins comerciais por enquanto, MVP até 15/11/2026, custo perto de zero. App Flutter + API NestJS. "IA" faz parte do nome e da proposta.

## Resumo

| Critério | Pl@ntNet | Plant.id (Kindwise) | Claude (visão) |
| --- | --- | --- | --- |
| Cota grátis | **500 identificações/dia, sem prazo** [1] | **100 créditos, teste de 30 dias** [4][6] | Não há cota grátis permanente documentada; paga por token [8] |
| Custo pago | Pro: €1.000/ano + €0,005/id [1] | €0,05 a €0,01 por id, conforme o volume [4] | Por foto de ~1 MP: ~US$ 0,0005 (Haiku 5.5), ~US$ 0,01 (Sonnet 5.5), ~US$ 0,02 (Opus 5.5). Estimativa abaixo |
| Precisão | Sem número oficial na documentação da API; devolve `score` 0–1 por espécie [3] | "93%: espécie certa no top 3", 35.000+ classes (dado do próprio fornecedor) [5] | Sem benchmark oficial de identificação de espécies; a documentação avisa que pode alucinar [9] |
| Nomes populares em pt | `lang=pt` suportado; `commonNames` por espécie [3][10] | Parâmetro `language`, até 3 idiomas [5][7]. Não confirmei se `pt` cobre nomes populares do plant.id | Gera o nome em pt-BR que você pedir, mas sem fonte por trás (pode inventar) |
| Termos para o PlantAí | Uso grátis até 500/dia; atribuição opcional; 1 conta grátis por pessoa; imagens não guardadas [2] | Teste acaba em 30 dias; Kindwise recebe licença irrevogável sobre as fotos dos usuários, inclusive para treinar modelos e redistribuir em CC-BY-SA 4.0 [6] | Imagens não são usadas para treinar modelos e não ficam guardadas após a requisição [9] |
| Latência | Não publicada. `nb-results` menor responde mais rápido; `detailed=true` deixa mais lento [3] | Não publicada; há modo assíncrono [7] | Não publicada; cresce com o tamanho da imagem e da resposta [9] |
| Formato | JSON com `bestMatch`, `results[]` (`score`, `species`, `commonNames`, `gbif.id`, `powo.id`), `remainingIdentificationRequests` [3] | JSON com sugestões + `details` opcionais (`common_names`, `taxonomy`, `watering`, `propagation_methods` etc.) [5][7] | Texto livre, ou JSON validado por schema com structured outputs (`output_config.format`) |
| Dicas de cuidado | Não tem | Tem, mas com cobertura baixa: rega 9,5%, propagação 9,16% das espécies [5] | Gera tudo (rega, luz, muda), em pt-BR |

**Recomendação: Pl@ntNet para identificar + uma única chamada ao Claude Haiku 5.5 para confirmar o nome popular e gerar as dicas.** Plant.id fica descartado para o MVP. Detalhes em [Recomendação](#recomendação).

## Pl@ntNet

**Custo e cota.** O plano Free custa €0 e dá 500 identificações por dia; a página de preços não lista restrição de uso comercial ou não comercial para ele [1]. Os termos dizem que a API "is free of use up to 500 identification queries per day" e que é paga "for commercial usage beyond 500 identification requests per day" [2]. Há ainda um plano Non-profit (educação/ciência, sob pedido, com logo obrigatório) e o Pro (€1.000/ano, €0,005 por identificação até 3M) [1].

**Termos relevantes** [2]:
- Atribuição é opcional: "Any free use of Pl@ntNet API might acknowledge Pl@ntNet". Há uma frase e logos sugeridos.
- "It is not allowed to create more than one free account per person or per legal entity."
- Imagens "are only kept in our server volatile memory during the identification process". Guardam data, hora e URLs das consultas, não as imagens.
- Limite de 20 requisições simultâneas por cliente. Não compartilhar a conta.
- Um relato em fórum (fonte secundária, não confirmada nos termos) diz que obrigar cada usuário final a criar a própria conta na API viola os termos [11]. Para nós não importa: a chave fica só na API NestJS.

**API** [3]:
- `POST https://my-api.plantnet.org/v2/identify/{project}?api-key=...` (multipart). `project=all` se não souber a flora.
- Até 5 imagens JPG/PNG da mesma planta, total de até 50 MB; `organs` (`leaf`, `flower`, `fruit`, `bark`, `auto`) por imagem.
- `lang` muda os nomes populares; `pt` aparece na lista de `/v2/languages` [10]. O contrato Pro fala em "a maximum of 3 common names for each species in the language selected" [12].
- `nb-results` limita a lista (e acelera); `no-reject=true` evita rejeitar quando a foto não parece planta.
- Resposta: `bestMatch`, `results[]` em ordem de confiança com `score` (0–1), `species.scientificNameWithoutAuthor`, `genus`, `family`, `commonNames`, `gbif.id`, `powo.id`; `predictedOrgans`; `remainingIdentificationRequests` (cota restante do dia).

**Precisão.** A documentação da API não publica acurácia. O `score` é útil para decidir quando pedir outra foto. Quão bem ela reconhece plantas comuns em casas brasileiras (jiboia, espada-de-são-jorge, costela-de-adão) precisa de teste prático.

## Plant.id (Kindwise)

**Custo e cota.** "Start testing our products with 100 free credits"; "The cost of each identification call is one credit"; pacotes de €0,05/crédito (1.000 créditos) a €0,01/crédito (1,5M) [4]. Os termos dizem que "The Trial Version ends after thirty days" e limitam o teste a uma requisição por segundo, sem garantia de disponibilidade [6]. Ou seja: 100 identificações em 30 dias e depois é pago. Não serve para um app de portfólio que precisa continuar no ar.

**Termos relevantes** [6]:
- §6.12: a chave de API deve ser mantida "strictly confidential".
- §17.5: o cliente dá à Kindwise uma licença "non-exclusive, unlimited and irrevocable" sobre "all photographs provided from its devices and/or its end users", inclusive "for developing machine learning" e para "share provided photographs under the license CC-BY-SA 4.0 or later". Rostos são borrados. Isso teria de constar na política de privacidade do app.
- §17.3.3: proíbe usar o serviço para desenvolver um sistema "based on the same principle".

**API e precisão.** Autenticação pelo header `Api-Key` [7]. `details` opcionais incluem `common_names`, `taxonomy`, `description`, `edible_parts`, `watering`, `propagation_methods`; `language` aceita até 3 códigos; há modo assíncrono e o resultado fica disponível por 6 meses [5][7]. O fornecedor anuncia 35.000+ classes e "Correct species in over 9/10 queries within the top three results", e cita estudos em que ficou à frente do Pl@ntNet em flora britânica e árvores urbanas [5]. Os dados de cuidado cobrem pouco: rega 9,50%, propagação 9,16% [5]. Não encontrei a referência oficial completa da v3 (a página do Postman não renderizou), então não confirmei a cobertura de `pt` nos nomes populares.

## Claude (visão)

**Preço por token** [8]:

| Modelo | Entrada / MTok | Saída / MTok |
| --- | --- | --- |
| `claude-opus-5-5` | US$ 4 | US$ 20 |
| `claude-sonnet-5-5` | US$ 2 | US$ 10 |
| `claude-haiku-5-5` (prompt até 100k tokens) | US$ 0,10 | US$ 0,50 |

A página de preços não menciona cota grátis para a API; é preciso ter créditos no Console. Contas novas começam num tier de avaliação com limites menores, e há teto de gasto mensal por tier (US$ 500 no Start) [13]. Dá para definir um limite de gasto próprio menor no Console [13], o que protege contra abuso.

**Custo da imagem** [9]: uma imagem custa `⌈largura/28⌉ × ⌈altura/28⌉` tokens. 1000×1000 px = 1.296 tokens; 1092×1092 = 1.521. Formatos JPEG, PNG, GIF, WebP; até 10 MB por imagem na API. A própria doc estima ~US$ 5,18 por mil imagens de 1 MP no Opus 5.5.

**Estimativa por identificação + dicas** (foto de ~1 MP redimensionada no app, ~500 tokens de prompt, ~800 de saída incluindo raciocínio):
- Haiku 5.5: 1.800 × 0,10/1M + 800 × 0,50/1M ≈ **US$ 0,0006**
- Sonnet 5.5: 1.800 × 2/1M + 800 × 10/1M ≈ **US$ 0,012**
- Opus 5.5: 1.800 × 4/1M + 800 × 20/1M ≈ **US$ 0,023**

Com 1.000 identificações no mês, isso dá menos de US$ 1 no Haiku e cerca de US$ 12 no Sonnet. O prompt de sistema fixo pode usar prompt caching para baratear mais [8].

**Precisão e limites.** Não há benchmark oficial de identificação de espécies. A doc avisa: "Claude might hallucinate or make mistakes when interpreting low-quality, rotated, or very small images under 200 pixels" [9]. Em identificação, o risco é dar um nome científico plausível e errado com confiança, sem um `score` calibrado como o do Pl@ntNet.

**Privacidade.** "Anthropic does not use uploaded images to train models"; as imagens "are automatically deleted after they have been processed" [9].

**Formato.** Com structured outputs (`output_config.format` com JSON Schema), a resposta sai como JSON validado, pronto para virar DTO no NestJS.

## Recomendação

**Para o MVP: Pl@ntNet identifica, e uma chamada ao `claude-haiku-5-5` confirma e escreve as dicas.**

Por quê:
1. **Custo perto de zero.** 500 identificações por dia de graça e sem prazo (Pl@ntNet) + menos de US$ 0,001 por chamada ao Haiku 5.5.
2. **Termos compatíveis.** Uso grátis permitido, atribuição opcional, imagens não guardadas (Pl@ntNet) e não usadas para treino (Anthropic). O Plant.id expira em 30 dias e pega licença irrevogável sobre as fotos dos usuários.
3. **Precisão com âncora.** O Pl@ntNet é um classificador treinado em espécies e devolve `score`; o Claude não precisa adivinhar a espécie do zero, só escolher entre candidatos e explicar. Isso reduz a chance de alucinação.
4. **IA continua no centro.** O Claude escreve o nome popular brasileiro, as dicas e o passo a passo da muda, que é a parte que o usuário lê.

**Fluxo sugerido (tudo no backend; as chaves ficam no `.env` da API NestJS, nunca no app Flutter):**

```
Flutter ──foto (redimensionada ~1000px, JPEG)──▶ NestJS
NestJS ──multipart, lang=pt, nb-results=3──▶ Pl@ntNet /v2/identify/all
  ├─ se rejeitar ("não é planta") ou top score < limiar → pedir outra foto
  └─ senão:
NestJS ──foto + top 3 candidatos (nome científico, score, commonNames)──▶ Claude Haiku 5.5
       (structured output: JSON Schema)
NestJS ◀── { especieEscolhida, nomePopularPtBr, confianca, rega, luz, solo, comoFazerMuda[], cuidados, avisoToxicidade }
NestJS ──salva no Postgres por nome científico (cache)──▶ Flutter
```

Pontos do encadeamento:
- **Uma chamada só ao Claude**, com a foto e os candidatos: ele confirma qual dos três bate com a imagem (ou diz "nenhum") e já gera as dicas. Evita duas idas e voltas.
- **Instruir no prompt** a usar só os candidatos recebidos, responder em pt-BR, e marcar `confianca: "baixa"` quando a foto não bater. Nunca inventar espécie fora da lista.
- **Cache por espécie.** As dicas dependem da espécie, não da foto. Guardar no Postgres por `scientificNameWithoutAuthor` e reusar: a segunda jiboia não paga Claude.
- **Limiar do `score`** do Pl@ntNet a definir com testes (ex.: abaixo de 0,2 pedir outra foto ou outro órgão da planta).
- **Atribuição:** mostrar "Identificação: Pl@ntNet" na tela de resultado. É opcional nos termos, mas é barato e honesto.
- **Modelo:** começar no Haiku 5.5. Se as dicas saírem rasas nos testes, trocar para Sonnet 5.5 (~20× mais caro, ainda centavos).

**Plano B, se o Pl@ntNet for mal nas plantas de casa brasileiras:** usar só o Claude (Sonnet 5.5) com a foto, também com structured output e um campo de confiança. É uma integração a menos, mas perde o `score` calibrado e aumenta o risco de nome errado com confiança.

## Perguntas para o humano decidir

1. **Aceita o fluxo híbrido (Pl@ntNet + Claude) ou prefere só Claude** para ter uma integração a menos até 15/11?
2. **Fazemos um teste rápido antes de fixar?** Proposta: 20 fotos de plantas comuns em casas brasileiras, medindo acerto do top 1/top 3 do Pl@ntNet, nomes em `pt` e latência real das duas chamadas.
3. **Haiku 5.5 ou Sonnet 5.5** para as dicas? Haiku custa ~US$ 0,0006 por chamada; Sonnet ~US$ 0,01.
4. **Qual limite de gasto mensal** colocar no Console da Anthropic (ex.: US$ 5)? E um limite de identificações por usuário por dia no app, para proteger a cota de 500/dia do Pl@ntNet?
5. **Quer mostrar o logo/atribuição do Pl@ntNet** na tela de resultado?

## Fontes

1. Pl@ntNet, preços: https://my.plantnet.org/pricing
2. Pl@ntNet, termos de uso da API: https://my.plantnet.org/terms_of_use
3. Pl@ntNet, documentação do endpoint de identificação: https://my.plantnet.org/doc/api/identify
4. Kindwise, preços: https://www.kindwise.com/pricing
5. Kindwise, página do plant.id: https://www.kindwise.com/plant-id
6. Kindwise, termos e condições da API (v3, PDF): https://www.kindwise.com/terms-and-conditions
7. Kindwise, handbook: https://www.kindwise.com/handbook; cliente Python oficial: https://pypi.org/project/kindwise-api-client/
8. Anthropic, preços: https://platform.claude.com/docs/en/about-claude/pricing
9. Anthropic, visão: https://platform.claude.com/docs/en/build-with-claude/vision
10. Pl@ntNet, outros endpoints (`/v2/languages`): https://my.plantnet.org/doc/api/other
11. Fórum UBports (fonte secundária): https://forums.ubports.com/post/64719
12. Pl@ntNet, contrato da API Pro v4.5 (PDF): https://my.plantnet.org/documents/agreement_PlantNet_API_english_v4.5_USD.pdf
13. Anthropic, limites de uso: https://platform.claude.com/docs/en/api/rate-limits
