# A API roda no AWS Lambda com Function URL, as fotos no S3 e o banco no Neon

A API NestJS roda no AWS Lambda, exposta por uma Function URL (sem API Gateway), em `us-east-1`. As fotos ficam no S3 e o Postgres com PostGIS fica no Neon Free (`aws-us-east-1`). A [pesquisa de hospedagem](../research/hospedagem.md) recomendava Cloud Run + Cloud Storage no GCP, com custo zero em franquias permanentes; o Ângelo preferiu a AWS. O Lambda também tem franquia permanente (1 milhão de requisições e 400 mil GB-s por mês), e o S3 custa centavos depois dos créditos. O RDS ficou de fora porque não tem franquia permanente (cerca de US$ 12 a 15/mês).

## Considered Options

- **Cloud Run + Cloud Storage (GCP):** a recomendação da pesquisa. Roda o NestJS como um container comum, sem adaptador. Foi preterido por preferência pela AWS, não por custo.
- **Lambda atrás de API Gateway:** acrescenta custo e configuração que a Function URL dispensa no MVP.

## Consequences

- A API é escrita para rodar como função: o NestJS entra por um handler de Lambda e não por um servidor HTTP escutando numa porta. Voltar para um container (Cloud Run, ECS) é possível, mas mexe na entrada da aplicação e no deploy.
- Limites do Lambda moldam o contrato da API: o corpo da requisição síncrona tem teto de 6 MB, e cada instância abre a própria conexão com o Postgres, então a conexão com o Neon passa pelo pooler dele.
- A conta AWS é Paid, e o Budgets só alerta (US$ 1 e US$ 5). A trava de gasto é a reserved concurrency de 5 execuções simultâneas no Lambda. Não remova essa trava sem pôr outra no lugar.
- O projeto no Google Cloud continua existindo só para a credencial OAuth do login com Google ([ADR 0001](0001-autenticacao-propria-uma-conta-por-email.md)), sem faturamento.
