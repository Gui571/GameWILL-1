using System;
using William.Core;
class Program {
 static int checks;
 static void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
 static void Run(Battle b,float time){for(int i=0;i<(int)(time*60);i++)b.Tick(1f/60);}
 static void Main(){
  var b=new Battle();Check(b.Basic(),"manual basic");Check(b.Energy==47,"energy gained");Check(!b.Basic(),"basic cooldown");
  Check(!b.Select("lyra"),"cannot target ally");Check(b.Select("enemy1"),"select target");
  float before=b.Target.Hp;Check(b.Cast(Power.Flame),"flame casts");Check(b.Target.Hp==before-60,"selected target damage");
  before=b.Energy;Check(!b.Cast(Power.Flame)&&b.Energy==before,"rejected cast spends no resource");
  b=new Battle();b.Paused=true;Run(b,5);Check(b.Elapsed==0&&b.Hero.Hp==200,"pause freezes simulation");Check(!b.Cast(Power.Frost),"paused cast blocked");
  b.Paused=false;b.Auto=false;Run(b,3.5f);Check(b.Units[3].Windup>0,"enemy telegraph");
  Check(b.Cast(Power.Frost),"frost casts");Check(b.Units[3].Windup==0&&b.Units[3].Frozen==3,"frost interrupts");
  b=new Battle();b.Energy=100;Check(b.Cast(Power.Aegis),"aegis casts");Check(b.Hero.Shield==45&&b.Units[1].Shield==45,"party shield");
  b=new Battle();b.Hero.Hp=100;Run(b,3.5f);Check(b.Hero.Hp>100,"healer prioritizes injured hero");
  for(int encounter=0;encounter<3;encounter++){
   b=new Battle(encounter,encounter,0,0);
   for(int frame=0;frame<60*180&&!b.Finished;frame++){
    if(b.Energy>=65)b.Cast(Power.Aegis);
    else if(b.Target!=null&&b.Target.Windup>0)b.Cast(Power.Frost);
    else if(b.Energy>=45)b.Cast(Power.Flame);
    b.Tick(1f/60);b.Events.Clear();
   }
   Check(b.Won&&!b.Lost,"encounter winnable "+encounter);Check(b.Hero.Hp>0,"hero survives");
   foreach(var u in b.Units)Check(u.Hp>=0&&u.Shield>=0,"bounded health/shield");
   before=b.Energy;Check(!b.Cast(Power.Flame)&&b.Energy==before,"completed combat blocked");
  }
  b=new Battle();b.Hero.Hp=1;b.Auto=false;Run(b,30);Check(b.Lost,"defeat reachable");
  b=new Battle();b.Tick(float.NaN);b.Tick(-2);b.Tick(float.PositiveInfinity);Check(b.Elapsed==0,"invalid delta rejected");Check(!b.Cast((Power)99),"unknown power rejected");
  var a=new Battle();var c=new Battle();Run(a,10);Run(c,10);Check(a.Hero.Hp==c.Hero.Hp&&a.Energy==c.Energy,"deterministic replay");
  Console.WriteLine($"PASS: {checks} combat assertions");
 }
}
