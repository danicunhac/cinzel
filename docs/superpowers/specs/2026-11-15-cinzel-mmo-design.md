# Cinzel: camada MMORPG (design)

15/11/2026. Pedido do Daniel: deixar o jogo mais perto de um MMORPG, com monstros que tenham personalidade e façam sentido com o que derrubam, e evolução pelo estilo de jogo. Sem árvore de habilidades e sem pontos para distribuir. Daniel aprovou os 8 itens abaixo. Entrega: 28/11. Apresentação: 21/11 (o que estiver pronto até lá entra).

Marcado **[proposta]**: decisão minha, para o Daniel corrigir.

## Intenção

O personagem fica melhor naquilo que o jogador faz. Quem luta de lança vira lanceiro; quem rola muito rola melhor. A sorte entra pelas relíquias, que reforçam um estilo. Os monstros dão o motivo para subir: cada andar tem criaturas próprias, cada uma derruba o material que carrega, e algumas são raras e caçadas.

Anti-objetivos: árvore de habilidades, pontos de atributo, barras de XP genéricas sem ligação com o que o jogador fez, grind obrigatório para passar de andar.

## Abordagens consideradas (evolução)

- **A. Maestria por uso, em níveis (escolhida).** Cada estilo tem nível 1 a 10 e sobe com o uso. Cada nível dá um bônus pequeno e visível, e certos níveis liberam golpes. Fácil de ler ("Lança 4"), fácil de testar.
- B. Atributos que crescem sem número visível. Mais "orgânico", mas o jogador não sente a evolução e é difícil de balancear.
- C. Só relíquias. Mantém o roguelike puro, mas não atende "evoluir pelo estilo de jogo".

## 1. Maestria por uso

Estilos: espada, espada longa, machado, lança, adaga, arco, rolamento e cura (8). Lâminas Gêmeas (habilidade secreta de duas espadas, em construção em 15/11, liberada só por `--dual` por enquanto) entra como nono estilo: tem maestria e os 3 degraus de golpe, reaproveitando o combo de duas espadas.

- Nível 1 a 10. XP:
  - armas: dano causado com aquele tipo de arma.
  - rolamento: golpes inimigos evitados rolando (o golpe pegaria, a invencibilidade salvou) e, menos, rolamentos feitos.
  - cura: vida recuperada parado.
- Curva: cada nível pede ~1,6× o anterior. Nível 3 em ~2 andares de uso, nível 10 só para quem joga muito com aquele estilo.
- Bônus por nível:
  - armas: +3% de dano e +1% de velocidade de ataque com aquele tipo.
  - rolamento: +2% de distância e, nos níveis 5 e 10, +0,05 s de invencibilidade.
  - cura: +4% de cura por segundo e −0,05 s na espera para começar.
- Ao subir de nível: aviso curto ("Lança 4") com o efeito de "unlock" (luz radial) e um som.
- Tela: aba "Maestria" na mochila, com os 8 estilos, nível, barra de progresso e o bônus atual.
- **[proposta] A maestria fica na morte**, como as roupas e o tutorial. É a habilidade do personagem, não o que ele carrega. A morte continua levando equipamento, mochila, ouro e andares.

## 2. Golpes liberados pela maestria

Hoje cada arma tem 1 golpe especial (segurar o ataque 0,5 s). Passa a ter 3, pela mesma tecla:

- segurar 0,5 s: golpe 1 (o atual), desde o nível 1.
- segurar 1,0 s: golpe 2, a partir do nível 3.
- segurar 1,5 s: golpe 3, a partir do nível 6.

A barra de carga mostra os degraus liberados. Cada golpe tem a sua recarga. Os golpes novos usam os padrões de dano e efeito que já existem (linha, giro, onda, investida, sequência, chuva) com alcance, dano e forma diferentes por arma. Exemplos:
- lança 2: investida dupla; lança 3: arremesso que atravessa.
- arco 2: leque de 3 flechas carregadas; arco 3: flecha que explode.

A lista completa dos 12 golpes novos fica no plano.

## 3. Relíquias por estilo

As 8 relíquias atuais ficam (gerais). Entram 16 novas, 2 por estilo:
- uma muda o jeito de jogar, por exemplo "a investida da lança atordoa" ou "rolar recarrega 20% do especial".
- uma acelera a maestria daquele estilo, +50% de XP.

Saem de baús, elites, raros e chefes, sorteadas. **[minha decisão]** O que se sorteia é qual relíquia cai; cada relíquia tem raridade fixa (como hoje, o item é só um id). As mais fortes são raras e épicas e caem mais de elites, raros e chefes. Continuam 3 espaços de relíquia.

## 4. Monstros por andar, elites e raros

Cada andar tem 3 monstros próprios. Cada um derruba principalmente o material que faz sentido com ele (tabela de materiais de 14/11). **[minha decisão]** Nos andares 2 e 3, cada monstro também derruba, com menos chance, ferro ou couro, que as receitas e o refino usam muito; assim ninguém precisa voltar ao andar 1 para juntar ferro e tem uma personalidade lida no comportamento e num aviso visual.

| Andar | Monstro | Comportamento | Derruba |
|---|---|---|---|
| 1 | Slime de Esgoto | persegue, se divide em 2 pequenos ao morrer | Couro Velho (restos que não digeriu) |
| 1 | Toco Vivo | parado até chegar perto, levanta e varre com galhos | Madeira de Freixo |
| 1 | Sentinela de Pedra | atira de longe e recua | Minério de Ferro |
| 2 | Esqueleto Mineiro | anda com picareta, golpeia e joga pedra | Minério de Prata |
| 2 | Besouro-Couraça | anda devagar e morde; fecha a carapaça quando leva golpe de frente (dano mínimo). Fica aberto por trás e por 1,5 s depois de morder | Quitina |
| 2 | Besouro-Rinoceronte | avisa e investe em linha | Chifre de Besouro |
| 3 | Salamandra de Brasa | cospe um jato de fogo curto e deixa brasa no chão | Carvão de Brasa |
| 3 | Golem de Obsidiana | lento, golpe no chão com onda | Obsidiana |
| 3 | Espectro | some e reaparece atrás do jogador | Tecido Espectral |

- **Elite:** qualquer monstro tem 8% de chance de vir elite: maior, com contorno dourado, +80% de vida, dano +30%, derruba o dobro e tem chance de relíquia.
- **Raro com nome**, 1 por andar, com 10% de chance por andar de aparecer numa sala:
  - Rei Gosma (andar 1)
  - Velho Picareta (andar 2)
  - Brasa Viva (andar 3)

  Tem uma fala curta ao aparecer, vida de mini-chefe e garante uma relíquia rara ou épica e um título.
- Os chefes ficam como estão.
- Arte: folhas novas de 24 px (chefes e raros 32 a 48 px) no estilo da cidade (preset `cinzel-pixel`), com animação de andar, ataque e aviso.
- Os slimes, sentinelas e besouros atuais são substituídos ou viram base desses.

## 5. Quadro de missões na cidade

Um quadro perto da loja com 3 missões, que mudam a cada volta à cidade.
- Tipos:
  - caçar N de um monstro
  - entregar N de um material
  - vencer um elite
  - chegar ao andar X sem sair
- Recompensa: ouro e, às vezes, uma relíquia ou um material raro.
- Aceitar é automático: as 3 contam ao mesmo tempo.
- Entregar é no quadro, com E.
- **[proposta]** O progresso das missões some na morte, junto com o resto do que é da subida.

## 6. Bestiário e títulos

- **Bestiário (aba na pausa):**
  - Cada monstro aparece ao ser morto pela primeira vez.
  - Cada página mostra o sprite, o andar, como ele ataca (o aviso), a fraqueza (por exemplo "por trás" ou "rolamento contra a investida"), o que derruba e o total de abates.
  - Os raros têm página própria.
- **Títulos:** ganhos por feitos.
  - 100 abates de uma espécie, por exemplo "Caçador de Slimes".
  - maestria 10 em um estilo, por exemplo "Mestre da Lança".
  - vencer um raro, por exemplo "Destronador do Rei Gosma".
  - vencer a torre.

  Um título escolhido aparece na tela de pausa e no topo da mochila. Só visual.
- **[proposta]** Bestiário e títulos ficam na morte.

## 7. Refino no ferreiro

- O ferreiro ganha a aba "Refinar", para armas e armaduras de +1 a +5.
- Custo: material do item (ferro para aço, couro para couro, e assim por diante, definido por item) mais ouro, crescendo a cada nível.
- Chance de dar certo: +1 100%, +2 90%, +3 75%, +4 60%, +5 45%.
- Falhar gasta o material e o ouro, mas o item não quebra nem perde nível.
- Cada + dá +8% de dano (arma) ou de defesa e vida (armadura).
- O nome mostra o nível ("Espada de Ferro +3"). No +5, o item brilha de leve no personagem.
- **[minha decisão]** O nível de refino fica guardado por id do item na subida (RunState), não por cópia: duas Espadas de Ferro compartilham o +3. Evita reescrever mochila, equipamento e loja para guardar dados por cópia; cópias repetidas do mesmo item são raras. Morrer zera os refinos junto com o equipamento.

## 8. Consumíveis

| Item | Efeito | Origem |
|---|---|---|
| Poção de Vida | cura 30 em 3 s, pode andar | loja, baús |
| Ração de Viagem | +10% de dano por 120 s | loja |
| Elixir do Vento | +15% de velocidade por 90 s | loja, baús |
| Tônico de Pedra | +3 de defesa por 120 s | loja |

- Ocupam espaço na mochila e empilham até 5.
- Os 3 espaços de item do HUD viram a barra rápida: teclas 1, 2 e 3, configuradas na mochila.
- **[proposta]** A poção cura devagar e é cara, para não quebrar o pilar "o que custa caro é o tempo": parar para curar continua sendo o jeito barato.
- Os efeitos ativos aparecem como ícones pequenos com tempo no HUD.

## Restrições

- Godot 4.7, GDScript tipado, testes no executor atual (hoje 293 passando), capturas reais para toda UI e VFX.
- Arte no estilo da cidade, com ícone e sprite batendo (regra de 15/11).
- Sem save em disco: "fica na morte" vale enquanto o jogo está aberto, como as roupas hoje.

## O que fica para quem constrói

- Números finos: curva de XP, valores dos golpes, preços, chances de drop. Balancear com o robô de teste e anotar em `docs/balance.md`.
- Lista final dos 12 golpes novos e das 16 relíquias, dentro das regras acima.
- Layout das abas novas no kit de UI atual.

## Ordem sugerida

1. Monstros novos, elites e raros (pedido direto, maior mudança de arte).
2. Maestria, golpes por maestria e relíquias por estilo, juntos, porque um depende do outro.
3. Consumíveis e barra rápida.
4. Refino.
5. Quadro de missões.
6. Bestiário e títulos.
