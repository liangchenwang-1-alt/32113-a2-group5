"""Build a self-contained dashboard from the verified warehouse CSV exports."""
import csv
import html

def render_dashboard(folder,batch):
    datasets={f.stem:list(csv.DictReader(f.open(encoding='utf-8-sig'))) for f in folder.glob('*.csv')}
    k=datasets['v_r5_data_quality_kpi'][0]
    tiles=''.join('<article><span>'+html.escape(label)+'</span><strong>'+html.escape(k[key])+'</strong></article>'
        for label,key in [('Customers','dim_customer_rows'),('Accepted transactions','transaction_rows'),
                          ('Accepted AUD volume','transaction_amount_aud'),('Rejected events','rejected_rows')])
    def chart(title,view,label,value):
        rows=datasets[view]; scale=max([float(r[value]) for r in rows]+[1])
        bars=''.join('<div class="barrow"><span>'+html.escape(r[label])+'</span><div class="track"><div class="bar" style="width:'+str(float(r[value])/scale*100)+'%"></div></div><b>'+html.escape(r[value])+'</b></div>' for r in rows)
        return '<section><h2>'+title+'</h2>'+bars+'</section>'
    charts=chart('R2 Accepted AUD by channel','v_r2b_transaction_by_channel','channel_code','amount_aud')+chart('R3 Digital activities by channel','v_r3_channel_engagement','channel_code','activity_count')+chart('R4 Service cases by status','v_r4_service_case_summary','status','case_count')
    tables=[]
    for name,rows in datasets.items():
        headers=list(rows[0]) if rows else []
        head=''.join('<th scope="col">'+html.escape(c)+'</th>' for c in headers)
        body=''.join('<tr>'+''.join('<td>'+html.escape(r[c])+'</td>' for c in headers)+'</tr>' for r in rows)
        tables.append('<section><h2>'+name+'</h2><p>'+str(len(rows))+' rows · <a href="'+name+'.csv">Download CSV</a></p><div class="scroll"><table><thead><tr>'+head+'</tr></thead><tbody>'+body+'</tbody></table></div></section>')
    return """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>CBA Customer 360</title>
<style>body{font:16px Arial,sans-serif;margin:0;background:#f4f6f8;color:#172d40}main{max-width:1250px;margin:auto;padding:32px}h1{font-size:30px}h2{font-size:19px;overflow-wrap:anywhere}p{line-height:1.55}.tiles{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}article,section{background:white;padding:20px;border:1px solid #dce2e8;border-radius:6px}article span{display:block;font-size:14px}strong{display:block;font-size:27px;margin-top:10px}.charts{display:grid;grid-template-columns:1fr;gap:16px;margin:20px 0}section{margin:20px 0}.barrow{display:grid;grid-template-columns:100px 1fr 120px;gap:12px;margin:12px 0;font-size:14px}.track{background:#edf2f6}.bar{height:18px;background:#286da8}.scroll{overflow:auto;max-height:450px}table{border-collapse:collapse;font-size:13px;width:100%}td,th{padding:9px;border:1px solid #d8dee5;text-align:left;white-space:nowrap}th{background:#e9eff5;position:sticky;top:0}input{padding:10px;max-width:350px;width:80%;font-size:16px}a{color:#165c94}@media(max-width:700px){main{padding:15px}.tiles{grid-template-columns:1fr 1fr}.barrow{grid-template-columns:80px 1fr 95px}strong{font-size:22px}}</style></head><body><main>
<h1>CBA Customer 360</h1><p>Fictional banking prototype · Synthetic data only</p><p>Verified batch: """+html.escape(batch)+"""</p><p>This snapshot is refreshed after a successful pipeline run. Accepted positive AUD volume is not net cash flow. Service cases have no channel attribution.</p><div class="tiles">"""+tiles+"""</div><div class="charts">"""+charts+"""</div><label for="filter">Filter detail-table rows </label><input id="filter" placeholder="Try C0001 or MOBILE"><p>Filtering hides detail rows only; it does not recalculate charts or KPI totals. Clear the search to restore all rows.</p>"""+''.join(tables)+"""<script>document.getElementById('filter').addEventListener('input',e=>{let q=e.target.value.toLowerCase();document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(q))})</script></main></body></html>"""
