# Pesquisa: custo mensal do PlantAí aberto ao público (fase 2)

Sem ticket; pedido direto do Ângelo em 30/10/2026. Todas as fontes foram lidas em 30/10/2026. Os preços da AWS vêm da Price List API oficial, com a data de publicação de cada arquivo nas fontes. Preços e planos mudam: confira de novo antes de decidir.

Neste arquivo, **fato** é o que está escrito numa fonte primária, com o número da fonte entre colchetes. **Estimativa** é conta minha a partir de premissas declaradas, marcada como tal.

## Pergunta

Quanto custa por mês manter o PlantAí no ar na fase 2, aberto ao público, em cenários bem acima das 500 identificações por dia do plano grátis do Pl@ntNet? O que domina o custo, e onde estão as alavancas para economizar?

## Restrições e arquitetura considerada

O modelo usa a arquitetura que o repo já decidiu ([ADR 0004](../adr/0004-api-no-aws-lambda-com-function-url.md), [ADR 0007](../adr/0007-fotos-pela-api-e-telefone-so-pelo-interesse.md), [ADR 0001](../adr/0001-autenticacao-propria-uma-conta-por-email.md)), conferida no código de `api/src`:

- **API:** NestJS no AWS Lambda em `us-east-1`, exposto por Function URL, **sem API Gateway**. Para ter domínio próprio, um CloudFront fica na frente da Function URL (ADR 0004). Toda a conta da AWS abaixo é em `us-east-1`.
- **Banco:** Postgres com PostGIS no Neon (`aws-us-east-1`). No MVP é o plano Free. Na fase 2, o modelo usa o plano pago Launch (ver [Banco](#banco-postgres-com-postgis)).
- **Fotos:** sobem pela API (`POST /v1/photos`). O sharp tira o EXIF e regrava como JPEG com qualidade 85, num bucket S3 privado. O app reduz a foto para no máximo 1600 px com qualidade 85 (`image_picker_photo_picker.dart`). A entrega é por URL pré-assinada do S3 com validade de 1 hora, direto do S3, sem CloudFront (`photo-storage.ts`). **Toda foto de identificação fica guardada para sempre**: a identificação "anexa" a foto e a regra de ciclo de vida só apaga as não anexadas (`identifications.service.ts`, `photos.service.ts`). Cada anúncio tem uma foto (`listings.photo_id`). Há limite de 50 fotos por usuário por dia.
- **Identificação:** **uma chamada ao Pl@ntNet por identificação**, com uma imagem, `nb-results=3`, `lang=pt` e `include-related-images=true` (`plantnet-identifier.ts`). Limite de 10 identificações por usuário por dia (`IDENTIFICATION_DAILY_LIMIT`). Candidatos sem chave do GBIF são resolvidos na API pública do GBIF, que não cobra.
- **Dicas de cuidado:** geradas pelo Claude **uma vez por espécie** e guardadas em `care_guides`, que serve de cache para todos os usuários (`care-guide.service.ts`). O modelo padrão é `claude-sonnet-5-5` (`DEFAULT_CARE_GUIDE_MODEL`), com `effort: 'low'`, `max_tokens: 8000`, uma ferramenta `strict` com `tool_choice: auto`, e **sem a foto**. O custo cresce com o número de espécies novas, não com o número de identificações. Ele só volta a crescer quando `CARE_GUIDE_PROMPT_VERSION` muda e as dicas são geradas de novo.
- **E-mail:** o código manda e-mail pelo **Resend** (`resend-email-sender.ts`), decidido no ADR 0001. Só vão e-mails de código de cadastro e de recuperação de senha. Quem entra pelo Google não recebe e-mail.
- **Ainda não decidido para a fase 2:** CloudFront também para as fotos, tamanho de memória e arquitetura (x86 ou Arm) do Lambda, e uma possível troca do Resend pelo SES. Onde faltou decisão, o modelo usa a opção atual do código e mostra a alternativa da AWS como alavanca.

Conversão de moeda: PTAX de venda do Banco Central no fechamento de **30/10/2026**: **US$ 1 = R$ 5,4212** e **€ 1 = R$ 6,0522** [27]. Por essas duas cotações, € 1 = US$ 1,1164. Os valores não incluem IOF, spread do cartão nem impostos do fornecedor. O Pl@ntNet cobra "excl. taxes" [3].

## Resumo

Custo mensal **estimado** no 12º mês de operação. As fotos acumulam, então o S3 cresce com o tempo. As premissas de cada cenário estão em [Premissas dos cenários](#premissas-dos-cenários).

| Item | A: 1.000 id/dia | B: 5.000 id/dia | C: 20.000 id/dia |
|---|---|---|---|
| **Pl@ntNet Pro** (anuidade + excedente, ÷ 12) | € 152,08 | € 760,42 | € 2.683,34 |
| Neon Launch (compute + storage) | US$ 20,04 | US$ 41,49 | US$ 87,88 |
| Lambda (requisições + GB-s, já descontada a franquia) | US$ 0,00 | US$ 5,96 | US$ 44,43 |
| S3 (armazenamento + requisições) | US$ 2,00 | US$ 10,02 | US$ 40,06 |
| Saída de dados para a internet (fotos direto do S3 + fotos enviadas ao Pl@ntNet) | US$ 0,00 | US$ 5,24 | US$ 47,95 |
| Resend (e-mail) | US$ 0 (Free) | US$ 20 (Pro) | US$ 20 (Pro) |
| Claude (dicas de espécies novas, Sonnet 5.5) | US$ 1,20 | US$ 3,20 | US$ 8,00 |
| CloudWatch Logs | US$ 0,00 | US$ 0,00 | US$ 2,00 |
| CloudFront da API + Route 53 | US$ 0,50 | US$ 0,50 | US$ 0,50 |
| **Infra sem o Pl@ntNet** | **US$ 23,75 = R$ 128,74** | **US$ 86,41 = R$ 468,45** | **US$ 250,83 = R$ 1.359,80** |
| **Total com Pl@ntNet Pro** | **US$ 193,53 = R$ 1.049,19** | **US$ 935,34 = R$ 5.070,66** | **US$ 3.246,50 = R$ 17.599,93** |
| Total com Pl@ntNet Non-profit (€ 0), se aceito | R$ 128,74 | R$ 468,45 | R$ 1.359,80 |

O que se tira da tabela:

- **O Pl@ntNet Pro domina o custo:** 88% do total em A, 91% em B e 92% em C. Tudo o mais somado fica abaixo de US$ 255/mês, mesmo no cenário C.
- **O Claude é irrelevante no custo**, graças ao cache por espécie: menos de US$ 10/mês mesmo no cenário C. Uma espécie custa cerca de US$ 0,008 no Sonnet 5.5 (estimativa).
- **Depois do Pl@ntNet, os maiores itens são o banco e a saída de dados das fotos.** O S3 cresce sem parar, porque nenhuma foto de identificação é apagada.
- O Pl@ntNet também tem custos fixos: a anuidade mínima do Pro é **€ 1.000/ano, cerca de R$ 6.052**, paga adiantada na assinatura e sem reembolso [3].

## Pl@ntNet

### Planos (fatos)

| Plano | Preço | Cota | Condições |
|---|---|---|---|
| Free | € 0 | 500 identificações/dia, "For low volume" [1] | Uma conta grátis por pessoa ou pessoa jurídica. Também é proibido criar várias contas grátis que consultem do mesmo IP [2] |
| Non-profit | € 0, "for education or science" [1] | "more than 500 identifications per day or burst usage, on demand" [1] | Pedido por contato informando "(i) the name and url of your non-profit organization" e uma descrição do uso [2]. O logo "powered by Pl@ntNet" é obrigatório [1] |
| Pro (pay as you go) | € 1.000/ano [1] | Sem teto anual na página. O contrato diz que o consumo não passa de 10 milhões de requisições sem aditivo [3] | Contrato de licença v5.1 com o CIRAD, por 1 ano, renovável por aditivo [3]. Logo não obrigatório [1]. Faturado em USD pelo câmbio do dia da fatura [2] |

Faixas do Pro na página de preços: € 0,005 por identificação até 3 milhões, € 0,004 acima de 3 milhões, € 0,003 acima de 30 milhões e € 0,002 acima de 300 milhões [1]. Os termos dizem que a cota de segurança é de 1 milhão de requisições por dia para clientes Pro e que cada cliente pode ter no máximo 20 requisições simultâneas [2].

### Os € 0,005 valem para todas as identificações ou só para as que passam de 500/dia?

**Para todas, pelo contrato.** O Artigo 10.1 do contrato Pro v5.1 diz [3]:

> "The Pl@ntNet APIs will be made available by the Publisher to the Client on payment of 1,000 € excl. taxes (one thousand euros excluding taxes) for a volume of 200,000 (two hundred thousand) requests with no carry-over from one year to another."
>
> "All consumption beyond the fixed rate of 200,000 (two hundred thousand) requests will be charged to the Client 5 € excl. taxes (five euros excluding taxes) for 1,000 (one thousand) additional requests."

Na prática: os € 1.000 compram as primeiras 200.000 requisições do ano (200.000 × € 0,005 = € 1.000), e cada requisição seguinte custa € 0,005. O efeito é **€ 0,005 por identificação, com mínimo de € 1.000/ano**. O contrato conta "requests" e não menciona as 500 grátis por dia. O excedente é cobrado no fim do ano de contrato [3].

Ressalva de interpretação: os termos do site dizem que a API "is paying for commercial usage beyond 500 identification requests per day" [2]. Daria para ler que só o que passa de 500/dia é cobrado, mas o contrato, que é o documento que se assina, não desconta nada. Se o Pl@ntNet descontasse as 500/dia, o custo mensal ficaria em cerca de € 83 (A), € 684 (B) e € 2.622 (C) (estimativa). Só no cenário A a diferença é grande. **Confirme por escrito com o Pl@ntNet antes de assinar.**

As faixas de € 0,004 e abaixo parecem progressivas: o contrato cobra "€ 4 / 1,000 identification requests, for requests over 3 million per year" [3]. Por isso o cálculo cobra € 0,004 só sobre o que passa de 3 milhões. Isso só pesa no cenário C.

### O Non-profit cobre um app de portfólio gratuito, sem fins comerciais?

**Provavelmente não, do jeito que o plano está escrito.** O Non-profit é "for education or science" [1] e "for specific non-profit educational and scientific purposes" [2]. O pedido exige o nome e a URL de uma **organização** sem fins lucrativos [2]. O PlantAí é um projeto pessoal de portfólio, não uma organização, e o uso não é educacional nem científico no sentido estrito. Nenhuma página fala de projeto pessoal, então a resposta definitiva só vem perguntando pelo formulário (`/contact?subject=non-profit-plan`) [1]. **Volume:** o Non-profit oferece mais de 500/dia "on demand" [1], sem número publicado.

### O que os termos dizem sobre uso não comercial acima de 500/dia?

Não dizem nada explícito. A frase de cobrança fala só de "commercial usage beyond 500" [2]. O caso "não comercial, sem organização, acima de 500/dia" não está previsto. Na prática, a conta Free tem a cota de 500/dia, e para passar disso só há o Non-profit (sob pedido) ou o Pro. Não há base nos termos para supor que o uso não comercial acima de 500/dia seja grátis.

## Claude (dicas de cuidado)

### Preços (fatos) [4]

| Modelo | Entrada / MTok | Escrita no cache (5 min) | Leitura do cache | Saída / MTok | Batch (entrada / saída) |
|---|---|---|---|---|---|
| `claude-sonnet-5-5` | US$ 2 | US$ 2,50 | US$ 0,10 | US$ 10 | US$ 1 / US$ 5 |
| `claude-haiku-5-5` (prompt até 100 mil tokens) | US$ 0,10 | US$ 0,125 | US$ 0,01 | US$ 0,50 | US$ 0,05 / US$ 0,25 |

Com ferramentas e `tool_choice: auto`, o prompt de sistema de tool use acrescenta 286 tokens de entrada no Sonnet 5.5 e no Haiku 5.5 [4]. O prompt mínimo para entrar no cache é de 512 tokens nos dois modelos [5].

### Custo por espécie (estimativa a partir do prompt real)

Não fiz chamada real para medir. Contei a partir de `claude-care-guide-writer.ts`:

- Entrada de **~950 tokens**: system prompt (~90) + mensagem do usuário com o nome científico e as instruções (~330) + schema da ferramenta `record_care_guide` (~250) + overhead de tool use (286 [4]).
- Saída de **~600 tokens**: o JSON com nome popular e três dicas de 2 a 4 frases, mais um pouco de raciocínio com `effort: low`. A fixture `claude-care-guide-valid.json` traz `output_tokens: 310`, então 600 é uma folga.
- **Sonnet 5.5:** 950 × 2/1M + 600 × 10/1M ≈ **US$ 0,008 por espécie**.
- **Haiku 5.5:** 950 × 0,10/1M + 600 × 0,50/1M ≈ **US$ 0,0004 por espécie**, cerca de 20 vezes menos.

### Quantas espécies novas por mês (estimativa)

O catálogo nasce com 116 espécies (`api/catalog/catalog-seed.json`). O Pl@ntNet reconhece mais de 50 mil [1], mas plantas de casa se concentram em poucas centenas de espécies. Suposição: 150 espécies novas/mês em A, 400 em B e 1.000 em C, caindo com o tempo, porque cada espécie nova só é paga uma vez. Mesmo que eu tenha errado por 10 vezes, o Claude fica abaixo de US$ 80/mês no cenário C.

Regenerar tudo quando o prompt muda custa cerca de 10.000 espécies × US$ 0,008 = **US$ 80 de uma vez** (estimativa).

### Caching e Batch

- **Prompt caching:** o prefixo fixo (ferramenta + system prompt) passa do mínimo de 512 tokens, mas o cache de 5 minutos só ajuda se duas espécies novas forem geradas em menos de 5 minutos. Mesmo no melhor caso, economizaria menos de US$ 0,001 por espécie. Não vale a complexidade.
- **Batch API:** dá 50% de desconto [4], mas o usuário está esperando na tela. Só serve para regerar o catálogo inteiro depois de uma mudança de prompt.

## AWS (`us-east-1`)

### Lambda e Function URL

- **Fatos:** US$ 0,20 por milhão de requisições. Computação x86 a US$ 0,0000166667/GB-s e Arm a US$ 0,0000133334/GB-s, na primeira faixa [7]. Franquia mensal de 1 milhão de requisições e 400 mil GB-s [6], que continua valendo no plano Paid ("30+ AWS services are always free within monthly usage limits on both the Free and Paid plans" [14]). A página de preços do Lambda não cita cobrança pela Function URL [6]. A dispensa de API Gateway está confirmada no ADR 0004.
- **Estimativa:** 1024 MB em x86. Cada identificação custa 3 GB-s no total, somando o upload com o sharp e a chamada `identify`, que espera ~1,8 s pelo Pl@ntNet (mediana medida em `teste-plantnet.md`) e consulta o GBIF. As demais requisições custam 0,15 GB-s cada. Com Arm, o Lambda fica 20% mais barato.
- **Atenção:** a trava atual de reserved concurrency em 5 (ADR 0004) precisa subir na fase 2, e o ADR pede outra trava no lugar. O Pl@ntNet limita a 20 requisições simultâneas por cliente [2]. No cenário C, a média é inferior a 2 identificações simultâneas mesmo no horário de pico (estimativa), então o limite não aperta.

### Banco Postgres com PostGIS

| Opção | Preço (fato) | Estimativa A / B / C |
|---|---|---|
| **Neon Free** (atual) | 100 CU-hora/projeto/mês, 1 GB, 5 GB de egress; ao estourar, o compute é suspenso [17] | Não serve: com tráfego contínuo, o compute nunca dorme, e 0,25 CU × 730 h = 182 CU-hora já passa dos 100 |
| **Neon Launch** (usado no modelo) | US$ 0,106/CU-hora, US$ 0,35/GB-mês, 500 GB de egress incluídos, sem mínimo [17] | Média de 0,25 / 0,5 / 1 CU e 2 / 8 / 30 GB → **US$ 20 / 41 / 88** |
| RDS PostgreSQL db.t4g.micro / small / medium, Single-AZ | US$ 0,016 / 0,032 / 0,065 por hora [15]; gp3 a US$ 0,115/GB-mês [15]; IPv4 público a US$ 0,005/hora [16] | micro + 20 GB + IPv4 ≈ US$ 17,6. medium + 50 GB + IPv4 ≈ US$ 57 |
| Aurora PostgreSQL Serverless v2 | US$ 0,12/ACU-hora; US$ 0,10/GB-mês [15] | 0,5 ACU fixos ≈ US$ 44 + storage |
| Supabase Pro | A partir de US$ 25/mês com US$ 10 de crédito de compute, 8 GB de disco e 250 GB de egress; US$ 0,125/GB de disco a mais [18] | US$ 25 a 40 |

O RDS sai um pouco mais barato nos cenários B e C, mas com dois custos ocultos de arquitetura. Para o Lambda fora de VPC alcançar o RDS, o banco precisa de IP público. Se o Lambda for para dentro da VPC, precisa de NAT para chamar o Pl@ntNet, o Claude e o Resend, e o NAT não foi orçado aqui. O Neon já está integrado e não tem esse problema. Os dados do banco são pequenos: cada identificação guarda os candidatos em JSON, com ~3 KB por linha (estimativa).

### Fotos: S3 e saída de dados

- **Fatos:** S3 Standard a US$ 0,023/GB-mês nos primeiros 50 TB. PUT a US$ 0,005 por mil e GET a US$ 0,0004 por mil [8]. Saída para a internet a US$ 0,09/GB nos primeiros 10 TB, "beyond the global free tier" [9]. Os primeiros 100 GB/mês são grátis, somando todos os serviços e regiões [10]. Saída do S3 para o CloudFront: US$ 0 [9][10].
- **Estimativa:** foto média de **180 KB** (a mediana medida foi 177 KB a 1600 px, em `teste-plantnet.md`). 1,1 foto guardada por identificação, contando os 10% de fotos de jardim e de anúncios. Cada foto gera 2 PUTs, o upload e a troca de tag, e 1 GET para enviar ao Pl@ntNet. Cada usuário ativo baixa **10 fotos por dia**: o app guarda cache pelo id da foto, mas não existe miniatura, então a lista baixa a foto inteira.
- Armazenamento acumulado no mês 12: **70 GB (A), 348 GB (B), 1,4 TB (C)**.
- A saída inclui as fotos que o Lambda manda ao Pl@ntNet, uma por identificação: 105 GB/mês em C.

### CloudFront

- **Fatos:** a franquia permanente do pay-as-you-go dá 1 TB de saída e 10 milhões de requisições HTTP/HTTPS por mês [11]. Na América do Sul, o excedente custa US$ 0,110/GB e US$ 0,0220 por 10 mil requisições HTTPS [11][13]. Também há planos de preço fixo: Free (US$ 0, 1 milhão de requisições, 100 GB) e Pro (US$ 15, 10 milhões de requisições, 50 TB) [12].
- **No modelo:** o CloudFront fica só na frente da API, como pede o ADR 0004, e cabe na franquia nos três cenários.
- **Alavanca:** servir também as fotos pelo CloudFront, com URL assinada do CloudFront no lugar da do S3. Isso tira a saída do S3 da conta, porque S3 → CloudFront custa US$ 0 e 1 TB de saída é grátis. Em C, a economia é de ~US$ 47 de saída. Como o tráfego passa de 10 milhões de requisições, sobram ~US$ 4 de requisições: **cerca de US$ 43/mês a menos**. Em B, ~US$ 5. Mexe no ADR 0007, que entrega as fotos por URL pré-assinada do S3.

### E-mail

- **Resend (atual, ADR 0001), fatos [19]:** o Free dá 3.000 e-mails/mês, com limite de 100 por dia. O Pro custa US$ 20/mês por 50.000 e-mails, sem limite diário.
- **SES (alternativa na AWS), fato:** US$ 0,0001 por destinatário, ou US$ 0,10 por mil, em `us-east-1` [20].
- **Estimativa:** 0,3 e-mail por usuário ativo no mês (códigos de cadastro e de senha) dá 600 / 3.000 / 12.000 e-mails. O cenário B já encosta nos 100/dia do Resend Free, por isso o modelo usa o Pro em B e C.
- **Alavanca:** trocar pelo SES custaria US$ 0,06 a US$ 1,20/mês em vez de US$ 20.

### CloudWatch Logs

- **Fatos:** a franquia grátis cobre 5 GB de dados de log [21]. A ingestão custa US$ 0,50/GB e o armazenamento US$ 0,03/GB-mês [22].
- **Estimativa:** ~1 KB de log por requisição, contando a linha do `request-logger` e as linhas START/END/REPORT do Lambda. Dá 0,45 / 2,25 / 9 GB por mês. Só C passa da franquia: ~US$ 2. Defina um prazo de retenção nos grupos de log, senão o armazenamento acumula.

## Fixos e únicos

| Item | Valor (fato) | Por mês |
|---|---|---|
| Conta de desenvolvedor do Google Play | US$ 25, pagos uma vez [24] | — |
| Domínio `.br` (como `plantai.ia.br`) | R$ 40,00 por ano [26] | R$ 3,33 |
| Zona hospedada no Route 53 (opcional; o DNS do Registro.br não cobra) | US$ 0,50/mês [23] | US$ 0,50 (já está na tabela) |
| Apple Developer Program (só se houver versão iOS) | US$ 99 por ano [25] | US$ 8,25 |
| Anuidade do Pl@ntNet Pro | € 1.000, pagos na assinatura [3] | Já está no cálculo do Pl@ntNet |
| Certificado ACM para o CloudFront | Não verifiquei a fonte. A documentação da AWS costuma informar certificados públicos do ACM como gratuitos | — |
| GBIF e login com Google (OAuth) | Sem cobrança. Não verifiquei os termos de volume do GBIF | — |

## Premissas dos cenários

Todas as premissas são estimativas minhas e podem ser trocadas no cálculo.

| Premissa | A | B | C |
|---|---|---|---|
| Identificações por dia (por mês) | 1.000 (30 mil) | 5.000 (150 mil) | 20.000 (600 mil) |
| Identificações por usuário ativo por dia (o limite é 10) | 2 | 2 | 2 |
| Usuários ativos por dia (DAU) | 500 | 2.500 | 10.000 |
| Usuários ativos por mês (MAU = 4 × DAU) | 2.000 | 10.000 | 40.000 |
| Chamadas à API por DAU por dia | 30 | 30 | 30 |
| Requisições ao Lambda por mês | 450 mil | 2,25 milhões | 9 milhões |
| Tamanho médio da foto | 180 KB | 180 KB | 180 KB |
| Fotos guardadas por identificação (inclui jardim e anúncios, 1 foto por anúncio) | 1,1 | 1,1 | 1,1 |
| Fotos baixadas por DAU por dia | 10 | 10 | 10 |
| E-mails por mês (códigos de cadastro e senha) | 600 | 3.000 | 12.000 |
| Espécies novas por mês | 150 | 400 | 1.000 |
| Neon: CU médio e storage no mês 12 | 0,25 CU, 2 GB | 0,5 CU, 8 GB | 1 CU, 30 GB |
| Lambda | 1024 MB, x86 | 1024 MB, x86 | 1024 MB, x86 |

## Alavancas para economizar, em ordem de impacto

1. **Pl@ntNet: conseguir o Non-profit ou um acordo.** É o único item de quatro dígitos. Se o Non-profit for aceito, o custo cai para R$ 129, R$ 468 e R$ 1.360 por mês. Vale pedir explicando o projeto, mesmo sem organização, e perguntar por escrito se as 500 identificações grátis por dia são descontadas no Pro.
2. **Reduzir as chamadas ao Pl@ntNet.** Cada chamada custa € 0,005, cerca de R$ 0,03. Algumas formas:
   - baixar o limite de 10 identificações por usuário por dia;
   - mostrar primeiro a busca no catálogo, que não chama o Pl@ntNet;
   - usar o Claude com visão como alternativa: no Haiku 5.5, a pesquisa `api-identificacao.md` estimou ~US$ 0,0006 por foto, contra ~US$ 0,0056 do Pl@ntNet. O teste dessa pesquisa, porém, validou a qualidade do Pl@ntNet, não a do Claude.
   - ficar no Free e cortar em 500 por dia, o que corta o serviço, não o custo.
3. **Fotos pelo CloudFront.** Economiza cerca de US$ 43/mês em C (ver [CloudFront](#cloudfront)).
4. **Política de retenção das fotos de identificação.** Hoje nenhuma é apagada. Algumas opções:
   - apagar as fotos de identificações sem planta salva depois de N dias;
   - mover as antigas para uma classe de armazenamento mais barata (não levantei os preços dessas classes).
5. **Miniaturas para as listas.** Uma versão de ~30 KB corta a maior parte da saída e do tempo de download no app.
6. **Trocar o Resend pelo SES.** Economiza cerca de US$ 20/mês a partir do cenário B.
7. **Lambda em Arm.** Fica 20% mais barato [7], mas só pesa em C, onde economiza ~US$ 9. Antes de trocar, é preciso conferir se o sharp roda na imagem Arm.
8. **Haiku 5.5 para as dicas.** Corta o custo das dicas em ~20 vezes, mas o ganho absoluto é de centavos a poucos dólares. A troca para o Sonnet 5.5 foi uma decisão de qualidade em `api-identificacao.md`, e não vale revertê-la por custo.

## Recomendação

- O custo da fase 2 é, na prática, **o custo do Pl@ntNet**. A infraestrutura da AWS com o Neon fica entre R$ 130 e R$ 1.400 por mês, mesmo com 20 mil identificações por dia. O Claude, graças ao cache por espécie, não chega a R$ 50.
- Antes de abrir ao público, convém:
  1. pedir o Non-profit ao Pl@ntNet e esclarecer por escrito a contagem das 500 grátis por dia no Pro;
  2. definir uma retenção para as fotos de identificação;
  3. pôr as fotos atrás do CloudFront.
- Sem acordo com o Pl@ntNet, um app gratuito com 1.000 identificações por dia custa cerca de **R$ 1.050/mês**, dos quais R$ 920 são do Pl@ntNet. Isso conversa com a [Monetização do PlantAí](https://github.com/angelobez/plantai/issues/13), já que o Pro libera explicitamente o uso comercial [3].

## Fontes

1. Pl@ntNet, preços (lida em 30/10/2026): https://my.plantnet.org/pricing
2. Pl@ntNet, termos de uso da API (lida em 30/10/2026): https://my.plantnet.org/terms_of_use
3. Pl@ntNet / CIRAD, contrato de licença da API v5.1 em EUR, PDF modificado em 03/09/2026, Artigos 5, 10 e 14 (lido em 30/10/2026): https://my.plantnet.org/documents/copyright_licence_PlantNet_API_english_v5.1_EUR.pdf. A versão em USD é a mesma URL com `_USD.pdf`.
4. Anthropic, preços (modelos, cache, Batch, tokens de tool use) (lida em 30/10/2026): https://platform.claude.com/docs/en/about-claude/pricing
5. Anthropic, prompt caching (mínimo cacheável) (lida em 30/10/2026): https://platform.claude.com/docs/en/build-with-claude/prompt-caching
6. AWS Lambda, preços (franquia e exemplos) (lida em 30/10/2026): https://aws.amazon.com/lambda/pricing/
7. AWS Price List API, AWSLambda `us-east-1`, publicada em 22/10/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AWSLambda/current/us-east-1/index.json
8. AWS Price List API, AmazonS3 `us-east-1`, publicada em 15/10/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/us-east-1/index.json
9. AWS Price List API, AWSDataTransfer `us-east-1`, publicada em 16/09/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AWSDataTransfer/current/us-east-1/index.json
10. Amazon S3, preços (100 GB de saída grátis somando todos os serviços; S3 → CloudFront grátis) (lida em 30/10/2026): https://aws.amazon.com/s3/pricing/
11. Amazon CloudFront, preços pay-as-you-go (franquia permanente e América do Sul) (lida em 30/10/2026): https://aws.amazon.com/cloudfront/pricing/pay-as-you-go
12. Amazon CloudFront, planos de preço fixo (lida em 30/10/2026): https://aws.amazon.com/cloudfront/pricing/
13. AWS Price List API, AmazonCloudFront (global), publicada em 19/10/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonCloudFront/current/index.json
14. AWS Free Tier (lida em 30/10/2026): https://aws.amazon.com/free/
15. AWS Price List API, AmazonRDS `us-east-1`, publicada em 29/10/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRDS/current/us-east-1/index.json
16. AWS Price List API, AmazonVPC `us-east-1` (IPv4 público), publicada em 16/10/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonVPC/current/us-east-1/index.json
17. Neon, preços (lida em 30/10/2026): https://neon.com/pricing
18. Supabase, preços (lida em 30/10/2026): https://supabase.com/pricing
19. Resend, preços (lida em 30/10/2026): https://resend.com/pricing
20. AWS Price List API, AmazonSES `us-east-1`, publicada em 27/10/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonSES/current/us-east-1/index.json
21. Amazon CloudWatch, preços (franquia grátis) (lida em 30/10/2026): https://aws.amazon.com/cloudwatch/pricing/
22. AWS Price List API, AmazonCloudWatch `us-east-1`, publicada em 07/10/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonCloudWatch/current/us-east-1/index.json
23. AWS Price List API, AmazonRoute53 (global), publicada em 11/09/2026 (lida em 30/10/2026): https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRoute53/current/index.json
24. Google Play Console, taxa de registro (lida em 30/10/2026): https://support.google.com/googleplay/android-developer/answer/6112435?hl=en
25. Apple Developer Program (lida em 30/10/2026): https://developer.apple.com/programs/
26. Registro.br, valores (lida em 30/10/2026): https://registro.br/dominio/valores/
27. Banco Central do Brasil, PTAX de 30/10/2026, boletim de fechamento (lida em 30/10/2026): https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/
