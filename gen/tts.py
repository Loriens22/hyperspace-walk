"""Generate Aether's voice lines with edge-tts (neural TTS). EN: en-US-JennyNeural, BG: bg-BG-KalinaNeural.
Output: game/voice/<lang>/<line_id>.mp3"""
import asyncio, json, os, sys
import edge_tts
C = json.load(open('game/data/content.json', encoding='utf-8'))
VOICES = {'en': ('en-US-JennyNeural', '-4%', '+0Hz'), 'bg': ('bg-BG-KalinaNeural', '-2%', '+0Hz')}
sem = asyncio.Semaphore(6)
async def one(lang, ln):
    out = f'game/voice/{lang}/{ln["id"]}.mp3'
    if os.path.exists(out) and os.path.getsize(out) > 2000 and '--force' not in sys.argv: return
    text = ln.get(lang + '_tts') or ln[lang]
    v, rate, pitch = VOICES[lang]
    async with sem:
        for attempt in range(4):
            try:
                await edge_tts.Communicate(text, v, rate=rate, pitch=pitch).save(out)
                print('ok', out, flush=True); return
            except Exception as e:
                print('retry', out, e, flush=True); await asyncio.sleep(2 + attempt * 3)
        print('FAIL', out)
async def main():
    tasks = [one(lang, ln) for l in C['lessons'] for ln in l['lines'] for lang in ('en', 'bg')]
    await asyncio.gather(*tasks)
asyncio.run(main())
