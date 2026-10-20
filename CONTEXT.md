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
O registro de uma tentativa de reconhecer uma planta pela foto: a foto, os candidatos sugeridos e a espécie confirmada, se houver.
_Avoid_: Scan, consulta, reconhecimento

**Dicas de cuidado**:
Orientações sobre rega, luz e como fazer muda de uma espécie, geradas por IA e reaproveitadas entre usuários.
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
