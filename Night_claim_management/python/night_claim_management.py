#!/usr/bin/env python3
"""
Night Schedule — Webview UI với AI Assistant

Modern HTML/JS webview replacement for the PowerShell NightSchedule GUI.
Provides a modern dark UI and implements the same schedule-check logic
in Python (fetch schedule, compute totals, USD using OKX price, save/load addresses).

Run with:
  pip install pywebview
  python -m night.night_schedule_webview

"""
from __future__ import annotations

import json
import os
import sys
import threading
import subprocess
import shutil
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from urllib.request import Request, urlopen
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.error import URLError, HTTPError

try:
    import webview
except Exception:
    webview = None

DATA_FILE = os.path.join(os.path.dirname(__file__), 'NIGHT_addresses.json')


def fetch_json(url: str, timeout: int = 8) -> Any:
    req = Request(url, headers={'User-Agent': 'night-webview/1.0'})
    try:
        with urlopen(req, timeout=timeout) as r:
            raw = r.read()
            return json.loads(raw.decode('utf-8', errors='ignore'))
    except HTTPError as e:
        raise
    except URLError as e:
        raise


def fetch_okx_prices() -> Dict[str, float]:
    """Fetch simplified OKX spot tickers and return mapping like {'NIGHT': price}.
    Uses public OKX endpoint similar to the PowerShell version.
    """
    out: Dict[str, float] = {}
    try:
        url = 'https://www.okx.com/api/v5/market/tickers?instType=SPOT'
        data = fetch_json(url)
        if not data or 'data' not in data:
            return out
        for item in data['data']:
            inst = item.get('instId', '')
            last = item.get('last')
            if not inst or not last:
                continue
            # inst like 'NIGHT-USDT' or 'NIGHT-USDT'
            sym = inst.split('-')[0]
            try:
                out[sym] = float(last)
            except Exception:
                continue
    except Exception:
        pass
    return out


class Api:
    def __init__(self):
        self._last_address: Optional[str] = None

    def check_address(self, address: str) -> Dict[str, Any]:
        """Check schedule for an address and return processed data.

        Returns structure matching the GUI needs: thaws list with amount (NIGHT), thaw_date (ISO), days_until, total_amount, total_usd
        """
        address = (address or '').strip()
        if not address:
            return {'error': 'empty address'}

        try:
            data = self._fetch_schedule_via_script(address)
        except Exception as e:
            return {'error': f'network error: {e}'}

        if not data or 'thaws' not in data or not data['thaws']:
          return {'error': 'No schedule found', 'thaws': []}

        thaws = []
        total_amount = 0.0
        idx = 1
        for item in data['thaws']:
          # amount in micro units per earlier implementation (divide by 1e6)
          raw_amount = item.get('amount', 0)
          try:
            amount = float(raw_amount) / 1e6
          except Exception:
            amount = 0.0

          # parse date (thawing_period_start) and build VN date (+7h)
          thaw_raw = item.get('thawing_period_start') or item.get('start') or ''
          thaw_dt = None
          vn_date_str = None
          days_until = None
          iso = None
          if thaw_raw:
            try:
              thaw_dt = datetime.fromisoformat(thaw_raw.replace('Z', '+00:00'))
            except Exception:
              try:
                thaw_dt = datetime.strptime(thaw_raw, '%Y-%m-%dT%H:%M:%S')
                # assume UTC
                thaw_dt = thaw_dt.replace(tzinfo=timezone.utc)
              except Exception:
                thaw_dt = None

          if thaw_dt:
            # VN timezone +7
            from datetime import timedelta
            vn_dt = thaw_dt + timedelta(hours=7)
            vn_date_str = vn_dt.strftime('%Y-%m-%d %H:%M:%S')
            now = datetime.now(timezone.utc)
            delta = thaw_dt - now
            days_until = max(0, delta.days)
            iso = thaw_dt.isoformat()

          status_raw = item.get('status', '')
          status_text = 'Unclaimed' if status_raw == 'upcoming' else 'Claimed'
          countdown_text = f" | In {days_until} days" if (status_raw == 'upcoming' and days_until is not None) else ''

          batch_info = f"📌 Batch {idx}: {round(amount,3)} NIGHT\n"
          batch_info += f"   🔔 {status_text}{countdown_text}\n"
          batch_info += f"   ⏰ {vn_date_str or 'Unknown'}"

          total_amount += amount
          thaws.append({
            'amount': amount,
            'thaw_date': iso,
            'days_until': days_until,
            'status': status_text,
            'vn_date': vn_date_str,
            'batch_info': batch_info,
            'raw': item
          })
          idx += 1

        # fetch price
        prices = fetch_okx_prices()
        night_price = prices.get('NIGHT') or prices.get('NIGHTUSDT') or 0.0
        total_usd = round(total_amount * (night_price or 0.0), 3)

        self._last_address = address

        return {'thaws': thaws, 'total_amount': total_amount, 'total_usd': total_usd, 'price': night_price}

    def _fetch_schedule_via_script(self, address: str) -> Any:
        """Call the repository's `fetch.ps1` script to retrieve the schedule and return parsed JSON.

        The script writes a JSON file named like `thaw_schedule_<prefix>.json` in its directory.
        We run PowerShell with the script directory as cwd so the output file is predictable.
        """
        if not address:
            raise ValueError('empty address')

        # script path expected next to this file
        script_dir = os.path.dirname(__file__)
        script_path = os.path.join(script_dir, 'fetch.ps1')
        if not os.path.exists(script_path):
            raise FileNotFoundError(f'fetch script not found: {script_path}')

        # prefer pwsh (PowerShell Core), fall back to powershell
        exe = shutil.which('pwsh') or shutil.which('powershell')
        if not exe:
            raise RuntimeError('No PowerShell executable found (pwsh or powershell)')

        args = [exe, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script_path, '-Address', address]
        try:
            proc = subprocess.run(args, cwd=script_dir, capture_output=True, text=True, timeout=30)
        except Exception as e:
            raise RuntimeError(f'Failed to execute PowerShell: {e}')

        if proc.returncode != 0:
            # include stderr/stdout for diagnostics
            msg = (proc.stderr or proc.stdout).strip() or f'PowerShell exited {proc.returncode}'
            raise RuntimeError(msg)

        # The fetch.ps1 writes an output file named thaw_schedule_<addrprefix>.json
        prefix = address[:10]
        out_name = f'thaw_schedule_{prefix}.json'
        out_path = os.path.join(script_dir, out_name)
        if not os.path.exists(out_path):
            # try to parse any 'Saved to' line in stdout
            for line in proc.stdout.splitlines():
                if 'Saved to' in line:
                    candidate = line.split('Saved to', 1)[1].strip()
                    # candidate may be a relative path
                    cand_path = os.path.join(script_dir, candidate) if not os.path.isabs(candidate) else candidate
                    if os.path.exists(cand_path):
                        out_path = cand_path
                        break
            else:
                raise RuntimeError('Expected JSON output file not found; PowerShell stdout: ' + proc.stdout.strip())

        try:
          # read with utf-8-sig to strip BOM if present
          with open(out_path, 'r', encoding='utf-8-sig') as f:
            return json.load(f)
        except Exception as e:
          raise RuntimeError(f'Failed to read JSON output file: {e}')

    def save_address(self, address: str) -> Dict[str, Any]:
        address = (address or '').strip()
        if not address:
            return {'error': 'empty address'}
        try:
            # load existing
            existing = []
            if os.path.exists(DATA_FILE):
                with open(DATA_FILE, 'r', encoding='utf-8') as f:
                    try:
                        obj = json.load(f)
                        existing = obj.get('Addresses', []) if isinstance(obj, dict) else []
                    except Exception:
                        existing = []

            if address not in existing:
                existing.append(address)
                obj = {'CreatedAt': datetime.now().strftime('%Y-%m-%d %H:%M:%S'), 'Addresses': existing}
                with open(DATA_FILE, 'w', encoding='utf-8') as f:
                    json.dump(obj, f, indent=2, ensure_ascii=False)
            return {'ok': True, 'path': DATA_FILE}
        except Exception as e:
            return {'error': str(e)}

    def view_all(self) -> Dict[str, Any]:
        if not os.path.exists(DATA_FILE):
            return {'addresses': []}
        try:
            with open(DATA_FILE, 'r', encoding='utf-8') as f:
                obj = json.load(f)
                return {'addresses': obj.get('Addresses', [])}
        except Exception as e:
            return {'error': str(e)}

    def fetch_ohlc(self, inst_id: str = 'NIGHT-USDT', bar: str = '1H', limit: int = 200):
        """Fetch OHLC (history-candles) from OKX and return list of dicts: {ts, open, high, low, close, volume} in chronological order."""
        try:
            # OKX history-candles endpoint
            url = f'https://www.okx.com/api/v5/market/history-candles?instId={inst_id}&bar={bar}&limit={limit}'
            data = fetch_json(url)
        except Exception as e:
            return {'error': str(e)}

        if not data or 'data' not in data:
            return {'error': 'no data'}

        out = []
        for item in data['data']:
            try:
                # item: [timestamp, open, high, low, close, volume]
                ts = int(item[0])
                o = float(item[1])
                h = float(item[2])
                l = float(item[3])
                c = float(item[4])
                v = float(item[5])
                out.append({'ts': ts, 'open': o, 'high': h, 'low': l, 'close': c, 'volume': v})
            except Exception:
                continue

        # OKX returns newest-first; return chronological (oldest first)
        out.reverse()
        return out

    def fetch_ohlc_bybit(self, inst_id: str = 'NIGHT-USDT', bar: str = '1H', limit: int = 200):
        """Fetch OHLC from Bybit (best-effort mapping).

        Returns same structure as fetch_ohlc: list of {ts, open, high, low, close, volume}
        """
        try:
            # map inst like 'ADA-USDT' -> 'ADAUSDT'
            symbol = inst_id.replace('-', '').upper()
            # timeframe mapping for Bybit v5 kline intervals
            tf_map = {
                '1m': '1', '5m': '5', '15m': '15', '1H': '60', '4H': '240', '1D': 'D'
            }
            interval = tf_map.get(bar, '60')

            url = (
                "https://api.bybit.com/v5/market/kline"
                f"?category=spot&symbol={symbol}&interval={interval}&limit={limit}"
            )

            data = fetch_json(url)
        except Exception as e:
            return {'error': str(e)}

        rows = []
        try:
            # Bybit v5 shape: {'retCode':0,'result':{'list':[[ts,o,h,l,c,vol],...]}}
            if isinstance(data, dict):
                rows = data.get('result', {}).get('list', []) if data.get('result') else data.get('result') or []
            elif isinstance(data, list):
                rows = data
        except Exception:
            rows = []

        out = []
        try:
            for r in rows:
                # expect r like [ts, open, high, low, close, volume]
                ts = int(r[0])
                out.append({
                    'ts': ts,
                    'open': float(r[1]),
                    'high': float(r[2]),
                    'low': float(r[3]),
                    'close': float(r[4]),
                    'volume': float(r[5]),
                })

            out.sort(key=lambda x: x['ts'])
            return out
        except Exception as e:
            return {'error': f'parse error: {e}'}

    def fetch_ohlc_gate(self, inst_id: str = 'NIGHT-USDT', bar: str = '1H', limit: int = 200):
        """Fetch OHLC from Gate.io (spec-compliant parser).

        Gate always returns arrays in the documented order:
        [timestamp, open, high, low, close, volume]
        Timestamps are seconds; convert to milliseconds and return chronological list.
        """
        try:
            pair = inst_id.replace('-', '_').upper()
            tf_map = {
                '1m': '1m', '5m': '5m', '15m': '15m', '1H': '1h', '4H': '4h', '1D': '1d'
            }
            interval = tf_map.get(bar, '1h')

            url = (
                "https://api.gateio.ws/api/v4/spot/candlesticks"
                f"?currency_pair={pair}&interval={interval}&limit={limit}"
            )

            data = fetch_json(url)
        except Exception as e:
            return {'error': str(e)}

        out = []
        try:
            if not isinstance(data, list):
                return {'error': 'unexpected response format'}

            for r in data:
              if not r or len(r) < 6:
                continue
              try:
                ts = int(float(r[0]))
                if ts < 1e12:
                  ts = int(ts * 1000)
                # parse fields as floats
                f1 = float(r[1]); f2 = float(r[2]); f3 = float(r[3]); f4 = float(r[4]); f5 = float(r[5])
                # Default assumed order: [open, high, low, close, volume]
                o, h, l, c, v = f1, f2, f3, f4, f5
                # Conservative fix: if 'open' looks like a very large number (likely volume)
                # while the last field is small (likely price), remap from [t, vol, close, high, low, open]
                max_price = max(abs(h), abs(l), abs(c), abs(o)) if any([h, l, c, o]) else 0
                if max_price > 0 and (o > max_price * 1000 and f5 < max_price * 100):
                  # interpret as [t, volume, close, high, low, open]
                  v = f1
                  c = f2
                  h = f3
                  l = f4
                  o = f5
                out.append({'ts': ts, 'open': o, 'high': h, 'low': l, 'close': c, 'volume': v})
              except Exception:
                continue

            out.sort(key=lambda x: x['ts'])
            return out
        except Exception as e:
            return {'error': f'parse error: {e}'}

    def chat_message(self, message: str, nodes_data=None):
        """
        Hàm xử lý chat tập trung.
        - message: Nội dung chat tự do.
        - nodes_data: (Tùy chọn) Dữ liệu flowchart để AI hiểu ngữ cảnh.
        """
        # New behaviour: act as a forwarding endpoint. Expect `nodes_data` to provide
        # an `endpoint` (URL) and a `payload` (object) to POST. An optional `apiKey`
        # may be provided in `nodes_data['apiKey']`; if omitted, the request will
        # be sent without Authorization header. This function no longer contains
        # built-in model lists or a default API key — it only forwards user-supplied
        # parameters.
        message = (message or '').strip()
        if not message:
            return {'error': 'Tin nhắn trống'}

        if not isinstance(nodes_data, dict) or not nodes_data.get('endpoint'):
            return {'error': 'No endpoint provided. Use the AI mode to supply an endpoint and payload.'}

        endpoint = nodes_data.get('endpoint')
        payload = nodes_data.get('payload')
        # If user didn't supply a full payload, construct a minimal one using message
        if payload is None:
            # allow optional model/messages fields in nodes_data
            model = nodes_data.get('model')
            messages = nodes_data.get('messages') or [{'role': 'user', 'content': message}]
            if model:
                payload = {'model': model, 'messages': messages}
            else:
                payload = {'messages': messages}

        headers = {
            'Content-Type': 'application/json',
            'HTTP-Referer': 'http://localhost',
            'X-Title': 'Multi-sig Flow Assistant'
        }
        api_key = nodes_data.get('apiKey')
        if api_key:
            headers['Authorization'] = f'Bearer {api_key}'

        try:
            req = Request(endpoint, data=json.dumps(payload).encode('utf-8'), headers=headers)
            with urlopen(req, timeout=30) as resp:
                result = json.load(resp)
                # return the raw response and a short `reply` when possible
                reply = None
                try:
                    # Common shape: {choices:[{message:{content:...}}]}
                    if isinstance(result, dict) and 'choices' in result and isinstance(result['choices'], list) and result['choices']:
                        m = result['choices'][0].get('message') or result['choices'][0]
                        reply = m.get('content') if isinstance(m, dict) else None
                except Exception:
                    reply = None
                return {'reply': reply or json.dumps(result), 'raw': result}
        except Exception as e:
            return {'error': str(e)}


HTML = r'''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>NIGHT Schedule</title>
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <style>
  :root{--bg:#07101a;--panel:#0f1720;--muted:#98a0a6;--accent:#ffb86b;--border:#263238;--text:#e6eef6}
    body{margin:0;font-family:Inter,Segoe UI,Roboto,Arial;background:var(--bg);color:var(--text);position:relative}
    .wrap{max-width:1100px;margin:18px auto;padding:18px}
    .head{display:flex;align-items:center;justify-content:space-between;gap:12px}
    h1{margin:0;color:var(--accent);font-size:20px}
    .card{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:14px;margin-top:12px}
    .grid{display:flex;gap:10px}
    input[type=text]{flex:1;padding:10px;border-radius:8px;border:1px solid var(--border);background:transparent;color:var(--text)}
    select,input[type=number]{padding:8px;border-radius:8px;border:1px solid var(--border);background:transparent;color:var(--text)}
    .btn{padding:9px 12px;border-radius:8px;border:none;cursor:pointer;font-weight:700}
    .btn.primary{background:var(--accent);color:#04202a}
    .btn.ghost{background:transparent;border:1px solid var(--border);color:var(--text)}
    .cols{display:flex;gap:12px;margin-top:12px}
    .col{flex:1}
    .log{margin-top:12px;padding:12px;border-radius:8px;background:#071018;border:1px solid var(--border);max-height:360px;overflow:auto}
    .thaw{padding:8px;border-radius:8px;border:1px solid rgba(255,255,255,0.02);margin-bottom:8px}
    footer{margin-top:12px;color:var(--muted);font-size:13px;display:flex;justify-content:space-between}
    @media(max-width:800px){.grid,.cols{flex-direction:column}}

    /* Chart Modal styles */
    .modal{position:fixed;inset:0;background:rgba(0,0,0,0.55);display:flex;align-items:center;justify-content:center;z-index:2500}
    .modal-content{width:calc(100% - 80px);max-width:1100px;background:var(--panel);border-radius:12px;padding:12px;border:1px solid var(--border);box-shadow:0 10px 30px rgba(0,0,0,0.6);position:relative;z-index:2501}
    .chart-controls{display:flex;gap:8px;align-items:center;margin-bottom:8px}

    /* Chat Sidebar styles */
    .chat-sidebar {
        position: fixed; right: 0; top: 0; width: 350px; height: 100vh;
        background: #1e293b; border-left: 1px solid #334155;
        display: flex; flex-direction: column; z-index: 3000; transition: 0.3s;
    }
    .chat-sidebar.collapsed { transform: translateX(300px); }
    .chat-header { padding: 15px; background: #0f172a; display: flex; justify-content: space-between; font-weight: bold; }
    .chat-content { flex: 1; overflow-y: auto; padding: 15px; display: flex; flex-direction: column; gap: 10px; }
    .msg { padding: 10px; border-radius: 8px; font-size: 14px; max-width: 90%; line-height: 1.5; white-space: pre-wrap; }
    .bot { background: #334155; color: #f1f5f9; align-self: flex-start; }
    .user { background: #3b82f6; color: white; align-self: flex-end; }
    .chat-input-area { padding: 15px; background: #0f172a; display: flex; gap: 8px; }
    #ai-input { flex: 1; background: #1e293b; border: 1px solid #334155; color: white; padding: 8px; border-radius: 4px; }
    .chat-input-area button { background: #3b82f6; border: none; color: white; padding: 0 15px; border-radius: 4px; cursor: pointer; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="head">
      <h1><i class="fas fa-moon"></i> NIGHT Schedule</h1>
      <div style="color:var(--muted)">Modern web UI với AI Assistant</div>
    </div>

    <div class="card">
      <div class="grid">
        <input id="address" type="text" placeholder="Enter address to check" />
        <button class="btn primary" id="btnCheck">Check</button>
        <button class="btn ghost" id="btnClear">Clear</button>
        <button class="btn ghost" id="btnSave">Save</button>
        <button class="btn ghost" id="btnViewAll">View All</button>
        <button class="btn ghost" id="btnChart">Chart</button>
        <button class="btn ghost" onclick="toggleChat()"><i class="fas fa-robot"></i> AI Assistant</button>
      </div>

      <div class="cols">
        <div class="col">
          <div style="margin-top:12px;font-size:13px;color:var(--muted)">Status</div>
          <div id="status" style="margin-top:6px;color:var(--muted)">Ready</div>

          <div style="margin-top:12px;font-size:13px;color:var(--muted)">Price (NIGHT)</div>
          <div id="price" style="margin-top:6px;color:var(--muted)">-</div>
        </div>

        <div class="col">
          <div style="margin-top:12px;font-size:13px;color:var(--muted)">Results</div>
          <div id="results" class="log">No results yet</div>
        </div>
      </div>
    </div>

    <!-- Embedded chart area (was modal). Hidden by default; toggled by Chart button -->
    <div id="chartArea" class="card" style="display:none;margin:12px auto 24px;max-width:1100px;padding:12px;margin-right:370px;"></div>

    <footer>
      <div>Saved addresses file: <code>NIGHT_addresses.json</code></div>
      <div style="color:var(--muted)">© NIGHT Schedule</div>
    </footer>
  </div>

  <!-- Chat Sidebar -->
  <div id="chat-sidebar" class="chat-sidebar collapsed">
    <div class="chat-header">
        <span><i class="fas fa-robot"></i> AI Assistant</span>
        <button onclick="toggleChat()" class="chat-toggle">−</button>
    </div>
    <div id="chat-content" class="chat-content">
      <div id="ai-mode-controls" style="display:flex;flex-direction:column;gap:8px;margin-bottom:8px;order:0;">
        <div style="display:flex;gap:8px;align-items:center;">
          <button id="btnUseKey" class="btn ghost">Use your AI (enter API key)</button>
          <button id="btnFree" class="btn ghost">Free (community)</button>
        </div>
        <div id="modelSelectRow" style="display:flex;gap:8px;align-items:center;">
          <select id="modelSelect" style="padding:8px;border-radius:6px;border:1px solid #334155;background:#0f172a;color:#fff">
            <option value="https://api.openai.com/v1/chat/completions">OpenAI — Chat Completions</option>
            <option value="https://api.anthropic.com/v1/complete">Anthropic Claude — /v1/complete</option>
            <option value="https://generativeai.googleapis.com/v1beta2/models/text-bison:generate">Google Gemini (Text-Bison)</option>
          </select>
          <input id="endpointDisplay" type="text" readonly placeholder="Endpoint" style="flex:1;padding:8px;border-radius:6px;border:1px solid #334155;background:#0f172a;color:#bbb">
        </div>
        <div id="apiKeyRow" style="display:none;gap:8px;align-items:center;">
          <input id="apiKeyInput" type="password" placeholder="Enter API key" style="flex:1;padding:8px;border-radius:6px;border:1px solid #334155;background:#0f172a;color:#fff">
          <button id="btnSaveApiKey" class="btn primary">Save Key</button>
        </div>
        <div id="apiKeyStatus" style="color:var(--muted);font-size:13px;display:none;">Using user-provided API key</div>
      </div>
      <!-- messages hidden until user configures Use-your-AI -->
      <div id="chatMessages" style="display:none;">
        <div class="msg bot">Chào mày! Tao là AI đây. Có thể hỏi về NIGHT schedule, crypto trading, hoặc bất cứ thứ gì khác nhé.</div>
      </div>
    </div>
    <div id="chatInputRow" class="chat-input-area" style="display:none;">
      <input type="text" id="ai-input" placeholder="Nhập câu hỏi..." onkeypress="if(event.key==='Enter') callAI()">
      <button onclick="callAI()"><i class="fas fa-paper-plane"></i></button>
    </div>
  </div>

  <script>
    const logEl = document.getElementById('status');
    const resultsEl = document.getElementById('results');
    const priceEl = document.getElementById('price');
    // store recent API outputs here so AI can use them for analysis
    window.apiOutputs = window.apiOutputs || {};

    function setStatus(s){ logEl.textContent = s }

    async function checkAddress(){
      const addr = document.getElementById('address').value.trim();
      if(!addr){ alert('Enter address'); return }
      setStatus('Loading...');
      resultsEl.innerHTML = '...';
      try{
        const res = await window.pywebview.api.check_address(addr);
        // save last check result for AI context
        try{ window.apiOutputs.last_check = res }catch(e){}
        if(res.error){ setStatus('Error: '+res.error); resultsEl.textContent = res.error; return }
        setStatus('Success');
        try{ priceEl.textContent = (res.price != null && isFinite(Number(res.price))) ? Number(res.price).toFixed(3) + ' USD' : 'N/A' }catch(e){ priceEl.textContent = 'N/A' }
        renderResults(res)
      }catch(e){ setStatus('JS error: '+e); resultsEl.textContent = ''+e }
    }

    function renderResults(res, target){
      const container = target || resultsEl;
      container.innerHTML = '';
      const total = document.createElement('div');
      const ta = (res.total_amount != null && isFinite(Number(res.total_amount))) ? Number(res.total_amount).toFixed(3) : '0.000';
      const tu = (res.total_usd != null && isFinite(Number(res.total_usd))) ? Number(res.total_usd).toFixed(3) : '0.000';
      total.innerHTML = `<strong>Total:</strong> ${ta} NIGHT ≈ $${tu}`;
      container.appendChild(total);
      container.appendChild(document.createElement('hr'));
      if(res.thaws && res.thaws.length){
        res.thaws.forEach(t=>{
          const d = document.createElement('div'); d.className='thaw';
          if(t.batch_info){
            // convert newlines to <br>
            const info = t.batch_info.replace(/\n/g, '<br>');
            d.innerHTML = `<div>${info}</div>`;
          } else {
            d.innerHTML = `<div><strong>Amount:</strong> ${t.amount} NIGHT</div>` +
                          `<div><strong>Thaw date:</strong> ${t.thaw_date || 'Unknown'}</div>` +
                          `<div><strong>Days until:</strong> ${t.days_until != null ? t.days_until : 'N/A'}</div>`;
          }
          container.appendChild(d);
        })
      } else {
        container.textContent = 'No thaw batches found.'
      }
    }

    async function saveAddress(){
      const addr = document.getElementById('address').value.trim();
      if(!addr){ alert('Enter address'); return }
      const res = await window.pywebview.api.save_address(addr);
      if(res.error) setStatus('Save error: '+res.error); else setStatus('Saved to '+res.path)
    }

    async function viewAll(){
      setStatus('Loading saved addresses...');
      const res = await window.pywebview.api.view_all();
      if(res.error){ setStatus('Error: '+res.error); alert(res.error); return }
      const list = res.addresses || [];
      if(!list.length){ alert('No saved addresses'); setStatus('Ready'); return }

      // build modal overlay for multi-select
      const modal = document.createElement('div'); modal.className = 'modal';
      const content = document.createElement('div'); content.className = 'modal-content card';
      content.style.maxHeight = '70vh'; content.style.overflow = 'auto';

      const titleRow = document.createElement('div'); titleRow.style.display='flex'; titleRow.style.justifyContent='space-between'; titleRow.style.alignItems='center';
      const title = document.createElement('div'); title.innerHTML = '<strong>Select addresses to check</strong>';
      titleRow.appendChild(title);

      content.appendChild(titleRow);
      content.appendChild(document.createElement('hr'));

      const listDiv = document.createElement('div'); listDiv.className = 'modal-list';
      list.forEach(addr => {
        const item = document.createElement('div');
        item.style.display='flex'; item.style.alignItems='center'; item.style.gap='8px'; item.style.padding='6px';
        const chk = document.createElement('input'); chk.type='checkbox'; chk.value = addr;
        const span = document.createElement('span'); span.textContent = addr; span.style.fontFamily='Consolas,monospace'; span.style.wordBreak='break-all';
        item.appendChild(chk); item.appendChild(span); listDiv.appendChild(item);
      });

      content.appendChild(listDiv);

      const btnRow = document.createElement('div'); btnRow.style.display='flex'; btnRow.style.justifyContent='flex-end'; btnRow.style.gap='8px'; btnRow.style.marginTop='12px';
      const btnSelectAll = document.createElement('button'); btnSelectAll.className='btn ghost'; btnSelectAll.textContent='✓ Select All';
      const btnDeselectAll = document.createElement('button'); btnDeselectAll.className='btn ghost'; btnDeselectAll.textContent='✗ Deselect All';
      const btnCheckSelected = document.createElement('button'); btnCheckSelected.className='btn primary'; btnCheckSelected.textContent='🔍 Check Selected';
      const btnCancel = document.createElement('button'); btnCancel.className='btn ghost'; btnCancel.textContent='Cancel';
      btnRow.appendChild(btnSelectAll); btnRow.appendChild(btnDeselectAll); btnRow.appendChild(btnCheckSelected); btnRow.appendChild(btnCancel);
      content.appendChild(btnRow);

      modal.appendChild(content); document.body.appendChild(modal);

      btnSelectAll.addEventListener('click', ()=>{ listDiv.querySelectorAll('input[type=checkbox]').forEach(c=>c.checked=true) });
      btnDeselectAll.addEventListener('click', ()=>{ listDiv.querySelectorAll('input[type=checkbox]').forEach(c=>c.checked=false) });
      btnCancel.addEventListener('click', ()=>{ document.body.removeChild(modal); setStatus('Ready'); });

      btnCheckSelected.addEventListener('click', async ()=>{
        const checked = Array.from(listDiv.querySelectorAll('input[type=checkbox]')).filter(c=>c.checked).map(c=>c.value);
        if(!checked.length){ alert('Please select at least one address'); return }
        document.body.removeChild(modal);
        setStatus('Checking selected addresses...');
        resultsEl.innerHTML = '';
        for(const addr of checked){
          console.log('[VIEW ALL] Checking:', addr);
          const header = document.createElement('div'); header.style.marginTop='8px'; header.innerHTML = `<div style="color:#7cc7ff"><strong>[VIEW ALL] Checking:</strong> ${addr}</div>`;
          resultsEl.appendChild(header);
          try{
            const r = await window.pywebview.api.check_address(addr);
            // capture view-all results for AI context
            try{ window.apiOutputs.view_all = window.apiOutputs.view_all || []; window.apiOutputs.view_all.push({address: addr, result: r}); }catch(e){}
            const addrContainer = document.createElement('div');
            addrContainer.style.marginTop = '8px';
            addrContainer.style.padding = '8px';
            addrContainer.style.border = '1px solid rgba(255,255,255,0.03)';
            addrContainer.style.borderRadius = '8px';
            const subHeader = document.createElement('div');
            subHeader.innerHTML = `<div style="color:#7cc7ff"><strong>[VIEW ALL] Result for:</strong> ${addr}</div>`;
            addrContainer.appendChild(subHeader);
            renderResults(r, addrContainer);
            resultsEl.appendChild(addrContainer);
            console.log('[VIEW ALL] Result for', addr, r);
          }catch(e){
            const err = document.createElement('div'); err.style.color='#ff8a80'; err.textContent = '[VIEW ALL] Error checking ' + addr + ': ' + e; resultsEl.appendChild(err); console.error('[VIEW ALL] Error', addr, e);
          }
        }
        setStatus('Done');
      });
    }

    // AI Chat functions
    async function callAI() {
        const input = document.getElementById('ai-input');
        const container = document.getElementById('chat-content');
        const text = input.value.trim();
        if (!text) return;

        // 1. Hiển thị tin nhắn user
        container.innerHTML += `<div class="msg user">${text}</div>`;
        input.value = '';
        container.scrollTop = container.scrollHeight;

        // 2. Hiển thị trạng thái chờ
        const loadingId = "ld-" + Date.now();
        container.innerHTML += `<div id="${loadingId}" class="msg bot"><em>Cụ chờ 1 lúc em đang suy nghĩ...</em></div>`;

          try {
            // Gửi qua Python API, include recent API outputs for context and optional user API key
            const nodes = { outputs: window.apiOutputs || {} };
            if(window.userApiKey) nodes.apiKey = window.userApiKey;
            // include selected endpoint if available
            nodes.endpoint = window.userApiEndpoint || (document.getElementById('modelSelect') && document.getElementById('modelSelect').value) || null;
            // also include model identifier if set
            if(window.userModel) nodes.model = window.userModel;
            const response = await window.pywebview.api.chat_message(text, nodes);
            
            document.getElementById(loadingId).remove();
            if (response.reply) {
                container.innerHTML += `<div class="msg bot"><strong>AI</strong>\n${response.reply}</div>`;
            } else {
                throw new Error(response.error);
            }
        } catch (err) {
            document.getElementById(loadingId).innerHTML = `<span style="color:red">Lỗi: ${err.message}</span>`;
        }
        container.scrollTop = container.scrollHeight;
    }

    function toggleChat() {
        const sidebar = document.getElementById('chat-sidebar');
        sidebar.classList.toggle('collapsed');
        const btn = document.querySelector('.chat-toggle');
        btn.textContent = sidebar.classList.contains('collapsed') ? '+' : '−';
        
        // Adjust chart area margin when chat is toggled
        const chartArea = document.getElementById('chartArea');
        if (chartArea) {
            if (sidebar.classList.contains('collapsed')) {
                chartArea.style.marginRight = '12px';
            } else {
                chartArea.style.marginRight = '370px';
            }
        }
    }

    // AI mode controls handlers
    try{
      const btnUseKey = document.getElementById('btnUseKey');
      const btnFree = document.getElementById('btnFree');
      const modelSelect = document.getElementById('modelSelect');
      const endpointDisplay = document.getElementById('endpointDisplay');
      const apiKeyRow = document.getElementById('apiKeyRow');
      const apiKeyInput = document.getElementById('apiKeyInput');
      const btnSaveApiKey = document.getElementById('btnSaveApiKey');
      const apiKeyStatus = document.getElementById('apiKeyStatus');

      if(btnUseKey){
        btnUseKey.addEventListener('click', ()=>{
          // show API input row; do not reveal chat until key saved
          apiKeyRow.style.display = 'flex';
          // ensure model selector is visible and endpoint shown
          try{ modelSelect.style.display = 'inline-block'; endpointDisplay.style.display = 'inline-block'; }catch(e){}
          apiKeyInput.focus();
        });
      }
      if(btnFree){
        btnFree.addEventListener('click', ()=>{
          // Free mode restricted — show notice and keep chat disabled
          alert('Free mode currently only supported for the VCC community pool. Please contact Admin.');
          // ensure chat remains hidden
          document.getElementById('chatMessages').style.display = 'none';
          document.getElementById('chatInputRow').style.display = 'none';
        });
      }
      // initialize model select / endpoint display
      try{
        if(modelSelect && endpointDisplay){
          // set default endpoint into window state
          window.userApiEndpoint = window.userApiEndpoint || modelSelect.value;
          window.userModel = window.userModel || modelSelect.options[modelSelect.selectedIndex].text.split(' — ')[0];
          endpointDisplay.value = window.userApiEndpoint;
          modelSelect.addEventListener('change', ()=>{
            try{
              const val = modelSelect.value;
              endpointDisplay.value = val;
              window.userApiEndpoint = val;
              window.userModel = modelSelect.options[modelSelect.selectedIndex].text.split(' — ')[0];
            }catch(e){console.warn('modelSelect change error', e)}
          });
        }
      }catch(e){ console.warn('model init failed', e); }
      const enableChatUI = ()=>{
        try{ document.getElementById('chatMessages').style.display = 'block'; }catch(e){}
        try{ document.getElementById('chatInputRow').style.display = 'flex'; }catch(e){}
      };
      if(btnSaveApiKey){
        btnSaveApiKey.addEventListener('click', ()=>{
          const v = (apiKeyInput.value || '').trim();
          if(!v){ alert('Enter API key'); return }
          // store key and ensure endpoint/model selected
          window.userApiKey = v;
          try{ window.userApiEndpoint = (document.getElementById('modelSelect') && document.getElementById('modelSelect').value) || window.userApiEndpoint; }catch(e){}
          try{ window.userModel = (document.getElementById('modelSelect') && document.getElementById('modelSelect').options[document.getElementById('modelSelect').selectedIndex].text.split(' — ')[0]) || window.userModel; }catch(e){}
          apiKeyRow.style.display = 'none';
          apiKeyStatus.style.display = 'block';
          enableChatUI();
          try{ document.getElementById('ai-input').focus(); }catch(e){}
        });
        // also allow Enter key in the apiKeyInput to save and enable chat
        apiKeyInput.addEventListener('keypress', (ev)=>{
          if(ev.key === 'Enter'){
            ev.preventDefault();
            btnSaveApiKey.click();
          }
        });
      }
    }catch(e){ console.warn('AI controls init failed', e); }

    // When opening the sidebar, if a key is already present, show chat UI
    try{
      const sidebarToggle = document.querySelector('.chat-toggle');
      // if userApiKey already exists (persisted elsewhere), enable chat immediately
      if(window.userApiKey){
        document.getElementById('apiKeyStatus').style.display = 'block';
        try{ document.getElementById('apiKeyRow').style.display = 'none'; }catch(e){}
        try{ document.getElementById('chatMessages').style.display = 'block'; document.getElementById('chatInputRow').style.display = 'flex'; }catch(e){}
        try{ const ed = document.getElementById('endpointDisplay'); if(ed && window.userApiEndpoint) ed.value = window.userApiEndpoint; }catch(e){}
      }
    }catch(e){}

    document.getElementById('btnCheck').addEventListener('click', checkAddress);
    document.getElementById('btnClear').addEventListener('click', ()=>{ document.getElementById('address').value=''; resultsEl.innerHTML='No results yet'; setStatus('Ready') });
    document.getElementById('btnSave').addEventListener('click', saveAddress);
    document.getElementById('btnViewAll').addEventListener('click', viewAll);
    document.getElementById('btnChart').addEventListener('click', openChart);

    // Chart modal + canvas
    function openChart(){
      setStatus('Opening chart...');
      const chartArea = document.getElementById('chartArea');
      if(!chartArea) { setStatus('No chart area found'); return }
      // clear and show
      chartArea.innerHTML = '';
      chartArea.style.display = 'block';
      
      // Adjust margin based on chat sidebar state
      const sidebar = document.getElementById('chat-sidebar');
      if (sidebar && !sidebar.classList.contains('collapsed')) {
          chartArea.style.marginRight = '370px';
      } else {
          chartArea.style.marginRight = '12px';
      }

      // build inner content (reuse modal-content styling)
      const content = document.createElement('div'); content.className='modal-content';

      // header controls
      const controls = document.createElement('div'); controls.className='chart-controls';
      const instrSel = document.createElement('select'); instrSel.style.padding='6px'; instrSel.style.borderRadius='6px';
      ['NIGHT-USDT','ADA-USDT','BTC-USDT','ETH-USDT','ADA/NIGHT','NIGHT/ADA'].forEach(i=>{ const o=document.createElement('option'); o.value=i; o.textContent=i; instrSel.appendChild(o)});
      const providerSel = document.createElement('select'); providerSel.style.padding='6px'; providerSel.style.borderRadius='6px'; ['okx','bybit','gate'].forEach(p=>{ const o=document.createElement('option'); o.value=p; o.textContent = p.toUpperCase(); providerSel.appendChild(o)});
      // initialize provider selection from top controls if present, otherwise default to 'okx'
      const topProviderEl = document.getElementById('provider');
      providerSel.value = (topProviderEl && topProviderEl.value) ? topProviderEl.value : 'okx';
      controls.appendChild(providerSel);

      // instrument selection: default to NIGHT-USDT when top control missing
      const topInstrEl = document.getElementById('instrument');
      instrSel.value = (topInstrEl && topInstrEl.value) ? topInstrEl.value : 'NIGHT-USDT';

      const tfSel = document.createElement('select'); tfSel.style.padding='6px'; tfSel.style.borderRadius='6px'; ['1m','5m','15m','1H','4H','1D'].forEach(t=>{const o=document.createElement('option');o.value=t;o.textContent=t; if(t==='1H') o.selected=true; tfSel.appendChild(o)});
      const topTfEl = document.getElementById('timeframe');
      tfSel.value = (topTfEl && topTfEl.value) ? topTfEl.value : '1H';
      const overlayChk = document.createElement('input'); overlayChk.type='checkbox'; overlayChk.id='chartOverlay'; const overlayLabel = document.createElement('label'); overlayLabel.style.display='flex'; overlayLabel.style.alignItems='center'; overlayLabel.style.gap='6px'; overlayLabel.appendChild(overlayChk); overlayLabel.appendChild(document.createTextNode('Overlay other'));
      const refreshBtn = document.createElement('button'); refreshBtn.className='btn ghost'; refreshBtn.textContent='Refresh';
      const closeBtn = document.createElement('button'); closeBtn.className='btn ghost'; closeBtn.textContent='Close';
      controls.appendChild(instrSel); controls.appendChild(tfSel); controls.appendChild(overlayLabel); controls.appendChild(refreshBtn); controls.appendChild(closeBtn);

      // status
      const chartStatus = document.createElement('div'); chartStatus.style.color='var(--muted)'; chartStatus.textContent='Ready';

      // canvas
      const canvas = document.createElement('canvas'); canvas.width = Math.min(1100, window.innerWidth-160); canvas.height = 480; canvas.style.width='100%'; canvas.style.height='480px'; canvas.style.background='#071018'; canvas.style.borderRadius='8px';

      content.appendChild(controls); content.appendChild(chartStatus); content.appendChild(canvas);
      chartArea.appendChild(content);

      // chart state for interactivity
      const chartState = {
        data: [], instrument: instrSel.value, timeframe: tfSel.value, overlay: overlayChk.checked,
        windowStart: 0, windowSize: 80, live: true, pollId: null
      };

      async function loadData(){
        try{
          // support synthetic pair like ADA/NIGHT -> compute ADA price divided by NIGHT price
          if(instrSel.value && instrSel.value.includes('/')){
            const parts = instrSel.value.split('/');
            const left = parts[0]; const right = parts[1];
            const leftInst = left.includes('-') ? left : (left + '-USDT');
            const rightInst = right.includes('-') ? right : (right + '-USDT');
                  // fetch series using selected provider
                  async function fetchSeries(inst){
                    const prov = providerSel.value || (document.getElementById('provider') && document.getElementById('provider').value) || 'okx';
                    if(prov === 'bybit') return await window.pywebview.api.fetch_ohlc_bybit(inst, tfSel.value, 500);
                    if(prov === 'gate') return await window.pywebview.api.fetch_ohlc_gate(inst, tfSel.value, 500);
                    return await window.pywebview.api.fetch_ohlc(inst, tfSel.value, 500);
                  }
                  const leftData = await fetchSeries(leftInst);
                  const rightData = await fetchSeries(rightInst);
                    // store fetched OHLC series for AI context
                    try{ window.apiOutputs['ohlc_'+leftInst] = leftData; window.apiOutputs['ohlc_'+rightInst] = rightData }catch(e){}
            if(!leftData || leftData.error) throw new Error('Left series error: '+(leftData && leftData.error));
            if(!rightData || rightData.error) throw new Error('Right series error: '+(rightData && rightData.error));
            // align by most recent candles (use min length)
            const minLen = Math.min(leftData.length, rightData.length);
            const out = [];
            for(let i=0;i<minLen;i++){
              const a = leftData[leftData.length - minLen + i];
              const b = rightData[rightData.length - minLen + i];
              // compute ratio = left / right
              const open = (a.open && b.open) ? (a.open / b.open) : 0;
              const high = (a.high && b.low) ? (a.high / b.low) : 0;
              const low = (a.low && b.high) ? (a.low / b.high) : 0;
              const close = (a.close && b.close) ? (a.close / b.close) : 0;
              const ts = a.ts || b.ts;
              out.push({ts: ts, open: open, high: high, low: low, close: close, volume: 0});
            }
            chartState.data = out;
          } else {
            // single instrument fetch using selected provider
            async function fetchSeriesSingle(inst){
              const prov = providerSel.value || (document.getElementById('provider') && document.getElementById('provider').value) || 'okx';
              if(prov === 'bybit') return await window.pywebview.api.fetch_ohlc_bybit(inst, tfSel.value, 500);
              if(prov === 'gate') return await window.pywebview.api.fetch_ohlc_gate(inst, tfSel.value, 500);
              return await window.pywebview.api.fetch_ohlc(inst, tfSel.value, 500);
            }
            const data = await fetchSeriesSingle(instrSel.value);
            try{ window.apiOutputs['ohlc_'+instrSel.value] = data }catch(e){}
            if(!data || data.error) throw new Error(data && data.error ? data.error : 'no data');
            chartState.data = data;
          }
          // default window: most recent N candles
          chartState.windowSize = Math.min(120, chartState.data.length || 120);
          chartState.windowStart = Math.max(0, chartState.data.length - chartState.windowSize);
          return chartState.data;
        }catch(e){ throw e }
      }

      async function draw(){
        try{
          const data = chartState.data || [];
          // slice window
          const start = Math.max(0, Math.min(chartState.windowStart, Math.max(0, data.length - 1)));
          const end = Math.min(data.length, start + chartState.windowSize);
          const slice = data.slice(start, end);
          await renderChart(slice, canvas, instrSel.value, overlayChk.checked, tfSel.value);
          // expose last slice for tooltip/pointer handlers
          canvas._lastSlice = slice;
        }catch(e){ console.error('Draw error', e); }
      }

      async function refreshOnce(){
        chartStatus.textContent = 'Loading ' + instrSel.value + ' ' + tfSel.value + '...';
        try{
          await loadData();
          chartStatus.textContent = 'Rendering...';
          await draw();
          chartStatus.textContent = 'Last update: ' + new Date().toLocaleString();
        }catch(e){ chartStatus.textContent = 'Chart error: '+(e && e.message ? e.message : e); }
      }

      // live poll every 30s when live mode on
      function startPolling(){
        if(chartState.pollId) clearInterval(chartState.pollId);
        chartState.pollId = setInterval(async ()=>{
          try{
            // Use loadData() so synthetic pairs (X/Y) are handled correctly
            try{ await loadData(); }catch(err){ console.error('Poll loadData error', err); return; }
            if(chartState.data && !chartState.data.error){
              // if live, keep view at most recent
              if(chartState.live) chartState.windowStart = Math.max(0, chartState.data.length - chartState.windowSize);
              await draw();
            } else {
              console.warn('Poll: no data or error', chartState.data && chartState.data.error);
            }
          }catch(e){ console.error('Poll error', e) }
        }, 30000);
      }

      refreshBtn.addEventListener('click', async ()=>{ chartState.live = true; await refreshOnce(); });
      closeBtn.addEventListener('click', ()=>{ if(chartState.pollId) clearInterval(chartState.pollId); chartArea.style.display='none'; chartArea.innerHTML=''; setStatus('Ready'); });
      instrSel.addEventListener('change', async ()=>{ chartState.instrument = instrSel.value; await refreshOnce(); });
      providerSel.addEventListener('change', async ()=>{ chartState.instrument = instrSel.value; await refreshOnce(); });
      tfSel.addEventListener('change', async ()=>{ chartState.timeframe = tfSel.value; await refreshOnce(); });

      // interactive zoom/pan handlers
      let isPanning = false, panStartX = 0, panStartWindow = 0;
      canvas.addEventListener('mousedown', (ev)=>{ isPanning=true; panStartX = ev.clientX; panStartWindow = chartState.windowStart; chartState.live = false; });
      window.addEventListener('mouseup', ()=>{ isPanning=false });
      canvas.addEventListener('mousemove', (ev)=>{
        if(!isPanning) return;
        const dx = ev.clientX - panStartX;
        const cssW = canvas.clientWidth; const pad = 50; const w = cssW - pad*2;
        const deltaIndex = Math.round((dx / w) * chartState.windowSize);
        chartState.windowStart = Math.max(0, Math.min(Math.max(0, chartState.data.length - 1), panStartWindow - deltaIndex));
        draw();
      });

      // wheel zoom centered at mouse
      canvas.addEventListener('wheel', (ev)=>{
        ev.preventDefault();
        const delta = ev.deltaY > 0 ? 1.15 : 0.85; // zoom out/in
        const rect = canvas.getBoundingClientRect();
        const mouseX = ev.clientX - rect.left;
        const cssW = canvas.clientWidth; const pad = 50; const w = cssW - pad*2;
        const rel = Math.max(0, Math.min(1, (mouseX - pad) / w));
        const anchor = Math.floor(chartState.windowStart + rel * chartState.windowSize);
        const newSize = Math.max(6, Math.min(chartState.data.length, Math.round(chartState.windowSize * delta)));
        const newStart = Math.round(anchor - rel * newSize);
        chartState.windowSize = newSize;
        chartState.windowStart = Math.max(0, Math.min(Math.max(0, chartState.data.length - newSize), newStart));
        chartState.live = false;
        draw();
      }, {passive:false});

      canvas.addEventListener('dblclick', async ()=>{ chartState.live = true; await refreshOnce(); });

      // tooltip element
      const tooltip = document.createElement('div');
      tooltip.style.position='absolute'; tooltip.style.pointerEvents='none'; tooltip.style.background='rgba(2,10,20,0.95)'; tooltip.style.color='#cfeaff'; tooltip.style.padding='8px'; tooltip.style.borderRadius='6px'; tooltip.style.fontSize='12px'; tooltip.style.display='none'; tooltip.style.zIndex=10000;
      content.style.position = 'relative'; content.appendChild(tooltip);

      // pointer tooltip handlers
      canvas.addEventListener('mousemove', (ev)=>{
        const slice = canvas._lastSlice;
        if(!slice || !slice.length) { tooltip.style.display='none'; return }
        const rect = canvas.getBoundingClientRect();
        const mouseX = ev.clientX - rect.left;
        const cssW = canvas.clientWidth; const pad = 60; const w = cssW - pad*2;
        const rel = Math.max(0, Math.min(1, (mouseX - pad) / w));
        const idx = Math.max(0, Math.min(slice.length-1, Math.round(rel * (slice.length-1))));
        const d = slice[idx];
        if(!d) { tooltip.style.display='none'; return }
        // format time based on timeframe
        const ts = (d.ts && d.ts > 1e12) ? d.ts : (d.ts ? d.ts*1000 : Date.now());
        const dt = new Date(ts);
        const tf = (tfSel && tfSel.value) || document.getElementById('timeframe').value || '1H';
        let timeStr = '';
        if(tf.toLowerCase().includes('m')){
          timeStr = dt.toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'});
        } else if(tf.toUpperCase().includes('H')){
          timeStr = dt.toLocaleString([], {month:'2-digit', day:'2-digit', hour:'2-digit'});
        } else {
          timeStr = dt.toLocaleDateString();
        }
        tooltip.innerHTML = `<div style="font-weight:700">${timeStr}</div>` +
          `<div>O: ${Number(d.open).toFixed(3)} H: ${Number(d.high).toFixed(3)} L: ${Number(d.low).toFixed(3)} C: ${Number(d.close).toFixed(3)}</div>`;
        tooltip.style.left = Math.min(rect.width - 160, mouseX + 12) + 'px';
        tooltip.style.top = Math.max(8, ev.clientY - rect.top + 12) + 'px';
        tooltip.style.display = 'block';
      });
      canvas.addEventListener('mouseleave', ()=>{ tooltip.style.display='none'; });

      // initial load and start polling
      (async ()=>{ await refreshOnce(); startPolling(); })();
      setStatus('Chart opened');
    }

    async function renderChart(data, canvas, instrument, overlay, timeframe){
      // draw candlestick chart into given canvas
      const ctx = canvas.getContext('2d');
      if(!data || !data.length){ ctx.clearRect(0,0,canvas.width,canvas.height); ctx.fillStyle='#98a0a6'; ctx.fillText('No chart data', 20,20); return }

      const closes = data.map(d=>d.close);
      const highs = data.map(d=>d.high);
      const lows = data.map(d=>d.low);
      const opens = data.map(d=>d.open);

      // compute size based on CSS width (canvas scaled)
      const DPR = window.devicePixelRatio || 1;
      const cssW = canvas.clientWidth;
      const cssH = canvas.clientHeight;
      canvas.width = Math.floor(cssW * DPR);
      canvas.height = Math.floor(cssH * DPR);
      ctx.scale(DPR, DPR);

      const max = Math.max(...highs), min = Math.min(...lows);
      const pad = 60;
      const w = cssW - pad*2, h = cssH - pad*2;
      ctx.clearRect(0,0,cssW,cssH);

      // background grid
      ctx.fillStyle = '#071018'; ctx.fillRect(0,0,cssW,cssH);
      ctx.strokeStyle = 'rgba(255,255,255,0.03)'; ctx.lineWidth=1;
      for(let i=0;i<5;i++){ const y=pad + (i/4)*h; ctx.beginPath(); ctx.moveTo(pad,y); ctx.lineTo(pad+w,y); ctx.stroke(); }

      // axes labels (Y axis)
      ctx.fillStyle='#98a0a6'; ctx.font='12px Inter, Arial'; ctx.textAlign='left';
      const yTicks = 5;
      for(let yi=0; yi<yTicks; yi++){
        const v = max - (yi/(yTicks-1))*(max-min);
        const y = pad + (yi/(yTicks-1))*h;
        ctx.fillText(v.toFixed(3), 8, y+4);
      }

      // draw candlesticks
      const n = data.length;
      const candleW = Math.max(2, Math.floor(w / n * 0.7));
      for(let i=0;i<n;i++){
        const x = pad + (i/(n-1))*w;
        const o = opens[i], hVal = highs[i], lVal = lows[i], c = closes[i];
        const yO = pad + ((max - o)/(max-min || 1))*h;
        const yH = pad + ((max - hVal)/(max-min || 1))*h;
        const yL = pad + ((max - lVal)/(max-min || 1))*h;
        const yC = pad + ((max - c)/(max-min || 1))*h;
        // wick
        ctx.strokeStyle = 'rgba(200,200,200,0.25)'; ctx.lineWidth=1; ctx.beginPath(); ctx.moveTo(x, yH); ctx.lineTo(x, yL); ctx.stroke();
        // body
        const top = Math.min(yO,yC), bottom = Math.max(yO,yC);
        ctx.fillStyle = c >= o ? '#28a745' : '#dc3545';
        ctx.fillRect(x - candleW/2, top, candleW, Math.max(1, bottom-top));
      }

      // X axis labels (dates) based on timeframe
      const ts = data.map(d=>d.ts || 0);
      const ticks = Math.min(6, Math.max(2, Math.floor(n/5)) );
      const tickCount = 6;
      ctx.textAlign='center'; ctx.fillStyle='#98a0a6'; ctx.font='12px Inter, Arial';
      for(let ti=0; ti<tickCount; ti++){
        const idx = Math.floor(ti*(n-1)/(tickCount-1));
        const t = ts[idx] || 0;
        const tms = (t>1e12) ? t : (t? t*1000 : Date.now());
        const dt = new Date(tms);
        let label = '';
        const tf = (timeframe || document.getElementById('timeframe').value || '1H');
        if(tf.toLowerCase().includes('m')){
          label = dt.toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'});
        } else if(tf.toUpperCase().includes('H')){
          label = dt.toLocaleString([], {month:'2-digit', day:'2-digit', hour:'2-digit'});
        } else {
          label = dt.toLocaleDateString();
        }
        const x = pad + (idx/(n-1))*w;
        ctx.fillText(label, x, pad + h + 18);
      }

      // overlay other instrument if requested
      if(overlay){
        const other = instrument === 'NIGHT-USDT' ? 'ADA-USDT' : 'NIGHT-USDT';
        try{
            // determine provider (prefer local providerSel if present, otherwise top control)
            const topProvider = (document.getElementById('provider') && document.getElementById('provider').value) ? document.getElementById('provider').value : null;
            const prov = (typeof providerSel !== 'undefined' && providerSel && providerSel.value) ? providerSel.value : (topProvider || 'okx');
            const tfVal = (timeframe || (document.getElementById('timeframe') && document.getElementById('timeframe').value) || '1H');
            // fetch overlay using selected provider
            let otherData = null;
            if(prov === 'bybit'){
              otherData = await window.pywebview.api.fetch_ohlc_bybit(other, tfVal, data.length);
            } else if(prov === 'gate'){
              otherData = await window.pywebview.api.fetch_ohlc_gate(other, tfVal, data.length);
            } else {
              otherData = await window.pywebview.api.fetch_ohlc(other, tfVal, data.length);
            }
            if(otherData && !otherData.error){
            try{ window.apiOutputs['overlay_'+other] = otherData }catch(e){}
            const otherCloses = otherData.map(d=>d.close);
            const oMax = Math.max(...otherCloses), oMin = Math.min(...otherCloses);
            ctx.beginPath(); ctx.strokeStyle='#7cc7ff'; ctx.lineWidth=1.5;
            for(let i=0;i<otherCloses.length;i++){
              const v = otherCloses[i];
              const x = pad + (i/(otherCloses.length-1))*w;
              const y = pad + ((oMax - v)/(oMax - oMin || 1))*h;
              if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
            }
            ctx.stroke();
          }
        }catch(e){ console.error('Overlay error', e) }
      }
    }

  </script>
</body>
</html>
'''


def start():
    if webview is None:
        print('pywebview is required. Install with: pip install pywebview')
        return

    api = Api()
    webview.create_window('NIGHT Schedule', html=HTML, js_api=api, width=1000, height=760)
    webview.start()


if __name__ == '__main__':
    start()
