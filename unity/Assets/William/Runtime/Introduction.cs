using System;
using System.Collections.Generic;
using UnityEngine;
using William.Core;
namespace William.Presentation {
// Temporary presentation uses existing licensed project art. No Mana Seed or Dragon Crashers assets.
public sealed class Introduction : MonoBehaviour {
    [Serializable] public class Sheet {public int frameWidth,frameHeight,originX,originY;public Clip[] clips;}
    [Serializable] public class Clip {public string name;public float fps;public Frame[] frames;}
    [Serializable] public class Frame {public int x,y;}
    sealed class Art {public Texture2D texture;public Sheet sheet;}
    sealed class Effect {public BattleEvent ev;public float life=1;}
    readonly Dictionary<string,Art> art=new Dictionary<string,Art>();
    readonly List<Effect> effects=new List<Effect>();
    readonly Color gold=new Color(.94f,.77f,.46f), cyan=new Color(.48f,.88f,.87f);
    Battle battle;string page="title",notice="";float clock,noticeUntil;int encounter,strength,vitality,focus,line;bool paused;
    GUIStyle text,title,small,button;Font font;AudioSource source;AudioClip hit;bool muted;
    string[] story={"O último trem desapareceu além das montanhas. William chegou ao vale onde as máquinas antigas ainda respiravam luz.","LYRA · TRANSMISSÃO\nO sinal de Tomás vem do portal. Vou guiar você. Bruma conhece a trilha — confie nela.","WILLIAM\nEntão vamos juntos. Se aquele guardião quer testar nossa vontade, encontrará três respostas."};
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot(){if(FindFirstObjectByType<Introduction>()==null)DontDestroyOnLoad(new GameObject("William introduction").AddComponent<Introduction>());}
    void Awake(){
        var cameraObject=new GameObject("Aurora Camera");cameraObject.transform.SetParent(transform);
        var camera=cameraObject.AddComponent<Camera>();camera.orthographic=true;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;
        cameraObject.AddComponent<AudioListener>();
        Application.targetFrameRate=60;font=Resources.Load<Font>("Art/Interface");
        foreach(string name in new[]{"william","guardian","fox","moth","plant"}) {
            var texture=Resources.Load<Texture2D>("Art/"+name);var json=Resources.Load<TextAsset>("Art/"+name);
            if(texture==null||json==null){Debug.LogError("Missing William art: "+name);continue;}
            texture.filterMode=FilterMode.Point;art[name]=new Art{texture=texture,sheet=JsonUtility.FromJson<Sheet>(json.text)};
        }
        source=gameObject.AddComponent<AudioSource>();hit=AudioClip.Create("Original hit",4410,1,22050,false);
        var samples=new float[4410];for(int i=0;i<samples.Length;i++)samples[i]=(float)(Math.Sin(i*.11)*Math.Exp(-i/600.0)*.12);hit.SetData(samples,0);
    }
    void OnDestroy(){if(hit!=null)Destroy(hit);}
    void Update(){
        if(paused)return;clock+=Time.deltaTime;
        for(int i=effects.Count-1;i>=0;i--){effects[i].life-=Time.deltaTime;if(effects[i].life<=0)effects.RemoveAt(i);}
        if(page!="battle")return;
        battle.Tick(Time.deltaTime);
        foreach(var ev in battle.Events){effects.Add(new Effect{ev=ev});if(!muted&&ev.Kind!="charge")source.PlayOneShot(hit);}
        battle.Events.Clear();
        if(battle.Finished){page=battle.Won?(encounter==2?"ending":"reward"):"defeat";}
    }
    void Begin(){encounter=strength=vitality=focus=line=0;page="story";paused=false;effects.Clear();}
    void Fight(){battle=new Battle(encounter,strength,vitality,focus);effects.Clear();page="battle";}
    void Cast(Power power){string reason=battle.CanCast(power);if(reason!=""){notice=reason;noticeUntil=clock+2;return;}battle.Cast(power);}
    void Styles(){
        if(text!=null)return;
        text=new GUIStyle(GUI.skin.label){font=font,fontSize=20,wordWrap=true};text.normal.textColor=new Color(.94f,.94f,.86f);
        small=new GUIStyle(text){fontSize=14};title=new GUIStyle(text){fontSize=54,fontStyle=FontStyle.Bold};
        button=new GUIStyle(GUI.skin.button){font=font,fontSize=17,wordWrap=true};button.normal.textColor=Color.white;
    }
    void Box(float x,float y,float w,float h,Color color){var old=GUI.color;GUI.color=color;GUI.DrawTexture(new Rect(x,y,w,h),Texture2D.whiteTexture);GUI.color=old;}
    void Label(string value,float x,float y,float w,float h,GUIStyle style=null){GUI.Label(new Rect(x,y,w,h),value,style??text);}
    bool Button(string value,float x,float y,float w=230,float h=52){return GUI.Button(new Rect(x,y,w,h),value,button);}
    void Bar(float x,float y,float w,float current,float max,Color color){Box(x,y,w,6,new Color(.03f,.07f,.1f));Box(x,y,w*Mathf.Clamp01(current/max),6,color);}
    void Actor(string name,Vector2 ground,float scale,bool flip=false,bool action=false){
        if(!art.TryGetValue(name,out var a))return;
        string clipName=(action?"action":"idle")+(flip?"_W":"_E");
        Clip clip=Array.Find(a.sheet.clips,c=>c.name==clipName)??a.sheet.clips[0];
        Frame frame=clip.frames[(int)(clock*clip.fps)%clip.frames.Length];
        var rect=new Rect(ground.x-a.sheet.originX*scale,ground.y-a.sheet.originY*scale,a.sheet.frameWidth*scale,a.sheet.frameHeight*scale);
        var uv=new Rect((float)frame.x/a.texture.width,1f-(float)(frame.y+a.sheet.frameHeight)/a.texture.height,(float)a.sheet.frameWidth/a.texture.width,(float)a.sheet.frameHeight/a.texture.height);
        GUI.DrawTextureWithTexCoords(rect,a.texture,uv,true);
    }
    Vector2 Position(Unit u){int index=battle.Units.IndexOf(u);return u.Side==Side.Heroes?new Vector2(370-index*78,360+index*86):new Vector2(820+(index-3)*110,350+(index-3)*85);}
    void World(){
        Box(0,0,1280,720,new Color(.035f,.10f,.15f));Box(0,220,1280,500,new Color(.07f,.21f,.23f));
        for(int i=0;i<12;i++){
            float x=i*117-20,y=100+(i*71%110);Box(x,y,58,240,new Color(.08f,.17f,.19f));
            Box(x-45,y-40,150,95,new Color(.12f,.27f,.27f));Box(x-30,y-52,115,60,new Color(.16f,.34f,.31f));
        }
        Box(0,347,1280,205,new Color(.22f,.29f,.28f));
        for(int i=0;i<22;i++){float x=i*61+Mathf.Sin(clock*.4f+i)*14,y=240+(i*89%295)+Mathf.Cos(clock+i)*8;Box(x,y,3,3,new Color(.8f,.86f,.56f,.4f));}
        Box(1060,170,15,180,gold);Box(1190,170,15,180,gold);Box(1060,160,145,12,gold);
        Box(1078,180,105,160,new Color(.2f,.85f,.8f,.12f+Mathf.Sin(clock)*.04f));
    }
    void OnGUI(){
        Styles();var old=GUI.matrix;float scale=Mathf.Min(Screen.width/1280f,Screen.height/720f);
        GUI.matrix=Matrix4x4.TRS(new Vector3((Screen.width-1280*scale)/2,(Screen.height-720*scale)/2,0),Quaternion.identity,new Vector3(scale,scale,1));
        World();
        if(page=="title"){
            Actor("william",new Vector2(850,530),3);Actor("fox",new Vector2(1030,550),2);
            Box(0,0,680,720,new Color(.02f,.07f,.1f,.88f));Label("WILLIAM",65,165,600,90,title);Label("L I M I A R  D E  A U R O R A",70,267,580,50);
            Label("Três vontades. Um antigo juramento.\nUma luz além dos trilhos.",70,355,500,100);
            if(Button("Iniciar introdução  →",70,485,340,62))Begin();
            Label("UNITY · PROTÓTIPO DE COMBATE\nArte temporária do projeto original",70,620,530,60,small);
        }else if(page=="story"){
            Actor("william",new Vector2(340,450),2.5f);Actor("moth",new Vector2(610,330),3);Actor("fox",new Vector2(790,450),2.5f);
            Box(60,490,1160,190,new Color(.02f,.07f,.11f,.96f));Label(story[line],90,515,1080,100);
            if(Button(line<story.Length-1?"Continuar →":"Entrar na clareira →",940,615)) {line++;if(line==story.Length)Fight();}
        }else if(page=="battle") DrawBattle();
        else if(page=="reward"){
            Label("O FAROL RESPONDE",110,160,1100,90,title);Label("Escolha uma melhoria para o próximo encontro.\nA equipe recuperará a vida ao seguir pela trilha.",115,280,1000,90);
            if(Button("Lâmina · +5 ataque",110,420,320,80)){strength++;encounter++;Fight();}
            if(Button("Vigor · +45 vida",480,420,320,80)){vitality++;encounter++;Fight();}
            if(Button("Sintonia · +15 energia inicial",850,420,320,80)){focus++;encounter++;Fight();}
        }else if(page=="ending"){
            Label("AURORA ESPERA",110,150,1100,90,title);Label("O guardião reconheceu o juramento dos três.\nAlém do portal, sete sinos responderam.\n\nWilliam apertou o bilhete de Tomás.\n“Guarde uma luz na janela, irmão. Estou chegando.”",115,270,1020,230);
            if(Button("Voltar ao título",110,580))page="title";
        }else if(page=="defeat"){
            Label("A LUZ AINDA VIVE",110,190,1100,90,title);Label("William caiu. Retome este encontro com a equipe recuperada.",115,320,1000,70);
            if(Button("Tentar novamente",115,440))Fight();if(Button("Voltar ao título",380,440))page="title";
        }
        GUI.matrix=old;
    }
    void DrawBattle(){
        foreach(var u in battle.Units){
            if(!u.Alive)continue;Vector2 p=Position(u);bool active=effects.Exists(e=>e.ev.Source==u.Id&&e.life>.4f);
            Actor(u.Art,p,u.Side==Side.Heroes?2.2f:2.4f,u.Side==Side.Enemies,active||u.Windup>0);
            Label(u.Name,p.x-85,p.y+8,200,30,small);Bar(p.x-70,p.y+40,150,u.Hp,u.MaxHp,u.Side==Side.Heroes?cyan:gold);
            if(u.Shield>0)Label("◇ "+(int)u.Shield,p.x-70,p.y+52,150,30,small);
            if(u.Side==Side.Enemies){
                if(!paused&&GUI.Button(new Rect(p.x-80,p.y-170,160,185),GUIContent.none,GUIStyle.none))battle.Select(u.Id);
                if(battle.Target==u)Label("▼ ALVO",p.x-35,p.y-200,130,30,small);
                if(u.Windup>0)Label("! GOLPE EM "+u.Windup.ToString("0.0"),p.x-65,p.y-230,180,30,small);
                if(u.Frozen>0)Label("CONGELADO",p.x-50,p.y-155,160,30,small);
            }
        }
        foreach(var e in effects){var u=battle.Units.Find(x=>x.Id==e.ev.Target);if(u==null)continue;var p=Position(u);Color color=e.ev.Kind=="flame"?new Color(1,.5f,.2f):e.ev.Kind=="frost"?cyan:gold;
            for(int i=0;i<10;i++){float a=i*Mathf.PI*.2f;Box(p.x+Mathf.Cos(a)*(1-e.life)*130,p.y-70+Mathf.Sin(a)*(1-e.life)*90,4,4,color);}
            Label(e.ev.Kind=="charge"?"!":e.ev.Amount.ToString("0"),p.x-20,p.y-125-(1-e.life)*60,150,40);
        }
        Box(0,0,1280,105,new Color(.02f,.06f,.09f,.96f));Label("WILLIAM / "+new[]{"A clareira","O caminho dos ecos","O guardião"}[encounter],30,22,790,45);
        Label("Toque em um inimigo para concentrar os ataques.",30,67,790,35,small);
        if(Button(muted?"Som: não":"Som: sim",885,22,135,48))muted=!muted;
        if(Button(paused?"Continuar":"Pausar",1040,22,210,48)){paused=!paused;battle.Paused=paused;}
        Box(0,590,1280,130,new Color(.02f,.06f,.09f,.98f));Label("ENERGIA  "+(int)battle.Energy+" / 100",25,605,260,35);Bar(25,648,225,battle.Energy,100,cyan);
        GUI.enabled=!paused;
        if(Button(battle.Auto?"Auto: ligado":"Auto: desligado",285,615,175,66))battle.Auto=!battle.Auto;
        if(Button("Corte\n+12 energia",475,615,155,66))battle.Basic();
        string[] names={"Chama","Geada","Égide"};
        for(int i=0;i<3;i++){var power=(Power)i;GUI.enabled=!paused&&battle.CanCast(power)=="";string suffix=battle.Cooldowns[i]>0?battle.Cooldowns[i].ToString("0.0")+"s":battle.Cost(power)+" energia";
            if(Button(names[i]+"\n"+suffix,650+i*200,615,185,66))Cast(power);
        }
        GUI.enabled=true;if(clock<noticeUntil)Label(notice,450,112,700,40);
        if(paused){Box(380,230,520,170,new Color(.02f,.06f,.09f,.95f));Label("JORNADA EM PAUSA",425,270,500,75);}
    }
}
}
