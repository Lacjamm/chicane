#!/usr/bin/env python3
"""Generate all WAV audio assets for Chicane 3D procedurally."""
import numpy as np, wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "chicane3d", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)

def save(name, sig, stereo=False):
    sig = np.clip(sig, -1, 1)
    pcm = (sig * 32767).astype(np.int16)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        if stereo:
            w.writeframes(np.column_stack([pcm, pcm]).tobytes())
        else:
            w.writeframes(pcm.tobytes())
    print(name, len(sig)/SR, "s")

def t(dur): return np.arange(int(SR*dur)) / SR

def env_ad(n, a, d):
    e = np.ones(n)
    ai = int(a*SR); di = int(d*SR)
    if ai: e[:ai] = np.linspace(0, 1, ai)
    if di: e[-di:] = np.linspace(1, 0, di)
    return e

def saw(f, tt): return 2*((f*tt) % 1) - 1
def sq(f, tt): return np.sign(np.sin(2*np.pi*f*tt))
def sin_(f, tt): return np.sin(2*np.pi*f*tt)
def noise(n): return np.random.uniform(-1, 1, n)

def lowpass(x, alpha):
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc); y[i] = acc
    return y

# ---------- engine loop (1s, pitch-shifted in game) ----------
tt = t(1.0)
base = 55.0
eng = 0.5*saw(base, tt) + 0.3*saw(base*1.01, tt) + 0.25*sq(base/2, tt) + 0.10*noise(len(tt))
eng = lowpass(eng, 0.12)
# make seamless loop
f = int(0.02*SR)
eng[:f] = eng[:f]*np.linspace(0,1,f) + eng[-f:]*np.linspace(1,0,f)
save("engine_loop", eng*0.55)

# ---------- siren loop (2s wail) ----------
tt = t(2.0)
fmod = 700 + 280*np.sin(2*np.pi*0.5*tt)
phase = np.cumsum(fmod)/SR
siren = np.sin(2*np.pi*phase)*0.5 + np.sin(2*np.pi*phase*2)*0.12
save("siren_loop", siren*0.5)

# ---------- skid loop ----------
tt = t(0.8)
sk = lowpass(noise(len(tt)), 0.6) - lowpass(noise(len(tt)), 0.1)
sk *= 0.5 + 0.3*np.sin(2*np.pi*23*tt)
f = int(0.02*SR); sk[:f] *= np.linspace(0,1,f); sk[-f:] *= np.linspace(1,0,f)
save("skid_loop", sk*0.45)

# ---------- crashes ----------
def crash(dur, big):
    n = int(SR*dur)
    body = lowpass(noise(n), 0.25) * env_ad(n, 0.002, dur*0.8)
    thump = sin_(52, t(dur)) * env_ad(n, 0.001, dur*0.5) * (1.2 if big else 0.8)
    metal = sum(sin_(fq, t(dur)) * env_ad(n, 0.001, dur*0.3) * 0.12
                for fq in ([320, 452, 613, 855] if big else [430, 611]))
    return (body*0.8 + thump + metal) * (1.0 if big else 0.75)
save("crash_big", crash(0.9, True))
save("crash_small", crash(0.35, False))

# glass tinkle
n = int(SR*0.7); g = np.zeros(n)
rng = np.random.default_rng(7)
for i in range(24):
    st = int(rng.uniform(0, 0.45)*SR); fq = rng.uniform(1800, 5200); dur = rng.uniform(0.04, 0.12)
    m = int(dur*SR); seg = sin_(fq, t(dur))*env_ad(m, 0.001, dur*0.8)*rng.uniform(0.05, 0.16)
    g[st:st+m] += seg[:max(0, min(m, n-st))]
save("glass", g)

# nitro whoosh
n = int(SR*1.2)
wh = lowpass(noise(n), 0.4)*env_ad(n, 0.15, 0.7)
sweep = np.cumsum(np.linspace(120, 900, n))/SR
wh += np.sin(2*np.pi*sweep)*env_ad(n, 0.1, 0.8)*0.25
save("nitro", wh*0.5)

# EMP zap
n = int(SR*0.6)
sweep = np.cumsum(np.linspace(1600, 90, n))/SR
z = sq(1, t(0.6))*0  # placeholder
z = np.sign(np.sin(2*np.pi*sweep))*env_ad(n, 0.002, 0.4)*0.4 + noise(n)*env_ad(n, 0.001, 0.15)*0.3
save("emp", z)

# UI blips
save("ui_click", sq(880, t(0.06))*env_ad(int(SR*0.06), 0.002, 0.04)*0.3)
save("ui_win", np.concatenate([sin_(f, t(0.14))*env_ad(int(SR*0.14), 0.005, 0.1)*0.4 for f in (660, 880, 1100, 1320)]))
save("ui_lose", np.concatenate([saw(f, t(0.2))*env_ad(int(SR*0.2), 0.005, 0.15)*0.25 for f in (330, 262, 196)]))
save("checkpoint", np.concatenate([sin_(f, t(0.09))*env_ad(int(SR*0.09), 0.003, 0.06)*0.35 for f in (880, 1320)]))

# ---------- music loops ----------
NOTE = lambda m: 440*2**((m-69)/12)

def render_song(bpm, bars, bass_seq, arp_seq, kick_pat, snare_pat, hat_pat, lead_wave="saw", detune=False, pad=None):
    spb = 60/bpm/4  # sixteenth
    n = int(SR*spb*16*bars)
    mix = np.zeros(n)
    for bar in range(bars):
        for step in range(16):
            st = int((bar*16+step)*spb*SR)
            # kick
            if kick_pat[step]:
                m = int(0.18*SR); fq = np.linspace(140, 42, m)
                seg = np.sin(2*np.pi*np.cumsum(fq)/SR)*env_ad(m, 0.001, 0.15)*0.9
                mix[st:st+m] += seg[:max(0, min(m, n-st))]
            # snare
            if snare_pat[step]:
                m = int(0.14*SR)
                seg = (lowpass(noise(m), 0.5)*0.7 + sin_(190, t(0.14))*0.3)*env_ad(m, 0.001, 0.12)*0.5
                mix[st:st+m] += seg[:max(0, min(m, n-st))]
            # hat
            if hat_pat[step % len(hat_pat)]:
                m = int(0.05*SR)
                seg = (noise(m) - lowpass(noise(m), 0.3))*env_ad(m, 0.001, 0.04)*0.25
                mix[st:st+m] += seg[:max(0, min(m, n-st))]
            # bass (each beat)
            if step % 4 == 0:
                fq = NOTE(bass_seq[bar % len(bass_seq)])
                m = int(spb*3.6*SR)
                seg = lowpass(saw(fq, t(spb*3.6)), 0.09)*env_ad(m, 0.005, spb*1.2)*0.5
                mix[st:st+m] += seg[:max(0, min(m, n-st))]
            # arp/lead (eighths)
            if step % 2 == 0 and arp_seq:
                fq = NOTE(arp_seq[(step//2) % len(arp_seq)] + 12*(bar % 2))
                m = int(spb*1.7*SR)
                w = saw(fq, t(spb*1.7)) if lead_wave == "saw" else sq(fq, t(spb*1.7)) if lead_wave == "sq" else sin_(fq, t(spb*1.7))
                if detune: w = 0.5*w + 0.5*(saw(fq*1.01, t(spb*1.7)) if lead_wave == "saw" else sq(fq*1.008, t(spb*1.7)))
                seg = lowpass(w, 0.25)*env_ad(m, 0.004, spb*0.9)*0.16
                mix[st:st+m] += seg[:max(0, min(m, n-st))]
        # pad chords
        if pad:
            chord = pad[bar % len(pad)]
            m = int(spb*16*SR)
            seg = sum(lowpass(saw(NOTE(c), t(spb*16)), 0.04) for c in chord)*env_ad(m, 0.4, 0.6)*0.10
            mix[st0 if (st0:=int(bar*16*spb*SR)) else 0:st0+m] += seg[:max(0, min(m, n-st0))]
    # gentle master lp + loop fade
    mix = lowpass(mix, 0.8)
    f = int(0.03*SR)
    mix[:f] = mix[:f]*np.linspace(0,1,f) + mix[-f:]*np.linspace(1,0,f)
    peak = np.abs(mix).max()
    return mix/peak*0.62 if peak > 0 else mix

K4  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]
SN  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]
SN2 = [0,0,0,0, 1,0,0,0, 0,0,1,0, 1,0,0,1]
save("music_electro", render_song(128, 8, [38,38,41,36], [62,65,69,72], K4, SN, [0,0,1,0], "saw", True))
save("music_synth",   render_song(102, 8, [33,33,36,31], [57,60,64,67], K4, SN, [0,1], "saw", True, pad=[[45,52,57],[45,52,57],[48,55,60],[43,50,55]]))
save("music_rock",    render_song(142, 8, [28,28,31,33], [52,55,59,55], [1,0,0,1,0,0,1,0,1,0,0,1,0,0,1,0], SN2, [1], "sq", True))
save("music_dnb",     render_song(172, 8, [31,31,34,29], [55,58,62,65], [1,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0], [0,0,0,0,1,0,0,0,0,1,0,0,1,0,0,0], [1,0,1,1], "saw"))
save("music_chill",   render_song(86,  8, [36,36,34,31], [], K4, SN, [0,0,1,0], "sin", pad=[[48,55,60,64],[48,55,60,64],[46,53,58,62],[43,50,55,59]]))

print("done")
