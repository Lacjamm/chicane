#!/usr/bin/env python3
"""Additional layered-audio assets for Chicane 3D v3."""
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "chicane3d", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
def save(name, sig):
    sig = np.clip(sig, -1, 1)
    pcm = (sig * 32767).astype(np.int16)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(name, round(len(sig)/SR,2), "s")
def t(d): return np.arange(int(SR*d))/SR
def saw(f,tt): return 2*((f*tt)%1)-1
def sq(f,tt): return np.sign(np.sin(2*np.pi*f*tt))
def sin_(f,tt): return np.sin(2*np.pi*f*tt)
def noise(n): return np.random.uniform(-1,1,n)
def lowpass(x,a):
    y=np.empty_like(x); acc=0.0
    for i,v in enumerate(x): acc+=a*(v-acc); y[i]=acc
    return y
def loopfade(x, ms=25):
    f=int(ms/1000*SR); x[:f]=x[:f]*np.linspace(0,1,f)+x[-f:]*np.linspace(1,0,f); return x

# Layered engine: idle (low rumble), mid (existing engine_loop), high (screamer), redline (harsh)
tt=t(1.0)
idle = lowpass(0.6*saw(38,tt)+0.35*sq(19,tt)+0.2*noise(len(tt)),0.06)
save("engine_idle", loopfade(idle)*0.5)
high = lowpass(0.55*saw(120,tt)+0.3*saw(121.5,tt)+0.25*sq(60,tt)+0.12*noise(len(tt)),0.28)
save("engine_high", loopfade(high)*0.5)
red = lowpass(0.5*saw(175,tt)+0.3*sq(87,tt)+0.3*(noise(len(tt))*sq(44,tt)),0.4)
save("engine_red", loopfade(red)*0.5)
# gear shift: clunk + brief hiss
n=int(SR*0.16)
shift = sin_(90,t(0.16))*np.exp(-np.linspace(0,14,n))*0.7 + lowpass(noise(n),0.5)*np.exp(-np.linspace(0,10,n))*0.4
save("shift", shift)
# turbo whine loop + blowoff
tt=t(0.8)
turbo = sin_(900,tt)*0.25 + sin_(1805,tt)*0.12 + lowpass(noise(len(tt)),0.7)*0.08
save("turbo_loop", loopfade(turbo)*0.5)
n=int(SR*0.5)
blow = (noise(n)-lowpass(noise(n),0.2))*np.exp(-np.linspace(0,7,n))*0.6
sweep = np.cumsum(np.linspace(1400,300,n))/SR
blow += np.sin(2*np.pi*sweep)*np.exp(-np.linspace(0,9,n))*0.2
save("blowoff", blow)
# wind loop
tt=t(1.5)
wind = lowpass(noise(len(tt)),0.15)*0.8
wind *= 0.7+0.3*np.sin(2*np.pi*0.7*tt)
save("wind_loop", loopfade(wind)*0.55)
# tyre squeal loop (slip-responsive via pitch/vol in engine)
tt=t(0.7)
sq_l = sin_(880,tt)*0.3+sin_(1320,tt)*0.18+sin_(660,tt)*0.2
sq_l *= 0.75+0.25*np.sin(2*np.pi*13*tt)
sq_l += (noise(len(tt))-lowpass(noise(len(tt)),0.4))*0.12
save("squeal_loop", loopfade(sq_l)*0.5)
print("done")
