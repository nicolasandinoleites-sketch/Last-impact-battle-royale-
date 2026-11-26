"""Deterministic original synthesized sound design, no external recordings."""
from pathlib import Path
import numpy as np, wave
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/deployment'
ROOT.mkdir(parents=True,exist_ok=True)
SR=22050
rng=np.random.default_rng(783)
def time(d):return np.arange(int(d*SR))/SR
def noise(t,lo,hi):
    f=np.fft.rfftfreq(len(t),1/SR); s=np.fft.rfft(rng.normal(size=len(t))); s*=np.exp(-0.5*(f/hi)**2)*(1-np.exp(-0.5*(f/max(lo,1))**2)); y=np.fft.irfft(s,n=len(t));return y/(np.std(y)+1e-8)
def write(name,y):
    y=np.clip(y,-.95,.95)
    with wave.open(str(ROOT/(name+'.wav')),'wb') as w:w.setparams((1,2,SR,len(y),'NONE','not compressed'));w.writeframes((y*32767).astype('<i2').tobytes())
t=time(4);y=(.24*np.sin(2*np.pi*52*t)+.12*np.sin(2*np.pi*104*t)+.08*np.sin(2*np.pi*156*t)+.10*noise(t,30,420))*(.88+.12*np.cos(2*np.pi*2*t));write('turbines',y)
t=time(4);write('airflow',(.13*noise(t,55,260)+.12*noise(t,300,2500))*(.8+.2*np.cos(2*np.pi*.75*t)))
t=time(.86);env=np.sin(np.pi*t/.86)**.8;write('ramp',env*(.20*np.sin(2*np.pi*(86*t+45*t*t))+.09*noise(t,60,1200))+.15*np.exp(-((t-.79)/.035)**2)*noise(t,80,1400))
t=time(.36);write('ready',.27*np.sin(2*np.pi*820*t)*np.sin(np.pi*t/.36)**2)
t=time(.48);write('wings',np.sin(np.pi*t/.48)**1.4*(.15*np.sin(2*np.pi*(140*t+210*t*t))+.19*noise(t,100,1800)))
t=time(.28);write('touchdown',.38*np.exp(-t*19)*np.minimum(1,t*500)*(.45*np.sin(2*np.pi*70*t)+.55*noise(t,45,450)))
