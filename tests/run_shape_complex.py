"""Synthetic clutter/shape regression. Does not claim real-camera validation."""
from pathlib import Path
import argparse, subprocess, math, random, json

p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True)
p.add_argument('--modelsim',type=Path,default=Path('D:/modelsim/win64'))
p.add_argument('--extended-only',action='store_true')
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
h=root/'user_source/hdl_source';lib=out/'simlib'
if not lib.exists():subprocess.run([str(a.modelsim/'vlib.exe'),str(lib)],check=True,capture_output=True)
def sim(name,top,args=''):
    script=out/(name+'.do');log=out/(name+'.log')
    script.write_text('onerror {quit -code 1 -force}\n'+
        'vlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '+
        ' '.join('{'+q.as_posix()+'}' for q in [h/'red_target_tracker.v',h/'shape_result_filter.v',root/'tests/tb_shape_components.sv',root/'tests/tb_shape_filter.sv',root/'tests/tb_shape_sequence.sv'])+
        '\nvsim -voptargs=+acc -lib {'+lib.as_posix()+'} '+top+' '+args+
        '\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
    r=subprocess.run([str(a.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=out,capture_output=True,text=True)
    txt=log.read_text(errors='replace')
    print(name+': '+'\n'.join(l for l in txt.splitlines() if any(k in l for k in ['PASS ','** Error','** Fatal'])),flush=True)
    if r.returncode or 'PASS ' not in txt or '** Error' in txt or '** Fatal' in txt:raise RuntimeError(str(log))

cases=[]
def scene(name,kind,cx=60,cy=34,rx=20,ry=20,col=0x202020,noise=True,angle=0,outline=False):
    pix=[];rng=random.Random(19)
    for y in range(68):
        for x in range(120):
            # Gray texture stays outside the foreground thresholds.
            g=120+(x*7+y*13)%32
            c=g*0x010101
            if noise and ((x<20 or x>100) and (x*17+y*11)%53==0):c=0x202020
            if noise and 4<x<17 and 6<y<16:c=0x20c030
            if noise and x>104 and y>45:c=0xffffff # border-touching distractor
            xx=(x-cx)*math.cos(angle)+(y-cy)*math.sin(angle)
            yy=-(x-cx)*math.sin(angle)+(y-cy)*math.cos(angle)
            inside=False;inner=False
            if kind=='rect':inside=abs(xx)<=rx and abs(yy)<=ry;inner=abs(xx)<rx-2 and abs(yy)<ry-2
            if kind=='circle':inside=xx*xx/(rx*rx)+yy*yy/(ry*ry)<=1;inner=xx*xx/((rx-2)**2)+yy*yy/((ry-2)**2)<1
            if kind=='tri':inside=-ry<=yy<=ry and abs(xx)<=rx*(yy+ry)/(2*ry);inner=-ry+3<=yy<=ry-2 and abs(xx)<rx*(yy+ry)/(2*ry)-2
            if kind=='trapezoid':inside=-ry<=yy<=ry and abs(xx)<=rx*(0.2+0.8*(yy+ry)/(2*ry))
            if kind=='diamond':inside=abs(xx)/rx+abs(yy)/ry<=1
            if kind=='cross':inside=(abs(xx)<5 and abs(yy)<=ry) or (abs(yy)<5 and abs(xx)<=rx)
            if inside and (not outline or not inner):c=col
            pix.append(c)
    path=out/(name+'.hex');path.write_text(''.join(f'{c:06x}\n' for c in pix))
    expected={'rect':1,'circle':3,'tri':4}.get(kind,0)
    # Negative cases have no distractor which is itself a supported shape.
    cases.append(dict(name=name,kind=kind,expected=expected))
    sim(name,'tb_shape_components',f'{{+PIXELS={path.as_posix()}}} +EXPECTED={expected}')

if not a.extended_only:
    sim('filter','tb_shape_filter')
    for kind in ['rect','circle','tri']:
        scene(kind+'_clutter',kind)
        scene(kind+'_red',kind,col=0xd02020)
        scene(kind+'_outline',kind,outline=True,noise=False)
        scene(kind+'_small',kind,rx=12,ry=12,noise=False)
    for dy in [-5,-1,0,1,5]:scene('diamond_'+str(dy),'diamond',cy=34+dy,noise=False)
    scene('cross','cross',noise=False)
    scene('rect_tilt','rect',angle=math.radians(5),noise=False)
    scene('circle_ellipse','circle',rx=24,ry=18,noise=False)
    (out/'cases.json').write_text(json.dumps(cases,indent=2))
    print('PASS all shape synthetic scenes',flush=True)
for name,kind in [('rect_clutter',1),('tri_outline',4),('diamond_0',0)]:
    path=out/(name+'.hex')
    sim(name+'_1080p','tb_shape_components',f'-gPIXEL_SHIFT=4 {{+PIXELS={path.as_posix()}}} +EXPECTED={kind}')
for name in ['blank','full_dark','coloured_speckles']:
    pix=[(0x808080 if name=='blank' else 0x202020) if name!='coloured_speckles' else
         [0xd02020,0x20d020,0x2020d0][(x+2*y)%3] for y in range(68) for x in range(120)]
    path=out/(name+'.hex');path.write_text(''.join(f'{c:06x}\n' for c in pix))
    sim(name,'tb_shape_components',f'{{+PIXELS={path.as_posix()}}} +EXPECTED=0')
# Exercise the actual SHAPE_SUPPORT=1 core in red mode with the established
# red-control/native tests, rather than testing only the red-only wrapper.
for top in ['tb_red_target_tracker','tb_red_tracker_1080p']:
    source=(root/'tests'/(top+'.sv')).read_text()
    source=source.replace('module '+top,'module '+top+'_shared').replace('red_target_tracker #','red_shape_tracker #')
    # red_shape_tracker 比 wrapper 多两个输入（I_shape_mode / I_target_color）。
    # 原来的位置补位 hack 在 gege 往端口列表中段插入 I_target_color 之后就错位了，
    # 改为按端口名追加，端口顺序再变也不会坏。
    source=source.replace('.O_area_percent(area)',
        ".O_area_percent(area)," + chr(10) + "          .I_shape_mode(1'b0),.I_target_color(2'd0)")
    generated=out/(top+'_shared.sv');generated.write_text(source)
    script=out/(top+'_shared.do');log=out/(top+'_shared.log')
    script.write_text('onerror {quit -code 1 -force}\nvlog -sv -work {'+lib.as_posix()+'} {'+generated.as_posix()+'}\n'+
        'vsim -lib {'+lib.as_posix()+'} '+top+'_shared\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
    r=subprocess.run([str(a.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=out,capture_output=True,text=True)
    txt=log.read_text(errors='replace');print('\n'.join(l for l in txt.splitlines() if 'PASS ' in l or '** Fatal' in l or '** Error' in l),flush=True)
    assert r.returncode==0 and 'PASS ' in txt and '** Fatal' not in txt and '** Error' not in txt
print('PASS native geometry, complex-mask stress and shared red mode',flush=True)
sim('sequence','tb_shape_sequence')
scene('triangle_inverted','tri',angle=math.pi,noise=False)
scene('trapezoid_reject','trapezoid',noise=False)
pix=[0xd02020 if 30<=x<=54 and 20<=y<=44 else
     (0x20d020 if 55<=x<=79 and 20<=y<=44 else 0x808080) for y in range(68) for x in range(120)]
path=out/'adjacent_colours.hex';path.write_text(''.join(f'{c:06x}\n' for c in pix))
sim('adjacent_colours','tb_shape_components',f'{{+PIXELS={path.as_posix()}}} +EXPECTED=1 +X0=60 +X1=109')
pix=[[0xd02020,0x20d020,0x2020d0,0xd0d020][(x%2)+2*(y%2)] for y in range(68) for x in range(120)]
path=out/'isolated_8160.hex';path.write_text(''.join(f'{c:06x}\n' for c in pix))
sim('isolated_8160','tb_shape_components',f'{{+PIXELS={path.as_posix()}}} +EXPECTED=0')
