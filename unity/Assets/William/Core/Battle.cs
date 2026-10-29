using System;
using System.Collections.Generic;

namespace William.Core {
public enum Side { Heroes, Enemies }
public enum Power { Flame, Frost, Aegis }

public sealed class Unit {
    public string Id, Name, Art, Role, IntentTarget = "", Intent = "";
    public Side Side;
    public float Hp, MaxHp, Shield, ShieldTime, Attack, Period, Clock, Frozen, Windup;
    public bool Enraged, IsBoss;
    public int Attacks;
    public bool Alive => Hp > 0;
    public Unit(string id, string name, string art, Side side, float hp, float attack, float period) {
        Id=id; Name=name; Art=art; Side=side; Hp=MaxHp=hp; Attack=attack; Period=period; Role="striker";
    }
}

public sealed class BattleEvent {
    public string Kind, Source, Target;
    public float Amount;
    public BattleEvent(string kind,string source,string target,float amount=0) {
        Kind=kind; Source=source; Target=target; Amount=amount;
    }
}

// Deterministic combat simulation. It owns no Unity objects and never waits for animation.
// Events are append-only until the presentation consumes and clears them.
public sealed class Battle {
    public readonly List<Unit> Units = new List<Unit>();
    public readonly List<BattleEvent> Events = new List<BattleEvent>();
    public readonly float[] Cooldowns = new float[3];
    public float Energy=35, Elapsed, DamageDealt, HealingDone;
    public int Interrupts, Combos;
    public bool Auto=true, Paused;
    public string Selected="";
    public bool Won => Units.Find(x=>x.Side==Side.Enemies && x.Alive)==null;
    public bool Lost => !Hero.Alive;
    public bool Finished => Won || Lost;
    public Unit Hero => Units[0];
    public Unit Target => Units.Find(x=>x.Id==Selected && x.Alive && x.Side==Side.Enemies)
        ?? Units.Find(x=>x.Alive && x.Side==Side.Enemies);

    public Battle(int encounter=0,int strength=0,int vitality=0,int focus=0) {
        encounter=Math.Max(0,Math.Min(2,encounter));
        strength=Math.Max(0,Math.Min(20,strength)); vitality=Math.Max(0,Math.Min(20,vitality)); focus=Math.Max(0,Math.Min(20,focus));
        Units.Add(new Unit("william","William","william",Side.Heroes,200+vitality*45,18+strength*5,1.3f));
        Units.Add(new Unit("lyra","Lyra · luz","moth",Side.Heroes,135+vitality*12,12,3.2f){Role="healer"});
        Units.Add(new Unit("bruma","Bruma · gelo","fox",Side.Heroes,155+vitality*12,11,2.1f){Role="companion"});
        if(encounter==0) {
            Enemy("enemy0","Sentinela de bronze","guardian",185,12,3.4f,"guardian");
            Enemy("enemy1","Espinho errante","plant",160,10,4.1f,"raider");
        } else if(encounter==1) {
            Enemy("enemy0","Vigia das ruínas","guardian",250,16,3.5f,"guardian");
            Enemy("enemy1","Espinho arcano","plant",190,13,4.2f,"caster");
            Enemy("enemy2","Caçador de ecos","guardian",220,14,3.8f,"raider");
        } else {
            Enemy("enemy0","Guardião do Limiar","guardian",720,22,3.6f,"guardian");
            Units[3].IsBoss=true;
            Enemy("enemy1","Raiz do juramento","plant",180,12,4.5f,"caster");
            Enemy("enemy2","Vigia do portal","guardian",210,14,4.1f,"raider");
        }
        Selected=Units[3].Id; Energy=Math.Min(100,Energy+focus*15);
    }
    void Enemy(string id,string name,string art,float hp,float attack,float period,string role) {
        Units.Add(new Unit(id,name,art,Side.Enemies,hp,attack,period){Role=role});
    }
    public bool Select(string id) {
        var unit=Units.Find(x=>x.Id==id && x.Alive && x.Side==Side.Enemies);
        if(unit==null || Paused || Finished)return false;
        Selected=id; return true;
    }
    public float Cost(Power power) => power==Power.Flame?25:power==Power.Frost?20:65;
    public string CanCast(Power power) {
        if((int)power<0 || (int)power>2)return "Técnica desconhecida";
        if(Paused || Finished)return "Combate indisponível";
        if(Cooldowns[(int)power]>.00001f)return "Recarregando";
        if(Energy<Cost(power))return "Energia insuficiente";
        return "";
    }
    public bool Cast(Power power) {
        if(CanCast(power)!="")return false;
        Energy-=Cost(power);
        Cooldowns[(int)power]=power==Power.Flame?4:power==Power.Frost?7:12;
        var target=Target;
        if(power==Power.Flame) {
            bool shatter=target.Frozen>0;
            if(shatter){target.Frozen=0; Combos++; Emit("combo",Hero,target,35);}
            Damage(Hero,target,shatter?95:60,"flame");
        } else if(power==Power.Frost) {
            bool interrupt=target.Windup>0;
            target.Frozen=3; target.Windup=0; target.Clock=0; target.IntentTarget=""; target.Intent="";
            if(interrupt){Interrupts++; Emit("interrupt",Hero,target); Energy=Math.Min(100,Energy+8);}
            Damage(Hero,target,26,"frost");
        } else {
            foreach(var ally in Units)if(ally.Alive && ally.Side==Side.Heroes) {
                ally.Shield=Math.Min(90,ally.Shield+45); ally.ShieldTime=8;
                Emit("shield",Hero,ally,45);
            }
            Damage(Hero,target,75,"aegis");
        }
        return true;
    }
    public bool Basic() {
        if(Paused || Finished || Hero.Clock>.00001f)return false;
        Hero.Clock=Hero.Period; Damage(Hero,Target,Hero.Attack,"hit");
        Energy=Math.Min(100,Energy+12); return true;
    }
    public void Tick(float dt) {
        if(float.IsNaN(dt) || float.IsInfinity(dt) || dt<=0 || Paused || Finished)return;
        // A one-second ceiling prevents a suspended application from resolving a whole battle on resume.
        float remaining=Math.Min(dt,1);
        while(remaining>.000001f && !Finished) {
            float step=Math.Min(remaining,1f/60); Step(step); remaining-=step;
        }
    }
    void Step(float dt) {
        Elapsed+=dt;
        for(int i=0;i<3;i++)Cooldowns[i]=CountDown(Cooldowns[i],dt);
        foreach(var unit in Units)if(unit.Alive && unit.ShieldTime>0) {
            unit.ShieldTime=CountDown(unit.ShieldTime,dt);
            if(unit.ShieldTime==0){unit.Shield=0; Emit("shield_expire",unit,unit);}
        }
        Hero.Clock=CountDown(Hero.Clock,dt);
        if(Auto)Basic();
        foreach(var unit in Units) {
            if(!unit.Alive || unit==Hero || Finished)continue;
            if(unit.Frozen>0){unit.Frozen=CountDown(unit.Frozen,dt);continue;}
            if(unit.Windup>0) {
                unit.Windup=CountDown(unit.Windup,dt);
                if(unit.Windup==0)ResolveEnemyAttack(unit);
                continue;
            }
            unit.Clock+=dt;
            float period=unit.Enraged?unit.Period*.72f:unit.Period;
            if(unit.Clock+.00001f<period)continue;
            unit.Clock=0;
            if(unit.Side==Side.Enemies)BeginEnemyAttack(unit);
            else if(unit.Role=="healer")ActHealer(unit);
            else Damage(unit,Target,unit.Attack,"hit");
        }
    }
    static float CountDown(float value,float dt) {
        float next=value-dt; return next<.00001f?0:next;
    }
    void ActHealer(Unit healer) {
        Unit wounded=null;
        foreach(var ally in Units)if(ally.Alive && ally.Side==Side.Heroes && ally.Hp<ally.MaxHp-1 &&
            (wounded==null || ally.Hp/ally.MaxHp<wounded.Hp/wounded.MaxHp))wounded=ally;
        if(wounded==null){Damage(healer,Target,healer.Attack,"light");return;}
        float healing=Math.Min(24,wounded.MaxHp-wounded.Hp);
        wounded.Hp+=healing; HealingDone+=healing; Emit("heal",healer,wounded,healing);
    }
    Unit ChooseVictim(Unit enemy) {
        if(enemy.Role=="guardian")return Hero;
        if(enemy.Role=="caster")return Units.Find(x=>x.Id=="lyra" && x.Alive) ?? Hero;
        // Raiders rotate through living allies, so health bars and party protection matter.
        var alive=Units.FindAll(x=>x.Side==Side.Heroes && x.Alive);
        return alive[(enemy.Attacks+2)%alive.Count];
    }
    void BeginEnemyAttack(Unit enemy) {
        var victim=ChooseVictim(enemy);
        bool wave=enemy.IsBoss && enemy.Enraged && enemy.Attacks%2==0;
        enemy.IntentTarget=victim.Id;
        enemy.Intent=wave?"Onda do Limiar":"Golpe → "+victim.Name;
        enemy.Windup=wave?1.8f:1.1f;
        Emit("charge",enemy,victim);
    }
    void ResolveEnemyAttack(Unit enemy) {
        bool wave=enemy.Intent=="Onda do Limiar";
        var victim=Units.Find(x=>x.Id==enemy.IntentTarget && x.Alive);
        if(wave) {
            foreach(var ally in Units)if(ally.Side==Side.Heroes && ally.Alive)
                Damage(enemy,ally,enemy.Attack*.85f,"enemy");
        } else if(victim!=null)Damage(enemy,victim,enemy.Attack*(enemy.Enraged?1.25f:1),"enemy");
        // A fallen target cancels the already-announced hit instead of silently switching victim.
        enemy.Attacks++; enemy.Intent=""; enemy.IntentTarget=""; enemy.Clock=0;
    }
    void Damage(Unit source,Unit target,float amount,string kind) {
        if(target==null || !target.Alive)return;
        float absorbed=Math.Min(target.Shield,amount); target.Shield-=absorbed;
        float dealt=Math.Min(target.Hp,amount-absorbed); target.Hp-=dealt;
        if(source.Side==Side.Heroes)DamageDealt+=dealt;
        Emit(kind,source,target,dealt);
        if(!target.Alive) {
            target.Windup=0; target.Frozen=0; target.Shield=0; target.ShieldTime=0; target.Intent=""; target.IntentTarget="";
            Emit("down",source,target);
        } else if(target.IsBoss && !target.Enraged && target.Hp<=target.MaxHp*.5f) {
            target.Enraged=true; Emit("enrage",target,target);
        }
    }
    void Emit(string kind,Unit source,Unit target,float amount=0) {
        Events.Add(new BattleEvent(kind,source.Id,target.Id,amount));
    }
}
}
