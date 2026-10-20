# Pesquisa: hospedagem barata para o MVP

Ticket: [#7](https://github.com/angelobez/plantai/issues/7). Pesquisa feita em 20/10/2026 nas páginas oficiais de preço e documentação. Preços e planos grátis mudam com frequência, então confira de novo antes de criar as contas.

> **Decisão (20/10/2026, ver a [resolução no ticket](https://github.com/angelobez/plantai/issues/7)).** A escolha final **diverge da recomendação desta pesquisa**: em vez de Cloud Run + Cloud Storage no GCP, fica a **AWS, por preferência do Ângelo**. A API NestJS roda no **AWS Lambda com Function URL** (sem API Gateway), as fotos ficam no **S3** e o banco continua no **Neon Free** (`aws-us-east-1`, PostGIS). Tudo nos EUA: AWS `us-east-1`, junto do Neon. A conta AWS é aberta no **plano Paid** (os créditos são gastos primeiro; o Free fecharia a conta em 6 meses), com alertas de orçamento em US$ 1 e US$ 5 e **reserved concurrency de 5** no Lambda como trava. O projeto no Google Cloud fica só para a credencial OAuth do login com Google, sem faturamento. O cold start é aceito, com estado "carregando" no app; manter a API "quente" (pago) só na semana de apresentar, se precisar. O domínio fica para depois: até lá, a API usa o endereço da Function URL e o Resend fica no modo de teste. Ver o [ADR 0004](../adr/0004-api-no-aws-lambda-com-function-url.md).
>
> Fatos da AWS levantados em 20/10/2026 para a decisão (não estão no corpo da pesquisa):
> - Desde 15/07/2025, conta AWS nova escolhe o plano Free ou o Paid, ambos com US$ 100 de créditos (até US$ 200 com atividades de onboarding). No Free, "The account closes on its own 6 months after you open it or when your credits run out, whichever comes first." O Paid cobra o que passar dos créditos. Fonte: https://aws.amazon.com/free/
> - O Lambda tem franquia grátis permanente de 1 milhão de requisições e 400 mil GB-s por mês (fonte secundária: https://infratally.com/articles/aws-free-tier-2026/). A Function URL não custa nada além do Lambda.
> - O S3 não tem franquia grátis permanente confirmada para contas novas: fica coberto pelos créditos e depois custa cerca de US$ 0,023/GB-mês, centavos para o MVP. O RDS também não tem franquia permanente (cerca de US$ 12 a 15/mês depois dos créditos), por isso o banco fica no Neon.
> - O AWS Budgets só alerta, não corta o gasto. Daí a reserved concurrency como trava.

## Pergunta

Onde hospedar a API NestJS, o PostgreSQL com PostGIS e as fotos com custo perto de zero até o fim do MVP (15/11/2026), deixando um link público no ar por meses sem custo surpresa?

## Resumo

| Peça | Recomendação | Custo esperado | Alternativa |
|---|---|---|---|
| API NestJS | Google Cloud Run (cobrança por requisição, `min-instances=0`) | US$ 0 dentro do Free Tier | Render Free (dorme e acorda em cerca de 1 min) |
| Postgres + PostGIS | Neon Free | US$ 0 | Supabase Free (pausa após 1 semana sem uso) |
| Fotos | Google Cloud Storage em região dos EUA (Free Tier de 5 GB) | US$ 0 | Cloudflare R2 (10 GB grátis, egress zero) |
| Deploy | GitHub Actions + Workload Identity Federation + `gcloud run deploy` | US$ 0 | Cloud Build (2.500 min/mês grátis) |

Railway, Fly.io e Cloud SQL não servem para "custo perto de zero por meses": Railway tem só US$ 1/mês de crédito depois do trial, Fly.io não tem plano grátis para contas novas e o Postgres gerenciado começa em US$ 38/mês, e Cloud SQL não tem Free Tier.

## Comparação: API (container NestJS)

| Opção | Plano grátis | Cold start | Quando o grátis acaba |
|---|---|---|---|
| **Google Cloud Run** | Free Tier mensal por conta de faturamento: 180.000 vCPU-s, 360.000 GiB-s e 2 milhões de requisições (cobrança por requisição) [1]; 1 GB de saída da América do Norte [2] | Escala a zero; a primeira requisição espera o container subir [3]. Dá para reduzir com *startup CPU boost* ou `min-instances=1` (pago) [3] | Passou do Free Tier, cobra por uso: US$ 0,000024 por vCPU-s ativo (Tier 1) [1]. Orçamento só alerta, não corta gasto [4] |
| **Render** | Web service Free: 0,1 CPU, 512 MB, 750 horas/mês por workspace [5][6] | Dorme após 15 min sem tráfego; acordar leva "about one minute" [5] | Acabaram as horas: todos os serviços Free ficam suspensos até o mês seguinte [5]. Starter custa US$ 7/mês [6] |
| **Railway** | Trial de US$ 5, válido 30 dias; depois plano Free com US$ 1/mês de crédito, 0,5 GB de RAM por serviço [7][8] | Sem *sleep* documentado para serviços comuns | Volumes do trial são apagados 30 dias após o fim do crédito [8]. Hobby: US$ 5/mês [7] |
| **Fly.io** | Nenhum: "New organizations don't have a free tier or a monthly free usage allowance"; trial de 2 h de máquina ou 7 dias [9] | Máquinas podem parar e voltar | Máquina shared-cpu-1x 256 MB: US$ 2,19/mês [9] |

Conta rápida do Cloud Run: 180.000 vCPU-s equivalem a 50 horas de CPU de 1 vCPU *processando requisições*. Na cobrança por requisição, CPU só é cobrada enquanto a requisição está sendo atendida [1]. Um MVP com poucos usuários fica muito abaixo disso.

## Comparação: PostgreSQL com PostGIS

| Opção | Plano grátis | PostGIS | Pausa e cold start | Quando o limite estoura |
|---|---|---|---|---|
| **Neon Free** | 1 GB por projeto, 100 CU-horas por projeto/mês, 5 GB de egress, até 100 projetos [10][11] | Sim, `CREATE EXTENSION postgis` em qualquer projeto [12] | Suspende após 5 min sem uso (não dá para desligar); volta "within a few hundred milliseconds" [11][13] | Compute pausa até o próximo ciclo; storage cheio bloqueia escrita; "None of these limits delete your data" [10]. Launch: US$ 0,106/CU-hora + US$ 0,35/GB-mês, sem mínimo [10] |
| **Supabase Free** | 500 MB de banco, 1 GB de arquivos, 5 GB de egress, 2 projetos ativos [14] | Sim, instalar no schema `extensions` [15] | "Free projects are paused after 1 week of inactivity" [14] | Pro: a partir de US$ 25/mês [14] |
| **Render Postgres Free** | 1 GB, 256 MB de RAM [5][6] | Sim no Postgres 13+ (a página não fala do plano Free) [16] | — | Expira 30 dias após a criação; apagado depois de mais 14 dias [5]. Pago: a partir de US$ 6/mês [6] |
| **Cloud SQL** | Sem Free Tier; só trial de 30 dias [2] | Sim | — | Instância paga desde o primeiro dia depois do trial |
| **Fly.io Managed Postgres** | Nenhum | — | — | Basic: US$ 38/mês + US$ 0,28/GB [9] |

Neon tem região em São Paulo (`aws-sa-east-1`) e nos EUA (`aws-us-east-1`, `aws-us-east-2`) [17]. A mesma página avisa que, desde 05/10/2026, projetos do plano Free inativos por 90 dias ou mais podem ser apagados [17]. O texto aparece junto da descontinuação das regiões Azure e não define "inativo", mas convém tratar como regra geral: um *ping* semanal (GitHub Actions agendado ou Cloud Scheduler) mantém o projeto ativo.

## Comparação: fotos (object storage)

| Opção | Grátis por mês | Depois do grátis | Observação |
|---|---|---|---|
| **Google Cloud Storage** | 5 GB-mês de storage regional (só `us-east1`, `us-west1`, `us-central1`), 5.000 operações Classe A, 50.000 Classe B, 100 GB de saída da América do Norte [2] | Cobrança por uso | Mesma conta e IAM do Cloud Run; URL assinada com a service account da API |
| **Cloudflare R2** | 10 GB-mês, 1 milhão de Classe A, 10 milhões de Classe B, egress grátis [18] | US$ 0,015/GB-mês; US$ 4,50 por milhão de Classe A [18] | API compatível com S3; mais uma conta e mais segredos para gerenciar |
| **Supabase Storage** | 1 GB, upload de até 50 MB [14] | Pro US$ 25/mês | Só faz sentido se o banco também for Supabase |
| **AWS S3** | Contas novas: até US$ 200 em créditos por 6 meses; no plano Free, "The account closes on its own 6 months after you open it or when your credits run out" [19] | Plano pago | Não há franquia fixa de S3 informada na página [19] |

Com foto comprimida no app (cerca de 200 KB), 5 GB guardam umas 25 mil fotos. As 5.000 operações Classe A do GCS (uploads) são o limite mais apertado, mas ainda estão muito acima do uso de um MVP de portfólio.

## O que acontece quando o crédito ou o plano grátis acaba

- **Google Cloud**: o trial dá US$ 300 por 90 dias e não cobra nada sozinho. Se você não fizer upgrade, ao fim do trial os recursos param e são apagados depois de 30 dias [2]. Para o app ficar no ar por meses, é preciso passar a conta para paga. O Free Tier continua valendo depois do upgrade [2], mas um orçamento "doesn't automatically cap ... usage or spending" [4]. Para evitar surpresa: alerta de orçamento em US$ 1–5, `max-instances` baixo no Cloud Run e, se quiser um corte automático, uma notificação de orçamento no Pub/Sub que desliga o faturamento do projeto [4].
- **Neon**: nunca cobra no Free. Estourou, o compute pausa ou a escrita é bloqueada, sem perder dados [10]. Risco: o projeto ser apagado após 90 dias inativo [17].
- **Supabase**: o projeto pausa após 1 semana sem uso [14]. Para um link de portfólio que alguém abre de vez em quando, é o pior cenário.
- **Render**: o banco Free some em 30 + 14 dias [5]. Não serve para "meses no ar".
- **Railway**: depois do trial, US$ 1/mês não roda uma API mais um Postgres; volumes do trial são apagados [8].
- **AWS**: no plano Free, a conta fecha sozinha em 6 meses ou quando os créditos acabam [19].

## Facilidade de deploy

- **Cloud Run**: deploy a partir de uma imagem Docker; GitHub Actions com `google-github-actions/auth` (Workload Identity Federation, sem chave JSON no repositório) e `gcloud run deploy`. Cloud Build tem 2.500 min/mês grátis e Artifact Registry 0,5 GB grátis [2]. Configure uma política de limpeza no Artifact Registry para não passar de 0,5 GB com imagens antigas.
- **Render e Railway**: conectam no GitHub e fazem deploy a cada push, com Dockerfile ou buildpack. São os mais simples, mas os planos grátis não atendem (veja acima).
- **Neon**: só uma connection string em segredo (Secret Manager tem 6 versões de segredo grátis [2]). O pooler do Neon ajuda com as conexões que surgem quando o Cloud Run escala.

## Cold start somado

No pior caso (API parada e banco suspenso), a primeira requisição paga o boot do NestJS no Cloud Run mais a volta do Neon, que leva "a few hundred milliseconds" [13]. Na prática, alguns segundos na primeira chamada depois de um tempo parado; as seguintes ficam normais. Para reduzir: *startup CPU boost* [3], evitar carregar módulos pesados no boot e mostrar um estado de "carregando" no app. `min-instances=1` elimina o cold start da API, mas cobra o tempo ocioso (US$ 0,0000025 por vCPU-s ocioso, Tier 1 [1], mais memória). Dá para ligar só na semana da demonstração.

## Região

O Free Tier do GCS só vale em `us-east1`, `us-west1` e `us-central1` [2]. O do Cloud Run é aplicado como desconto calculado no preço de `us-central1` [1]. Por isso, a sugestão é colocar tudo nos EUA: Cloud Run e bucket em `us-east1` e Neon em `aws-us-east-1` (Virgínia). Banco e API ficam perto um do outro. A latência Brasil–EUA (cerca de 120–150 ms) é aceitável para o MVP. Colocar o Neon em São Paulo e a API nos EUA seria pior, porque cada consulta atravessaria o continente.

## Recomendação

**Cloud Run (API) + Neon Free (Postgres/PostGIS) + Cloud Storage (fotos), com deploy por GitHub Actions.**

Motivos:
1. Custo zero real com o tráfego de um MVP: os três ficam dentro de franquias mensais permanentes, não de créditos que vencem.
2. PostGIS funciona no Neon sem restrição de plano [12], e o Neon não apaga dados ao estourar limites [10].
3. Escala a zero nas duas pontas. O cold start é de segundos, contra cerca de 1 minuto no Render.
4. Currículo: Cloud Run, GCS, Secret Manager, Workload Identity Federation e alertas de orçamento via Pub/Sub são o stack que o Ângelo já usa no trabalho, agora mostrado num projeto público. Neon acrescenta Postgres serverless.
5. Saída fácil: se o Neon apertar, o mesmo `DATABASE_URL` aponta para o plano Launch (pago por uso) ou para Cloud SQL sem mudar código.

Proteções obrigatórias: conta de faturamento com alerta de orçamento, `max-instances` de 2 a 3, política de limpeza no Artifact Registry e um *ping* semanal no Neon.

Alternativa para as fotos: **Cloudflare R2**, se o desenvolvedor preferir egress zero e o dobro de espaço. Custa mais uma conta e um par de chaves S3 para guardar.

## Perguntas para o humano decidir

1. Você já tem uma conta GCP pessoal com faturamento pago, ou vai abrir um trial novo? O trial para os recursos ao fim de 90 dias se não houver upgrade.
2. Aceita cadastrar cartão e passar a conta para paga, confiando em alerta de orçamento, `max-instances` e corte automático via Pub/Sub, para o app ficar no ar depois do trial?
3. Fotos no GCS (tudo no GCP, 5 GB) ou no R2 (10 GB, egress zero, outra conta)?
4. Região nos EUA (Free Tier do GCS, latência de cerca de 150 ms) ou São Paulo (menor latência, mas sem Free Tier de storage e com preço mais alto)?
5. Um cold start de alguns segundos na primeira chamada é aceitável na demo, ou vale pagar `min-instances=1` em períodos de apresentação?
6. Domínio próprio ou a URL `*.run.app` basta para o portfólio?

## Fontes

1. Cloud Run pricing — https://cloud.google.com/run/pricing
2. Google Cloud Free Program (trial e Free Tier) — https://docs.cloud.google.com/free/docs/free-cloud-features
3. Cloud Run general development tips (startup, min instances, CPU boost) — https://docs.cloud.google.com/run/docs/tips/general
4. Cloud Billing budgets — https://docs.cloud.google.com/billing/docs/how-to/budgets
5. Render free instances — https://render.com/docs/free
6. Render pricing — https://render.com/pricing
7. Railway pricing — https://railway.com/pricing
8. Railway free trial — https://docs.railway.com/reference/pricing/free-trial
9. Fly.io pricing — https://docs.fly.io/about/pricing
10. Neon pricing — https://neon.com/pricing
11. Neon plans — https://neon.com/docs/introduction/plans
12. Neon PostGIS extension — https://neon.com/docs/extensions/postgis
13. Neon scale to zero — https://neon.com/docs/introduction/scale-to-zero
14. Supabase pricing — https://supabase.com/pricing
15. Supabase PostGIS — https://supabase.com/docs/guides/database/extensions/postgis
16. Render Postgres extensions — https://render.com/docs/postgresql-extensions
17. Neon regions — https://neon.com/docs/introduction/regions
18. Cloudflare R2 pricing — https://developers.cloudflare.com/r2/pricing/
19. AWS Free Tier — https://aws.amazon.com/free/
