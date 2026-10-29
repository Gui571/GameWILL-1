"""Package the self-contained playable preview and preserve existing download checksums."""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib,shutil
root=Path(__file__).resolve().parents[1]
downloads=root/'downloads';html=downloads/'William-Aurora-Demo.html'
shutil.copyfile(root/'demo/index.html',html)
with ZipFile(downloads/'William-Aurora-Demo.zip','w',ZIP_DEFLATED) as z:
 z.write(html,html.name)
 z.write(root/'demo/README.md','LEIA-ME.md')
 for file in (root/'unity/Assets/William/Resources/Art').rglob('*'):
  if file.suffix in ('.txt','.md'):z.write(file,'LICENSES/'+str(file.relative_to(root/'unity/Assets/William/Resources/Art')))
with ZipFile(downloads/'William-Aurora-Demo.zip') as z:
 assert z.testzip() is None
checks=[]
for file in sorted(downloads.iterdir()):
 if file.suffix in ('.zip','.html'):
  checks.append(hashlib.sha256(file.read_bytes()).hexdigest()+'  '+file.name)
(downloads/'SHA256SUMS.txt').write_text('\n'.join(checks)+'\n')
print('Packaged:',html.stat().st_size,'bytes HTML;', (downloads/'William-Aurora-Demo.zip').stat().st_size,'bytes ZIP')
