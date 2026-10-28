# William — Limiar de Aurora · Introdução 0.2

## Direção

Fantasia com detalhes modernos: natureza luminosa, armaduras, cristais, máquinas antigas e poderes elementais. A experiência apresenta William ao mundo de Aurora por meio de uma pequena travessia. O combate de demonstração combina ataques básicos automáticos com três habilidades acionadas pelo jogador.

## Percurso

1. **Chegada ao vale:** uma cena curta conecta a viagem de William à busca por Tomás; Lyra orienta pelo rádio.
2. **Farol adormecido:** explore a trilha, encontre criaturas e ative o farol para despertar o guardião.
3. **Prova do limiar:** aproxime-se para atacar automaticamente ou desligue essa opção; experimente Chama, Geada e Égide. A intenção do guardião é anunciada para permitir interromper ou evitar o golpe.
4. **Passagem:** depois da prova, alcance o portal e assista ao encerramento desta introdução.

O caminho principal permanece acessível ao trocar o cenário. Vegetação e outros detalhes procedurais variam com a semente. O objetivo é uma área introdutória fechada e legível, não um editor de mundos nem uma campanha completa.

## Interações

William caminha com WASD/setas, clique no chão ou controle virtual por toque. **Seguir trilha** conduz ao objetivo atual e pode ser interrompido movendo-se manualmente. **F** interage com o farol e o portal. **1/Q**, **2/E** e **3/R** ativam os poderes. **T** alterna o ataque automático. **C** abre o códice; aproximar-se da fauna registra as espécies.

O jogador pode repetir o confronto ao cair. Voltar ao título e começar novamente reinicia a introdução. Não há progressão persistente nesta abertura.

## Implementação e referências

- **Cenário:** implementação própria em GDScript, inspirada nos terraços, contornos desenhados, água e vegetação de Cartoon Terrain Studio. Usa uma semente estável, ruído e distribuição procedural; as interações narrativas permanecem em posições controladas.
- **Criaturas:** spritesheets efetivamente renderizadas pelo núcleo C# de Procedural Pixel Creatures. O gerador e as licenças estão incluídos no pacote de fontes; o jogo lê as imagens geradas e não necessita de .NET.
- **Personagem:** William foi adaptado a partir de um genoma humanoide com equipamento e paleta coerentes com a referência fornecida. O guardião utiliza armadura e elmo.
- **Apresentação:** interface, efeitos elementais, diálogos e música original integrados em Godot 4.6.3 standard.

Referências consultadas:

| Projeto | Origem | Revisão consultada |
| --- | --- | --- |
| Cartoon Terrain Studio | https://github.com/idlerunner00/cartoon-terrain-studio | `7aa76ad58d4a31c4a9441f5718e8c3a31d6349a1` |
| Procedural Pixel Creatures | https://github.com/idlerunner00/procedural-pixel-creatures | `a2207c4bd6f1be51d426684cf58f11668def7579` |

Os dois projetos são distribuídos sob licença MIT. Os avisos adicionais de terceiros foram preservados. O gerador de terreno/editor C# completo não foi transplantado; o pacote final contém a experiência de introdução.

## Arquivos e distribuição

`intro/intro.tscn` é a cena inicial. `intro/intro.gd` controla apresentação, deslocamento e história. `intro/intro_model.gd` contém as regras. `intro/terrain.gd` desenha e valida o terreno. `intro/creatures/` contém sprites e adaptação de animações. `tools/creature_generator/` permite reproduzir as imagens.

`scripts/build_intro.sh` exige os testes de modelo e fluxo, exporta os executáveis com PCK incorporado, reúne licenças e gera ZIPs com SHA256. Os testes automáticos não substituem a validação nativa em cada sistema. Os pacotes Windows são exportados a partir do Linux.

A distribuição é para desktop Windows/Linux. O controle de toque está no jogo; um aplicativo Android/iOS não faz parte desta entrega.

## Continuidade possível

Esta abertura estabelece visual, controles e identidade. Próximas etapas podem ampliar as diferenças entre elementos, dar mais personalidade aos inimigos, aumentar as animações de William e introduzir equipamentos e companheiros controláveis. Essas possibilidades ainda não estão implementadas e podem ser escolhidas a partir da experiência com a introdução.
