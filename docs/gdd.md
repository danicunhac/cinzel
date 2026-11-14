# Cinzel: GDD

Versão 2 (rascunho), 14/11/2026. Projeto em Equipe da Trilha 2. Apresentação: 21/11. Entrega: 28/11.
Itens marcados com **[a decidir]** dependem de resposta do Daniel.

## 1. Visão

Ação roguelike 2D com visão de cima. Um escalador sobe uma torre de andares, como Aincrad em Sword Art Online, e volta para a cidade para vender o que achou e se equipar, como em Moonlighter.

Frase do jogo: **o que custa caro é o tempo, não a vida.**

## 2. Pilares

1. **Tempo como recurso.** Dentro da torre, a dificuldade sobe a cada minuto. Curar exige ficar parado. Sair cedo é seguro; ficar mais rende mais.
2. **Risco e recompensa da mochila.** Tudo o que você carrega pode ser perdido. Sair vivo transforma o saque em ouro e equipamento.
3. **Equipamento muda o jeito de jogar.** Armas e peças têm efeitos visíveis no combate e na aparência do personagem.
4. **Torre ilustrada.** Cada sala parece pintada à mão, no estilo da arte-chave da torre.

## 3. Loop

```
Cidade (vender, comprar, forjar, equipar)
  → Caminhar até a entrada da torre (norte da cidade) e escolher um andar liberado
  → Salas de combate (saque, baús) → sala do chefe → próximo andar liberado
  → Sair (segurar Q, fora da sala do chefe) → Cidade com tudo o que carrega
  → Morrer → perde TUDO (mochila, equipamento, ouro, andares) → Cidade, andar 1
Vitória: vencer o chefe do andar 3.
```

## 4. Regras que já existem no jogo

- **Relógio:** só corre dentro da torre. Na cidade e nos menus ele pausa e não zera. Só zera na morte. Sobe 1 nível a cada 60 s; cada nível dá +10% de vida e +8% de dano aos inimigos, e a partir do nível 5 aparece +1 inimigo por sala (regra mantida no balanço de 14/11).
- **Combate:** combo de 3 golpes, rolamento com 0,3 s de invencibilidade, vida inicial 100.
- **Cura:** depois de 1,5 s parado, recupera 6 de vida por segundo (era 8; ver `docs/balance.md`), com aura amarela.
- **Saída:** segurar Q por 2 s. Não funciona na sala do chefe e é cancelada se o jogador levar dano.
- **Cidade sem armas:** na cidade o ataque não funciona. Apertar o botão mostra o aviso "Sem armas na cidade".
- **Entrada da torre:** para entrar é preciso caminhar até a entrada, no fim do caminho norte. Com só o andar 1 liberado, entra direto; com mais andares, abre a lista de andares. Quem volta a pé pela escada do andar 1 chega por essa entrada; quem sai por teleporte chega no cristal.
- **Morte:** perde tudo e volta ao andar 1 com o relógio zerado.
- **Andares:** 3 andares. Cada um tem um tutorial (só no andar 1), de 4 a 5 salas sorteadas e um chefe. Vencer o chefe libera o próximo andar na entrada da torre.
- **Inimigos:**
  - Slime: persegue.
  - Sentinela de pedra: atira de longe.
  - Besouro: avisa e investe.
- **Chefes:**
  - Andar 1: slime gigante, com onda de choque.
  - Andar 2: besouro gigante, com investidas.
  - Andar 3: cavaleiro espectral com 2 fases; na segunda, invoca slimes.

### Caminho de volta (decidido em 14/11)
- As salas de um andar ficam ligadas nos dois sentidos: a porta de entrada leva de volta à sala anterior, e as salas já limpas continuam limpas.
- A primeira sala de cada andar tem uma **escada para baixo**, que leva à sala do chefe (já vencido) do andar anterior. No andar 1, a escada leva à cidade.
- Assim o jogador pode descer a torre a pé a qualquer momento. Segurar Q continua como saída rápida, fora da sala do chefe.
- O relógio continua correndo enquanto o jogador está dentro da torre, inclusive na volta a pé.

## 5. Equipamento (novo, proposta)

Pedido do Daniel: mais armas, armaduras, roupas e mochilas, mais perto de SAO.

### Espaços do personagem (decidido em 14/11)
| Espaço | O que faz | Aparece no sprite |
|---|---|---|
| Arma | Define o estilo de ataque (alcance, velocidade, combo, golpe especial) | Sim (camada `weapon`) |
| Armadura | Só atributos: defesa, vida máxima, peso (armadura pesada deixa o rolamento mais lento) | Não |
| Capuz/elmo | Só atributos: bônus pequeno (crítico, resistência) | Não |
| Mochila | Quantos espaços de saque cabem | Sim (parte de `outfit`) |
| Relíquias (até 3) | Os 8 itens atuais, com efeitos passivos | Não |
| **Roupa (visual)** | Só aparência, estilo SAO: escolhida livremente na cidade (guarda-roupa) e desbloqueada por compra, baú ou chefe. Não muda números. | Sim (camadas `hair` e `outfit`) |

A aparência vem da roupa, e os números vêm do equipamento. Cada roupa precisa da sua folha de sprite completa (8×13 quadros de 32 px nas camadas `hair` e `outfit`).

### Tipos de arma (decidido pelo Daniel em 14/11)
- **Espada:** equilibrada, combo de 3. Especial: estocada em linha.
- **Espada longa:** lenta, arco grande, mais dano. Especial: giro em volta do herói.
- **Machado:** lento e pesado, atordoa por pouco tempo. Especial: golpe no chão com onda curta.
- **Lança:** alcance longo e estocada. Especial: investida curta.
- **Adaga:** muito rápida e com pouco alcance, crítico alto. Especial: sequência de 6 cortes.
- **Arco e flecha:** ataque à distância e rolamento para recuar; a flecha atravessa um inimigo se carregada. Especial: chuva de flechas numa área.

O **golpe especial** imita as Sword Skills de SAO: segurar o ataque por 0,5 s carrega um golpe com rastro de luz, com uma recarga curta.

### Raridade
Comum (branco), Rara (azul), Épica (roxo). A raridade aumenta os números, e as épicas trazem um efeito extra.

### Quantidade de conteúdo (decidido em 14/11, opção B)
- 12 armas (2 de cada tipo)
- 6 armaduras
- 4 capuzes/elmos
- 3 mochilas: 8, 14 e 20 espaços
- 8 relíquias (as atuais)
- 5 roupas visuais (a inicial e mais 4)
- 10 materiais (3 por andar, mais 1 raro de chefe)

## 6. Mochila, saque e loja (novo, proposta)

- Inimigos derrubam **materiais**, e cada material vira algo que faz sentido (minério vira lâmina e malha, couro vira gibão e cabo). Baús e chefes derrubam **equipamentos** e **relíquias**.
  - Andar 1: minério de ferro (sentinelas de pedra), couro velho (os slimes largam as correias do que não digeriram), madeira de freixo (besouros).
  - Andar 2: quitina e chifre de besouro (besouros; os slimes também largam quitina), minério de prata (sentinelas, que ainda trazem ferro).
  - Andar 3: carvão de brasa (besouros), obsidiana (sentinelas, com ferro), tecido espectral (slimes, com couro).
  - Chefes: 3 materiais do andar e, às vezes, o cristal da torre.
  - Receitas do ferreiro: lança (freixo + ferro), arco (freixo + couro), gibão (couro), elmo de ferro (ferro); depois do 1º chefe escamas (quitina + couro), espada do cavaleiro (ferro + prata + couro), machado de guerra (ferro + freixo), cota de malha (ferro + couro), elmo com chifres (ferro + chifre); depois do 2º chefe espada longa em brasa (ferro + carvão + cristal), adaga de presa (obsidiana + couro), placas (ferro + carvão), armadura das sombras (tecido espectral + cristal).
- O saque vai para a **mochila**, uma grade de espaços: a mochila inicial tem 8 e as melhores chegam a 20. Mochila cheia obriga a escolher o que largar.
- **Loja (decidido em 14/11):** preço base fixo por item, corrigido por oferta e procura. A loja paga mais pelo que está em falta e menos pelo que o jogador vendeu demais, e a tabela muda a cada volta da torre. O preço livre com clientes, estilo Moonlighter, fica como evolução depois da entrega.
- **Ferreiro:** em vez de "2 itens por 1", forja armas e armaduras com materiais e ouro, por receitas que vão sendo liberadas por andar.
- **Sem baú de casa (decidido em 14/11):** morrer perde TUDO (equipamento, mochila, ouro e andares liberados). O que protege o jogador é sair a tempo.

## 7. Cidade

Uma tela única com:
- a loja do herói
- o ferreiro
- a entrada da torre, no fim do caminho norte: o jogador caminha até ela para entrar
- o cristal, onde o jogador chega quando sai da torre por teleporte (Q ou portal do chefe)
- moradores andando
- fumaça da forja
- luz das lanternas
- falas curtas em balões

Estilo da arte-chave "cidade 1".

## 8. Arte

- Resolução base 480×270, escala inteira.
- Herói de 32 px, em camadas: corpo, capuz, roupa e arma. O equipamento troca as camadas, e cada peça visível precisa da sua folha.
- Inimigos de 24 px e chefes de 48 px.
- **Salas e cidade como pinturas inteiras**, no estilo da arte-chave "torre 1". O layout de cada sala vira um rascunho em blocos, a IA pinta por cima e a colisão vem do layout.
- Luz 2D (tochas e lanternas), partículas e números de dano.
- Personagem autoral: o Daniel redesenha o escalador à mão (é exigência da rubrica).

## 9. Áudio

- Efeitos sonoros: golpe, acerto, dano, rolamento, moeda, baú, porta, cura, compra, venda, teleporte, forja e golpe especial.
- Músicas: cidade, torre e chefe.

## 10. Telas e controles

- **Telas:** título, cidade, torre com HUD, mochila e equipamento, loja, ferreiro, entrada da torre (lista de andares), pausa, derrota, vitória e créditos.
- **Teclado:**
  - WASD move
  - J ou clique ataca (segurar faz o golpe especial)
  - Espaço rola
  - E interage
  - Q (segurar) sai da torre
  - Tab abre a mochila
  - Esc pausa
- **Controle:** extra, se der tempo.

## 11. Escopo e prazos

- **21/11 (apresentação técnica):**
  - andar 1 completo com salas pintadas, chefe, cidade, HUD e efeitos
  - sistema de equipamento com 2 tipos de arma e algumas armaduras
  - mochila e venda
- **28/11 (entrega):**
  - andares 2 e 3
  - todas as armas escolhidas
  - ferreiro com receitas
  - áudio completo
  - personagem redesenhado pelo Daniel
  - build Windows
  - ficha de entrega

## 12. Perguntas em aberto

Ver as marcações **[a decidir]**. As respostas fecham este documento e o plano de implementação.
