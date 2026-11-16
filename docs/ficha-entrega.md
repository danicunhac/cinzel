# Ficha de entrega: Cinzel

Rascunho. Campos entre `[colchetes]` são do Daniel.

## Nome do jogo

Cinzel

## Equipe

Daniel Cunha Costa, solo (apresentação e entrega individuais, com OK do professor).

## Engine

Godot 4.7, GDScript tipado.

## Resumo e como jogar

Roguelike de ação 2D, visto de cima. Você sobe uma torre de 3 andares e volta à cidade para vender o saque, forjar e se equipar. O relógio corre só dentro da torre: a cada minuto, os inimigos ganham 10% de vida e 8% de dano. Curar exige ficar parado. Morrer perde tudo (mochila, equipamento, ouro e andares). Para sair vivo com o saque, segure Q.

Como jogar:

1. Na cidade, use a loja, o ferreiro e o guarda-roupa. Na cidade não dá para atacar. Para entrar na torre, caminhe até a entrada no fim do caminho norte.
2. Cada sala tem inimigos. Todo ataque inimigo avisa em vermelho: role para fora.
3. Mate todos para abrir a porta. Abra baús com E.
4. No fim do andar, vença o chefe para liberar o próximo andar.
5. Segure Q para voltar à cidade com tudo o que carrega, ou desça a pé pelas escadas.
6. Venda o saque. A loja paga mais pelo que está em falta.

Vitória: vencer o chefe do andar 3.

## Controles

| Ação | Tecla |
|---|---|
| Mover | WASD ou setas |
| Atacar | J ou clique esquerdo |
| Golpe especial | Segurar J (ou o clique) por 0,5 s e soltar |
| Rolar | Espaço |
| Interagir (loja, ferreiro, guarda-roupa, baú) | E |
| Sair da torre | Segurar Q por 2 s (não vale na sala do chefe) |
| Mochila | Tab (ou I) |
| Largar item | X |
| Pausa | Esc |

## Observações para rodar

- Build Windows: arquivo zip em `[link do zip, gerar antes de 28/11]`.
- Sem instalação. Extrair o zip e abrir `Cinzel.exe`.
- Janela de 1440x810 (viewport de 480x270 com escala inteira).
- Teclado e mouse. Sem controle.
- Pelo código: abrir `game/project.godot` no Godot 4.7 e rodar a cena principal (título).
- Testes: `godot --headless --path game -s res://tests/run_tests.gd` (287 testes, todos passam em 15/11).
- Campus e turma: IFPB Campus João Pessoa.

## O que cada integrante fez

Daniel Cunha Costa (único integrante):

- Direção e design do jogo: ideia, pilares, regras (relógio, cura parada, morte perde tudo, mercado), escolha das armas, roupas e quantidade de conteúdo, escolha das artes-chave.
- Programação com assistência de IA (Claude): o código foi escrito com o Claude a partir das decisões do Daniel, que revisou e testou.
- Arte autoral: redesenho à mão do escalador no Pixelorama, seguindo `docs/personagem-guia.md`. Status: `[pronto / parcial: idle e andar / a fazer]`.
- Processo: quadro de tarefas, revisão de cada tarefa, balanço do andar 1.

## Autoria dos assets

Detalhe arquivo por arquivo em `docs/assets.md`.

| Asset | Autoria |
|---|---|
| Escalador (herói), versão final da build | Desenhado à mão por Daniel no Pixelorama. `[status]`. Fonte em `art-src/`. |
| Escalador, versão provisória e referência | Gerado por IA e ajustado por script |
| Inimigos, chefes, cidade, moradores, salas pintadas, tiles, portas, escadas, ícones e UI | Gerados por IA (preset `cinzel-pixel`) a partir das artes-chave escolhidas por Daniel, com ajuste por script (redução à grade, 32 cores, alinhamento) |
| Camadas de arma, roupas visuais e logo | Geradas por IA e desenhadas por script (`art-src/build_*.py`) |
| Efeitos sonoros (28) | Gerados por IA (ElevenLabs Sound Effects), tratados com ffmpeg |
| Músicas (cidade, torre, chefe) | Geradas por IA (MiniMax Music), cortadas e normalizadas com ffmpeg |
| Fonte Silkscreen | Jason Kottke, licença SIL OFL 1.1. Licença em `game/assets/fonts/Silkscreen-OFL.txt` |
| Código GDScript | Escrito com assistência de IA (Claude), revisado por Daniel |

## Ferramenta colaborativa e link aberto

GitHub Projects (quadro de tarefas): `[link aberto do quadro]`

## Link do repositório aberto

https://github.com/danicunhac/cinzel (ramo `feat/mvp`, depois `main`)
