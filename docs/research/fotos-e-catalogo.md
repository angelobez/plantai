# Pesquisa: fotos de referência e catálogo de espécies

Ticket: [#8](https://github.com/angelobez/plantai/issues/8). Pesquisa feita em 20/10/2026 nas fontes primárias (documentação, swagger e termos de uso), com algumas chamadas de teste às APIs. **[não confirmado]** marca o que não deu para verificar.

> **Decisão (20/10/2026, ver a [resolução no ticket](https://github.com/angelobez/plantai/issues/8)).**
> - **Fotos dos candidatos:** vêm do próprio Pl@ntNet (`include-related-images`). O app as exibe pela URL deles, sem copiar, com o crédito embaixo.
> - **Semente do Catálogo:** ~100 espécies. Os nomes científicos são validados no GBIF, os nomes populares vêm da Flora e Funga do Brasil (com o GBIF de reserva), as fotos vêm do Wikimedia Commons e são copiadas para o S3 com o crédito, e as dicas são geradas pela API real.
> - **Créditos:** existe uma tela "Sobre e créditos".

## Pergunta

De onde vêm as fotos de referência dos candidatos e do Catálogo, com licença compatível com o app (inclusive se ele for monetizado), e como validar nomes científicos e obter nomes populares em português para pré-popular o Catálogo?

## 1. Fotos dos candidatos (Pl@ntNet)

- `/v2/identify/{project}` aceita `include-related-images=true` (o padrão é `false`). Com ele, cada item de `results[]` traz `images[]`. Fontes: [swagger](https://my-api.plantnet.org/swagger.json) e [doc identify](https://my.plantnet.org/doc/api/identify).
- Cada imagem tem `organ`, `author`, `license`, `citation`, `date` e `url {o, m, s}` (original, média e pequena). As dimensões de cada tamanho não estão documentadas **[não confirmado]**.
- Licença: "Images shared on Pl@ntNet are usually licensed under CC BY-SA". O crédito pedido é "Photo(s): [autor] / Pl@ntNet, CC BY-SA". Como diz "usually", é preciso ler o campo `license` de cada imagem. Fonte: [Using images](https://my.plantnet.org/doc/references/using-images).
- Os [termos de uso](https://my.plantnet.org/terms_of_use) proíbem copiar ou republicar "elementos da aplicação Pl@ntNet" sem autorização escrita, e sugerem uma frase de crédito para o uso gratuito ("The image-based plant species identification service used, is based on the Pl@ntNet recognition API…").
- Nenhuma página trata de cache nem de copiar a imagem para um storage próprio **[não confirmado]**. A licença CC BY-SA permitiria a cópia, mas a cláusula genérica dos termos deixa dúvida. Por isso o app exibe pela URL e guarda só a URL e os metadados.
- A ShareAlike só vale para obras adaptadas. Só exibir a foto exige atribuição e link para a licença ([deed CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.en)).

## 2. Listar espécies no Pl@ntNet

- `GET /v2/species` e `GET /v2/projects/{project}/species` aceitam `lang` (inclusive `pt`), `pageSize`, `page` e `prefix`. Devolvem `scientificNameWithoutAuthor`, `commonNames[]`, `gbifId`, `powoId`, `family` e `genus`.
- As imagens desses endpoints são "pro plan only": no plano grátis, a lista vem sem fotos.
- `/v2/species/byCommonName/{name}` é `[private]`, então a busca por nome popular precisa ser nossa.
- Não está documentado se `/species` consome a cota de 500/dia de `identify` **[não confirmado]**. As cotas são por tipo de requisição ([quota](https://my.plantnet.org/doc/api/quota)), e dá para checar com `GET /v2/quota/daily`.

## 3. Fotos para a semente do Catálogo

| Fonte | Como buscar | Licenças encontradas | Serve? |
|---|---|---|---|
| Wikimedia Commons / Wikidata | Nome científico → item do Wikidata (P225) → imagem P18 → `imageinfo` com `extmetadata` (`LicenseShortName`, `Artist`, `LicenseUrl`) na [API do Commons](https://commons.wikimedia.org/w/api.php) | Só licenças livres: CC0, CC BY, CC BY-SA e domínio público. NC não é aceito ([Commons:Licensing](https://commons.wikimedia.org/wiki/Commons:Licensing)) | Sim, é a fonte principal |
| iNaturalist | `GET https://api.inaturalist.org/v1/taxa?q=…&rank=species&locale=pt-BR` → `default_photo` com `license_code` e `attribution` | Mistura CC0, CC BY, CC BY-NC e "all rights reserved". Na jiboia, a foto padrão é "all rights reserved" e 6 de 9 eram NC | Só como reserva, filtrando `cc0`, `cc-by` e `cc-by-sa` |
| GBIF (ocorrências) | `GET https://api.gbif.org/v1/occurrence/search?taxonKey=…&mediaType=StillImage&license=…` | Na jiboia, as 25 imagens eram CC BY-NC (vêm do iNaturalist) | Não |

Teste: *Epipremnum aureum* = Wikidata Q161809, P18 "Epipremnum aureum 31082012.jpg". O campo `Artist` vem em HTML e precisa ser limpo.

O que cada licença exige: CC0 não exige nada. CC BY exige autor, link da licença e aviso de alteração. CC BY-SA exige o mesmo, e a obra adaptada precisa sair na mesma licença. CC BY-NC proíbe uso "primarily intended for commercial advantage" e viraria dívida se o app for monetizado ([Monetização do PlantAí](https://github.com/angelobez/plantai/issues/13)).

Os limites da API do iNaturalist (cerca de 60 req/min e menos de 10 mil/dia) vêm de relatos em fórum **[não confirmado]**. A [página oficial](https://www.inaturalist.org/pages/api+recommended+practices) ficou bloqueada pela Cloudflare.

## 4. Validar nomes e obter nomes populares em português

- **GBIF:** `GET https://api.gbif.org/v1/species/match?name=…` devolve `usageKey`, `status` e, quando o nome é sinônimo, `acceptedUsageKey`. Exemplo: *Sansevieria trifasciata* volta como SYNONYM de *Dracaena trifasciata* (11041822). Existe também a `/v2/species/match` (blocos `usage` e `acceptedUsage`). Se a v1 está depreciada é **[não confirmado]**. Nomes populares: `GET /v1/species/{key}/vernacularNames`, filtrando `language == "por"`.
- **Flora e Funga do Brasil (JBRJ):** `GET https://servicos.jbrj.gov.br/v2/flora/taxon/{nome científico}` devolve `taxonomicstatus` e `vernacular_name[]` em português ([índice](https://servicos.jbrj.gov.br/v2/)). O download completo em DwC-A, com nomes vernáculos e licença CC BY 4.0, está no [IPT do JBRJ](https://ipt.jbrj.gov.br/jbrj/archive.do?r=lista_especies_flora_brasil). A Flora só cobre espécies que ocorrem no Brasil, e ornamentais exóticas podem faltar **[não confirmado em escala]**.

## Fontes

- Pl@ntNet: https://my-api.plantnet.org/swagger.json, https://my.plantnet.org/doc/api/identify, https://my.plantnet.org/doc/references/using-images, https://my.plantnet.org/terms_of_use, https://my.plantnet.org/doc/api/quota
- Creative Commons: https://creativecommons.org/licenses/by-sa/4.0/deed.en
- Wikimedia: https://commons.wikimedia.org/wiki/Commons:Licensing, https://commons.wikimedia.org/w/api.php
- iNaturalist: https://api.inaturalist.org/v1/, https://www.inaturalist.org/pages/api+recommended+practices
- GBIF: https://api.gbif.org/v1/species/match, https://www.gbif.org/dataset/aacd816d-662c-49d2-ad1a-97e66e2a2908
- Flora e Funga do Brasil: https://servicos.jbrj.gov.br/v2/, https://ipt.jbrj.gov.br/jbrj/archive.do?r=lista_especies_flora_brasil
