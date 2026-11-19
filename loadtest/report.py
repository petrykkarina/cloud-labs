"""Print a short Markdown report from a k6 summary JSON.

Usage: python3 loadtest/report.py loadtest/results/<label>-summary.json
"""

import json
import sys

data = json.load(open(sys.argv[1]))
m = data["metrics"]


def v(metric, key):
    return m[metric]["values"][key]


duration_s = data["state"]["testRunDurationMs"] / 1000
print(f"| Метрика | Значення |\n|---|---|")
print(f"| Тривалість | {duration_s / 60:.1f} хв |")
print(f"| Запитів усього | {int(v('http_reqs', 'count'))} |")
print(f"| Запитів за секунду (середнє) | {v('http_reqs', 'rate'):.1f} |")
print(f"| Ітерацій | {int(v('iterations', 'count'))} |")
print(f"| Частка помилок | {v('http_req_failed', 'rate') * 100:.2f}% |")
for p in ["med", "p(95)", "p(99)"]:
    label = "p50" if p == "med" else p.replace("(", "").replace(")", "")
    print(f"| Латентність {label} | {v('http_req_duration', p):.0f} мс |")

print("\n| Ендпоінт | p50, мс | p95, мс | p99, мс |\n|---|---|---|---|")
for name, metric in m.items():
    if name.startswith("http_req_duration{name:"):
        endpoint = name[len("http_req_duration{name:"):-1]
        vals = metric["values"]
        print(f"| {endpoint} | {vals['med']:.0f} | {vals['p(95)']:.0f} | {vals['p(99)']:.0f} |")
