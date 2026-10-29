import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {Battle, Power, Side} from '../combat.js';
const tick=(b,seconds)=>{for(let i=0;i<seconds*60;i++)b.Tick(1/60);};

test('manual attacks grant energy only when available; targets cannot be allies',()=>{
  const b=new Battle();assert.equal(b.Basic(),true);assert.equal(b.Energy,47);assert.equal(b.Basic(),false);assert.equal(b.Energy,47);
  assert.equal(b.Select('lyra'),false);assert.equal(b.Select('enemy1'),true);const hp=b.Target.Hp;
  assert.equal(b.Cast(Power.Flame),true);assert.equal(b.Target.Hp,hp-60);const energy=b.Energy;
  assert.equal(b.Cast(Power.Flame),false);assert.equal(b.Energy,energy);
});
test('Geada interrupts a real announced strike; Chama shatters frost for bonus damage',()=>{
  const b=new Battle();b.Auto=false;b.Energy=100;tick(b,3.5);assert.ok(b.Target.Windup>0);
  const hp=b.Target.Hp;assert.ok(b.Cast(Power.Frost));assert.equal(b.Interrupts,1);assert.equal(b.Target.Windup,0);assert.equal(b.Target.Intent,'');
  assert.ok(b.Cast(Power.Flame));assert.equal(b.Combos,1);assert.equal(b.Units[3].Hp,hp-26-95);assert.equal(b.Units[3].Frozen,0);
});
test('party shield expires, healer chooses injured companion, boss enrages',()=>{
  const b=new Battle(2);b.Auto=false;b.Energy=100;
  for(const enemy of b.Units.filter(u=>u.Side===Side.Enemies))enemy.Period=999;
  b.Units[2].Hp=50;assert.ok(b.Cast(Power.Aegis));assert.equal(b.Units[2].Shield,45);
  tick(b,3.3);assert.equal(b.Units[2].Hp,74);tick(b,5);assert.equal(b.Units[2].Shield,0);
  const boss=b.Units[3];b.Damage(b.Hero,boss,400,'hit');assert.equal(boss.Enraged,true);assert.ok(b.Events.some(e=>e.Kind==='enrage'));
});
test('pause blocks all battle input, invalid deltas are ignored, long resume is capped',()=>{
  const b=new Battle();b.Paused=true;tick(b,3);assert.equal(b.Elapsed,0);assert.equal(b.Cast(Power.Flame),false);assert.equal(b.Basic(),false);assert.equal(b.Select('enemy1'),false);
  b.Paused=false;for(const delta of [NaN,Infinity,-1,0])b.Tick(delta);assert.equal(b.Elapsed,0);b.Tick(500);assert.ok(b.Elapsed<1.001);assert.equal(b.Cast(99),false);
});
test('victory, defeat and post-battle input are well-defined',()=>{
  const b=new Battle();for(const u of b.Units)if(u.Side===Side.Enemies)u.Hp=0;
  assert.equal(b.Won,true);assert.equal(b.Finished,true);assert.equal(b.Cast(Power.Flame),false);assert.equal(b.Basic(),false);
  const loss=new Battle();loss.Hero.Hp=0;assert.equal(loss.Lost,true);assert.equal(loss.Finished,true);
});

function compare(actual,expected,path='state'){
  if(typeof expected==='number'){assert.ok(Number.isFinite(actual),`${path} finite`);assert.ok(Math.abs(actual-expected)<0.00005,`${path}: ${actual} != ${expected}`);return;}
  if(Array.isArray(expected)){assert.equal(actual.length,expected.length,`${path}.length`);expected.forEach((v,i)=>compare(actual[i],v,`${path}[${i}]`));return;}
  if(expected!==null&&typeof expected==='object'){for(const [k,v]of Object.entries(expected))compare(actual[k],v,`${path}.${k}`);return;}
  assert.equal(actual,expected,path);
}
function state(frame,b){return {Frame:frame,Energy:b.Energy,Elapsed:b.Elapsed,DamageDealt:b.DamageDealt,HealingDone:b.HealingDone,Interrupts:b.Interrupts,Combos:b.Combos,Won:b.Won,Lost:b.Lost,Selected:b.Selected,Auto:b.Auto,Paused:b.Paused,Cooldowns:b.Cooldowns,Units:b.Units,Events:b.Events};}
const fixture=JSON.parse(readFileSync(new URL('./combat-parity.json',import.meta.url),'utf8'));
test('parity fixture is from the current authoritative C# source',()=>{
  const source=readFileSync(new URL('../../unity/Assets/William/Core/Battle.cs',import.meta.url));
  assert.equal(createHash('sha256').update(source).digest('hex'),fixture.Sha256,'Core changed: regenerate fixture and review browser translation');
});
for(const expected of fixture.Scenarios)test(`C# parity: scenario ${expected.Scenario}, ${expected.Snapshots.length} recorded states`,()=>{
  const scenario=expected.Scenario,b=new Battle(expected.Encounter,expected.Encounter,0,0);let index=0;
  for(let frame=0;frame<7200;frame++){
    b.Paused=frame>=120&&frame<180;
    if(frame===90)b.Select('enemy1');if(frame===240)b.Select('enemy0');
    if(scenario===4){b.Auto=false;if(frame%100===0)b.Basic();}
    else if(scenario!==1&&!b.Paused){
      if(b.Target&&b.Target.Windup>0)b.Cast(Power.Frost);
      else if(b.Target&&b.Target.Frozen>0)b.Cast(Power.Flame);
      else if(b.Energy>=80)b.Cast(Power.Aegis);
      else if(b.Energy>=50)b.Cast(Power.Flame);
    }
    b.Tick(frame%73===0?.1:1/60);
    if(frame%30===0||b.Finished){assert.ok(index<expected.Snapshots.length);compare(state(frame,b),expected.Snapshots[index],`scenario${scenario}/frame${frame}`);index++;b.Events.length=0;}
    if(b.Finished)break;
  }
  assert.equal(index,expected.Snapshots.length);
});
