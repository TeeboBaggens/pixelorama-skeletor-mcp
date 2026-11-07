#!/usr/bin/env python3
"""pixq.py <tool> [params.json]  |  pixq.py eval <script.gd>  -- compact bridge client."""
import json, sys, urllib.request
URL = "http://127.0.0.1:7373/command"
tool = sys.argv[1]
if tool == "eval":
    params = {"code": open(sys.argv[2]).read(), "record_undo": False}
    tool = "eval_gdscript"
else:
    a = sys.argv[2] if len(sys.argv) > 2 else "{}"
    params = json.loads(a) if a.lstrip().startswith("{") else json.load(open(a))
req = urllib.request.Request(URL, json.dumps({"tool": tool, "params": params}).encode(),
                             {"Content-Type": "application/json"})
try:
    r = json.load(urllib.request.urlopen(req, timeout=120))
except urllib.error.HTTPError as e:
    r = json.load(e)
if not r.get("success"):
    print("FAIL:", r.get("error")); sys.exit(1)
d = r.get("data", {})
out = d.get("result", d) if isinstance(d, dict) else d
print(json.dumps(out, indent=1)[:4000])
