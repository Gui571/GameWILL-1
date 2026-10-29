using System;
using System.Linq;
using William.Core;

class Program {
    static int checks;
    static void Check(bool ok,string message) {checks++; if(!ok)throw new Exception(message);}
    static void Near(float actual,float expected,string message) => Check(Math.Abs(actual-expected)<.01f,message+": "+actual+" != "+expected);
    static void Run(Battle battle,float seconds) {for(int frame=0;frame<(int)(seconds*60);frame++)battle.Tick(1f/60);}
    static void Quiet(Battle battle) {battle.Auto=false;foreach(var unit in battle.Units)if(unit!=battle.Hero)unit.Period=1000;}
    static bool Event(Battle battle,string kind,string target="") => battle.Events.Any(e=>e.Kind==kind && (target=="" || e.Target==target));
    static void Main() {
        InputsAndResources(); ElementalCombat(); PartyAndEnemyBehavior(); BossAndOutcome(); CampaignBalance(); Determinism();
        Console.WriteLine($"PASS: {checks} combat assertions; targeting, elemental combos, party protection, boss phases, nine upgrade routes and determinism.");
    }
    static void InputsAndResources() {
        var b=new Battle(); Check(b.Basic(),"manual basic"); Near(b.Energy,47,"basic regenerates energy");
        Check(!b.Basic(),"basic cooldown prevents duplicate hit"); Check(!b.Select("lyra"),"allies cannot be attack targets");
        Check(!b.Select("missing"),"unknown target rejected"); Check(b.Select("enemy1"),"select enemy");
        float health=b.Target.Hp; Check(b.Cast(Power.Flame),"flame casts"); Near(b.Target.Hp,health-60,"flame hits selected target");
        float energy=b.Energy; Check(!b.Cast(Power.Flame),"cooldown rejects cast"); Near(b.Energy,energy,"rejected cast spends nothing");
        b=new Battle(); b.Energy=19; Check(!b.Cast(Power.Frost),"insufficient energy rejects frost"); Near(b.Energy,19,"rejection preserves energy");
        b.Energy=99; b.Basic(); Near(b.Energy,100,"energy is capped");
        b.Paused=true; health=b.Hero.Hp; float elapsed=b.Elapsed; Run(b,10); Near(b.Elapsed,elapsed,"pause freezes time");
        Near(b.Hero.Hp,health,"pause freezes health"); Check(!b.Cast(Power.Aegis)&&!b.Basic()&&!b.Select("enemy1"),"pause blocks combat commands");
        b=new Battle(); b.Tick(float.NaN); b.Tick(float.PositiveInfinity); b.Tick(-1); b.Tick(0); Near(b.Elapsed,0,"invalid deltas ignored");
        Check(!b.Cast((Power)99)&&!b.Cast((Power)(-1)),"invalid powers rejected safely");
        b.Tick(30); Near(b.Elapsed,1,"resume catchup capped at one second");
        b=new Battle(-1,-100,-100,-100); Near(b.Hero.MaxHp,200,"negative upgrade counts clamped"); Check(b.Units.Count==5,"invalid negative encounter clamps to opening");
    }
    static void ElementalCombat() {
        var b=new Battle(); Quiet(b); b.Energy=100; var target=b.Target;
        target.Windup=.7f; target.IntentTarget="william"; target.Intent="Golpe";
        Check(b.Cast(Power.Frost),"frost succeeds during telegraph");
        Near(target.Windup,0,"frost cancels telegraph"); Near(target.Frozen,3,"frost applies freeze");
        Check(target.IntentTarget=="" && target.Intent=="","interrupt clears locked intent");
        Near(b.Energy,88,"well-timed interrupt refunds eight energy"); Check(b.Interrupts==1&&Event(b,"interrupt"),"interrupt counted and announced");
        float hp=target.Hp; Check(b.Cast(Power.Flame),"flame follows frost"); Near(hp-target.Hp,95,"frozen target takes shatter bonus");
        Near(target.Frozen,0,"flame consumes freeze"); Check(b.Combos==1&&Event(b,"combo"),"combo recorded");
        Run(b,4.05f); Check(b.Cooldowns[0]==0,"flame cooldown expires");
        b=new Battle(); Quiet(b); b.Energy=100; b.Cast(Power.Frost); Check(b.Interrupts==0,"freezing an idle enemy is not an interrupt");
        Near(b.Energy,80,"idle freeze has no refund"); Run(b,2.5f); Check(b.Target.Frozen>0,"freeze lasts through interval");
        Run(b,.6f); Near(b.Target.Frozen,0,"freeze naturally expires");
        b=new Battle(); Quiet(b); b.Energy=100; b.Cast(Power.Aegis);
        foreach(var ally in b.Units.Where(u=>u.Side==Side.Heroes)) {Near(ally.Shield,45,"aegis shields every living ally");Near(ally.ShieldTime,8,"shield has fixed lifetime");}
        float oldHp=b.Hero.Hp; var foe=b.Units[3];foe.Windup=.2f;foe.IntentTarget=b.Hero.Id;Run(b,.3f);
        Near(b.Hero.Hp,oldHp,"shield absorbs enemy hit");Near(b.Hero.Shield,33,"shield consumes absorbed damage");
        Run(b,7.8f); foreach(var ally in b.Units.Where(u=>u.Side==Side.Heroes))Near(ally.Shield,0,"unused shield expires");
        Check(Event(b,"shield_expire"),"shield expiry exposed to presentation");
    }
    static void PartyAndEnemyBehavior() {
        var b=new Battle(); b.Auto=false; Run(b,3.25f); Check(Event(b,"light"),"healthy party makes Lyra attack rather than heal zero");
        b=new Battle(); Quiet(b); b.Units[1].Period=3.2f;b.Hero.Hp=150;b.Units[2].Hp=30;
        Run(b,3.25f);Near(b.Units[2].Hp,54,"healer prioritizes lowest health fraction");Near(b.Hero.Hp,150,"healer does not blindly heal William");
        Near(b.HealingDone,24,"effective healing tracked");
        b=new Battle(1); b.Auto=false; Run(b,6);Check(Event(b,"enemy","lyra"),"caster attacks Lyra");Check(Event(b,"enemy","bruma"),"raider attacks Bruma");
        b=new Battle(1);Quiet(b);var caster=b.Units[4];caster.Period=.2f;Run(b,.25f);Check(caster.IntentTarget=="lyra","enemy locks telegraph target");
        b.Units[1].Hp=0;float heroHp=b.Hero.Hp;Run(b,1.2f);Near(b.Hero.Hp,heroHp,"fallen announced target does not redirect a surprise hit");
        b=new Battle();Quiet(b);b.Units[1].Hp=0;b.Energy=100;b.Cast(Power.Aegis);Near(b.Units[1].Shield,0,"dead allies receive no shield");
        var dead=b.Units[3];dead.Hp=1;b.Select(dead.Id);b.Basic();Check(!dead.Alive&&Event(b,"down",dead.Id),"death emitted once");
        Check(b.Target.Id=="enemy1","target falls back to next living enemy");Check(!b.Select(dead.Id),"dead target rejected");
    }
    static void BossAndOutcome() {
        var b=new Battle(2);Quiet(b);var boss=b.Units[3];Check(boss.IsBoss,"final encounter contains a boss");
        boss.Hp=boss.MaxHp*.5f+1;b.Basic();Check(boss.Enraged&&Event(b,"enrage"),"boss enters phase two at half health");
        b.Hero.Clock=0;b.Basic();Check(b.Events.Count(e=>e.Kind=="enrage")==1,"enrage only announced once");
        boss.Period=.2f;Run(b,.3f);Check(boss.Intent=="Onda do Limiar"&&boss.Windup>1,"enraged boss announces team attack with longer warning");
        Run(b,2);foreach(string id in new[]{"william","lyra","bruma"})Check(Event(b,"enemy",id),"boss wave damages "+id);
        b=new Battle();Quiet(b);b.Hero.Hp=1;var enemy=b.Units[3];enemy.Windup=.1f;enemy.IntentTarget="william";Run(b,.2f);
        Check(b.Lost&&b.Finished&&!b.Won,"William's defeat ends the encounter");
        Check(!b.Basic()&&!b.Cast(Power.Flame),"defeat blocks attacks");float elapsed=b.Elapsed;Run(b,3);Near(b.Elapsed,elapsed,"defeat stops simulation");
        b=new Battle();Quiet(b);foreach(var u in b.Units.Where(u=>u.Side==Side.Enemies))u.Hp=0;
        Check(b.Won&&b.Finished&&!b.Lost,"all enemies defeated means victory");
        Check(!b.Basic()&&!b.Cast(Power.Aegis),"victory blocks further commands");
    }
    static void PlayActively(Battle b) {
        for(int frame=0;frame<60*180&&!b.Finished;frame++) {
            var threat=b.Units.Find(u=>u.Side==Side.Enemies&&u.Alive&&u.Windup>0);
            if(threat!=null&&b.CanCast(Power.Frost)=="") {b.Select(threat.Id);b.Cast(Power.Frost);}
            if(b.Target!=null&&b.Target.Frozen>0&&b.CanCast(Power.Flame)=="")b.Cast(Power.Flame);
            else if(b.Energy>=65)b.Cast(Power.Aegis);
            else if(b.Energy>=45)b.Cast(Power.Flame);
            b.Tick(1f/60);b.Events.Clear();
        }
    }
    static void CampaignBalance() {
        float shortest=999,longest=0;
        for(int first=0;first<3;first++)for(int second=0;second<3;second++) {
            int[] upgrades=new int[3];
            for(int encounter=0;encounter<3;encounter++) {
                var b=new Battle(encounter,upgrades[0],upgrades[1],upgrades[2]);PlayActively(b);
                Check(b.Won&&!b.Lost,$"upgrade route {first}/{second}, encounter {encounter} is winnable");
                Check(b.Hero.Hp>0&&b.Energy>=0&&b.Energy<=100,"survivor/resources valid");
                Check(b.Units.All(u=>u.Hp>=0&&u.Hp<=u.MaxHp&&u.Shield>=0),"all health/shield bounded");
                shortest=Math.Min(shortest,b.Elapsed);longest=Math.Max(longest,b.Elapsed);
                if(encounter<2)upgrades[encounter==0?first:second]++;
            }
        }
        var opening=new Battle();Run(opening,120);Check(opening.Won,"opening remains approachable with auto attacks only");
        Console.WriteLine($"Active encounters across all upgrade routes: {shortest:0.0}–{longest:0.0}s; auto-only opening: {opening.Elapsed:0.0}s.");
    }
    static void Determinism() {
        var a=new Battle(1);var b=new Battle(1);Run(a,10);Run(b,10);
        for(int i=0;i<a.Units.Count;i++) {Near(a.Units[i].Hp,b.Units[i].Hp,"deterministic health");Near(a.Units[i].Windup,b.Units[i].Windup,"deterministic windup");}
        Near(a.Energy,b.Energy,"deterministic energy");
        a=new Battle();Quiet(a);b=new Battle();Quiet(b);Run(a,6);for(int i=0;i<6;i++)b.Tick(1);
        Near(a.Elapsed,b.Elapsed,"substep equivalence");
    }
}
