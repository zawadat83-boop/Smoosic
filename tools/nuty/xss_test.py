#!/usr/bin/env python3
"""Regression test (Nuty security review 2026-09-26): text from a MusicXML document must never
execute script in the editor. Serves dist/nuty-smoosic over http://127.0.0.1 and opens a crafted
score with Chromium (Playwright). Exit code 1 on failure."""
import http.server
import socketserver
import sys
import threading
from functools import partial
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2] / 'dist' / 'nuty-smoosic'
PAYLOADS = ['";window.__pwned=1;"', "';window.__pwned=2;'", '\\";window.__pwned=3;//', '<img src=x onerror="window.__pwned=4">',
            '</title><script>window.__pwned=5</script>', '\\u0022;window.__pwned=6;\\u0022']


def score(payload):
    esc = payload.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1"><work><work-title>{esc}</work-title></work>
<identification><creator type="composer">{esc}</creator><rights>{esc}</rights></identification>
<credit page="1"><credit-words>{esc}</credit-words></credit>
<part-list><score-part id="P1"><part-name>{esc}</part-name></score-part></part-list>
<part id="P1"><measure number="1"><attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
<direction placement="above"><direction-type><words>{esc}</words></direction-type></direction>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type><lyric><text>{esc}</text></lyric></note></measure></part></score-partwise>'''


PAGE = '''<!doctype html><html><head><meta charset="utf-8"><link href="/styles/bootstrap.css" rel="stylesheet">
<script src="/jquery.slim.min.js"></script><script src="/jszip.js"></script><script src="/smoosic.js"></script>
<script>Smo.SuiSampleMedia.soundfontBaseUrl = '/soundfonts/FluidR3_GM'; Smo.SuiSampleMedia.percussionUrl = '/soundfonts/percussion-ogg.js';</script></head>
<body><div id="smoo"></div></body></html>'''


def main():
    (ROOT / 'xss-test.html').write_text(PAGE)
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass
    handler = partial(Quiet, directory=str(ROOT))
    with socketserver.TCPServer(('127.0.0.1', 0), handler) as httpd:
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        url = f'http://127.0.0.1:{httpd.server_address[1]}/xss-test.html'
        failures = []
        with sync_playwright() as p:
            browser = p.chromium.launch()
            for payload in PAYLOADS:
                page = browser.new_page()
                dialogs = []
                page.on('dialog', lambda d: (dialogs.append(d.message), d.dismiss()))
                page.goto(url)
                page.evaluate('''async (xml) => { await Smo.SuiApplication.configure({mode: 'application', domContainer: 'smoo', libraryUrl: '', initialScore: xml}); }''', score(payload))
                page.wait_for_timeout(2500)
                pwned = page.evaluate('window.__pwned')
                if pwned or dialogs:
                    failures.append((payload, pwned, dialogs))
                page.close()
            browser.close()
        httpd.shutdown()
    (ROOT / 'xss-test.html').unlink()
    if failures:
        print('XSS REGRESSION:', failures)
        sys.exit(1)
    print(f'XSS regression test passed ({len(PAYLOADS)} payloads).')


if __name__ == '__main__':
    main()
