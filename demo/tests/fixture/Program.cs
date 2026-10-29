using System;
using System.Collections.Generic;
using System.Text.Json;
using William.Core;
using System.IO;
using System.Security.Cryptography;
class Program {
 static object State(int frame,Battle b) => new { Frame=frame,b.Energy,b.Elapsed,b.DamageDealt,b.HealingDone,b.Interrupts,b.Combos,b.Won,b.Lost,b.Selected,b.Auto,b.Paused,b.Cooldowns,b.Units,Events=b.Events.ToArray() };
 static void Main(string[] args){
  var scenarios=new List<object>();
  for(int scenario=0;scenario<5;scenario++){
   int encounter=scenario%3;var b=new Battle(encounter,encounter,0,0);var snapshots=new List<object>();
   for(int frame=0;frame<7200;frame++){
    b.Paused=frame>=120&&frame<180;
    if(frame==90)b.Select("enemy1");if(frame==240)b.Select("enemy0");
    if(scenario==4){b.Auto=false;if(frame%100==0)b.Basic();}
    else if(scenario!=1&&!b.Paused){
     if(b.Target!=null&&b.Target.Windup>0)b.Cast(Power.Frost);
     else if(b.Target!=null&&b.Target.Frozen>0)b.Cast(Power.Flame);
     else if(b.Energy>=80)b.Cast(Power.Aegis);
     else if(b.Energy>=50)b.Cast(Power.Flame);
    }
    b.Tick(frame%73==0?.1f:1f/60);
    if(frame%30==0||b.Finished){
     // Deep serialize now: objects are mutable and must not leak into later snapshots.
     snapshots.Add(JsonSerializer.Deserialize<JsonElement>(JsonSerializer.Serialize(State(frame,b),new JsonSerializerOptions{IncludeFields=true})));
     b.Events.Clear();
    }
    if(b.Finished)break;
   }
   scenarios.Add(new { Scenario=scenario,Encounter=encounter,Snapshots=snapshots });
  }
  string source=args.Length>0?args[0]:"unity/Assets/William/Core/Battle.cs";
  Console.WriteLine(JsonSerializer.Serialize(new {Source="unity/Assets/William/Core/Battle.cs",Sha256=Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(source))).ToLowerInvariant(),Scenarios=scenarios}));
 }
}
