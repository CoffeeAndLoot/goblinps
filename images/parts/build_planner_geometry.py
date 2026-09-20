"""Measure-check the planner layout and render handoff proofs; preserve source art."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
LAYOUTS = {
    'wide': {'canvas': [1600, 1024],
        'title_plate': (480, 100, 1120, 260), 'tagline_plate': (1120, 910, 1440, 990),
        'close_button': (1410, 230, 38), 'gear_button': (1320, 230, 38),
        'tools_button': (1410, 230, 38), 'layout_button': (150, 215, 330, 270),
        'from_box': (150, 300, 610, 374), 'here_button': (622, 300, 782, 374),
        'to_box': (802, 300, 1350, 374), 'dropdown_button': (1402, 337, 37),
        'results_list': (150, 382, 1440, 660),
        'screen': (150, 396, 912, 748), 'strip_track': (185, 480, 877, 654),
        'side_panel': (934, 396, 1440, 748),
        'go_button': (1120, 766, 1440, 846),
        'total_line': (160, 765, 1080, 797), 'hint_line': (160, 807, 1080, 839)},
    'tall': {'canvas': [1024, 1600],
        'title_plate': (300, 100, 724, 206), 'tagline_plate': (352, 1495, 672, 1575),
        'close_button': (858, 270, 34), 'gear_button': (776, 270, 34),
        'tools_button': (858, 270, 34), 'layout_button': (140, 244, 340, 300),
        'from_box': (140, 320, 680, 394), 'here_button': (696, 320, 884, 394),
        'to_box': (140, 414, 792, 488), 'dropdown_button': (848, 451, 36),
        'results_list': (140, 500, 884, 812),
        'screen': (140, 510, 884, 822), 'strip_track': (175, 584, 849, 756),
        'side_panel': (140, 844, 884, 1234),
        'go_button': (524, 1330, 884, 1420),
        'total_line': (150, 1338, 510, 1374), 'hint_line': (150, 1262, 874, 1302)}
}


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


geometry = {'_units': {'origin': 'top-left', 'x': "fraction of that layout's canvas width",
    'y': "fraction of that layout's canvas height", 'r': 'fraction of canvas WIDTH, always',
    'canvas': 'source pixel dimensions; the exception to normalized numbers',
    'strip': 'all three lengths are fractions of the active layout canvas WIDTH'},
    '_placement': {'screen-backdrop': 'independent insert: uniformly cover screen rectangle, center-crop overflow; never stack at canvas origin',
        'planner-panel': 'tile behind contents, clipped to interior opening; no exterior background',
        'controls': 'destination rectangles describe full sprite canvases; use fixed end caps for inputs and buttons',
        'tools_button': 'compatibility alias of close_button; disabled as a separate control; never draw twice',
        'layout_button': 'existing button art with runtime Wide/Tall label',
        'results_list': 'overlay above content while either search is active; hide otherwise',
        'screen': 'contains strip_track; backdrop is decorative, not a geographic map',
        'side_panel': 'always-visible scrollable detailed step list; below screen in tall mode',
        'lines': 'vertical center slots for live text, not clipping rectangles',
        'source_art_changed': False, 'in_game_verified': False}}

for mode, layout in LAYOUTS.items():
    w, h = layout['canvas']
    g = {'canvas': [w, h]}
    for key, v in layout.items():
        if key == 'canvas':
            continue
        if len(v) == 3:
            x, y, radius = v
            g[key] = dict(cx=x/w, cy=y/h, r=radius/w)
        else:
            x, y, right, bottom = v
            assert x < right and y < bottom
            g[key] = dict(left=x/w, top=y/h, right=right/w, bottom=bottom/h)
        assert all(0 <= n <= 1 for n in g[key].values())
    geometry[mode] = g
geometry['strip'] = dict(node_diameter=0.06, line_thickness=0.003, label_gap=0.012)
assert geometry['wide'].keys() == geometry['tall'].keys()
(ROOT / 'planner-geometry.json').write_text(json.dumps(geometry, indent=2)+'\n', encoding='utf-8')

for mode, l in LAYOUTS.items():
    w, h = l['canvas']
    frame = art('planner-frame-'+mode)
    assert frame.size == (w, h)
    # Check real usable areas against source frame alpha, not a guessed border.
    for key in ('from_box', 'to_box', 'here_button', 'results_list', 'screen',
                'side_panel', 'go_button', 'total_line', 'hint_line'):
        assert frame.getchannel('A').crop(l[key]).getextrema()[1] == 0, (mode, key, 'overlaps frame')
    base = Image.new('RGBA', (w, h))
    # The frame has tiny transparent seams: bound the fill explicitly so it
    # cannot flood through a seam into the exterior.
    interior = Image.new('L', (w,h))
    polygon = ([(125,275),(1475,275),(1475,815),(1400,880),(200,880),(125,805)]
               if mode == 'wide' else
               [(115,235),(909,235),(909,1415),(850,1470),(174,1470),(115,1415)])
    ImageDraw.Draw(interior).polygon(polygon, fill=255)
    tile = art('planner-panel')
    for y in range(0, h, tile.height):
        for x in range(0, w, tile.width):
            base.paste(tile, (x, y))
    base.putalpha(interior)
    base = Image.alpha_composite(Image.new('RGBA', (w, h)), base)
    box = l['screen']
    screen = ImageOps.fit(art('screen-backdrop'), (box[2]-box[0], box[3]-box[1]), Image.Resampling.LANCZOS)
    base.alpha_composite(screen, box[:2])
    ImageDraw.Draw(base).rectangle(l['side_panel'], fill='#152017', outline='#5d6739', width=2)
    base.alpha_composite(frame)
    for key, name in [('title_plate','title-plate'),('tagline_plate','tagline-plate'),
                      ('from_box','input-box'),('to_box','input-box'),('here_button','button'),
                      ('go_button','button'),('layout_button','button')]:
        paste(base, name, l[key])
    for key, name in [('close_button','close'),('gear_button','gear'),('dropdown_button','dropdown-button')]:
        x, y, r = l[key]
        paste(base, name, (x-r,y-r,x+r,y+r))
    for key, value in [('from_box','From: where you stand'),('to_box','To: The Crossroads'),
                       ('here_button','Here'),('go_button','Start Route'),
                       ('layout_button','Tall' if mode == 'wide' else 'Wide'),
                       ('total_line','About 12 min'),('hint_line','Warning: higher-level zone')]:
        text(base,l[key],value,30,'#f0b54a' if key == 'hint_line' else '#d3ebac',key in ('here_button','go_button','layout_button'))
    x, y, r, b = l['side_panel']
    text(base,(x+12,y+8,r-12,y+48),'ROUTE STEPS   1-3 of 10',26)
    for i, (label, detail) in enumerate([('1. Ride to the south gate','Through Durotar'),
            ('2. Continue to Razor Hill','Stay on the main road'),('3. Enter the Barrens','Through the west crossing')]):
        yy = y+64+i*86
        text(base,(x+12,yy,r-26,yy+32),label,28)
        text(base,(x+24,yy+35,r-26,yy+63),detail,23,'#9eae8e')
    ImageDraw.Draw(base).rectangle((r-14,y+58,r-8,b-14),fill='#53633e')
    x,y,r,b = l['strip_track']
    cy = y+55
    xs = [x+65,(x+r)//2,r-65]
    ImageDraw.Draw(base).line((xs[0],cy,xs[-1],cy),fill='#91de51',width=max(2,round(w*geometry['strip']['line_thickness'])))
    diameter = round(w*geometry['strip']['node_diameter'])
    # Markers have a visible 128px ring on a 192px source canvas.
    sprite = round(diameter*192/128)
    for xx,name,label in zip(xs,['icon-horde','node-current','node-destination'],['Orgrimmar','Razor Hill','Crossroads']):
        paste(base,name,(xx-sprite//2,cy-sprite//2,xx-sprite//2+sprite,cy-sprite//2+sprite))
        text(base,(xx-105,cy+diameter//2+round(w*.012),xx+105,b),label,25,centered=True)
    base.save(ROOT / ('_planner-'+mode+'-geometry-assembled.png'))
    proof = base.copy()
    d = ImageDraw.Draw(proof)
    for key,v in l.items():
        if key in ('canvas','tools_button'):
            continue
        if len(v)==3:
            x,y,r=v
            d.ellipse((x-r,y-r,x+r,y+r),outline='#ff62ed',width=2)
        else:
            d.rectangle(v,outline='#ff62ed',width=2)
            d.text((v[0]+2,v[1]+2),key,font=font(16),fill='#ffffff',stroke_width=2,stroke_fill='#000000')
    proof.save(ROOT / ('_planner-'+mode+'-geometry-proof.png'))
    overlay = base.copy()
    ImageDraw.Draw(overlay).rectangle(l['results_list'],fill='#162017',outline='#b8873b',width=3)
    x,y,r,b=l['results_list']
    for i,label in enumerate(['The Crossroads','Crossroads flight master','The Barrens']):
        text(overlay,(x+12,y+12+i*66,r-12,y+64+i*66),label,30)
    overlay.save(ROOT / ('_planner-'+mode+'-search-proof.png'))
print('PASS: both layouts, matching keys, normalized coordinates, source dimensions, and all content areas clear frame alpha.')
print('Saved planner-geometry.json and six layout/search proofs; existing art unchanged.')
