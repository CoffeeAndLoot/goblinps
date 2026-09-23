"""Build promotional cards around real captures without repainting the UI.

Requires Pillow and numpy. Run from any directory. Originals stay untouched.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parent


def font(size, bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/' + ('arialbd.ttf' if bold else 'arial.ttf'), size)


def lettering(canvas, pos, words, size, color='#ecdbb1', bold=False):
    d = ImageDraw.Draw(canvas)
    d.text(pos, words, font=font(size,bold), fill=color, stroke_width=2, stroke_fill='#09110d')


def capture(name, size):
    im = Image.open(ROOT/name).convert('RGBA')
    a = np.array(im)
    # Remove only edge-connected dark green screenshot backdrop, not UI pixels.
    rgb = a[:,:,:3].astype(int)
    difference = np.abs(rgb-rgb[0,0]).max(axis=2)
    candidate = Image.fromarray(np.uint8(difference <= 20)*255).convert('RGB')
    for point in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)]:
        ImageDraw.floodfill(candidate, point, (255,0,0))
    fill = np.array(candidate)
    a[(fill[:,:,0]==255)&(fill[:,:,1]==0)] = 0
    im = Image.fromarray(a)
    im.thumbnail(size,Image.Resampling.LANCZOS)
    return im


hero = Image.open(ROOT/'trade-prince-background.jpg').convert('RGBA')
brand_font = font(78, True)
brand_x = 620
for letters, color in [('G', '#b3ee52'), ('oblin', '#d3ad65'), ('PS', '#b3ee52')]:
    lettering(hero, (brand_x,55), letters,78,color,True)
    brand_x += brand_font.getlength(letters)
lettering(hero,(624,151),'THE GOBLIN POSITIONING SYSTEM',23,'#d3ad65',True)
lettering(hero,(620,210),"LESS WALKIN'.",55,'#ffe1a0',True)
lettering(hero,(620,270),"MORE EARNIN'.",55,'#ffe1a0',True)
planner = capture('planner.jpg',(940,595))
hero.alpha_composite(planner,(570,350))
lettering(hero,(650,935),'Time is money, friend.',29,'#b3ee52',True)
lettering(hero,(650,979),'Actual planner capture. Excessive confidence sold separately.',18)
hero.convert('RGB').save(ROOT/'goblinps-planner-demo.jpg',quality=94,subsampling=0)

dash = Image.open(ROOT/'engineer-background.jpg').convert('RGBA')
lettering(dash,(110,55),'FOLLOW THE ARROW.',54,'#b3ee52',True)
lettering(dash,(113,126),'Save the scenic detour for somebody on salary.',26)
unit = capture('dash.png',(520,760))
dash.alpha_composite(unit,(70,205))
for y, heading, detail in [(300,'PICK A PLACE.','Let the planner do the sums.'),
                           (440,'GET MOVIN\u2019.','Next stop. Distance. Directions.'),
                           (580,'MIND THE RED BUTTON.','Stop means stop. Fancy, huh?')]:
    lettering(dash,(590,y),heading,27,'#efbe63',True)
    # Keep copy away from the engineer's hand and face.
    if y==440:
        lettering(dash,(590,y+45),'Next stop. Distance.',23)
        lettering(dash,(590,y+76),'Directions.',23)
    elif y==580:
        lettering(dash,(590,y+45),'Stop means stop.',23)
        lettering(dash,(590,y+76),'Fancy, huh?',23)
    else:
        lettering(dash,(590,y+45),'Let the planner',23)
        lettering(dash,(590,y+76),'do the sums.',23)
lettering(dash,(590,785),'GOBLIN ENGINEERED.',25,'#b3ee52',True)
lettering(dash,(590,827),'Warranty void if eaten.',22)
lettering(dash,(110,981),'Actual dash capture. Character art and sales patter added for the demo.',18)
dash.convert('RGB').save(ROOT/'goblinps-dash-demo.jpg',quality=94,subsampling=0)
print('Built two 1536x1024 demo cards using unchanged product captures.')
