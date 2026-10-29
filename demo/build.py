"""Build a standalone offline HTML from reviewed sources and existing licensed atlases."""
import base64,json,re
from pathlib import Path
root=Path(__file__).resolve().parent
repo=root.parent
data={'art':{},'licenses':{}}
for name,path in {'Sprites · MIT':'intro/creatures/PROCEDURAL-CREATURES-LICENSE.txt','Créditos':'intro/creatures/THIRD_PARTY_NOTICES.md','Adaptações':'tools/creature_generator/ADAPTATION-NOTICE.md','Fonte':'assets/FONT-LICENSE.txt'}.items():
 data['licenses'][name]=(repo/path).read_text()
for kind,file in {'atlas':'Characters.png','forest':'Forest.png'}.items():
 p=repo/'unity/Assets/William/Resources/Art/Aurora'/file
 data['art'][kind]={'image':'data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode()}
data['licenses']['Nova arte · Aurora']=(repo/'unity/Assets/William/Resources/Art/Aurora/ART-NOTES.md').read_text()
font=base64.b64encode((repo/'assets/interface.ttf').read_bytes()).decode()
css="@font-face{font-family:Interface;src:url(data:font/ttf;base64,"+font+") format('truetype');font-display:swap}"+(root/'src/style.css').read_text()
combat=(root/'combat.js').read_text();combat=re.sub(r'^export\s+(?=(?:class|const|function)\b)','',combat,flags=re.M)
html=(root/'src/shell.html').read_text().replace('/*STYLE*/',css).replace('/*DATA*/','const DATA='+json.dumps(data,separators=(',',':'))+';').replace('/*COMBAT*/',combat).replace('/*GAME*/',(root/'src/game.js').read_text())
(root/'index.html').write_text(html)
print('Built offline demo:',len(html.encode()),'bytes')
