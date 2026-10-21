# Teste do Pl@ntNet com plantas comuns em casas brasileiras

Ticket: [Teste do Pl@ntNet com fotos de plantas brasileiras](https://github.com/angelobez/plantai/issues/14). Rodado em 2026-10-20.

## Como foi feito

- No lugar das fotos tiradas em casa, usei 60 fotos do iNaturalist: 20 espécies comuns em casa, 3 fotos de cada, tiradas no Brasil (place 6878), cada uma de um observador diferente.
- As observações foram criadas entre 02/2026 e 10/2026, a maioria depois de 01/08/2026. São 35 research grade e 25 casual; 24 estão marcadas como cultivadas.
- Só entrou observação em que a comunidade confirmou a espécie.
- Chamada: `POST /v2/identify/all`, `lang=pt`, `nb-results=3`, `organs=auto`. Cada foto foi reduzida para 1600 px antes do envio (mediana de 177 KB).
- Script, fotos, fontes e `resultado.json` ficaram fora do repo, em `~/plantai-teste-plantnet/`.

## Números

- **Top 3: 93,3% (56/60).** Top 1: 68,3% (41/60). Nenhuma foto rejeitada. No top 3, o gênero certo apareceu em 60/60.
- Quase todo erro de top 1 é uma espécie irmã, com cuidados parecidos: *Epipremnum pinnatum* no lugar da jiboia, *Ocimum americanum* no lugar do manjericão, *Mentha × rotundifolia* no lugar da hortelã.
- A samambaia (*Nephrolepis exaltata*) errou as 3 fotos, sempre com outra *Nephrolepis* no lugar. Separar essas espécies é difícil, então o rótulo do próprio iNaturalist pode estar errado. A peperômia acertou 2 de 3 no top 3. As outras 18 espécies acertaram 3 de 3.
- Latência: mediana de 1,8 s, p90 de 2,4 s, máximo de 3,2 s.

## Nomes populares em `pt`

- O top 1 veio com nome em `pt` em 97% das fotos. Os nomes são os usados no Brasil: Jiboia, Espada-de-são-jorge, Língua-de-sogra, Zamioculca, Comigo-ninguém-pode, Boldo-de-jardim, Barriga-de-sapo.
- **Não dá para mostrar o `commonNames` sem tratamento.** Três problemas:
  - o primeiro hífen às vezes vira espaço ("Costela de-adão", "Espada de-são-jorge");
  - há texto colaborativo que não é nome, como "Fica maiorzinha, trocar de vazo, pouca água, não por no sol" no kalanchoe e "Dourados 1" numa hortelã;
  - aparece nome de outra planta, como "Jibóia" no filodendro.

## Score e limiar

- O `score` do top 1 **não separa acerto de erro**: a mediana foi 0,55 nos acertos e 0,58 nos erros.
- As 4 fotos sem a espécie certa no top 3 tiveram scores 0,25, 0,34, 0,56 e 0,68.
- Com limiar de 0,2, uma das 56 fotos com acerto no top 3 seria pedida de novo à toa. Com 0,3 seriam 3, com 0,4 seriam 9 e com 0,5 seriam 20, e mesmo com 0,5 só 2 das 4 fotos erradas seriam pegas.
- **Limiar proposto: 0,2.** Ele serve só para barrar foto inútil, que não é planta ou está borrada. A defesa contra erro é o usuário escolher entre os 3 candidatos, como já decidido.

## Ressalvas

- Parte das fotos é research grade e pode ter entrado no treino do Pl@ntNet pelo GBIF. As datas recentes reduzem esse risco, mas não o eliminam.
- Quem posta no iNaturalist costuma fotografar melhor que um usuário comum. Fotos de casa, com pouca luz e a planta pequena no quadro, devem ir pior. Ainda assim, a folga entre 93% e a meta de 70% é grande.
- Com 3 fotos por espécie, o número de cada espécie é ruidoso. Só o total serve para decidir.
