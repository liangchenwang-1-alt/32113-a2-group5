"""Read-only classroom inspection. Run inside the Python container."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
from run_all import Pipeline
p=argparse.ArgumentParser()
p.add_argument('topic', choices=['overview','sources','identity','rejects','reports','audit','trace','guards'])
a=p.parse_args()
root=Path(__file__).resolve().parent
out=root/'evidence'/('inspect_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
out.mkdir(parents=True)
r=Pipeline(root/'config/docker-compose.yml',out)
sql=(root/'queries'/(a.topic+'.sql')).read_text(encoding='utf-8')
print(r.query(a.topic,'BEGIN READ ONLY;\n'+sql+'\nROLLBACK;'))
