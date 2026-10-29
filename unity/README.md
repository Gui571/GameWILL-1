# William — introdução em Unity

Primeira implementação Unity independente da versão Godot. O combate em C# tem três integrantes, alvo selecionável, ataques automáticos ou manuais, Chama, Geada com interrupção, Égide com escudo de equipe, cura automática, três encontros, melhorias entre encontros, derrota e encerramento. A apresentação usa temporariamente as sprites procedurais já licenciadas do projeto; Lyra usa a forma de uma mariposa luminosa e Bruma a de uma raposa.

**Estado:** regras compiladas e testadas em .NET 8. O editor Unity não está instalado neste ambiente; cenas, importação, áudio, apresentação, entrada por toque e builds ainda precisam de validação no Unity. Não existe um novo executável Unity nesta entrega. O ZIP Windows em `../downloads` continua sendo a versão Godot 0.2.

## Abrir e executar

1. Instale Unity 6.0 LTS pelo Unity Hub, incluindo Windows Build Support para exportação Windows. O projeto fixa inicialmente `6000.0.23f1`; patches diferentes devem passar por importação e validação antes de atualizar essa referência.
2. Adicione **esta pasta `unity/`** como projeto no Hub.
3. Abra `Assets/William/Scenes/Introduction.unity` e pressione Play. O ponto de entrada cria a apresentação automaticamente ao carregar a cena.
4. Inicie a introdução, avance os diálogos e toque/clique em um inimigo para selecionar o alvo. Os botões inferiores controlam Auto, Corte, Chama, Geada e Égide. A barra superior controla som e pausa.
5. Escolha uma melhoria após cada vitória. O terceiro encontro termina no portal de Aurora.

A apresentação inicial usa IMGUI, spritesheets e coordenadas de referência 1280×720 com ajuste proporcional. É uma camada temporária para integração: a interface final de celular deverá passar para Canvas/UI Toolkit com áreas seguras, acessibilidade e testes físicos. O suporte Android ainda não foi configurado ou exportado.

## Compilar Windows

No editor, use **William → Build Windows introduction**. O resultado vai para `Build/Windows/William.exe`, acompanhado dos arquivos de dados obrigatórios. Distribua a pasta completa. O build exige editor e licença válidos e o módulo de destino instalado.

Linha de comando, usando o caminho do seu editor:

```bash
Unity -batchmode -quit -projectPath /caminho/GameWILL-1/unity \
  -executeMethod WilliamBuild.Windows -logFile build.log
```

## Validar as regras sem Unity

```bash
dotnet run --project Tests/William.Core.Tests.csproj -c Release
```

46 verificações exercitam dano, energia, recargas, alvos, pausa, cura, interrupção, escudo, vitória nos três encontros, derrota, entradas inválidas e repetição determinística. Esses testes não verificam APIs ou renderização Unity.

## Estrutura

- `Assets/William/Core`: regras independentes do motor, compiladas em assembly sem referências Unity. A apresentação consome eventos de combate.
- `Assets/William/Runtime`: fluxo da introdução, leitura de atlas, animações, interface e efeito sonoro original.
- `Assets/William/Editor`: importação pixel art sem redimensionar atlas e comando de build.
- `Assets/William/Resources/Art`: material temporário e seus avisos de licença.

## Direção aprovada e avaliação

- **Dragon Crashers:** referência de apresentação e leitura de combate. Nenhum código ou recurso gráfico desse projeto foi copiado.
- **Mana Seed:** candidata artística. Nenhum pacote foi comprado ou incorporado. Escolher um pacote com as animações necessárias e confirmar sua licença antes de substituir as sprites.
- **Fluid Behavior Tree:** biblioteca MIT avaliada pela documentação. A equipe inicial precisa de poucas prioridades (curar o integrante mais ferido, atacar o alvo selecionado e anunciar golpes). Implementação direta nesta etapa evita dependência desnecessária. Reavaliar a biblioteca quando houver movimentação, ameaças e árvores de decisão mais complexas; não está instalada.
- **Unity Gameplay Ability System:** referência conceitual para atributos, custos, recargas e efeitos. O projeto de referência está arquivado; esta implementação foi escrita para William e não copia seu código. O sistema atual ainda não é um editor genérico de habilidades ou inventário.

A arte definitiva, movimento pelo cenário, equipamentos visíveis, dados editáveis de habilidades e otimização Android são etapas seguintes. Esta implementação entrega o fluxo de introdução e o núcleo de combate para validação no editor, não uma migração completa de todos os recursos Godot.
