# As fotos passam pela API, e o telefone do doador só sai pelo Interesse

As fotos sobem pela própria API (`POST /v1/photos`), e não direto para o S3 por URL pré-assinada. Assim a API remove o EXIF, inclusive o GPS, antes de gravar. Uma foto de anúncio com o GPS original mostraria o endereço exato do doador e anularia o arredondamento da localização de doação ([ADR 0002](0002-localizacao-de-doacao-arredondada-antes-de-salvar.md)). Confiar no app para limpar a foto seria frágil. As fotos ficam num bucket privado e são entregues por URL pré-assinada com validade de 1 hora, sem bucket público.

Pelo mesmo motivo, o telefone do doador nunca aparece na lista nem no detalhe do anúncio. Ele só sai na resposta que registra o Interesse, já como o link `wa.me` pronto. Quem quiser o telefone precisa passar pelo Interesse, que fica registrado e entra na contagem que o doador vê.

## Considered Options

- **Upload direto para o S3 com URL pré-assinada:** evita o limite de 6 MB do Lambda e a imagem passando pela função, mas deixa a remoção do EXIF para o app ou para um gatilho do S3.
- **Fotos públicas via CloudFront com chaves UUID:** cache mais simples no app, mas as fotos do jardim ficariam abertas para quem tivesse o link, e a entrega dependeria do CloudFront estar pronto.

## Consequences

- O app precisa reduzir a foto (cerca de 1600 px, menos de 1 MB) antes de enviar, por causa do teto de 6 MB da Function URL.
- As URLs das fotos mudam a cada resposta. O app usa o id da foto como chave de cache, não a URL.
- Nenhum endpoint novo pode devolver o telefone do doador fora do registro de Interesse.
