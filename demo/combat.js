/** Browser companion to unity/Assets/William/Core/Battle.cs.
 * The Unity project is authoritative. Float32 arithmetic keeps decision timing
 * consistent with C#; tests compare snapshots against a .NET-generated fixture.
 * This browser module is not a Unity/WebGL export.
 */
const f = Math.fround;
const EPSILON = f(.00001);
export const Side = Object.freeze({Heroes: 0, Enemies: 1});
export const Power = Object.freeze({Flame: 0, Frost: 1, Aegis: 2});
export class Unit {
  constructor(id, name, art, side, hp, attack, period) {
    Object.assign(this, {Id:id, Name:name, Art:art, Side:side, Hp:f(hp), MaxHp:f(hp), Attack:f(attack), Period:f(period), Role:'striker', IntentTarget:'', Intent:'', Shield:0, ShieldTime:0, Clock:0, Frozen:0, Windup:0, Enraged:false, IsBoss:false, Attacks:0});
  }
  get Alive() { return this.Hp > 0; }
}
export class BattleEvent {
  constructor(kind, source, target, amount=0) {Object.assign(this,{Kind:kind,Source:source,Target:target,Amount:f(amount)});}
}
export class Battle {
  constructor(encounter=0, strength=0, vitality=0, focus=0) {
    const clamp=(value,max)=>Math.max(0,Math.min(max,Math.trunc(Number.isFinite(value)?value:0)));
    encounter=clamp(encounter,2);strength=clamp(strength,20);vitality=clamp(vitality,20);focus=clamp(focus,20);
    this.Units=[];this.Events=[];this.Cooldowns=[0,0,0];this.Energy=35;this.Elapsed=0;this.DamageDealt=0;this.HealingDone=0;this.Interrupts=0;this.Combos=0;this.Auto=true;this.Paused=false;this.Selected='';
    this.Units.push(new Unit('william','William','william',Side.Heroes,200+vitality*45,18+strength*5,1.3));
    this.Units.push(Object.assign(new Unit('lyra','Lyra · luz','moth',Side.Heroes,135+vitality*12,12,3.2),{Role:'healer'}));
    this.Units.push(Object.assign(new Unit('bruma','Bruma · gelo','fox',Side.Heroes,155+vitality*12,11,2.1),{Role:'companion'}));
    if(encounter===0) {
      this.Enemy('enemy0','Sentinela de bronze','guardian',185,12,3.4,'guardian');
      this.Enemy('enemy1','Espinho errante','plant',160,10,4.1,'raider');
    } else if(encounter===1) {
      this.Enemy('enemy0','Vigia das ruínas','guardian',250,16,3.5,'guardian');
      this.Enemy('enemy1','Espinho arcano','plant',190,13,4.2,'caster');
      this.Enemy('enemy2','Caçador de ecos','guardian',220,14,3.8,'raider');
    } else {
      this.Enemy('enemy0','Guardião do Limiar','guardian',720,22,3.6,'guardian');this.Units[3].IsBoss=true;
      this.Enemy('enemy1','Raiz do juramento','plant',180,12,4.5,'caster');
      this.Enemy('enemy2','Vigia do portal','guardian',210,14,4.1,'raider');
    }
    this.Selected=this.Units[3].Id;this.Energy=Math.min(100,f(this.Energy+focus*15));
  }
  get Won(){return !this.Units.some(x=>x.Side===Side.Enemies&&x.Alive);}
  get Lost(){return !this.Hero.Alive;}
  get Finished(){return this.Won||this.Lost;}
  get Hero(){return this.Units[0];}
  get Target(){return this.Units.find(x=>x.Id===this.Selected&&x.Alive&&x.Side===Side.Enemies)??this.Units.find(x=>x.Alive&&x.Side===Side.Enemies)??null;}
  Enemy(id,name,art,hp,attack,period,role){this.Units.push(Object.assign(new Unit(id,name,art,Side.Enemies,hp,attack,period),{Role:role}));}
  Select(id){const unit=this.Units.find(x=>x.Id===id&&x.Alive&&x.Side===Side.Enemies);if(!unit||this.Paused||this.Finished)return false;this.Selected=id;return true;}
  Cost(power){return power===Power.Flame?25:power===Power.Frost?20:65;}
  CanCast(power){
    if(!Number.isInteger(power)||power<0||power>2)return 'Técnica desconhecida';
    if(this.Paused||this.Finished)return 'Combate indisponível';
    if(this.Cooldowns[power]>EPSILON)return 'Recarregando';
    if(this.Energy<this.Cost(power))return 'Energia insuficiente';return '';
  }
  Cast(power){
    if(this.CanCast(power)!=='')return false;
    this.Energy=f(this.Energy-this.Cost(power));this.Cooldowns[power]=power===Power.Flame?4:power===Power.Frost?7:12;
    const target=this.Target;
    if(power===Power.Flame){
      const shatter=target.Frozen>0;
      if(shatter){target.Frozen=0;this.Combos++;this.Emit('combo',this.Hero,target,35);}
      this.Damage(this.Hero,target,shatter?95:60,'flame');
    }else if(power===Power.Frost){
      const interrupt=target.Windup>0;
      target.Frozen=3;target.Windup=0;target.Clock=0;target.IntentTarget='';target.Intent='';
      if(interrupt){this.Interrupts++;this.Emit('interrupt',this.Hero,target);this.Energy=Math.min(100,f(this.Energy+8));}
      this.Damage(this.Hero,target,26,'frost');
    }else{
      for(const ally of this.Units)if(ally.Alive&&ally.Side===Side.Heroes){ally.Shield=Math.min(90,f(ally.Shield+45));ally.ShieldTime=8;this.Emit('shield',this.Hero,ally,45);}
      this.Damage(this.Hero,target,75,'aegis');
    }
    return true;
  }
  Basic(){
    if(this.Paused||this.Finished||this.Hero.Clock>EPSILON)return false;
    this.Hero.Clock=this.Hero.Period;this.Damage(this.Hero,this.Target,this.Hero.Attack,'hit');this.Energy=Math.min(100,f(this.Energy+12));return true;
  }
  Tick(dt){
    dt=f(dt);if(!Number.isFinite(dt)||dt<=0||this.Paused||this.Finished)return;
    let remaining=Math.min(dt,1);
    while(remaining>f(.000001)&&!this.Finished){const step=Math.min(remaining,f(1/60));this.Step(step);remaining=f(remaining-step);}
  }
  Step(dt){
    this.Elapsed=f(this.Elapsed+dt);
    for(let i=0;i<3;i++)this.Cooldowns[i]=this.CountDown(this.Cooldowns[i],dt);
    for(const unit of this.Units)if(unit.Alive&&unit.ShieldTime>0){unit.ShieldTime=this.CountDown(unit.ShieldTime,dt);if(unit.ShieldTime===0){unit.Shield=0;this.Emit('shield_expire',unit,unit);}}
    this.Hero.Clock=this.CountDown(this.Hero.Clock,dt);if(this.Auto)this.Basic();
    for(const unit of this.Units){
      if(!unit.Alive||unit===this.Hero||this.Finished)continue;
      if(unit.Frozen>0){unit.Frozen=this.CountDown(unit.Frozen,dt);continue;}
      if(unit.Windup>0){unit.Windup=this.CountDown(unit.Windup,dt);if(unit.Windup===0)this.ResolveEnemyAttack(unit);continue;}
      unit.Clock=f(unit.Clock+dt);const period=unit.Enraged?f(unit.Period*f(.72)):unit.Period;
      if(f(unit.Clock+EPSILON)<period)continue;unit.Clock=0;
      if(unit.Side===Side.Enemies)this.BeginEnemyAttack(unit);else if(unit.Role==='healer')this.ActHealer(unit);else this.Damage(unit,this.Target,unit.Attack,'hit');
    }
  }
  CountDown(value,dt){const next=f(value-dt);return next<EPSILON?0:next;}
  ActHealer(healer){
    let wounded=null;
    for(const ally of this.Units)if(ally.Alive&&ally.Side===Side.Heroes&&ally.Hp<f(ally.MaxHp-1)&&(!wounded||f(ally.Hp/ally.MaxHp)<f(wounded.Hp/wounded.MaxHp)))wounded=ally;
    if(!wounded){this.Damage(healer,this.Target,healer.Attack,'light');return;}
    const healing=Math.min(24,f(wounded.MaxHp-wounded.Hp));wounded.Hp=f(wounded.Hp+healing);this.HealingDone=f(this.HealingDone+healing);this.Emit('heal',healer,wounded,healing);
  }
  ChooseVictim(enemy){
    if(enemy.Role==='guardian')return this.Hero;
    if(enemy.Role==='caster')return this.Units.find(x=>x.Id==='lyra'&&x.Alive)??this.Hero;
    const alive=this.Units.filter(x=>x.Side===Side.Heroes&&x.Alive);return alive[(enemy.Attacks+2)%alive.length];
  }
  BeginEnemyAttack(enemy){const victim=this.ChooseVictim(enemy);const wave=enemy.IsBoss&&enemy.Enraged&&enemy.Attacks%2===0;enemy.IntentTarget=victim.Id;enemy.Intent=wave?'Onda do Limiar':'Golpe → '+victim.Name;enemy.Windup=wave?f(1.8):f(1.1);this.Emit('charge',enemy,victim);}
  ResolveEnemyAttack(enemy){
    const wave=enemy.Intent==='Onda do Limiar';const victim=this.Units.find(x=>x.Id===enemy.IntentTarget&&x.Alive);
    if(wave){for(const ally of this.Units)if(ally.Side===Side.Heroes&&ally.Alive)this.Damage(enemy,ally,f(enemy.Attack*f(.85)),'enemy');}
    else if(victim)this.Damage(enemy,victim,f(enemy.Attack*(enemy.Enraged?f(1.25):1)),'enemy');
    enemy.Attacks++;enemy.Intent='';enemy.IntentTarget='';enemy.Clock=0;
  }
  Damage(source,target,amount,kind){
    if(!target||!target.Alive)return;
    const absorbed=Math.min(target.Shield,amount);target.Shield=f(target.Shield-absorbed);
    const dealt=Math.min(target.Hp,f(amount-absorbed));target.Hp=f(target.Hp-dealt);
    if(source.Side===Side.Heroes)this.DamageDealt=f(this.DamageDealt+dealt);this.Emit(kind,source,target,dealt);
    if(!target.Alive){target.Windup=0;target.Frozen=0;target.Shield=0;target.ShieldTime=0;target.Intent='';target.IntentTarget='';this.Emit('down',source,target);}
    else if(target.IsBoss&&!target.Enraged&&target.Hp<=f(target.MaxHp*f(.5))){target.Enraged=true;this.Emit('enrage',target,target);}
  }
  Emit(kind,source,target,amount=0){this.Events.push(new BattleEvent(kind,source.Id,target.Id,amount));}
}
