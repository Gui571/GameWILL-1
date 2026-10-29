using System;
using System.Collections.Generic;
namespace William.Core {
public enum Side { Heroes, Enemies }
public enum Power { Flame, Frost, Aegis }
public sealed class Unit {
    public string Id, Name, Art;
    public Side Side;
    public float Hp, MaxHp, Shield, Attack, Period, Clock, Frozen, Windup;
    public bool Alive => Hp > 0;
    public Unit(string id,string name,string art,Side side,float hp,float attack,float period) {
        Id=id;Name=name;Art=art;Side=side;Hp=MaxHp=hp;Attack=attack;Period=period;
    }
}
public sealed class BattleEvent {
    public string Kind, Source, Target; public float Amount;
    public BattleEvent(string kind,string source,string target,float amount=0) {Kind=kind;Source=source;Target=target;Amount=amount;}
}
// Engine-independent simulation: presentation consumes events; no Unity or animation dependencies.
public sealed class Battle {
    public readonly List<Unit> Units=new List<Unit>();
    public readonly List<BattleEvent> Events=new List<BattleEvent>();
    public readonly float[] Cooldowns=new float[3];
    public float Energy=35, Elapsed;
    public bool Auto=true, Paused;
    public string Selected="";
    public bool Won => Units.FindAll(x=>x.Side==Side.Enemies).TrueForAll(x=>!x.Alive);
    public bool Lost => !Hero.Alive;
    public bool Finished => Won || Lost;
    public Unit Hero => Units[0];
    public Battle(int encounter=0,int strength=0,int vitality=0,int focus=0) {
        Units.Add(new Unit("william","William","william",Side.Heroes,200+vitality*45,18+strength*5,1.3f));
        Units.Add(new Unit("lyra","Lyra · luz","moth",Side.Heroes,130,12,3.4f));
        Units.Add(new Unit("bruma","Bruma · gelo","fox",Side.Heroes,150,10,2.1f));
        int count=encounter==0?2:3;
        for(int i=0;i<count;i++) Units.Add(new Unit("enemy"+i,encounter==2&&i==0?"Guardião do Limiar":"Sentinela "+(i+1),"guardian",Side.Enemies,(encounter==2&&i==0?400:150)+encounter*35,12+encounter*3,3.4f+i*.7f));
        Selected=Units[3].Id;Energy=Math.Min(100,Energy+focus*15);
    }
    public Unit Target => Units.Find(x=>x.Id==Selected&&x.Alive&&x.Side==Side.Enemies) ?? Units.Find(x=>x.Alive&&x.Side==Side.Enemies);
    public bool Select(string id) {var u=Units.Find(x=>x.Id==id&&x.Alive&&x.Side==Side.Enemies);if(u==null)return false;Selected=id;return true;}
    public float Cost(Power p) => p==Power.Flame?25:p==Power.Frost?20:65;
    public string CanCast(Power p) {
        if((int)p<0||(int)p>2)return "Técnica desconhecida";
        if(Paused||Finished)return "Combate indisponível";
        if(Cooldowns[(int)p]>.001f)return "Recarregando";
        if(Energy<Cost(p))return "Energia insuficiente";
        return "";
    }
    public bool Cast(Power p) {
        if(CanCast(p)!="")return false;
        Energy-=Cost(p);Cooldowns[(int)p]=p==Power.Flame?4:p==Power.Frost?7:12;
        var target=Target;
        if(p==Power.Flame) Damage(Hero,target,60,"flame");
        if(p==Power.Frost) {target.Frozen=3;target.Windup=0;target.Clock=0;Damage(Hero,target,26,"frost");}
        if(p==Power.Aegis) {
            foreach(var u in Units)if(u.Alive&&u.Side==Side.Heroes)u.Shield=Math.Min(100,u.Shield+45);
            Damage(Hero,target,75,"aegis");
        }
        return true;
    }
    public bool Basic() {
        if(Paused||Finished||Hero.Clock>0)return false;
        Hero.Clock=Hero.Period;Damage(Hero,Target,Hero.Attack,"hit");Energy=Math.Min(100,Energy+12);return true;
    }
    public void Tick(float dt) {
        if(float.IsNaN(dt)||float.IsInfinity(dt)||dt<=0||Paused||Finished)return;
        float remaining=Math.Min(dt,1);
        while(remaining>.00001f&&!Finished){float step=Math.Min(remaining,1f/60);Step(step);remaining-=step;}
    }
    void Step(float dt) {
        Elapsed+=dt;for(int i=0;i<3;i++)Cooldowns[i]=Math.Max(0,Cooldowns[i]-dt);
        Hero.Clock=Math.Max(0,Hero.Clock-dt);if(Auto)Basic();
        foreach(var u in Units) {
            if(!u.Alive||u==Hero||Finished)continue;
            if(u.Frozen>0){u.Frozen=Math.Max(0,u.Frozen-dt);continue;}
            if(u.Windup>0){u.Windup=Math.Max(0,u.Windup-dt);if(u.Windup==0){Damage(u,Hero,u.Attack,"enemy");u.Clock=0;}continue;}
            u.Clock+=dt;if(u.Clock<u.Period)continue;u.Clock=0;
            if(u.Side==Side.Enemies){u.Windup=1;Events.Add(new BattleEvent("charge",u.Id,Hero.Id));}
            else if(u.Id=="lyra"){
                var wounded=Hero;
                foreach(var ally in Units)if(ally.Alive&&ally.Side==Side.Heroes&&ally.Hp/ally.MaxHp<wounded.Hp/wounded.MaxHp)wounded=ally;
                float healing=Math.Min(16,wounded.MaxHp-wounded.Hp);wounded.Hp+=healing;Events.Add(new BattleEvent("heal",u.Id,wounded.Id,healing));
            } else Damage(u,Target,u.Attack,"hit");
        }
    }
    void Damage(Unit source,Unit target,float amount,string kind) {
        if(target==null||!target.Alive)return;
        float absorbed=Math.Min(target.Shield,amount);target.Shield-=absorbed;
        float dealt=Math.Min(target.Hp,amount-absorbed);target.Hp-=dealt;
        Events.Add(new BattleEvent(kind,source.Id,target.Id,dealt));
        if(!target.Alive)Events.Add(new BattleEvent("down",source.Id,target.Id));
    }
}
}
