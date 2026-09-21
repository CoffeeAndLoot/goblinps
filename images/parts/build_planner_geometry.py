"""Measure-check the planner layout and render handoff proofs; preserve source art."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
LAYOUT = {'canvas': [1600, 1024],
    'title_plate': (480,100,1120,260), 'tagline_plate': (1120,910,1440,990),
    'close_button': (1410,230,38), 'gear_button': (1320,230,38),
    'to_box': (330,286,1328,374), 'dropdown_button': (1374,330,36),
    'results_list': (330,380,1410,650),
    'screen': (150,386,1440,778), 'strip_track': (230,480,1360,640),
    'total_line': (190,666,1400,704), 'hint_line': (190,722,1400,760),
    'notes_line': (190,484,1400,528), 'known_line': (190,548,1400,590),
    'go_button': (560,786,1040,866)}


def art(name):
    return Image.open(ROOT / (name + '.png')).convert('RGBA')


def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/arial.ttf', size)


def paste(canvas, name, box):
    x, y, r, b = box
    canvas.alpha_composite(art(name).resize((r-x, b-y), Image.Resampling.LANCZOS), (x, y))


def text(canvas, box, value, size=30, color='#d3ebac', centered=False):
    x, y, r, b = box
    f = font(size)
    while f.getlength(value) > r-x-56 and size > 12:
        size -= 1
        f = font(size)
    ImageDraw.Draw(canvas).text(((x+r)/2 if centered else x+28, (y+b)/2), value, font=f, fill=color, anchor='mm' if centered else 'lm')


def main():
    import re
    import numpy as np
    path = ROOT / 'planner-geometry.json'
    original = path.read_bytes()
    geometry = json.loads(original)
    # Preserve the historical tall record literally, including whitespace.
    pattern = rb'  "tall": \{.*?\n  \}'
    tall_bytes = re.search(pattern, original, re.S).group()
    w, h = LAYOUT['canvas']
    wide = {'canvas': [w,h]}
    for key, v in LAYOUT.items():
        if key == 'canvas':
            continue
        if len(v) == 3:
            x,y,r = v
            wide[key] = dict(cx=x/w,cy=y/h,r=r/w)
        else:
            x,y,r,b = v
            assert x < r and y < b
            wide[key] = dict(left=x/w,top=y/h,right=r/w,bottom=b/h)
        assert all(0 <= n <= 1 for n in wide[key].values())
    geometry['wide'] = wide
    expected = set('canvas title_plate tagline_plate close_button gear_button to_box dropdown_button results_list screen strip_track total_line hint_line notes_line known_line go_button'.split())
    assert set(wide) == expected
    # Full texture height includes the glow, not only the bright center stroke.
    geometry['strip']['line_thickness'] = 0.02
    geometry['_placement'] = {
        'screen-backdrop': 'independent insert: uniformly cover screen, center-crop overflow',
        'planner-panel': 'tile inside frame opening only',
        'controls': 'rectangles describe complete sprites; preserve input end caps',
        'strip_track': 'left/right are endpoint badge CENTERS; vertical center is badge/line center; labels below visible ring',
        'results_list': 'overlay while searching; ends above total and hint',
        'lines': 'text vertical-center slots, not clipping heights',
        'notes_line': 'idle only, mutually exclusive with route strip',
        'known_line': 'idle only, mutually exclusive with route strip',
        'tall': 'historical record preserved verbatim; unused by current planner',
        'source_art_changed': False, 'in_game_verified': False}
    serialized = (json.dumps(geometry,indent=2)+'\n').encode()
    serialized = re.sub(pattern, lambda _: tall_bytes, serialized, flags=re.S)
    assert re.search(pattern,serialized,re.S).group() == tall_bytes
    assert json.loads(serialized)['tall'] == geometry['tall']
    frame = art('planner-frame-wide')
    brass = {'title_plate','tagline_plate','close_button','gear_button'}
    for key,v in LAYOUT.items():
        if key == 'canvas' or key in brass:
            continue
        box = v if len(v)==4 else (v[0]-v[2],v[1]-v[2],v[0]+v[2],v[1]+v[2])
        assert frame.getchannel('A').crop(box).getextrema()[1] == 0, key
    assert LAYOUT['results_list'][3] < LAYOUT['total_line'][1]
    assert LAYOUT['strip_track'][3] < LAYOUT['total_line'][1]
    assert LAYOUT['hint_line'][3] < LAYOUT['go_button'][1]
    strip = geometry['strip']
    assert all(0 < v < 1 for v in strip.values())
    diameter = round(w*strip['node_diameter'])
    sprite = round(diameter*1.5)
    sx,sy,sr,sb = LAYOUT['strip_track']
    assert sx-sprite/2 >= LAYOUT['screen'][0]
    assert sr+sprite/2 <= LAYOUT['screen'][2]
    assert (sr-sx)/10 > diameter  # eleven stops retain separated visible rings
    path.write_bytes(serialized)

    base = Image.new('RGBA',(w,h))
    tile = art('planner-panel')
    for y in range(0,h,tile.height):
        for x in range(0,w,tile.width):
            base.paste(tile,(x,y))
    mask = Image.new('L',(w,h))
    ImageDraw.Draw(mask).polygon([(125,275),(1475,275),(1475,815),(1400,880),(200,880),(125,805)],fill=255)
    base.putalpha(mask)
    base = Image.alpha_composite(Image.new('RGBA',(w,h)),base)
    x,y,r,b = LAYOUT['screen']
    base.alpha_composite(ImageOps.fit(art('screen-backdrop'),(r-x,b-y),Image.Resampling.LANCZOS),(x,y))
    base.alpha_composite(frame)
    for key,name in [('title_plate','title-plate'),('tagline_plate','tagline-plate'),('to_box','input-box'),('go_button','button')]:
        paste(base,name,LAYOUT[key])
    for key,name in [('close_button','close'),('gear_button','gear'),('dropdown_button','dropdown-button')]:
        x,y,r = LAYOUT[key]
        paste(base,name,(x-r,y-r,x+r,y+r))
    text(base,LAYOUT['to_box'],'To: The Crossroads',32)
    text(base,LAYOUT['go_button'],'Start Route',34,centered=True)

    def route(count):
        out = base.copy()
        cy = (sy+sb)//2
        xs = [round(sx+i*(sr-sx)/(count-1)) for i in range(count)]
        # Preserve each texture's aspect and tile, never stretch a leg.
        thickness = w*strip['line_thickness']
        for i,(left,right) in enumerate(zip(xs,xs[1:])):
            line = art('line-solid' if i == 0 else 'line-dashed')
            th = max(1,round(thickness))
            line = line.resize((round(line.width*th/line.height),th),Image.Resampling.LANCZOS)
            band = Image.new('RGBA',(right-left,th))
            for xx in range(0,band.width,line.width):
                band.alpha_composite(line,(xx,0))
            out.alpha_composite(band,(left,cy-th//2))
            mid = (left+right)//2
            paste(out,'line-dot',(mid-10,cy-10,mid+10,cy+10))
        names = ['icon-horde']+['icon-ride','icon-flight','icon-boat','icon-walk','icon-zeppelin','icon-tram','icon-hearth','icon-ride','icon-walk'][:count-2]+['node-destination']
        for i,(xx,name) in enumerate(zip(xs,names)):
            paste(out,name,(xx-sprite//2,cy-sprite//2,xx+sprite//2,cy+sprite//2))
            if (sr-sx)/(count-1) >= 2*diameter:
                label = ['You are here','Razor Hill','The Crossroads'][i] if count==3 else 'Stop'
                top = round(cy+diameter/2+w*strip['label_gap'])
                text(out,(max(150,xx-145),top,min(1440,xx+145),top+32),label,28,centered=True)
        text(out,LAYOUT['total_line'],'~15 min · free',30,centered=True)
        text(out,LAYOUT['hint_line'],'Warning: route crosses a higher-level zone',28,'#f0b54a',True)
        return out

    assembled = route(3)
    assembled.save(ROOT/'_planner-wide-geometry-assembled.png')
    route(11).save(ROOT/'_planner-wide-eleven-stops.png')
    idle = base.copy()
    text(idle,LAYOUT['notes_line'],'Visit a flight master so GoblinPS can learn your flight paths.',30,centered=True)
    text(idle,LAYOUT['known_line'],'Flight paths known: 3',30,centered=True)
    paste(idle,'button-disabled',LAYOUT['go_button'])
    text(idle,LAYOUT['go_button'],'Start Route',34,'#9b9b8d',True)
    idle.save(ROOT/'_planner-wide-idle-proof.png')
    overlay = assembled.copy()
    ImageDraw.Draw(overlay).rectangle(LAYOUT['results_list'],fill='#162017',outline='#b8873b',width=3)
    x,y,r,b = LAYOUT['results_list']
    for i,label in enumerate(['The Crossroads','Crossroads flight master','The Barrens']):
        text(overlay,(x+12,y+12+i*66,r-12,y+64+i*66),label,30)
    overlay.save(ROOT/'_planner-wide-search-proof.png')
    proof = assembled.copy()
    draw = ImageDraw.Draw(proof)
    for key,v in LAYOUT.items():
        if key=='canvas':
            continue
        box = v if len(v)==4 else (v[0]-v[2],v[1]-v[2],v[0]+v[2],v[1]+v[2])
        draw.rectangle(box,outline='#ff62ed',width=2)
        draw.text(box[:2],key,font=font(16),fill='white',stroke_width=2,stroke_fill='black')
    proof.save(ROOT/'_planner-wide-geometry-proof.png')
    seams = Image.new('RGBA',(1536,220),'#172016')
    for row,name in enumerate(['line-solid','line-dashed']):
        line = art(name)
        pixels = np.array(line)
        assert np.array_equal(pixels[:,0],pixels[:,-1]), name+' edge mismatch'
        for i in range(3):
            seams.alpha_composite(line,(i*line.width,30+row*100))
        ImageDraw.Draw(seams).text((8,row*100+5),name,font=font(18),fill='white')
    seams.save(ROOT/'_planner-line-seams.png')
    print('PASS: normalized wide geometry, source-alpha clearance, footer separation, eleven-stop spacing, exact tall preservation, and identical line edge pixels.')
    print('Saved wide-only proofs; source artwork and historical tall previews unchanged.')


if __name__ == '__main__':
    main()
