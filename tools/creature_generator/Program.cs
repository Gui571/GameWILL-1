using System;
using System.IO;
using System.Collections.Generic;
using PixelCreatures.Core;
using PixelCreatures.Core.Export;
using PixelCreatures.Core.Genetics;
using PixelCreatures.Core.Serialization;

class Program
{
    static CreatureRegistry reg = CreatureRegistry.CreateDefault();
    static CreatureGenome Template(string family,string form,ulong seed)
    {
        var f=reg.GetFamily(family);var g=GenomeFactory.Sample(f,seed);var values=g.CopyValues();
        f.SampleAnatomy(values,Rng.Derive(seed,"anatomy"),form);
        return g.WithValues(values).WithChoice("form",form).With("color.outline",0.65);
    }
    static void Main(string[] args)
    {
        reg.DiscoverExtensions(typeof(Program).Assembly);
        var output=Path.GetFullPath(args.Length>0?args[0]:"../../intro/creatures");Directory.CreateDirectory(output);
        var fox=Template("quadruped","canine",571).WithName("Raposa das Lanternas")
            .With("size",0.37).With("mass",0.25).With("color.hue",74).With("color.saturation",0.64).With("color.value",0.65)
            .With("color.glow",0.9).With("color.eyeHue",190).WithChoice("head.eyeStyle","glow")
            .WithChoice("head.horns","none").WithChoice("tail.tip","fluffy").With("tail.length",0.8).With("head.earSize",0.72);
        var moth=Template("winged","moth",927).WithName("Mariposa dos Ecos")
            .With("size",0.4).With("color.hue",198).With("color.saturation",0.49).With("color.value",0.76)
            .With("color.glow",0.8).With("color.eyeHue",190).WithChoice("wings.pattern","eyespot");
        var plant=Template("plantfolk","mushroom",364).WithName("Cogumelo Errante")
            .With("size",0.32).With("color.leafHue",166).With("color.clothHue",210).WithChoice("cap.style","glowcap")
            .With("color.glow",0.9).With("color.eyeHue",183).WithChoice("face.eyeStyle","glow");
        var guardian=Template("biped","golem",1844).WithName("Cavaleiro do Limiar")
            .With("size",0.82).With("mass",0.68).With("posture",0.02)
            .With("torso.length",0.35).With("torso.shoulders",0.85).With("torso.belly",0.05)
            .With("legs.length",0.68).With("legs.thickness",0.65).WithChoice("legs.stance","plantigrade")
            .With("head.size",0.26).With("head.snout",0).With("head.nose",0.06).With("head.jaw",0.15)
            .With("head.beard",0).WithChoice("head.ears","none").WithChoice("head.horns","none")
            .WithChoice("head.teeth","none").WithChoice("head.eyeStyle","glow")
            .With("arms.length",0.4).With("arms.thickness",0.6).With("arms.hands",0.35).With("arms.claws",0)
            .WithChoice("gear.weapon","spear").With("gear.size",0.88).WithChoice("gear.outfit","armor")
            .WithChoice("gear.helmet","helmet").With("gear.pauldrons",1).With("gear.shield",1)
            .WithChoice("back.feature","crystals").With("back.size",0.34).WithChoice("tail.kind","none")
            .With("color.hue",190).With("color.saturation",0.2).With("color.value",0.45)
            .With("color.clothHue",185).With("color.clothSaturation",0.4).With("color.clothValue",0.27)
            .WithChoice("color.metal","steel").With("color.glow",0.7).With("color.eyeHue",180)
            .WithChoice("pattern.type","none");
        var william=Template("biped","dwarf",57117).WithName("William")
            .With("hero.william",1).With("size",0.56).With("mass",0.46).With("posture",0.0).With("legs.length",0.68).With("legs.thickness",0.34).WithChoice("legs.stance","plantigrade")
            .With("torso.length",0.32).With("torso.shoulders",0.72).With("torso.belly",0.03)
            .With("head.size",0.27).With("head.snout",0.0).With("head.jaw",0.20).With("head.brow",0.17)
            .With("head.nose",0.18).With("head.beard",0.0).With("head.earSize",0.12).WithChoice("head.ears","round")
            .WithChoice("head.teeth","none").WithChoice("head.horns","none").WithChoice("tail.kind","none")
            .WithChoice("gear.weapon","dagger").With("gear.size",0.98).WithChoice("gear.outfit","tunic")
            .WithChoice("gear.helmet","none").With("gear.pauldrons",1).With("gear.shield",0)
            .WithChoice("back.feature","none").With("back.size",0.58)
            .With("arms.length",0.4).With("arms.thickness",0.34).With("arms.hands",0.23).With("arms.claws",0)
            .With("color.hue",64).With("color.saturation",0.25).With("color.value",0.74)
            .With("color.clothHue",59).With("color.clothSaturation",0.37).With("color.clothValue",0.29)
            .With("color.hairHue",90).With("color.hairSaturation",0.73).With("color.hairValue",0.75)
            .With("color.eyeHue",205).With("color.glow",0).WithChoice("pattern.type","none");
        foreach(var pair in new[]{("fox",fox),("moth",moth),("plant",plant),("guardian",guardian),("william",william)})
        {
            Console.WriteLine("Generating "+pair.Item1);
            var model=new CreatureFactory(reg).Build(pair.Item2);
            var opts=new SpritesheetOptions{Clips=new List<ClipKind>{ClipKind.Idle,ClipKind.Walk,ClipKind.Action},Fps=6,Quality=1,DrawShadow=false,Padding=2,MaxPageSize=4096};
            var result=SpritesheetExporter.Export(model,reg,opts,pair.Item1);
            for(int i=0;i<result.Pages.Count;i++){
                var p=result.Pages[i];var name=result.Pages.Count==1?pair.Item1:pair.Item1+"_"+i;
                File.WriteAllBytes(Path.Combine(output,name+".png"),PngEncoder.Encode(p.rgba,p.width,p.height));
            }
            File.WriteAllText(Path.Combine(output,pair.Item1+".json"),result.MetadataJson);
            File.WriteAllText(Path.Combine(output,pair.Item1+".genome.json"),new GenomeSerializer(reg).Serialize(pair.Item2));
            Console.WriteLine($"{pair.Item1}: {result.TotalFrames} frames {result.FrameWidth}x{result.FrameHeight} origin {result.OriginX},{result.OriginY}");
        }
    }
}
