# Adaptations for William: Limiar de Aurora

Upstream: https://github.com/idlerunner00/procedural-pixel-creatures
Commit: a2207c4bd6f1be51d426684cf58f11668def7579
Copyright and MIT license: see vendor/LICENSE and vendor/THIRD_PARTY_NOTICES.md.

The upstream engine-independent core and Plantfolk extension are included with their notices. Program.cs selects five reproducible genomes, exports eight-direction idle/walk/action sprite atlases and retains their metadata. BipedFamily.cs has a William-specific genome flag that adds blonde hair, a traveling coat and fur mantle, dark boots and a longer blade using the existing animated skeleton. The guardian uses the built-in biped golem family with armor, helmet, spear and shield. These are original character adaptations; they do not reproduce the supplied sprite sheet pixel for pixel.

The game loads exported PNG and JSON files and does not require .NET at runtime. Godot's terrain renderer is an original GDScript implementation visually informed by Cartoon Terrain Studio, whose attribution is in docs/references/.
