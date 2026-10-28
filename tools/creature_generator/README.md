# Procedural creature sprites for William

This tool generates the five actors in `intro/creatures/` from deterministic genomes using the actual MIT-licensed [Procedural Pixel Creatures](https://github.com/idlerunner00/procedural-pixel-creatures) framework by idlerunner00. It does not need Godot .NET or online services. The source core and Plantfolk extension are vendored under `vendor/`, with upstream license and notices preserved.

Requires .NET SDK 8 (local verified cloud SDK: `/workspace/.tools/dotnet/dotnet`). From the repository root:

```sh
DOTNET_CLI_HOME=/tmp/william-dotnet-cli /workspace/.tools/dotnet/dotnet run -c Release --project tools/creature_generator -- intro/creatures
```

Each actor has a reproducible genome, transparent PNG atlas and JSON metadata. Idle, walk and action animations are exported in eight directions at 6 fps. Motion originates from the framework's skeleton/locomotion simulation. Godot reads these assets through `intro/creatures/sprite_library.gd`; players need neither .NET nor the generator installed.

`Program.cs` owns the five curated seeds and art direction. The fauna and guardian are native framework families. William is an adapted biped inspired by the creator's visual reference, not a pixel-for-pixel reproduction of the attached sheet.
