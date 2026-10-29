using System;
using System.Collections.Generic;
using UnityEngine;
using William.Core;

namespace William.Presentation {
/// <summary>Original presentation. The provisional atlas art is licensed in Resources/Art.</summary>
public sealed class Introduction : MonoBehaviour {
    [Serializable] public class Sheet { public int frameWidth, frameHeight, originX, originY; public Clip[] clips; }
    [Serializable] public class Clip { public string name; public float fps; public Frame[] frames; }
    [Serializable] public class Frame { public int x, y; }
    sealed class Art { public Texture2D texture; public Sheet sheet; public Dictionary<string,Clip> clips = new Dictionary<string,Clip>(); }
    sealed class Effect { public BattleEvent ev; public float life = 1.1f; }
    readonly Dictionary<string,Art> art = new Dictionary<string,Art>();
    readonly List<Effect> effects = new List<Effect>();
    readonly Dictionary<string,AudioClip> sounds = new Dictionary<string,AudioClip>();
    readonly Color gold = Hex(0xe9c88a), cyan = Hex(0x87ddd2), ink = Hex(0x071a25), pale = Hex(0xf0eddb), muted = Hex(0x9ab3b5);
    readonly string[] names = {"O farol esquecido", "A ponte dos ecos", "O juramento do guardião"};
    readonly string[] descriptions = {"A luz do farol despertou duas sentinelas. Aprenda a quebrar seus golpes antes de seguir.","Os ecos procuram os aliados mais frágeis. Proteja Lyra e escolha qual ameaça derrubar primeiro.","O guardião conserva o último juramento de Aurora. Quando sua armadura ceder, ele lutará com fúria."};
    readonly string[] voices = {"VESPER · DEPOIS DO ÚLTIMO TREM", "LYRA · UM ECO NO CRISTAL", "WILLIAM"};
    readonly string[] story = {
        "O último trem desapareceu entre as montanhas. William seguiu o sinal do irmão até uma floresta onde antigas máquinas ainda respiravam luz.",
        "O bilhete de Tomás abriu o caminho. Vou acompanhar você por este cristal. Bruma conhece a trilha; deixe que ela nos leve até o farol.",
        "Então vamos juntos. Se o guardião quer saber quem somos… responderemos com nossas próprias escolhas."
    };
    Battle battle;
    string page = "title", notice = "", help = "";
    float clock, pageTime, noticeUntil, shake, pendingFinish, typed;
    int encounter, strength, vitality, focus, line, totalCombos, totalInterrupts;
    bool paused, isMuted, lowMotion;
    GUIStyle text, heading, title, small, tiny, centered;
    Font font;
    Texture2D disc, glow, characterAtlas, forestArt;
    AudioSource source, music;
    AudioClip ambient;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() {
        if (FindFirstObjectByType<Introduction>() == null)
            DontDestroyOnLoad(new GameObject("William introduction").AddComponent<Introduction>());
    }
    void Awake() {
        var cameraObject = new GameObject("Aurora camera"); cameraObject.transform.SetParent(transform);
        var camera = cameraObject.AddComponent<Camera>(); camera.orthographic = true;
        camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = Color.black;
        cameraObject.AddComponent<AudioListener>();
        Application.targetFrameRate = 60;
        font = Resources.Load<Font>("Art/Interface");
        foreach (string name in new[] {"william", "guardian", "fox", "moth", "plant"}) {
            var texture = Resources.Load<Texture2D>("Art/" + name);
            var json = Resources.Load<TextAsset>("Art/" + name);
            if (texture == null || json == null) { Debug.LogError("Missing William art: " + name); continue; }
            texture.filterMode = FilterMode.Point;
            var a = new Art { texture = texture, sheet = JsonUtility.FromJson<Sheet>(json.text) };
            foreach (var clip in a.sheet.clips) a.clips[clip.name] = clip;
            art[name] = a;
        }
        characterAtlas = Resources.Load<Texture2D>("Art/Aurora/Characters");
        forestArt = Resources.Load<Texture2D>("Art/Aurora/Forest");
        disc = Disc(false); glow = Disc(true);
        source = gameObject.AddComponent<AudioSource>(); music = gameObject.AddComponent<AudioSource>();
        foreach (string kind in new[] {"hit", "flame", "frost", "aegis", "heal", "charge", "win", "click"}) sounds[kind] = Sound(kind);
        ambient = Ambient(); music.clip = ambient; music.loop = true; music.volume = .26f; music.Play();
        isMuted = PlayerPrefs.GetInt("william.sound.off", 0) == 1;
        lowMotion = PlayerPrefs.GetInt("william.motion.low", 0) == 1; ApplySound();
    }
    void OnDestroy() {
        foreach (var clip in sounds.Values) if (clip != null) Destroy(clip);
        if (ambient != null) Destroy(ambient); if (disc != null) Destroy(disc); if (glow != null) Destroy(glow);
    }
    static Color Hex(int h) { return new Color(((h >> 16) & 255) / 255f, ((h >> 8) & 255) / 255f, (h & 255) / 255f); }
    Texture2D Disc(bool soft) {
        var t = new Texture2D(64, 64, TextureFormat.RGBA32, false); var pixels = new Color[4096];
        for (int y = 0; y < 64; y++) for (int x = 0; x < 64; x++) {
            float distance = Vector2.Distance(new Vector2(x + .5f, y + .5f), new Vector2(32, 32)) / 32;
            pixels[y * 64 + x] = new Color(1, 1, 1, soft ? Mathf.Pow(Mathf.Clamp01(1 - distance), 2) : Mathf.Clamp01((1 - distance) * 32));
        }
        t.SetPixels(pixels); t.Apply(); return t;
    }
    AudioClip Sound(string kind) {
        int rate = 22050, count = kind == "aegis" || kind == "win" ? 17640 : 6615;
        var data = new float[count]; float freq = kind == "frost" ? 880 : kind == "flame" ? 145 : kind == "heal" ? 660 : kind == "charge" ? 95 : kind == "click" ? 440 : 220;
        for (int i = 0; i < count; i++) {
            float t = (float)i / rate, progress = (float)i / count;
            float tone = Mathf.Sin(t * freq * 6.283185f * (kind == "hit" ? 1 - progress * .5f : 1));
            if (kind == "aegis" || kind == "win") tone = (Mathf.Sin(t * 261.63f * 6.283185f) + Mathf.Sin(t * 329.63f * 6.283185f) + Mathf.Sin(t * 392 * 6.283185f)) / 3;
            data[i] = tone * Mathf.Sin(Mathf.Min(1, progress * 20) * Mathf.PI / 2) * Mathf.Pow(1 - progress, 3) * .16f;
        }
        var clip = AudioClip.Create("William original " + kind, count, 1, rate, false); clip.SetData(data, 0); return clip;
    }
    AudioClip Ambient() {
        int rate = 22050, count = rate * 12; var data = new float[count];
        // Integer cycles make the pad loop without a discontinuity.
        for (int i = 0; i < count; i++) {
            double phase = (double)i / count * Math.PI * 2;
            data[i] = (float)((Math.Sin(phase * 1568) + Math.Sin(phase * 1976) * .5 + Math.Sin(phase * 2349) * .3) * .05 * (.8 + .2 * Math.Cos(phase)));
        }
        var clip = AudioClip.Create("Aurora original ambient", count, 1, rate, false); clip.SetData(data, 0); return clip;
    }
    void Play(string kind) { if (!isMuted && sounds.TryGetValue(kind, out var clip)) source.PlayOneShot(clip); }
    void ApplySound() { source.mute = music.mute = isMuted; PlayerPrefs.SetInt("william.sound.off", isMuted ? 1 : 0); }
    void Go(string value) {
        page = value; pageTime = 0; help = "";
        if (value == "map") SaveCheckpoint();
        if (value == "ending") { PlayerPrefs.DeleteKey("william.checkpoint"); PlayerPrefs.Save(); }
    }
    void SaveCheckpoint() {
        PlayerPrefs.SetInt("william.checkpoint", 1);
        PlayerPrefs.SetInt("william.encounter", encounter); PlayerPrefs.SetInt("william.strength", strength);
        PlayerPrefs.SetInt("william.vitality", vitality); PlayerPrefs.SetInt("william.focus", focus);
        PlayerPrefs.SetInt("william.combos", totalCombos); PlayerPrefs.SetInt("william.interrupts", totalInterrupts); PlayerPrefs.Save();
    }
    void ContinueCheckpoint() {
        encounter = Mathf.Clamp(PlayerPrefs.GetInt("william.encounter", 0), 0, 2);
        strength = Mathf.Clamp(PlayerPrefs.GetInt("william.strength", 0), 0, 2);
        vitality = Mathf.Clamp(PlayerPrefs.GetInt("william.vitality", 0), 0, 2);
        focus = Mathf.Clamp(PlayerPrefs.GetInt("william.focus", 0), 0, 2);
        totalCombos = Mathf.Max(0, PlayerPrefs.GetInt("william.combos", 0));
        totalInterrupts = Mathf.Max(0, PlayerPrefs.GetInt("william.interrupts", 0));
        paused = false; battle = null; effects.Clear(); Go("map");
    }
    void OnApplicationFocus(bool focused) { if (!focused && page == "battle" && !paused) Pause(); }
    void Begin() { encounter = strength = vitality = focus = line = totalCombos = totalInterrupts = 0; battle = null; paused = false; typed = 0; effects.Clear(); Go("story"); }
    void AdvanceStory() {
        if (typed < story[line].Length) { typed = story[line].Length; return; }
        line++; typed = 0; if (line == story.Length) Go("map");
    }
    void Fight() { battle = new Battle(encounter, strength, vitality, focus); effects.Clear(); pendingFinish = 0; paused = false; Go("battle"); }
    void Pause() { if (page != "battle" || battle.Finished) return; paused = !paused; battle.Paused = paused; }
    void Cast(Power power) {
        if (page != "battle" || paused || help != "") return;
        string reason = battle.CanCast(power); if (reason != "") { Notify(reason); return; } battle.Cast(power);
    }
    void Notify(string value) { notice = value; noticeUntil = clock + 2.8f; }
    void Update() {
        if (paused || help != "") return;
        float dt = Mathf.Min(Time.deltaTime, .1f); clock += dt; pageTime += dt; typed += dt * 38; shake = Mathf.Max(0, shake - dt * 9);
        for (int i = effects.Count - 1; i >= 0; i--) { effects[i].life -= dt; if (effects[i].life <= 0) effects.RemoveAt(i); }
        if (page != "battle") return;
        battle.Tick(dt);
        foreach (var ev in battle.Events) {
            effects.Add(new Effect { ev = ev });
            if (ev.Kind == "enemy" || ev.Kind == "flame" || ev.Kind == "aegis") shake = lowMotion ? 0 : .8f;
            if (ev.Kind == "combo") Notify("CHOQUE TÉRMICO · gelo + chama");
            if (ev.Kind == "interrupt") Notify("RUPTURA · golpe interrompido");
            if (ev.Kind == "enrage") Notify("O guardião despertou sua fúria. Prepare a Égide!");
            Play(sounds.ContainsKey(ev.Kind) ? ev.Kind : ev.Kind == "down" ? "hit" : "click");
        }
        battle.Events.Clear();
        if (battle.Finished) {
            pendingFinish += dt;
            if (pendingFinish > 1.2f) {
                if (battle.Won) { totalCombos += battle.Combos; totalInterrupts += battle.Interrupts; Play("win"); Go(encounter == 2 ? "ending" : "reward"); }
                else Go("defeat");
            }
        }
    }
    void Styles() {
        if (text != null) return;
        text = new GUIStyle(GUI.skin.label) { font = font, fontSize = 20, wordWrap = true }; text.normal.textColor = pale;
        small = new GUIStyle(text) { fontSize = 14 }; small.normal.textColor = muted;
        tiny = new GUIStyle(small) { fontSize = 12 }; heading = new GUIStyle(text) { fontSize = 32, fontStyle = FontStyle.Bold };
        title = new GUIStyle(heading) { fontSize = 72 }; centered = new GUIStyle(text) { alignment = TextAnchor.MiddleCenter };
    }
    void Box(float x, float y, float w, float h, Color color) { Color previous = GUI.color; GUI.color = color; GUI.DrawTexture(new Rect(x, y, w, h), Texture2D.whiteTexture); GUI.color = previous; }
    void Oval(Vector2 p, float w, float h, Color color, bool soft = false) { Color previous = GUI.color; GUI.color = color; GUI.DrawTexture(new Rect(p.x - w / 2, p.y - h / 2, w, h), soft ? glow : disc); GUI.color = previous; }
    void Stroke(Vector2 a, Vector2 b, Color color, float width = 2) {
        var saved = GUI.matrix; GUIUtility.RotateAroundPivot(Mathf.Atan2(b.y - a.y, b.x - a.x) * Mathf.Rad2Deg, a);
        Box(a.x, a.y - width / 2, (b - a).magnitude, width, color); GUI.matrix = saved;
    }
    void Ring(Vector2 p, float radius, Color color, float flatten = 1) {
        const int segments = 40; for (int i = 0; i < segments; i++) { float a = i * Mathf.PI * 2 / segments, b = (i + 1) * Mathf.PI * 2 / segments;
            Stroke(p + new Vector2(Mathf.Cos(a) * radius, Mathf.Sin(a) * radius * flatten), p + new Vector2(Mathf.Cos(b) * radius, Mathf.Sin(b) * radius * flatten), color); }
    }
    void Panel(float x, float y, float w, float h, bool accent = false) {
        Box(x, y + 5, w, h, new Color(0, 0, 0, .2f)); Box(x, y, w, h, new Color(.025f, .075f, .11f, .96f));
        Box(x, y, w, 1, accent ? gold : new Color(.3f, .48f, .5f, .65f)); Box(x, y + h - 1, w, 1, new Color(.3f, .48f, .5f, .4f));
    }
    void Label(string value, float x, float y, float w, float h, GUIStyle style = null) { GUI.Label(new Rect(x, y, w, h), value, style ?? text); }
    bool Button(string value, float x, float y, float w = 230, float h = 52, bool primary = false) {
        var r = new Rect(x, y, w, h); bool hover = r.Contains(Event.current.mousePosition) && GUI.enabled;
        Color background = primary ? gold : hover ? Hex(0x28454c) : Hex(0x122d38);
        if (!GUI.enabled) background = Hex(0x16242c); Box(x, y, w, h, background); Box(x, y, w, 1, primary ? pale : Hex(0x557371));
        Color previous = GUI.contentColor; GUI.contentColor = primary ? ink : GUI.enabled ? pale : muted;
        GUI.Label(r, value, centered); GUI.contentColor = previous;
        bool clicked = GUI.Button(r, GUIContent.none, GUIStyle.none); if (clicked) Play("click"); return clicked;
    }
    void Bar(float x, float y, float w, float current, float max, Color color, float height = 5) { Box(x, y, w, height, Hex(0x06121c)); Box(x, y, w * Mathf.Clamp01(current / max), height, color); }
    void Actor(string name, Vector2 ground, float scale, bool flip = false, bool action = false, float alpha = 1) {
        if (characterAtlas != null) {
            Rect crop; Vector2 pivot;
            switch(name) {
                case "william": crop=new Rect(0,0,418,610); pivot=new Vector2(220,578); break;
                case "moth": crop=new Rect(418,0,430,610); pivot=new Vector2(230,578); break;
                case "fox": crop=new Rect(848,0,406,610); pivot=new Vector2(230,578); break;
                case "guardian": crop=new Rect(0,610,418,600); pivot=new Vector2(220,550); break;
                case "boss": crop=new Rect(418,610,452,600); pivot=new Vector2(225,550); break;
                default: crop=new Rect(870,610,384,600); pivot=new Vector2(190,550); break;
            }
            float f=scale*(name=="fox"?72:92)/crop.height;
            float bob=lowMotion?0:Mathf.Sin(clock*2.3f)*1.2f;
            var original=GUI.matrix; if(flip)GUI.matrix=GUI.matrix*Matrix4x4.TRS(new Vector3(ground.x*2,0,0),Quaternion.identity,new Vector3(-1,1,1));
            var oldColor=GUI.color; GUI.color=new Color(1,1,1,alpha);
            GUI.DrawTextureWithTexCoords(new Rect(ground.x-pivot.x*f,ground.y-pivot.y*f+bob,crop.width*f,crop.height*f),characterAtlas,new Rect(crop.x/characterAtlas.width,1-(crop.y+crop.height)/characterAtlas.height,crop.width/characterAtlas.width,crop.height/characterAtlas.height),true);
            GUI.color=oldColor;GUI.matrix=original;return;
        }
        if (!art.TryGetValue(name, out var a)) return;
        string clipName = (action ? "action" : "idle") + (flip ? "_W" : "_E");
        if (!a.clips.TryGetValue(clipName, out var clip)) clip = a.sheet.clips[0];
        Frame frame = clip.frames[(int)(clock * clip.fps) % clip.frames.Length];
        var rect = new Rect(ground.x - a.sheet.originX * scale, ground.y - a.sheet.originY * scale, a.sheet.frameWidth * scale, a.sheet.frameHeight * scale);
        var uv = new Rect((float)frame.x / a.texture.width, 1f - (float)(frame.y + a.sheet.frameHeight) / a.texture.height, (float)a.sheet.frameWidth / a.texture.width, (float)a.sheet.frameHeight / a.texture.height);
        Color previous = GUI.color; GUI.color = new Color(1, 1, 1, alpha); GUI.DrawTextureWithTexCoords(rect, a.texture, uv, true); GUI.color = previous;
    }
    Vector2 Position(Unit unit) {
        int i = battle.Units.IndexOf(unit); return unit.Side == Side.Heroes ? new Vector2(360 - i * 83, 392 + i * 64) : new Vector2(800 + (i - 3) * 145, 370 + (i - 3) * 65);
    }
    void Tree(float x, float y, float scale, int seed, Color color) {
        Oval(new Vector2(x + 8 * scale, y + 6), 100 * scale, 28 * scale, new Color(0, 0, 0, .13f));
        Box(x - 7 * scale, y - 140 * scale, 14 * scale, 145 * scale, Hex(0x1a3438));
        Stroke(new Vector2(x, y - 60 * scale), new Vector2(x - 32 * scale, y - 110 * scale), Hex(0x253f40), 7 * scale);
        for (int i = 0; i < 5; i++) { float a = i * 2.4f + seed;
            var p = new Vector2(x + Mathf.Sin(a) * 40 * scale, y - (120 + i * 14) * scale);
            Oval(p + Vector2.down * 5, 108 * scale, 70 * scale, Hex(0x112b34)); Oval(p, 102 * scale, 65 * scale, color);
            Stroke(p + new Vector2(-25, -12) * scale, p + new Vector2(18, -22) * scale, new Color(.45f, .66f, .55f, .16f), 2 * scale);
        }
    }
    void World() {
        if(forestArt != null) {
            GUI.DrawTexture(new Rect(0,0,1280,720),forestArt,ScaleMode.ScaleAndCrop);
            Box(0,0,1280,720,new Color(.01f,.05f,.09f,.14f));
            for(int i=0;i<(lowMotion?5:25);i++){float x=i*89%1280+Mathf.Sin(clock*.3f+i)*12,y=180+i*53%390+Mathf.Cos(clock*.5f+i)*6;Oval(new Vector2(x,y),12,12,new Color(.8f,.9f,.5f,.18f),true);}
            return;
        }
        for (int i = 0; i < 18; i++) Box(0, i * 40, 1280, 41, Color.Lerp(Hex(0x061422), Hex(0x365249), i / 17f));
        Oval(new Vector2(990, 130), 460, 460, new Color(.37f, .82f, .77f, .35f), true);
        for (int i = 0; i < 11; i++) Tree(i * 135 - 30, 300 + i % 3 * 18, .95f, i, Hex(0x18373c));
        for (int i = 0; i < 6; i++) Oval(new Vector2(i * 260, 335), 470, 120, new Color(.3f, .58f, .57f, .07f), true);
        Oval(new Vector2(650, 650), 1500, 610, Hex(0x112a2c)); Oval(new Vector2(650, 620), 1500, 610, Hex(0x2e4841));
        Oval(new Vector2(670, 505), 1180, 260, Hex(0x475648)); Oval(new Vector2(670, 488), 1130, 235, Hex(0x52604d));
        for (int i = 0; i < 44; i++) { float x = i * 113 % 1260, y = 330 + i * 67 % 260; Box(x, y, 12 + i % 9, 2, new Color(.75f, .79f, .57f, .08f)); }
        Ring(new Vector2(864, 430), 117, new Color(.72f, .78f, .57f, .24f), .35f); Ring(new Vector2(864, 430), 100, new Color(.72f, .78f, .57f, .15f), .35f);
        Portal(new Vector2(1120, 316));
        if (page != "battle") { Actor("plant", new Vector2(1200, 500), 1.3f); Actor("moth", new Vector2(725, 325 + Mathf.Sin(clock) * 12), 1.1f); }
        for (int i = 0; i < 35; i++) { float x = i * 89 % 1280 + Mathf.Sin(clock * .25f + i) * 14, y = 180 + i * 53 % 390 + Mathf.Cos(clock * .5f + i) * 8;
            Oval(new Vector2(x, y), 24, 24, new Color(.5f, .9f, .65f, .18f), true); Box(x, y, 2, 2, new Color(.8f, .95f, .7f, .5f)); }
        Tree(-18, 655, 1.8f, 8, Hex(0x123136)); Tree(1295, 645, 1.8f, 9, Hex(0x17383c));
        Box(0, 0, 1280, 4, gold);
    }
    void Portal(Vector2 p) {
        Oval(p + new Vector2(0, -80), 240, 320, new Color(.2f, .9f, .83f, .3f), true);
        Oval(p + new Vector2(0, -75), 90, 170, new Color(.3f, .8f, .77f, .28f));
        Stroke(p + new Vector2(-62, 0), p + new Vector2(-50, -145), Hex(0x6d8b7c), 15);
        Stroke(p + new Vector2(62, 0), p + new Vector2(50, -145), Hex(0x6d8b7c), 15);
        Stroke(p + new Vector2(-50, -145), p + new Vector2(0, -190), gold, 5); Stroke(p + new Vector2(50, -145), p + new Vector2(0, -190), gold, 5);
        for (int i = 0; i < 6; i++) Stroke(p + new Vector2(-38, -i * 26), p + new Vector2(38, -i * 26), new Color(.5f, 1, .92f, .15f));
        Ring(p, 70, gold, .3f); Ring(p, 56, cyan, .3f);
    }
    void KeyInput() {
        var e = Event.current; if (e.type != EventType.KeyDown) return;
        if (e.keyCode == KeyCode.Escape) { if (help != "") help = ""; else Pause(); e.Use(); return; }
        if (help != "" || paused) return;
        if (page == "story" && (e.keyCode == KeyCode.Space || e.keyCode == KeyCode.Return)) { AdvanceStory(); e.Use(); return; }
        if (page != "battle") return;
        switch (e.keyCode) {
            case KeyCode.Q: case KeyCode.Alpha1: Cast(Power.Flame); break;
            case KeyCode.E: case KeyCode.Alpha2: Cast(Power.Frost); break;
            case KeyCode.R: case KeyCode.Alpha3: Cast(Power.Aegis); break;
            case KeyCode.Space: battle.Basic(); break;
            case KeyCode.T: battle.Auto = !battle.Auto; break;
            case KeyCode.Tab:
                int i = battle.Units.IndexOf(battle.Target); for (int j = 1; j <= battle.Units.Count; j++) if (battle.Select(battle.Units[(i + j) % battle.Units.Count].Id)) break;
                break;
            default: return;
        }
        e.Use();
    }
    void OnGUI() {
        Styles(); var old = GUI.matrix; Rect safe = Screen.safeArea;
        float scale = Mathf.Min(safe.width / 1280, safe.height / 720);
        GUI.matrix = Matrix4x4.TRS(new Vector3(safe.x + (safe.width - 1280 * scale) / 2, Screen.height - safe.yMax + (safe.height - 720 * scale) / 2, 0), Quaternion.identity, new Vector3(scale, scale, 1));
        KeyInput(); World();
        if (page == "title") DrawTitle(); else if (page == "story") DrawStory(); else if (page == "map") DrawMap();
        else if (page == "battle") DrawBattle(); else if (page == "reward") DrawReward(); else DrawEnd();
        if (help != "") DrawHelp();
        if (pageTime < .5f) Box(0, 0, 1280, 720, new Color(.02f, .05f, .08f, Mathf.Clamp01(1 - pageTime * 2)));
        GUI.matrix = old;
    }
    void DrawTitle() {
        Oval(new Vector2(880, 530), 340, 90, new Color(0, 0, 0, .22f)); Actor("william", new Vector2(890, 550), 3.4f); Actor("fox", new Vector2(1050, 565), 2);
        for (int i = 0; i < 15; i++) Box(i * 48, 0, 49, 720, new Color(.025f, .06f, .09f, .96f - i * .05f));
        Label("UM MUNDO ALÉM DOS TRILHOS", 70, 145, 600, 35, small); Box(72, 197, 74, 2, gold);
        Label("WILLIAM", 63, 220, 640, 100, title); Label("L I M I A R   D E   A U R O R A", 73, 326, 650, 42);
        Label("Três vontades. Um antigo juramento.\nUma luz esperando do outro lado.", 73, 398, 560, 90);
        if (Button("Atravesse o limiar  →", 73, 520, 370, 62, true)) Begin();
        if (Button("Como jogar", 73, 598, 178, 46)) help = "controls";
        if (Button("Créditos", 265, 598, 178, 46)) help = "credits";
        if (PlayerPrefs.GetInt("william.checkpoint", 0) == 1 && Button("Continuar trilha", 460, 598, 235, 46)) ContinueCheckpoint();
        Label("PRÓLOGO  /  UMA JORNADA EM TRÊS ENCONTROS", 73, 675, 750, 28, tiny);
    }
    void DrawStory() {
        Actor("william", new Vector2(400, 445), 2.7f); Actor("moth", new Vector2(625, 445), 2.5f); Actor("fox", new Vector2(770, 465), 2.2f);
        Panel(55, 492, 1170, 190, true); Label(voices[line], 83, 510, 1030, 35, small);
        Label(story[line].Substring(0, Mathf.Min(story[line].Length, (int)typed)), 83, 549, 1080, 82);
        Label((line + 1) + " / 3  ·  ESPAÇO PARA CONTINUAR", 83, 645, 700, 25, tiny);
        if (Button("Continuar  →", 955, 628, 240, 42)) AdvanceStory();
        if (Button("Pular", 1110, 25, 115, 42)) Go("map");
    }
    void DrawMap() {
        Box(0, 0, 1280, 720, new Color(.02f, .06f, .09f, .62f)); Label("A TRILHA DE AURORA", 70, 64, 1100, 65, heading);
        Label("Cada passagem revela um fragmento do juramento.", 73, 130, 1000, 45);
        for (int i = 0; i < 3; i++) {
            float x = 250 + i * 390, y = 300 + (i == 1 ? 65 : 0);
            if (i < 2) Stroke(new Vector2(x, y), new Vector2(x + 390, i == 0 ? 365 : 300), new Color(.8f, .77f, .5f, .35f), 2);
            Oval(new Vector2(x, y), 100, 100, new Color(.12f, .24f, .26f)); Ring(new Vector2(x, y), 48, i <= encounter ? gold : muted);
            Label(i < encounter ? "✓" : "0" + (i + 1), x - 40, y - 24, 80, 48, centered);
            Label(names[i], x - 145, y + 66, 290, 60, centered);
        }
        Panel(70, 520, 1140, 147, true); Label(names[encounter], 95, 541, 760, 44, heading);
        Label(descriptions[encounter], 95, 590, 775, 62, small);
        if (Button("Entrar na passagem  →", 895, 561, 285, 65, true)) Fight();
    }
    void DrawBattle() {
        var saved = GUI.matrix;
        if (!lowMotion && shake > 0) GUI.matrix = GUI.matrix * Matrix4x4.Translate(new Vector3(Mathf.Sin(clock * 75) * shake * 4, Mathf.Cos(clock * 83) * shake * 2, 0));
        foreach (var u in battle.Units) {
            Vector2 p = Position(u); if (!u.Alive) { Oval(p, 75, 23, new Color(0, 0, 0, .14f)); continue; }
            bool active = effects.Exists(e => e.ev.Source == u.Id && e.life > .6f && e.ev.Kind != "charge");
            Vector2 lunge = active && !lowMotion ? new Vector2(u.Side == Side.Heroes ? 13 : -13, -3) : Vector2.zero;
            Oval(p + new Vector2(0, 2), u.IsBoss ? 110 : 75, 22, new Color(0, 0, 0, .23f));
            if (battle.Target == u) Ring(p, u.IsBoss ? 70 : 52, gold, .28f);
            if (u.Windup > 0) Ring(p, 70 + u.Windup * 23, new Color(1, .38f, .23f, .75f), .4f);
            if (u.Shield > 0) Ring(p + new Vector2(0, -60), 67, new Color(.6f, .9f, .96f, .42f));
            Actor(u.IsBoss ? "boss" : u.Art, p + lunge, u.IsBoss ? 2.9f : u.Side == Side.Heroes ? 2.3f : 2.2f, u.Side == Side.Enemies, active || u.Windup > 0);
            if (u.Side == Side.Enemies) {
                Label(u.Name, p.x - 100, p.y + 12, 210, 28, small); Bar(p.x - 75, p.y + 43, 150, u.Hp, u.MaxHp, u.Enraged ? Hex(0xf3a077) : gold);
                if (battle.Target == u) Label("ALVO", p.x - 35, p.y - (u.IsBoss ? 235 : 195), 100, 25, tiny);
                if (u.Windup > 0) {
                    var target = battle.Units.Find(x => x.Id == u.IntentTarget);
                    Panel(p.x - 110, p.y - 170, 220, 52); Label("! " + (u.Intent.StartsWith("Onda") ? "Toda a equipe" : target == null ? "Ataque" : target.Name) + " · " + u.Windup.ToString("0.0") + "s", p.x - 100, p.y - 158, 210, 35, small);
                }
                if (u.Frozen > 0) Label("GEADA · " + u.Frozen.ToString("0.0") + "s", p.x - 65, p.y - 138, 170, 32, small);
                if (u.Enraged) Label("FÚRIA", p.x - 30, p.y - 205, 100, 32, small);
                if (!paused && help == "" && GUI.Button(new Rect(p.x - 75, p.y - 145, 150, 190), GUIContent.none, GUIStyle.none)) battle.Select(u.Id);
            }
        }
        DrawEffects(); GUI.matrix = saved;
        Panel(0, 0, 1280, 84); Label("0" + (encounter + 1) + "  /  " + names[encounter].ToUpperInvariant(), 30, 18, 810, 36);
        Label("Selecione um inimigo · Geada interrompe · Chama sobre Geada causa choque térmico", 30, 55, 930, 22, tiny);
        if (Button("?", 1034, 20, 48, 45)) help = "controls";
        if (Button("Pausar", 1094, 20, 155, 45)) Pause();
        for (int i = 0; i < 3; i++) {
            var u = battle.Units[i]; float x = 25 + i * 205;
            Panel(x, 99, 193, 83); Label(u.Name, x + 13, 108, 180, 30, small); Label(u.Alive ? ((int)u.Hp + " / " + (int)u.MaxHp) : "CAÍDO", x + 13, 135, 140, 25, tiny);
            Bar(x + 13, 166, 167, u.Hp, u.MaxHp, cyan); if (u.Shield > 0) Label("◇ " + (int)u.Shield, x + 126, 137, 64, 25, tiny);
        }
        Panel(0, 582, 1280, 138);
        Label("RESSONÂNCIA", 27, 601, 220, 25, tiny); Label(((int)battle.Energy).ToString("00") + " / 100", 27, 631, 220, 40, heading);
        Bar(27, 686, 198, battle.Energy, 100, cyan, 6);
        GUI.enabled = !paused && help == "" && !battle.Finished;
        if (Button(battle.Auto ? "AUTO  ●" : "AUTO  ○", 248, 602, 155, 40)) battle.Auto = !battle.Auto;
        if (Button("Corte  [ESPAÇO]", 248, 651, 155, 47)) battle.Basic();
        string[] skills = {"CHAMA", "GEADA", "ÉGIDE"}; string[] keys = {"Q", "E", "R"}; string[] hints = {"Dano / choque térmico", "Interrompe e congela", "Protege toda a equipe"};
        for (int i = 0; i < 3; i++) {
            var power = (Power)i; bool available = !paused && help == "" && battle.CanCast(power) == ""; GUI.enabled = available;
            string status = battle.Cooldowns[i] > .01f ? battle.Cooldowns[i].ToString("0.0") + " s" : (int)battle.Cost(power) + " energia";
            if (Button(skills[i] + "  [" + keys[i] + "]\n" + status, 425 + i * 280, 602, 260, 68, available && i == 2)) Cast(power);
            Label(hints[i], 439 + i * 280, 679, 252, 28, tiny);
        }
        GUI.enabled = true;
        if (clock < noticeUntil) { Panel(385, 195, 620, 42, true); Label(notice, 405, 205, 580, 30, small); }
        if (paused) DrawPause();
    }
    void DrawEffects() {
        foreach (var e in effects) {
            var u = battle.Units.Find(x => x.Id == e.ev.Target); if (u == null) continue;
            Vector2 p = Position(u) + new Vector2(0, -60); float progress = 1 - e.life / 1.1f;
            Color color = e.ev.Kind == "flame" ? Hex(0xffb06c) : e.ev.Kind == "frost" ? cyan : e.ev.Kind == "heal" ? Hex(0xa7ebae) : gold;
            color.a = Mathf.Clamp01(e.life * 2);
            if (e.ev.Kind != "charge") {
                int count = lowMotion ? 4 : 13;
                for (int i = 0; i < count; i++) { float a = i * Mathf.PI * 2 / count; Box(p.x + Mathf.Cos(a) * progress * 110, p.y + Mathf.Sin(a) * progress * 80, 3, 3, color); }
                if (e.ev.Kind == "frost" || e.ev.Kind == "flame" || e.ev.Kind == "aegis") Ring(p, 15 + progress * 100, color);
            }
            string value = e.ev.Kind == "interrupt" ? "RUPTURA" : e.ev.Kind == "combo" ? "CHOQUE" : e.ev.Kind == "heal" ? "+" + (int)e.ev.Amount : e.ev.Amount > 0 ? ((int)e.ev.Amount).ToString() : "";
            if (value != "") Label(value, p.x - 50, p.y - 70 - progress * 50, 220, 45);
        }
    }
    void DrawPause() {
        Box(0, 0, 1280, 720, new Color(0, .02f, .04f, .6f)); Panel(385, 170, 510, 390, true);
        Label("UM INSTANTE DE SILÊNCIO", 415, 200, 450, 50); Label("O combate está pausado.", 415, 250, 450, 40, small);
        if (Button("Retomar", 415, 302, 450, 50, true)) Pause();
        if (Button(isMuted ? "Ativar som" : "Silenciar", 415, 367, 215, 48)) { isMuted = !isMuted; ApplySound(); }
        if (Button(lowMotion ? "Movimento: reduzido" : "Movimento: normal", 650, 367, 215, 48)) { lowMotion = !lowMotion; PlayerPrefs.SetInt("william.motion.low", lowMotion ? 1 : 0); }
        if (Button("Voltar ao título", 415, 443, 450, 48)) { paused = false; Go("title"); }
    }
    void DrawReward() {
        Box(0, 0, 1280, 720, new Color(.02f, .06f, .09f, .79f)); Label("UM FRAGMENTO DO JURAMENTO", 70, 67, 1160, 65, heading);
        Label("O farol reconhece sua vontade. Escolha o que levar adiante.", 73, 143, 1120, 50);
        Label("Combos " + battle.Combos + "   /   Interrupções " + battle.Interrupts + "   /   Tempo " + battle.Elapsed.ToString("0") + " s", 73, 205, 1100, 30, small);
        string[] titles = {"LÂMINA DE ÂMBAR", "MANTO DO VIAJANTE", "CRISTAL DE AURORA"};
        string[] bodies = {"Cada corte de William\ncausa mais 5 de dano.", "William recebe\nmais 45 de vida máxima.", "Comece os próximos encontros\ncom mais 15 de energia."};
        for (int i = 0; i < 3; i++) {
            float x = 70 + i * 390; Panel(x, 285, 360, 300, true); Ring(new Vector2(x + 180, 345), 25, i == 2 ? cyan : gold);
            Label(titles[i], x + 20, 390, 320, 55, centered); Label(bodies[i], x + 25, 452, 310, 70, centered);
            if (Button("Escolher", x + 25, 529, 310, 45)) { if (i == 0) strength++; else if (i == 1) vitality++; else focus++; encounter++; Go("map"); }
        }
        Label("A equipe se recupera antes de continuar. Sua escolha permanece até o fim desta jornada.", 73, 630, 1130, 55, small);
    }
    void DrawEnd() {
        bool won = page == "ending";
        Box(0, 0, 1280, 720, new Color(.02f, .06f, .09f, .75f)); Label(won ? "AURORA ESPERA" : "A LUZ AINDA VIVE", 85, 115, 1100, 95, title);
        Label(won ? "O guardião reconheceu o juramento dos três. Além do portal, sete sinos responderam.\n\nWilliam apertou o bilhete de Tomás.\n“Guarde uma luz na janela, irmão. Estou chegando.”" : "William caiu, mas o caminho permanece aberto.\nUse Geada durante o aviso de ataque. Preserve energia para proteger a equipe com Égide.", 90, 255, 1000, 205);
        if (won) Label("JORNADA CONCLUÍDA   ·   " + totalCombos + " combos   ·   " + totalInterrupts + " interrupções", 90, 490, 1100, 45, small);
        if (Button(won ? "Uma nova jornada" : "Retomar encontro", 90, 567, 340, 60, true)) { if (won) Begin(); else Fight(); }
        if (Button("Voltar ao título", 455, 567, 280, 60)) Go("title");
        Label(won ? "FIM DO PRÓLOGO / O sinal de Tomás continua além de Aurora." : "As melhorias escolhidas são preservadas ao retomar.", 90, 660, 1100, 35, tiny);
    }
    void DrawHelp() {
        Box(0, 0, 1280, 720, new Color(0, .02f, .04f, .8f)); Panel(235, 105, 810, 510, true);
        Label(help == "credits" ? "FEITO PARA WILLIAM" : "CARREGUE A LUZ", 270, 140, 740, 55, heading);
        string value = help == "credits"
            ? "William e direção criativa: Gui571.\n\nArte revisada: imagens originais geradas com assistência de IA; poses com movimentos procedurais. Atlas antigos: Procedural Pixel Creatures, MIT. Créditos em Resources/Art. Fonte DejaVu e respectivos avisos incluídos. Cenário, apresentação e áudio originais deste projeto.\n\nDragon Crashers é referência de apresentação. Nenhum asset desse jogo ou da coleção Mana Seed foi incorporado."
            : "William ataca automaticamente. Toque em um inimigo para concentrar a equipe nele; TAB alterna o alvo.\n\nQ · CHAMA causa dano. Sobre um inimigo congelado, produz choque térmico.\nE · GEADA interrompe golpes anunciados e congela o alvo.\nR · ÉGIDE protege a equipe com um escudo temporário.\n\nESPAÇO executa um corte manual e recupera energia. T alterna Auto; ESC pausa. Os botões também respondem a cliques e toques.";
        Label(value, 270, 215, 740, 325); if (Button("Entendi", 735, 540, 270, 50, true)) help = "";
    }
}
}
