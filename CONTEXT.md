# PlantAí

App em que vizinhos identificam plantas com IA, cuidam delas no seu jardim e doam mudas uns para os outros.

## Pessoas

**Usuário**:
Qualquer pessoa com conta no PlantAí. Todo usuário pode identificar, ter um jardim, doar e demonstrar interesse.
_Avoid_: Cliente, conta, membro

**Doador**:
O papel do usuário que criou um anúncio, em relação a esse anúncio. Não é um tipo de conta.
_Avoid_: Anunciante, vendedor

## Plantas

**Espécie**:
Um tipo de planta, identificado pelo nome científico, com um ou mais nomes populares.
_Avoid_: Tipo, variedade

**Identificação**:
O registro de uma tentativa de reconhecer uma planta pela foto: a foto, os candidatos sugeridos e a espécie que o usuário escolheu entre eles, se escolheu. Quem confirma a espécie é sempre o usuário; se ele marca "nenhuma destas", a planta fica só com o nome popular.
_Avoid_: Scan, consulta, reconhecimento

**Candidato**:
Uma espécie sugerida para a foto de uma identificação, mostrada com fotos de referência, nome popular e nome científico, para o usuário comparar com a planta dele.
_Avoid_: Resultado, palpite, sugestão

**Dicas de cuidado**:
Orientações sobre rega, luz e como fazer muda de uma espécie, junto com o nome popular brasileiro dela. São geradas por IA uma única vez por espécie e as mesmas valem para todos os usuários.
_Avoid_: Plano de cuidados, guia

**Planta**:
Um exemplar que um usuário tem e guarda no seu jardim. Tem nome popular obrigatório e espécie opcional; sem espécie, não tem dicas de cuidado.
_Avoid_: Item, planta salva

**Meu jardim**:
A coleção de plantas de um usuário.
_Avoid_: Coleção, galeria

**Muda**:
Uma planta jovem, fisicamente separada para ser doada.
_Avoid_: Broto, filhote

## Doação

**Anúncio**:
A oferta de doação de uma quantidade de mudas de uma mesma espécie, feita por um doador. Tem nome popular obrigatório e espécie opcional, e pode nascer de uma planta do jardim ou ser criado direto.
_Avoid_: Post, oferta, doação (para o anúncio em si)

**Interesse**:
O registro de que um usuário quer mudas de um anúncio. É o que leva a conversa para o WhatsApp do doador.
_Avoid_: Pedido, reserva, match

**Situação do anúncio**:
Um anúncio está **Ativo** (visível e com mudas disponíveis), **Doado** (quantidade chegou a zero) ou **Encerrado** (o doador desistiu, ou o anúncio expirou após 30 dias sem renovação).
_Avoid_: Status (no texto para pessoas), pausado, vendido

## Localização

**Localização de doação**:
O lugar aproximado de onde um usuário doa, definido uma vez no perfil. Cada anúncio guarda uma cópia da localização de doação do momento em que foi criado. Nunca é o endereço exato: o endereço só é combinado no WhatsApp.
_Avoid_: Endereço, localização do anúncio, ponto

**Bairro**:
O nome do bairro da localização de doação, mostrado em cada anúncio. O app sugere e o doador pode corrigir.
_Avoid_: Região, área, endereço

**Distância aproximada**:
A distância arredondada entre quem procura e um anúncio, como "menos de 1 km" ou "a cerca de 2 km". É a única noção de distância que um usuário vê.
_Avoid_: Distância exata, raio

**Mudas por perto**:
A lista de anúncios ativos de até 30 km de quem procura, do mais perto para o mais longe. A localização de quem procura não fica guardada.
_Avoid_: Feed, vitrine, busca por raio
