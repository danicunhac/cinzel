# Cinzel: design do jogo (Projeto em Equipe, Trilha 2)

Data: 13/11/2026. Entrega final: 28/11/2026 até meia-noite (com penalidade até 05/12).

## Intenção

Jogo de ação roguelike 2D com visão de cima. Um escalador sobe os andares de uma torre, como em Sword Art Online, com o visual e o loop cidade/masmorra de Moonlighter. A base é o GDD do Cinzel feito na Trilha 1. A ideia central fica igual: **o que custa caro é o tempo, não a vida.** Dentro da torre, a dificuldade sobe a cada minuto, e curar exige ficar parado, então gasta tempo.


## Objetivos

- Jogo jogável do início ao fim, com vitória e derrota claras, entregue como build Windows zipada até 28/11.
- Cobrir a rubrica com nota máxima:
  - Programação (1,5): controle responsivo, colisão, estado do jogo, HUD e troca de telas sem falhas.
  - Design de níveis (1,5): fase legível, mecânicas apresentadas em ordem, ritmo sem picos.
  - Arte (1,5): **pelo menos um elemento próprio animado** (o personagem, feito pelo Daniel) e visual coeso.
  - Áudio (1,0): efeitos sonoros em todas as ações principais e música de fundo.
  - Processo (1,0): quadro de tarefas público com as tarefas e quem fez cada uma.
  - Apresentação e build (3,5): build no formato certo, ficha completa e apresentação técnica.
- Versão jogável (MVP) pronta até 21/11, caso a apresentação caia nesse dia.

## Fora do escopo (não-objetivos)

- Salvar o progresso entre sessões. Fechar o jogo reinicia tudo.
- Tela de customização do personagem e da roupa. Fica como extra depois que a entrega estiver estável. O sprite e o código já nascem em camadas (corpo, cabelo, roupa, arma e paleta por camada) para encaixar a tela sem retrabalho.
- Mais de 3 andares, multiplayer, geração procedural de salas do zero.
- Versões para Mac, Linux ou consoles.

## O que seria fracasso (anti-objetivos)

- Build que não abre no Windows do professor.
- Jogo bonito, mas que não fecha um ciclo completo (do menu até a vitória ou a derrota).
- Visual com cara de "assets aleatórios", com estilos diferentes entre a arte gerada e o personagem.
- Nenhuma arte autoral (a nota de arte cai para 0,5).

## Restrições

- Engine Godot 4.7.2 (instalada em /Applications/Godot.app), GDScript, 2D.
- Exportar para Windows a partir do macOS (precisa dos export templates 4.7.2).
- Repositório público e quadro de tarefas público, exigidos na ficha.
- A arte gerada por IA precisa ser declarada na ficha ("Autoria dos assets"). O personagem é autoral, desenhado pelo Daniel no Pixelorama ou no Aseprite.
- Apresentação de 6 a 10 minutos mostrando o projeto aberto no Godot ou o jogo rodando.

## Abordagens consideradas

1. **Código do Claude, arte de pacote CC0 (Kenney, 0x72) e personagem autoral.** Visual coeso com pouco esforço, mas genérico.
2. **Código do Claude, arte e áudio gerados pelo gerador de IA com referência de Moonlighter e SAO, e personagem autoral.** Visual mais único. O risco é a coesão, que se resolve com um preset de estilo e uma paleta fixa. **Escolhida pelo Daniel** porque ele quer um visual próprio.
3. Pacote CC0 e arte gerada misturados. Foi descartada porque mistura estilos, que é justamente o que a rubrica pune.

## O jogo

### Loop

```
Título → Cidade ⇄ Torre (andar N) → Chefe → andar N+1 ... → Chefe do andar 3 → Vitória
                    ↑ sair (fora da sala do chefe)        ↓ vida zero
                    └──────────────── Derrota: perde tudo, volta ao andar 1 ────┘
```

### Regras decididas pelo Daniel

- **Visão de cima**, como em Moonlighter. Não tem pulo, e a esquiva é um rolamento.
- **Andares como em SAO:** vencer o chefe de um andar libera o teleporte para o próximo. Da cidade, o jogador entra em qualquer andar já liberado.
- **Tempo:** o relógio só corre dentro da torre. Na cidade ele pausa, mas não zera, e só volta a zero na morte.
- **Sair da torre:** pode a qualquer momento, em qualquer andar, menos dentro da sala do chefe. Quem entrou na sala do chefe vence ou morre.
- **Morte:** perde tudo (itens, ouro e andares liberados), volta para a cidade com o relógio zerado e só o andar 1 liberado.
- **Cidade:** tem lojas para vender, comprar e trocar itens.
- **Itens:** mudam atributos e o estilo de jogo de forma simples. São 3 espaços para equipar (do GDD).
- **Curar exige ficar parado** (do GDD).

### Escolhas do Claude (podem ser revistas)

- **Tamanho:** 3 andares. Cada andar tem de 4 a 5 salas de combate e uma sala do chefe. A sala inicial de cada andar é a entrada e mostra o portal de saída.
- **Montagem dos andares:** as salas são feitas à mão (de 6 a 8 modelos por andar) e sorteadas em sequência a cada entrada. Isso dá variação de roguelike e mantém a fase legível (design de níveis). As portas só abrem quando a sala está limpa.
- **Apresentação das mecânicas:** o andar 1 começa com 3 salas fixas (tutorial: mover e atacar, depois esquivar de projétil, depois curar parado) e só então entram as salas sorteadas.
- **Chefes:** os andares 1 e 2 têm um chefe que é a versão maior de um inimigo comum, com um ataque a mais. O andar 3 tem um chefe próprio com 2 fases.
- **Inimigos comuns (3):**
  - Rastejante: persegue e ataca de perto.
  - Atirador: mantém distância e atira projéteis.
  - Investidor: avisa e depois avança em linha reta.
- **Dificuldade por tempo:** sobe 1 nível a cada 60 s dentro da torre. Cada nível dá +10% de vida e +8% de dano aos inimigos, e a partir do nível 5 aparece +1 inimigo por sala. O HUD mostra o relógio e o nível.
- **Combate do jogador:**
  - Ataque corpo a corpo em arco, combo de 3 golpes.
  - Rolamento com invencibilidade de cerca de 0,3 s e recarga.
  - Vida inicial 100.
- **Cura parada:** depois de 1,5 s sem se mover nem atacar, recupera 8 de vida por segundo. Uma aura amarela indica a cura, e o relógio continua correndo.
- **Saída da torre:** segurar Q por 2 s (barra de progresso) teleporta para a cidade. Não funciona na sala do chefe e é interrompido se o jogador levar dano.
- **Itens:** 8 itens, cada um com preço de venda e de compra. Por exemplo:
  - Lâmina pesada: +dano, golpe mais lento.
  - Botas leves: +velocidade.
  - Coração de pedra: +vida máxima.
  - Presa: roubo de vida.
  - Capa do vento: rolamento mais longo.
  - Ampulheta rachada: cura parada começa em 0,75 s.
  - Faísca: golpes deixam rastro de dano.
  - Escudo de vidro: bloqueia 1 golpe por sala.

  Os itens caem de baús (1 ou 2 por andar) e dos chefes.
- **Ouro:** cai dos inimigos, e a quantidade cresce com o nível de dificuldade. Dá para gastar só na cidade.
- **Cidade:** uma tela (cena caminhável pequena) com 3 pontos:
  - Loja: vender e comprar itens, com estoque rotativo de 3 itens.
  - Ferreiro: troca 2 itens por 1 aleatório.
  - Pedra de teleporte: escolher o andar liberado.
- **Telas:** título, cidade, torre (com HUD), pausa, derrota (mostra andar, tempo e ouro), vitória e créditos.
- **HUD:** vida, relógio e nível de dificuldade, ouro, 3 espaços de itens, andar atual e barra de saída quando ativa.
- **Controles:**
  - Teclado: WASD move, J ou clique ataca, Espaço rola, E interage, Q (segurar) sai, Esc pausa.
  - Controle: suporte via InputMap, como extra se der tempo.
- **Resolução:** base 320×180 em pixel art, escala inteira na janela 1280×720 (×4), tela cheia opcional.

### Arte e áudio

- **Estilo:** pixel art com visão de cima e luz quente, referência Moonlighter. A torre é de pedra e ferro, e a cidade tem toldos e madeira (referência SAO, Aincrad). As cores seguem o GDD: amarelo marca item ou cura, vermelho marca perigo.
- **Coesão:** um preset de estilo no gerador de IA (`create_style_preset`) com paleta limitada e um único tamanho de pixel. Toda arte gerada usa esse preset. Os tiles têm 16×16.
- **Gerado:** tiles da torre (3 variações de cor por andar), tiles da cidade, 3 inimigos e 2 chefes com animações simples, ícones dos 8 itens, NPCs da cidade, UI e fundo da tela de título.
- **Personagem:** o escalador tem sprite de 24×24 em 3 direções (baixo, cima e lado espelhado). As animações são parado (2 frames), andar (4), atacar (3), rolar (4) e morrer (4, só de frente). **O sprite fica em camadas separadas (corpo, cabelo, roupa e arma)** para a customização depois. Os tiles continuam com 16×16, e o personagem ocupa cerca de 1,5 tile.
  - O Claude gera primeiro uma versão completa (ela é o sprite provisório e a referência).
  - Depois, o Daniel redesenha à mão no Pixelorama, seguindo a referência e o guia.
  - **A versão que vai na build é a desenhada pelo Daniel.** É ela que conta como arte autoral na rubrica, e a ficha declara isso.
  - Decisão do Claude, delegada pelo Daniel: 24×24 em vez de 16×16 para que a roupa trocável apareça.
- **Áudio** (`generate_sfx` e `generate_music`):
  - Efeitos: golpe, acerto, rolamento, dano no jogador, morte de inimigo, coletar ouro ou item, porta abrindo, cura (loop), compra e venda, teleporte e saída.
  - Músicas: cidade, torre e chefe.


## Entregáveis e organização

```
/Users/dancunhac/Games/cinzel/
  game/            projeto Godot (project.godot, scenes/, scripts/, assets/)
  art-src/         arquivos-fonte do personagem (Pixelorama/Aseprite)
  docs/
    gdd.md                     GDD atualizado (versão Trilha 2)
    ficha-entrega.md           rascunho da ficha (nome, equipe, engine, resumo, controles, papéis, autoria dos assets, links)
    apresentacao.md            roteiro da apresentação técnica (6–10 min)
    personagem-guia.md         guia para desenhar o escalador
    superpowers/specs/         este documento
  builds/          builds Windows zipadas (fora do git)
```

- Repositório público no GitHub e quadro de tarefas no GitHub Projects (vale o ponto de "processo").
- Build Windows zipada. Se der tempo, também uma versão web no itch.io.

## Marcos

- **14/11:** guia do personagem pronto (antes do resto, porque o tamanho do sprite define a escala de toda a arte gerada). **Apresentação confirmada para 21/11.**
- **15/11:** projeto Godot criado, jogador se movendo com sprite provisório, uma sala com um inimigo.
- **18/11:** combate, rolamento, cura parada, relógio de dificuldade, salas encadeadas e saída para a cidade.
- **20/11:** versão rascunho do sprite autoral (parado e andar) no jogo. A apresentação pode ser em 21/11, e a arte autoral precisa aparecer nela.
- **21/11 (MVP):** andar 1 completo com chefe, cidade com loja, vitória e derrota, HUD e arte gerada aplicada.
- **25/11:** andares 2 e 3, todos os itens, áudio completo, todas as animações do sprite autoral.
- **27/11:** ajuste fino, build Windows testada, ficha e roteiro da apresentação prontos.
- **28/11:** entrega.

## Deixado para quem constrói

- Estrutura de cenas e scripts no Godot, nomes de arquivos e autoloads.
- Layout de cada modelo de sala, respeitando a apresentação das mecânicas.
- Ajuste fino dos números (dano, vida, preços, velocidades) em testes.
- Padrões de ataque dos chefes, dentro do limite descrito.
