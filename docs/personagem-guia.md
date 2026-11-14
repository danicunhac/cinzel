# Guia para redesenhar o escalador

O escalador atual foi gerado por IA e reduzido por script. Este guia explica como redesenhá-lo à mão no Pixelorama sem mexer no código: basta exportar arquivos com os mesmos nomes, tamanhos e posições.

## Tamanho e grade

- Cada quadro tem 24x24 pixels.
- Cada folha tem 4 colunas x 13 linhas de quadros: 96x312 pixels.
- Fundo transparente. Quadro que não é usado fica vazio.
- Os pés ficam na linha 22 do quadro (contando do 0, de cima para baixo). O centro do capuz fica na coluna 12.
- O lado esquerdo não existe na folha: o jogo espelha o lado direito. Desenhe o lado sempre olhando para a direita.

## Linhas e quadros

| Linha | Animação | Quadros usados |
|---|---|---|
| 0 | `idle_down` (parado, de frente) | 2 |
| 1 | `idle_up` (parado, de costas) | 2 |
| 2 | `idle_side` (parado, de lado) | 2 |
| 3 | `walk_down` (andando, de frente) | 4 |
| 4 | `walk_up` | 4 |
| 5 | `walk_side` | 4 |
| 6 | `attack_down` (golpe: preparo, golpe, acompanhamento) | 3 |
| 7 | `attack_up` | 3 |
| 8 | `attack_side` | 3 |
| 9 | `roll_down` (rolamento) | 4 |
| 10 | `roll_up` | 4 |
| 11 | `roll_side` | 4 |
| 12 | `death` (morte, só de frente) | 4 |

## Uma camada por arquivo

O personagem é montado no jogo com 4 folhas empilhadas, nesta ordem (a de baixo primeiro):

1. `body.png`: pele, mãos e botas.
2. `hair.png`: capuz e cabelo.
3. `outfit.png`: jaqueta, cachecol, calça e mochila.
4. `weapon.png`: espada e o arco claro do golpe.

As 4 folhas têm o mesmo tamanho e a mesma grade. Um pixel pertence a uma camada só. Separar assim permite trocar a cor da roupa ou a arma depois sem redesenhar o resto.

## Paleta

Contorno de todas as camadas: `#181014`.

- Pele: `#CFA151` (luz), `#A5803E`, `#96642A`, `#84723A` (sombra no capuz).
- Botas e couro escuro: `#874D20`, `#793E1E`, `#65301B`, `#502617`, `#341A10`, `#1C110C`.
- Capuz e cachecol (verde-oliva): `#6D6F3D` (luz), `#68673A`, `#596137`, `#495634`, `#455232`, `#404B30`, `#364028`, `#303320` (sombra).
- Jaqueta e mochila: `#995323` (luz), `#874D20`, `#793E1E`, `#5F3B1B`, `#532F17`, `#362615`.
- Calça cáqui: `#A5803E`, `#84723A`, `#5F522C`.
- Espada: `#EADECA` (brilho e arco do golpe), `#C4BFAE`, `#A7A696`, `#8A887D`.

Regras do jogo para cor: amarelo marca item ou cura e vermelho marca perigo. Não use esses dois no escalador.

## Passo a passo no Pixelorama

1. Abra o Pixelorama e crie uma imagem nova de 96x312 pixels, fundo transparente.
2. Em Ver > Grade, ligue a grade com 24x24 pixels. Cada quadrado é um quadro.
3. Importe `art-src/climber-reference.png` como uma camada nova (Arquivo > Importar, como camada). Chame essa camada de `guia`, baixe a opacidade para uns 40% e trave a camada.
4. Crie 4 camadas acima da guia, com os nomes `body`, `hair`, `outfit` e `weapon`, nesta ordem de baixo para cima.
5. Carregue a paleta acima (Paletas > Nova, e adicione as cores pelo código hex).
6. Redesenhe camada por camada, por cima da guia:
   - Comece pela linha 0 (parado, de frente). Quando ela estiver boa, copie para as outras linhas e ajuste.
   - Mantenha os pés na linha 22 e o capuz centrado na coluna 12 em todos os quadros, senão o personagem "pula" quando a animação troca.
   - Para conferir uma animação, selecione os quadros de uma linha e use a prévia do Pixelorama, ou exporte e rode o jogo.
7. Esconda a camada `guia`.
8. Exporte uma folha por camada: deixe visível só uma camada por vez e use Arquivo > Exportar > PNG, com o nome da camada. Salve em `game/assets/characters/climber/`, sobrescrevendo `body.png`, `hair.png`, `outfit.png` e `weapon.png`.
9. Confira os arquivos: `python3 -I art-src/check_art.py .` (precisa de um Python com Pillow, por exemplo um venv). Ele avisa se o tamanho estiver errado, se houver mais de 32 cores ou pixel semitransparente.
10. Abra o Godot (ele reimporta sozinho) e rode a sala de teste para ver o resultado.

Se quiser voltar à versão gerada, rode `python3 -I art-src/build_climber.py .`.
