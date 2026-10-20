# A localização de doação é arredondada antes de chegar ao banco

A API nunca guarda o ponto exato de quem doa. Antes de salvar, o ponto é encaixado numa grade de cerca de 1 km e só o centro da célula vai para o banco. A distância que o app mostra sai desse centro e também é arredondada. O endereço exato só é combinado no WhatsApp. Escolhemos assim porque arredondar só a distância na tela não protege: quem consulta de três lugares diferentes e cruza as distâncias acha a casa do doador (trilateração). Um ataque não recupera o que nunca foi guardado.

## Considered Options

- **Guardar o ponto exato e arredondar só a distância exibida:** é o caminho óbvio, mas permite a trilateração.
- **Guardar só o bairro e usar o centro dele:** depende de geocodificar o bairro, e o tamanho de um bairro varia muito.
- **Somar um deslocamento aleatório ao ponto:** o ponto muda de um anúncio para outro, e várias consultas permitem tirar a média do ruído.

## Consequences

- A distância é imprecisa de propósito, em cerca de 1 km. Não "corrija" isso guardando o ponto exato.
- Os anúncios de quem mora na mesma célula ficam no mesmo ponto. Por isso o MVP não tem mapa: o pino cairia no centro da célula e confundiria.
- Como o ponto exato nunca foi guardado, deixar a localização mais precisa depois exigiria pedir de novo a localização de cada doador.
- Células de cerca de 500 m ficariam precisas demais em bairro com poucas casas; células de 2 km deixariam a distância sem sentido.
