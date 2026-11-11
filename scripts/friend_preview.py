"""Host-side mock of Friend's drawing code (no SDK needed).

FriendArt and FriendSprites below are line-for-line ports of
garmin-pet/probes/wrist-diary/source/FriendArt.mc and FriendSprites.mc, and
FriendView mirrors the draw* functions of WristDiaryView.mc. Change both
together: the mock is how a machine without the Connect IQ SDK sees what the
watch will draw. The sprites are the baked strips themselves, read through
the generated table the watch compiles (FriendSpriteTable.mc, sprites.xml).

    python scripts/friend_preview.py            # writes bin/friend/preview/*.png
    python scripts/friend_preview.py --out DIR
    python scripts/friend_preview.py --check    # the mock still matches the watch code

Faithful: every shape, position, color and animation frame (integer math
only, and div() truncates like Monkey C), and every sprite pixel. Stand-ins:
the fonts (Arial Narrow for Garmin's system fonts, at guessed pixel sizes)
and the anti-aliasing.
--check compares the integer literals of every mirrored function in the two
languages, the art tables and palettes, and the width of every voice line.
"""
import argparse
import math
import os
import re

from PIL import Image, ImageDraw, ImageFont

SS = 3  # supersampling: draw at 3x, shrink once, to stand in for setAntiAlias

FONT_XTINY, FONT_TINY, FONT_SMALL, FONT_MEDIUM, FONT_LARGE, FONT_NUMBER_MILD = range(6)
FONT_PX = {FONT_XTINY: 26, FONT_TINY: 31, FONT_SMALL: 35, FONT_MEDIUM: 41,
           FONT_LARGE: 48, FONT_NUMBER_MILD: 58}
JUST_CENTER, JUST_LEFT, JUST_RIGHT = 1, 2, 0
ARC_CCW = 0

WHITE = 0xFFFFFF
LT_GRAY = 0xAAAAAA
DK_GRAY = 0x555555
BLACK = 0x000000


def div(a, b):
    """Integer division that truncates toward zero, as Monkey C does."""
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


def rgb(color):
    return ((color >> 16) & 255, (color >> 8) & 255, color & 255)


_font_cache = {}


def load_font(px):
    if px not in _font_cache:
        for name in ("ARIALNB.TTF", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
            try:
                _font_cache[px] = ImageFont.truetype(name, px)
                break
            except OSError:
                continue
        else:
            _font_cache[px] = ImageFont.load_default()
    return _font_cache[px]


class Dc:
    """The slice of Toybox.Graphics.Dc that Friend uses."""

    def __init__(self, size=416):
        self.size = size
        self.img = Image.new("RGB", (size * SS, size * SS), (0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.color = (255, 255, 255)
        self.pen = 1
        self.clip = None

    def setClip(self, x, y, w, h):
        self.clip = (x, y, x + w, y + h)

    def clearClip(self):
        self.clip = None

    def drawBitmap(self, x, y, bitmap):
        """A bitmap 1:1, inside the clip. Pasted at 3x so finish() gives it back."""
        left, top, right, bottom = self.clip or (0, 0, self.size, self.size)
        left, top = max(left, x, 0), max(top, y, 0)
        right, bottom = min(right, x + bitmap.width, self.size), min(bottom, y + bitmap.height,
                                                                     self.size)
        if right <= left or bottom <= top:
            return
        part = bitmap.crop((left - x, top - y, right - x, bottom - y))
        part = part.resize((part.width * SS, part.height * SS), Image.NEAREST)
        self.img.paste(part, (left * SS, top * SS), part)

    def getWidth(self):
        return self.size

    def getHeight(self):
        return self.size

    def setColor(self, fg, bg=None):
        self.color = rgb(fg)

    def setPenWidth(self, w):
        self.pen = w

    def clear(self):
        self.d.rectangle([0, 0, self.size * SS, self.size * SS], fill=(0, 0, 0))

    def fillCircle(self, x, y, r):
        self.fillEllipse(x, y, r, r)

    def drawCircle(self, x, y, r):
        w = self.pen * SS
        self.d.ellipse([(x - r) * SS - w // 2, (y - r) * SS - w // 2,
                        (x + r) * SS + w // 2, (y + r) * SS + w // 2],
                       outline=self.color, width=w)

    def fillEllipse(self, x, y, a, b):
        if a <= 0 or b <= 0:
            return
        self.d.ellipse([(x - a) * SS, (y - b) * SS, (x + a) * SS, (y + b) * SS],
                       fill=self.color)

    def fillRectangle(self, x, y, w, h):
        if w <= 0 or h <= 0:
            return
        self.d.rectangle([x * SS, y * SS, (x + w) * SS - 1, (y + h) * SS - 1],
                         fill=self.color)

    def fillRoundedRectangle(self, x, y, w, h, r):
        if w <= 0 or h <= 0:
            return
        self.d.rounded_rectangle([x * SS, y * SS, (x + w) * SS - 1, (y + h) * SS - 1],
                                 radius=r * SS, fill=self.color)

    def fillPolygon(self, pts):
        self.d.polygon([(px * SS, py * SS) for px, py in pts], fill=self.color)

    def drawLine(self, x1, y1, x2, y2):
        w = self.pen * SS
        self.d.line([x1 * SS, y1 * SS, x2 * SS, y2 * SS], fill=self.color, width=w)
        r = w // 2
        for px, py in ((x1, y1), (x2, y2)):
            self.d.ellipse([px * SS - r, py * SS - r, px * SS + r, py * SS + r],
                           fill=self.color)

    def drawArc(self, x, y, r, direction, start, end):
        # Connect IQ: degrees, 0 at 3 o'clock, counter-clockwise positive.
        # PIL: clockwise positive with y down, so mirror the angles.
        w = self.pen * SS
        self.d.arc([(x - r) * SS - w // 2, (y - r) * SS - w // 2,
                    (x + r) * SS + w // 2, (y + r) * SS + w // 2],
                   360 - end, 360 - start, fill=self.color, width=w)

    def getFontHeight(self, font):
        return FONT_PX[font]

    def getTextWidthInPixels(self, text, font):
        return int(load_font(FONT_PX[font]).getlength(text))

    def drawText(self, x, y, font, text, just):
        f = load_font(FONT_PX[font] * SS)
        anchor = {JUST_CENTER: "mm", JUST_LEFT: "lm", JUST_RIGHT: "rm"}[just]
        self.d.text((x * SS, y * SS), text, font=f, fill=self.color, anchor=anchor)

    def finish(self):
        img = self.img.resize((self.size, self.size), Image.LANCZOS)
        mask = Image.new("L", (self.size, self.size), 0)
        ImageDraw.Draw(mask).ellipse([0, 0, self.size - 1, self.size - 1], fill=255)
        out = Image.new("RGB", (self.size, self.size), (24, 24, 28))
        out.paste(img, (0, 0), mask)
        return out


# ------------------------------------------------------------ FriendSprites
# The generated table, read from the Monkey C the watch compiles, so the mock
# and the watch cannot disagree about a number or a file.

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
APP = os.path.join(REPO, "garmin-pet", "probes", "wrist-diary")
_table = open(os.path.join(APP, "source", "FriendSpriteTable.mc"), encoding="utf-8").read()
_files = dict(re.findall(r'<bitmap id="(\w+)" filename="([^"]+)"',
                         open(os.path.join(APP, "resources", "drawables", "sprites.xml"),
                              encoding="utf-8").read()))
_bitmaps = {}


def _const(name):
    return int(re.search(r"^const %s = (\d+);" % name, _table, re.M).group(1))


def _body(function):
    return _table.split("function " + function + "(")[1].split("\n}\n")[0]


def _arrays(function):
    return [[int(v) for v in m.split(",")]
            for m in re.findall(r"return \[([-\d, ]+)\]", _body(function))]


def _bitmap(ident):
    if ident not in _bitmaps:
        _bitmaps[ident] = Image.open(os.path.join(APP, "resources", "drawables",
                                                  _files[ident])).convert("RGBA")
    return _bitmaps[ident]


FRIEND_PETS = _const("FRIEND_PETS")
FRIEND_SLOTS = _const("FRIEND_SLOTS")
FRIEND_SLOT_FIELDS = _const("FRIEND_SLOT_FIELDS")
FRIEND_EMBLEMS = _const("FRIEND_EMBLEMS")
FRIEND_EMBLEM_LEVELS = _const("FRIEND_EMBLEM_LEVELS")
FRIEND_EMBLEM_TILE = _const("FRIEND_EMBLEM_TILE")
FRIEND_EMBLEM_TILE_SMALL = _const("FRIEND_EMBLEM_TILE_SMALL")
PALETTE_COUNT = 6
_heights = _arrays("friendHeights")             # the card size comes first in the source
_cells = _arrays("friendCells")                 # home size, then card size
_strips = re.findall(r"Rez\.Drawables\.(\w+)", _body("loadFriendStrip"))
_emblems = re.findall(r"Rez\.Drawables\.(\w+)", _body("loadFriendEmblem"))


def friendHeights(small):
    return _heights[0] if small else _heights[1]


def friendEmblemNames():
    return re.findall(r'"(\w+)"', _body("friendEmblemNames"))


def friendCells(pet, small):
    return _cells[pet + (FRIEND_PETS if small else 0)]


def loadFriendStrip(pet, pal, small):
    k = pet * PALETTE_COUNT + pal
    return _bitmap(_strips[k + (FRIEND_PETS * PALETTE_COUNT if small else 0)])


def loadFriendEmblem(emblem):
    return _bitmap(_emblems[emblem - 1])


SLOT_IDLE, SLOT_BREATHE, SLOT_DROOP, SLOT_BACK = range(4)
SLOT_CROUCH, SLOT_HOP, SLOT_CHEER, SLOT_FLEX = range(4, 8)
SLOT_RUN_A, SLOT_RUN_B, SLOT_EFFORT, SLOT_ASLEEP = range(8, 12)


# Mirrors FriendSprites.mc. Keep names, order and numbers identical.
class FriendSprites:
    def __init__(self, small):
        self.mSmall = small
        self.mStrip = None
        self.mStripKey = -1
        self.mPet = -1
        self.mCells = []
        self.mEmblem = None
        self.mEmblemKey = -1

    def petFor(self, stage, form):
        if stage == STAGE_BABY:
            return 0
        if stage == STAGE_CHILD:
            return 1
        if stage == STAGE_ADULT:
            return 2 + form
        return -1

    def slotFor(self, face, pose, frame):
        if pose == POSE_SLEEP:
            return SLOT_ASLEEP
        if pose == POSE_RUN:
            return SLOT_RUN_A if (frame % 4) < 2 else SLOT_RUN_B
        if pose == POSE_HOP:
            beat = frame % 8
            return SLOT_CROUCH if (beat == 0 or beat >= 6) else SLOT_HOP
        if pose == POSE_FLEX:
            return SLOT_CHEER if (frame % 4) < 2 else SLOT_FLEX
        if pose == POSE_SPIN:
            return SLOT_IDLE if (frame % 4) < 2 else SLOT_BACK
        if pose == POSE_FLAMES or face == FACE_EFFORT:
            return SLOT_EFFORT
        if face == FACE_MISTY:
            return SLOT_DROOP
        return SLOT_IDLE if (frame % 12) < 6 else SLOT_BREATHE

    def ready(self, pet, pal):
        if pet < 0 or pet >= FRIEND_PETS:
            return False
        key = pet * PALETTE_COUNT + pal
        if key != self.mStripKey:
            try:
                bmp = loadFriendStrip(pet, pal, self.mSmall)
            except OSError:
                bmp = None
            self.mStrip = bmp
            self.mStripKey = key
            self.mPet = pet
            self.mCells = friendCells(pet, self.mSmall)
        return self.mStrip is not None and len(self.mCells) >= FRIEND_SLOTS * FRIEND_SLOT_FIELDS

    def unit(self):
        if self.mPet < 0:
            return 0
        return div(friendHeights(self.mSmall)[self.mPet], 2)

    def draw(self, dc, footX, footY, slot):
        strip = self.mStrip
        if strip is None:
            return
        i = slot * FRIEND_SLOT_FIELDS
        w = self.mCells[i + 2]
        h = self.mCells[i + 3]
        left = footX - self.mCells[i + 4]
        top = footY - h
        dc.setClip(left, top, w, h)
        dc.drawBitmap(left - self.mCells[i], top - self.mCells[i + 1], strip)
        dc.clearClip()

    def drawEmblem(self, dc, footX, footY, slot, pal, emblem, level):
        if emblem < 1 or emblem > FRIEND_EMBLEMS:
            return
        i = slot * FRIEND_SLOT_FIELDS
        if self.mCells[i + 5] < 0:
            return
        if emblem != self.mEmblemKey:
            try:
                loaded = loadFriendEmblem(emblem)
            except OSError:
                loaded = None
            self.mEmblem = loaded
            self.mEmblemKey = emblem
        bmp = self.mEmblem
        if bmp is None:
            return
        tile = FRIEND_EMBLEM_TILE
        row = level * tile
        if self.mSmall:
            tile = FRIEND_EMBLEM_TILE_SMALL
            row = FRIEND_EMBLEM_LEVELS * FRIEND_EMBLEM_TILE + level * tile
        left = footX - self.mCells[i + 4] + self.mCells[i + 5] - div(tile, 2)
        top = footY - self.mCells[i + 3] + self.mCells[i + 6] - div(tile, 2)
        dc.setClip(left, top, tile, tile)
        dc.drawBitmap(left - pal * tile, top - row, bmp)
        dc.clearClip()


# ---------------------------------------------------------------- FriendArt
# Mirrors FriendArt.mc. Keep names, order and numbers identical.

STAGE_EGG, STAGE_BABY, STAGE_CHILD, STAGE_ADULT = 0, 1, 2, 3
FORM_SLEEK, FORM_ROUND, FORM_WILD = 0, 1, 2
FACE_MISTY, FACE_FAIR, FACE_SUNNY, FACE_RADIANT, FACE_EFFORT, FACE_JOY, FACE_SLEEP = range(7)
POSE_IDLE, POSE_RUN, POSE_HOP, POSE_FLEX, POSE_SPIN, POSE_FLAMES, POSE_SLEEP = range(7)

PALETTES = [
    # body, shade, belly
    [0x6ED6A8, 0x3E9C78, 0xC8F5E0],   # mint
    [0xFFB15C, 0xD9822B, 0xFFE2B8],   # peach
    [0x6EC1FF, 0x3A8BD1, 0xCDEBFF],   # sky
    [0xB79CFF, 0x8468D6, 0xE4DAFF],   # lilac
    [0xF2D550, 0xC9A21E, 0xFFF3B8],   # sun
    [0xFF8FAF, 0xD65C82, 0xFFD6E2],   # rose
]
PALETTE_NAMES = ["MINT", "PEACH", "SKY", "LILAC", "SUN", "ROSE"]

INK = 0x1B1B2A
BLUSH = 0xFF6F8E
LEAF = 0x7BE07B
BAND_RED = 0xFF5A5A
FLAME_OUT = 0xFF8A2A
FLAME_IN = 0xFFE066
SHELL = 0xF4F1E6
SHADOW = 0x14201A

BOB = [0, 1, 2, 2, 2, 1, 0, -1, -2, -2, -2, -1]
RUN_JUMP = [0, 7, 10, 7]
HOP_JUMP = [0, 20, 34, 40, 34, 20, 0, -5]
SPIN_WIDTH = [100, 72, 40, 72, 100, 72, 40, 72]


class FriendArt:
    def __init__(self):
        self.mStage = STAGE_BABY
        self.mBand = 0
        self.mForm = FORM_ROUND
        self.mEvos = 0
        self.mPal = 0
        self.mFace = FACE_FAIR
        self.mPose = POSE_IDLE
        self.mFrame = 0
        self.mBig = FriendSprites(False)
        self.mLittle = FriendSprites(True)
        self.mEmblem = 0
        self.mEmblemLevel = 1

    def setLook(self, stage, band, form, evos, pal):
        self.mStage = stage
        self.mBand = band
        self.mForm = form
        self.mEvos = evos
        self.mPal = pal % len(PALETTES)

    def setPose(self, face, pose, frame):
        self.mFace = face
        self.mPose = pose
        self.mFrame = frame

    def setEmblem(self, emblem, level):
        self.mEmblem = emblem
        self.mEmblemLevel = level

    def bodyColor(self):
        return PALETTES[self.mPal][0]

    def shadeColor(self):
        return PALETTES[self.mPal][1]

    def bellyColor(self):
        return PALETTES[self.mPal][2]

    # Body radius in pixels for a stage, as a share of the screen height.
    def sizeFor(self, stage, height):
        if stage == STAGE_ADULT:
            return div(height * 150, 1000)
        if stage == STAGE_CHILD:
            return div(height * 140, 1000)
        if stage == STAGE_BABY:
            return div(height * 124, 1000)
        return div(height * 130, 1000)

    def ellipseHalf(self, a, b, dy):
        if dy < 0:
            dy = -dy
        if b <= 0 or dy >= b:
            return 0
        return int(a * math.sqrt(b * b - dy * dy) / b)

    # The friend standing on footY, at a percentage of its home size: the
    # baked sprite when its character has a sheet, the drawn stand-in when not.
    def drawStanding(self, dc, x, footY, percent):
        sprites = self.mBig if percent >= 75 else self.mLittle
        if sprites.ready(sprites.petFor(self.mStage, self.mForm), self.mPal):
            self.drawSprite(dc, sprites, x, footY)
            return
        size = div(self.sizeFor(self.mStage, dc.getHeight()) * percent, 100)
        self.draw(dc, x, footY - size, size)

    def drawSprite(self, dc, sprites, x, footY):
        frame = self.mFrame
        unit = sprites.unit()
        jump = 0
        if self.mPose == POSE_RUN:
            jump = div(unit * RUN_JUMP[frame % 4], 100)
        elif self.mPose == POSE_HOP:
            jump = div(unit * HOP_JUMP[frame % 8], 150)
            if jump < 0:
                jump = 0
        self.drawShadow(dc, x, footY, div(unit * 90, 100) - jump, unit)
        if self.mEvos >= 2:
            self.drawAura(dc, x, footY - unit, unit, frame)
        if self.mPose == POSE_FLAMES:
            self.drawFlames(dc, x, footY - unit, unit, frame)
        slot = sprites.slotFor(self.mFace, self.mPose, frame)
        sprites.draw(dc, x, footY - jump, slot)
        level = self.mEmblemLevel
        if self.mFace == FACE_EFFORT and (frame % 4) < 2:
            level = 2
        sprites.drawEmblem(dc, x, footY - jump, slot, self.mPal, self.mEmblem, level)
        if self.mPose == POSE_SLEEP:
            self.drawZ(dc, x + div(unit * 70, 100), footY - div(unit * 150, 100), unit, frame)

    # The whole friend, centered on (cx, cy) with body radius s.
    def draw(self, dc, cx, cy, s):
        if self.mStage == STAGE_EGG:
            self.drawEgg(dc, cx, cy, s, 0)
            return
        frame = self.mFrame
        a = s
        b = s
        if self.mStage == STAGE_BABY:
            b = div(s * 94, 100)
        elif self.mStage == STAGE_CHILD:
            a = div(s * 94, 100)
        elif self.mForm == FORM_SLEEK:
            a = div(s * 84, 100)
            b = div(s * 106, 100)
        elif self.mForm == FORM_ROUND:
            a = div(s * 108, 100)
            b = div(s * 96, 100)
        else:
            a = div(s * 96, 100)

        jump = 0
        if self.mPose == POSE_RUN:
            jump = div(s * RUN_JUMP[frame % 4], 100)
        elif self.mPose == POSE_HOP or self.mPose == POSE_FLEX:
            jump = div(s * HOP_JUMP[frame % 8], 100)
        elif self.mPose == POSE_SPIN:
            a = div(a * SPIN_WIDTH[frame % 8], 100)
        elif self.mPose == POSE_SLEEP:
            a = div(a * 108, 100)
            b = div(b * 88, 100)
            cy = cy + div(s * 12, 100)
        else:
            b = b + div(s * BOB[frame % 12], 100)
        footY = cy + b - div(s * 4, 100)
        self.drawShadow(dc, cx, footY + div(s * 10, 100), div(s * 112, 100) - jump, s)
        cy = cy - jump
        back = (self.mPose == POSE_SPIN and (frame % 4) == 2)

        if self.mEvos >= 2:
            self.drawAura(dc, cx, cy, s, frame)
        if self.mPose == POSE_FLAMES:
            self.drawFlames(dc, cx, cy, s, frame)
        if self.mBand >= 5:
            self.drawCape(dc, cx, cy, a, b, s, frame)
        if self.mStage == STAGE_ADULT:
            dc.setColor(self.shadeColor(), BLACK)
            dc.fillCircle(cx + div(a * 92, 100), cy + div(b * 52, 100), div(s * 20, 100))
        self.drawFeet(dc, cx, footY - jump, a, s, frame)
        if self.mStage != STAGE_BABY:
            self.drawEars(dc, cx, cy, a, b, s)

        dc.setColor(self.bodyColor(), BLACK)
        dc.fillEllipse(cx, cy, a, b)
        if self.mStage != STAGE_BABY and not back:
            dc.setColor(self.bellyColor(), BLACK)
            dc.fillEllipse(cx, cy + div(b * 40, 100), div(a * 56, 100), div(b * 42, 100))
        dc.setColor(self.bellyColor(), BLACK)
        dc.fillEllipse(cx - div(a * 44, 100), cy - div(b * 56, 100),
                       div(a * 17, 100), div(b * 10, 100))

        if self.mStage != STAGE_BABY:
            self.drawArms(dc, cx, cy, a, b, s, frame)
        if self.mBand >= 2:
            self.drawHeadband(dc, cx, cy, a, b, s, frame)
        if self.mStage == STAGE_BABY:
            self.drawShellCap(dc, cx, cy, a, b, s)
        elif self.mBand == 1 or self.mBand == 2:
            self.drawSprout(dc, cx, cy - b, s, frame)
        elif self.mForm == FORM_WILD:
            self.drawTuft(dc, cx, cy - b, s)
        if not back:
            self.drawFace(dc, cx, cy, a, b, s, frame)
        if self.mPose == POSE_SLEEP:
            self.drawZ(dc, cx + a, cy - div(b * 60, 100), s, frame)

    def drawShadow(self, dc, cx, y, a, s):
        dc.setColor(SHADOW, BLACK)
        dc.fillEllipse(cx, y, a, div(s * 15, 100))

    def drawFeet(self, dc, cx, y, a, s, frame):
        lift = div(s * 12, 100)
        left = 0
        right = 0
        if self.mPose == POSE_RUN:
            if (frame % 4) < 2:
                left = lift
            else:
                right = lift
        dc.setColor(self.shadeColor(), BLACK)
        dc.fillEllipse(cx - div(a * 42, 100), y - left, div(s * 25, 100), div(s * 13, 100))
        dc.fillEllipse(cx + div(a * 42, 100), y - right, div(s * 25, 100), div(s * 13, 100))

    def drawEars(self, dc, cx, cy, a, b, s):
        body = self.bodyColor()
        shade = self.shadeColor()
        if self.mStage == STAGE_ADULT and self.mForm == FORM_SLEEK:
            side = -1
            while side <= 1:
                x = cx + side * div(a * 52, 100)
                y = cy - div(b * 104, 100)
                dc.setColor(body, BLACK)
                dc.fillEllipse(x, y, div(s * 15, 100), div(s * 40, 100))
                dc.setColor(shade, BLACK)
                dc.fillEllipse(x, y + div(s * 4, 100), div(s * 7, 100), div(s * 26, 100))
                side += 2
        elif self.mStage == STAGE_ADULT and self.mForm == FORM_WILD:
            side = -1
            while side <= 1:
                x = cx + side * div(a * 62, 100)
                y = cy - div(b * 70, 100)
                dc.setColor(body, BLACK)
                dc.fillPolygon([[x - div(s * 22, 100), y + div(s * 14, 100)],
                                [x + side * div(s * 20, 100), y - div(s * 46, 100)],
                                [x + div(s * 22, 100), y + div(s * 14, 100)]])
                dc.setColor(shade, BLACK)
                dc.fillPolygon([[x - div(s * 10, 100), y + div(s * 6, 100)],
                                [x + side * div(s * 14, 100), y - div(s * 28, 100)],
                                [x + div(s * 10, 100), y + div(s * 6, 100)]])
                side += 2
        else:
            r = div(s * 26, 100)
            if self.mStage == STAGE_ADULT:
                r = div(s * 30, 100)
            side = -1
            while side <= 1:
                x = cx + side * div(a * 66, 100)
                y = cy - div(b * 74, 100)
                dc.setColor(body, BLACK)
                dc.fillCircle(x, y, r)
                dc.setColor(shade, BLACK)
                dc.fillCircle(x, y, div(r * 52, 100))
                side += 2

    def drawArms(self, dc, cx, cy, a, b, s, frame):
        dc.setColor(self.shadeColor(), BLACK)
        armA = div(s * 13, 100)
        armB = div(s * 22, 100)
        if self.mPose == POSE_FLEX:
            side = -1
            while side <= 1:
                x = cx + side * (a + div(s * 12, 100))
                dc.fillEllipse(x, cy + div(s * 4, 100), div(s * 24, 100), armA)
                dc.fillEllipse(x + side * div(s * 16, 100), cy - div(s * 18, 100),
                               armA, div(s * 26, 100))
                dc.fillCircle(x + side * div(s * 4, 100), cy - div(s * 8, 100),
                              div(s * 17, 100))
                side += 2
            return
        swing = 0
        if self.mPose == POSE_RUN:
            swing = div(s * 12, 100)
            if (frame % 4) < 2:
                swing = -swing
        elif self.mPose == POSE_HOP:
            swing = -div(s * 30, 100)
            dc.fillEllipse(cx - a - div(s * 2, 100), cy + swing, armA, armB)
            dc.fillEllipse(cx + a + div(s * 2, 100), cy + swing, armA, armB)
            return
        dc.fillEllipse(cx - a + div(s * 2, 100), cy + div(s * 18, 100) + swing, armA, armB)
        dc.fillEllipse(cx + a - div(s * 2, 100), cy + div(s * 18, 100) - swing, armA, armB)

    def drawHeadband(self, dc, cx, cy, a, b, s, frame):
        top = cy - div(b * 62, 100)
        bottom = cy - div(b * 42, 100)
        wTop = self.ellipseHalf(a, b, cy - top)
        wBottom = self.ellipseHalf(a, b, cy - bottom)
        dc.setColor(BAND_RED, BLACK)
        dc.fillPolygon([[cx - wTop, top], [cx + wTop, top],
                        [cx + wBottom, bottom], [cx - wBottom, bottom]])
        # The knot's two tails flutter on alternate frames.
        flutter = div(s * 6, 100)
        if (frame % 4) < 2:
            flutter = -flutter
        knotX = cx + wBottom - div(s * 2, 100)
        knotY = div(top + bottom, 2)
        dc.fillPolygon([[knotX, knotY - div(s * 5, 100)],
                        [knotX + div(s * 30, 100), knotY - div(s * 14, 100) + flutter],
                        [knotX + div(s * 26, 100), knotY + div(s * 2, 100) + flutter]])
        dc.fillPolygon([[knotX, knotY + div(s * 3, 100)],
                        [knotX + div(s * 24, 100), knotY + div(s * 12, 100) - flutter],
                        [knotX + div(s * 14, 100), knotY + div(s * 22, 100) - flutter]])

    def drawShellCap(self, dc, cx, cy, a, b, s):
        y = cy - div(b * 60, 100)
        w = self.ellipseHalf(a, b, cy - y) + div(s * 8, 100)
        tooth = div(s * 20, 100)
        top = cy - b - div(s * 14, 100)
        dc.setColor(SHELL, BLACK)
        dc.fillPolygon([[cx - w, y - tooth],
                        [cx - div(w * 66, 100), y],
                        [cx - div(w * 33, 100), y - tooth],
                        [cx, y],
                        [cx + div(w * 33, 100), y - tooth],
                        [cx + div(w * 66, 100), y],
                        [cx + w, y - tooth],
                        [cx + div(w * 86, 100), top + div(s * 22, 100)],
                        [cx + div(w * 50, 100), top],
                        [cx - div(w * 50, 100), top],
                        [cx - div(w * 86, 100), top + div(s * 22, 100)]])
        dc.setColor(self.bodyColor(), BLACK)
        dc.fillCircle(cx + div(w * 30, 100), top + div(s * 20, 100), div(s * 8, 100))

    def drawSprout(self, dc, cx, topY, s, frame):
        sway = 0
        if (frame % 12) < 6:
            sway = div(s * 3, 100)
        tipX = cx + sway
        tipY = topY - div(s * 26, 100)
        dc.setColor(LEAF, BLACK)
        dc.setPenWidth(4)
        dc.drawLine(cx, topY + div(s * 4, 100), tipX, tipY)
        dc.fillPolygon([[tipX, tipY],
                        [tipX - div(s * 14, 100), tipY - div(s * 22, 100)],
                        [tipX - div(s * 34, 100), tipY - div(s * 18, 100)],
                        [tipX - div(s * 20, 100), tipY - div(s * 2, 100)]])
        dc.fillPolygon([[tipX, tipY],
                        [tipX + div(s * 14, 100), tipY - div(s * 22, 100)],
                        [tipX + div(s * 34, 100), tipY - div(s * 18, 100)],
                        [tipX + div(s * 20, 100), tipY - div(s * 2, 100)]])

    def drawTuft(self, dc, cx, topY, s):
        dc.setColor(self.shadeColor(), BLACK)
        base = topY + div(s * 8, 100)
        dc.fillPolygon([[cx - div(s * 26, 100), base],
                        [cx - div(s * 18, 100), topY - div(s * 22, 100)],
                        [cx - div(s * 8, 100), base - div(s * 4, 100)],
                        [cx, topY - div(s * 34, 100)],
                        [cx + div(s * 8, 100), base - div(s * 4, 100)],
                        [cx + div(s * 18, 100), topY - div(s * 22, 100)],
                        [cx + div(s * 26, 100), base]])

    def drawCape(self, dc, cx, cy, a, b, s, frame):
        flutter = div(s * 5, 100)
        if (frame % 4) < 2:
            flutter = -flutter
        dc.setColor(0xC8324A, BLACK)
        dc.fillPolygon([[cx - div(a * 70, 100), cy - div(b * 40, 100)],
                        [cx + div(a * 70, 100), cy - div(b * 40, 100)],
                        [cx + a + div(s * 34, 100), cy + b + flutter],
                        [cx + div(a * 40, 100), cy + b - div(s * 8, 100)],
                        [cx - a - div(s * 34, 100), cy + b - flutter]])

    def drawAura(self, dc, cx, cy, s, frame):
        dc.setColor(0xE8CF70, BLACK)
        dc.setPenWidth(3)
        dc.drawCircle(cx, cy, div(s * 120, 100) + (frame % 4))

    def drawFlames(self, dc, cx, cy, s, frame):
        flick = div(s * 8, 100)
        if (frame % 2) == 0:
            flick = -flick
        i = 0
        while i < 5:
            x = cx + div((i - 2) * s * 58, 100)
            h = div(s * 170, 100)
            if i == 1 or i == 3:
                h = div(s * 215, 100)
            if i == 2:
                h = div(s * 250, 100)
            if (i % 2) == 0:
                h = h + flick
            else:
                h = h - flick
            base = cy + div(s * 95, 100)
            w = div(s * 40, 100)
            dc.setColor(FLAME_OUT, BLACK)
            dc.fillPolygon([[x - w, base], [x - div(w * 60, 100), base - div(h * 55, 100)],
                            [x, base - h], [x + div(w * 60, 100), base - div(h * 55, 100)],
                            [x + w, base]])
            dc.setColor(FLAME_IN, BLACK)
            dc.fillPolygon([[x - div(w * 55, 100), base],
                            [x, base - div(h * 62, 100)],
                            [x + div(w * 55, 100), base]])
            i += 1

    def drawFace(self, dc, cx, cy, a, b, s, frame):
        face = self.mFace
        eyeDX = div(a * 36, 100)
        eyeY = cy - div(b * 14, 100)
        eyeR = div(s * 13, 100)
        if self.mStage == STAGE_BABY:
            eyeR = div(s * 16, 100)
            eyeY = cy - div(b * 6, 100)
        mouthY = eyeY + div(s * 30, 100)
        blink = ((frame % 23) == 22)

        if face == FACE_SUNNY or face == FACE_RADIANT or face == FACE_JOY:
            dc.setColor(BLUSH, BLACK)
            dc.fillEllipse(cx - div(a * 62, 100), eyeY + div(s * 22, 100),
                           div(s * 12, 100), div(s * 7, 100))
            dc.fillEllipse(cx + div(a * 62, 100), eyeY + div(s * 22, 100),
                           div(s * 12, 100), div(s * 7, 100))

        dc.setColor(INK, BLACK)
        pen = div(s * 7, 100)
        if pen < 3:
            pen = 3
        dc.setPenWidth(pen)
        if face == FACE_SLEEP:
            dc.drawLine(cx - eyeDX - eyeR, eyeY, cx - eyeDX + eyeR, eyeY)
            dc.drawLine(cx + eyeDX - eyeR, eyeY, cx + eyeDX + eyeR, eyeY)
        elif face == FACE_JOY:
            # Happy closed eyes: two upturned arcs.
            dc.drawArc(cx - eyeDX, eyeY + div(eyeR, 2), eyeR, ARC_CCW, 20, 160)
            dc.drawArc(cx + eyeDX, eyeY + div(eyeR, 2), eyeR, ARC_CCW, 20, 160)
        elif blink:
            dc.drawLine(cx - eyeDX - eyeR, eyeY, cx - eyeDX + eyeR, eyeY)
            dc.drawLine(cx + eyeDX - eyeR, eyeY, cx + eyeDX + eyeR, eyeY)
        else:
            dc.fillCircle(cx - eyeDX, eyeY, eyeR)
            dc.fillCircle(cx + eyeDX, eyeY, eyeR)
            dc.setColor(WHITE, BLACK)
            shine = div(eyeR * 38, 100)
            dc.fillCircle(cx - eyeDX - div(eyeR * 30, 100), eyeY - div(eyeR * 34, 100), shine)
            dc.fillCircle(cx + eyeDX - div(eyeR * 30, 100), eyeY - div(eyeR * 34, 100), shine)
            if face == FACE_MISTY:
                # Half-lidded: the body color over the top of each eye.
                dc.setColor(self.bodyColor(), BLACK)
                dc.fillRectangle(cx - eyeDX - eyeR - 1, eyeY - eyeR - 1,
                                 eyeR * 2 + 2, eyeR + 1)
                dc.fillRectangle(cx + eyeDX - eyeR - 1, eyeY - eyeR - 1,
                                 eyeR * 2 + 2, eyeR + 1)
            dc.setColor(INK, BLACK)
            if face == FACE_EFFORT:
                # Determined brows, tilted in toward the nose.
                dc.drawLine(cx - eyeDX - eyeR, eyeY - eyeR - div(s * 10, 100),
                            cx - eyeDX + eyeR, eyeY - eyeR - div(s * 2, 100))
                dc.drawLine(cx + eyeDX - eyeR, eyeY - eyeR - div(s * 2, 100),
                            cx + eyeDX + eyeR, eyeY - eyeR - div(s * 10, 100))

        dc.setColor(INK, BLACK)
        if face == FACE_SLEEP or face == FACE_MISTY:
            dc.drawLine(cx - div(s * 8, 100), mouthY, cx + div(s * 8, 100), mouthY)
        elif face == FACE_FAIR:
            dc.drawArc(cx, mouthY - div(s * 14, 100), div(s * 18, 100), ARC_CCW, 235, 305)
        elif face == FACE_SUNNY:
            dc.drawArc(cx, mouthY - div(s * 16, 100), div(s * 24, 100), ARC_CCW, 220, 320)
        else:
            # Open, laughing mouth: a disc with its top half painted back out.
            mouth = div(s * 17, 100)
            if face == FACE_EFFORT and (frame % 4) >= 2:
                mouth = div(s * 13, 100)
            dc.fillCircle(cx, mouthY - div(s * 4, 100), mouth)
            dc.setColor(self.bodyColor(), BLACK)
            dc.fillRectangle(cx - mouth - 1, mouthY - div(s * 4, 100) - mouth - 1,
                             mouth * 2 + 2, mouth + 1)
            dc.setColor(BLUSH, BLACK)
            dc.fillEllipse(cx, mouthY - div(s * 4, 100) + div(mouth * 70, 100),
                           div(mouth * 55, 100), div(mouth * 30, 100))
        if self.mStage == STAGE_ADULT and self.mForm == FORM_WILD and face != FACE_SLEEP:
            dc.setColor(WHITE, BLACK)
            dc.fillPolygon([[cx + div(s * 6, 100), mouthY + div(s * 1, 100)],
                            [cx + div(s * 14, 100), mouthY + div(s * 1, 100)],
                            [cx + div(s * 10, 100), mouthY + div(s * 11, 100)]])

        if face == FACE_EFFORT:
            # One sweat drop that slides down the side of the head.
            dropX = cx + div(a * 78, 100)
            dropY = cy - div(b * 62, 100) + div(s * 6 * (frame % 4), 100)
            drop = div(s * 8, 100)
            dc.setColor(0x7FD4FF, BLACK)
            dc.fillCircle(dropX, dropY, drop)
            dc.fillPolygon([[dropX - drop, dropY], [dropX, dropY - div(drop * 24, 10)],
                            [dropX + drop, dropY]])

    def drawZ(self, dc, x, y, s, frame):
        rise = div(s * (frame % 12), 12)
        dc.setColor(0x9FB4C8, BLACK)
        dc.drawText(x + div(s * 14, 100), y - div(rise, 2), FONT_XTINY, "z", JUST_CENTER)
        dc.drawText(x + div(s * 44, 100), y - div(s * 36, 100) - div(rise, 2),
                    FONT_TINY, "Z", JUST_CENTER)

    # crack 0 = whole egg; 1..3 = a growing crack; the egg rocks while it waits.
    def drawEgg(self, dc, cx, cy, s, crack):
        rock = BOB[self.mFrame % 12]
        cx = cx + div(s * rock * 3, 100)
        a = div(s * 82, 100)
        b = div(s * 108, 100)
        self.drawShadow(dc, cx, cy + b, s, s)
        dc.setColor(SHELL, BLACK)
        dc.fillEllipse(cx, cy, a, b)
        dc.fillEllipse(cx, cy + div(b * 18, 100), div(a * 106, 100), div(b * 82, 100))
        dc.setColor(self.bodyColor(), BLACK)
        dc.fillCircle(cx - div(a * 38, 100), cy - div(b * 30, 100), div(s * 14, 100))
        dc.fillCircle(cx + div(a * 44, 100), cy + div(b * 6, 100), div(s * 18, 100))
        dc.fillCircle(cx - div(a * 20, 100), cy + div(b * 52, 100), div(s * 16, 100))
        dc.fillCircle(cx + div(a * 16, 100), cy - div(b * 62, 100), div(s * 9, 100))
        dc.setColor(self.bellyColor(), BLACK)
        dc.fillEllipse(cx - div(a * 46, 100), cy - div(b * 58, 100),
                       div(s * 12, 100), div(s * 7, 100))
        if crack > 0:
            dc.setColor(INK, BLACK)
            dc.setPenWidth(4)
            y = cy - div(b * 10, 100)
            step = div(a * 30, 100)
            x = cx - step * crack
            tooth = div(s * 12, 100)
            i = 0
            while i < crack * 2:
                dy = tooth
                if (i % 2) == 1:
                    dy = -tooth
                dc.drawLine(x, y, x + step, y + dy)
                x = x + step
                y = y + dy
                i += 1

    # ---- small shared icons -------------------------------------------------
    def drawFlame(self, dc, x, y, size, lit):
        outer = FLAME_OUT
        inner = FLAME_IN
        if not lit:
            outer = 0x3A2A20
            inner = 0x3A2A20
        dc.setColor(outer, BLACK)
        dc.fillPolygon([[x - div(size * 50, 100), y + div(size * 30, 100)],
                        [x - div(size * 46, 100), y - div(size * 10, 100)],
                        [x - div(size * 10, 100), y - size],
                        [x + div(size * 8, 100), y - div(size * 40, 100)],
                        [x + div(size * 34, 100), y - div(size * 62, 100)],
                        [x + div(size * 50, 100), y + div(size * 26, 100)],
                        [x, y + div(size * 60, 100)]])
        dc.setColor(inner, BLACK)
        dc.fillPolygon([[x - div(size * 22, 100), y + div(size * 30, 100)],
                        [x, y - div(size * 24, 100)],
                        [x + div(size * 22, 100), y + div(size * 30, 100)],
                        [x, y + div(size * 52, 100)]])

    def drawHeart(self, dc, x, y, size):
        dc.setColor(0xFF6B6B, BLACK)
        dc.fillCircle(x - div(size, 2), y - div(size, 3), div(size, 2) + 1)
        dc.fillCircle(x + div(size, 2), y - div(size, 3), div(size, 2) + 1)
        dc.fillPolygon([[x - size - 1, y - div(size, 4)], [x + size + 1, y - div(size, 4)],
                        [x, y + size]])

    def drawSparkle(self, dc, x, y, size, color):
        dc.setColor(color, BLACK)
        thin = div(size * 28, 100)
        if thin < 1:
            thin = 1
        dc.fillPolygon([[x, y - size], [x + thin, y - thin], [x + size, y],
                        [x + thin, y + thin], [x, y + size], [x - thin, y + thin],
                        [x - size, y], [x - thin, y - thin]])

    def drawShield(self, dc, x, y, size, lit):
        color = 0x6EC1FF
        if not lit:
            color = 0x26323C
        dc.setColor(color, BLACK)
        dc.fillPolygon([[x - size, y - size], [x + size, y - size],
                        [x + size, y + div(size * 20, 100)], [x, y + size + div(size * 30, 100)],
                        [x - size, y + div(size * 20, 100)]])

    # Sky by mood weather (0 misty .. 3 radiant); night swaps the sun for a moon.
    def drawSky(self, dc, w, h, weather, night, frame):
        sunX = div(w * 22, 100)
        sunY = div(h * 21, 100)
        sunR = div(h * 40, 1000)
        if night:
            dc.setColor(0xDCE6F2, BLACK)
            dc.fillCircle(sunX, sunY, sunR)
            dc.setColor(BLACK, BLACK)
            dc.fillCircle(sunX + div(sunR * 45, 100), sunY - div(sunR * 25, 100), sunR)
            twinkle = frame % 12
            self.drawSparkle(dc, div(w * 80, 100), div(h * 17, 100),
                             4 + (1 if twinkle < 4 else 0), 0xDCE6F2)
            self.drawSparkle(dc, div(w * 73, 100), div(h * 27, 100),
                             3 + (1 if twinkle >= 8 else 0), 0x9FB4C8)
        elif weather >= 2:
            dc.setColor(0xF2D550, BLACK)
            dc.fillCircle(sunX, sunY, sunR)
            dc.setPenWidth(3)
            near = sunR + 5
            far = sunR + 11 + (2 if (frame % 6) < 3 else 0)
            diag = div(near * 71, 100)
            diagFar = div(far * 71, 100)
            dc.drawLine(sunX - far, sunY, sunX - near, sunY)
            dc.drawLine(sunX + near, sunY, sunX + far, sunY)
            dc.drawLine(sunX, sunY - far, sunX, sunY - near)
            dc.drawLine(sunX, sunY + near, sunX, sunY + far)
            dc.drawLine(sunX - diagFar, sunY - diagFar, sunX - diag, sunY - diag)
            dc.drawLine(sunX + diag, sunY - diag, sunX + diagFar, sunY - diagFar)
            dc.drawLine(sunX - diagFar, sunY + diagFar, sunX - diag, sunY + diag)
            dc.drawLine(sunX + diag, sunY + diag, sunX + diagFar, sunY + diagFar)
            if weather >= 3:
                twinkle = frame % 12
                self.drawSparkle(dc, div(w * 79, 100), div(h * 18, 100),
                                 5 + (2 if twinkle < 4 else 0), 0xFFF3B8)
                self.drawSparkle(dc, div(w * 85, 100), div(h * 31, 100),
                                 4 + (2 if twinkle >= 6 else 0), 0xFFF3B8)
                self.drawSparkle(dc, div(w * 14, 100), div(h * 36, 100),
                                 3 + (2 if (twinkle >= 3 and twinkle < 8) else 0), 0xFFF3B8)
        if weather == 1 and not night:
            self.drawCloud(dc, div(w * 24, 100), div(h * 22, 100), div(h * 30, 1000), 0x8FA6BC)
        if weather == 0 or (weather == 1 and not night):
            drift = (frame % 24)
            if drift > 12:
                drift = 24 - drift
            color = 0x6F8496
            if weather == 0:
                color = 0x55636F
            self.drawCloud(dc, div(w * 77, 100) + drift, div(h * 21, 100), div(h * 34, 1000), color)
        if weather == 0:
            dc.setColor(0x3A444C, BLACK)
            dc.fillRoundedRectangle(div(w * 9, 100), div(h * 38, 100), div(w * 16, 100), 6, 3)
            dc.fillRoundedRectangle(div(w * 76, 100), div(h * 34, 100), div(w * 15, 100), 6, 3)
            dc.fillRoundedRectangle(div(w * 13, 100), div(h * 45, 100), div(w * 11, 100), 6, 3)

    def drawCloud(self, dc, x, y, r, color):
        dc.setColor(color, BLACK)
        dc.fillCircle(x - r, y + div(r * 30, 100), div(r * 80, 100))
        dc.fillCircle(x, y - div(r * 20, 100), r)
        dc.fillCircle(x + r, y + div(r * 30, 100), div(r * 80, 100))
        dc.fillRectangle(x - r, y + div(r * 30, 100), r * 2, div(r * 80, 100))


# ------------------------------------------------------------- view mirror
# FriendView mirrors the draw* functions of WristDiaryView.mc. The state the
# watch computes (pet, sensors, clock) is set directly on the object here.

C_ACCENT = 0x3E7A62
C_MINT = 0x6ED6A8
C_GOLD = 0xE8CF70
C_ORANGE = 0xFFB15C

(SCREEN_HOME, SCREEN_WALK, SCREEN_END_WALK, SCREEN_WALK_RESULT, SCREEN_EXPORT,
 SCREEN_TODAY, SCREEN_GROWTH, SCREEN_TRAIL, SCREEN_EGG, SCREEN_HATCHING, SCREEN_VOICE,
 SCREEN_REWARD, SCREEN_GREW, SCREEN_EVOLVE, SCREEN_EVOLVE_CONFIRM,
 SCREEN_EMBLEM) = range(16)

VOICE_NAMES = ["DRILL SGT", "CHEERLEADER", "DEADPAN", "ZEN"]
VOICE_SAMPLES = ["Sup. Let's go.", "You've got this!!", "Oh. We're doing this.",
                 "Whenever you're ready."]


class PetStub:
    """The slice of FriendPet the drawing code reads."""

    def __init__(self, **kw):
        self.alive = True
        self.xp_ = 372
        self.evos_ = 0
        self.form_ = FORM_ROUND
        self.pal = 0
        self.voice = 0
        self.memories_ = 18
        self.age = 15
        self.day_minutes = 22
        self.warm = 100
        self.shields_ = 0
        self.trail_m = 0
        self.trail_walks = 0
        self.owed_points = 0
        self.owed_flames = 2
        self.owed_seconds = 1290
        self.owed_flags = 1
        self.emblem_ = 1
        self.__dict__.update(kw)

    def emblem(self):
        return self.emblem_

    def exists(self):
        return self.alive

    def xp(self):
        return self.xp_

    def evos(self):
        return self.evos_

    def form(self):
        return self.form_

    def palette(self):
        return self.pal

    def persona(self):
        return self.voice

    def memories(self):
        return self.memories_

    def ageDays(self, now):
        return self.age

    def dayMinutes(self, now):
        return self.day_minutes

    def warmth(self, now):
        return self.warm

    def shields(self, now):
        return self.shields_

    def trailMeters(self):
        return self.trail_m

    def trailWalks(self):
        return self.trail_walks

    def owedPoints(self):
        return self.owed_points

    def owedFlames(self):
        return self.owed_flames

    def owedSeconds(self):
        return self.owed_seconds

    def owedFlags(self):
        return self.owed_flags

    def weather(self, mood):
        if mood >= 85:
            return 3
        if mood >= 70:
            return 2
        if mood >= 50:
            return 1
        return 0

    def bandThreshold(self, index):
        if index <= 0:
            return 0
        if index <= 9:
            return 60 * index * index + 40 * index
        return 5220 + (index - 9) * 1100

    def trailGoal(self):
        walked = self.trail_m
        if walked < 1000:
            return 1000
        if walked < 5000:
            return 5000
        if walked < 10000:
            return 10000
        if walked < 21097:
            return 21097
        if walked < 42195:
            return 42195
        return (div(walked, 50000) + 1) * 50000


class WalkStub:
    def __init__(self, **kw):
        self.recording = True
        self.failed = False
        self.saved = True
        self.seconds = 1285
        self.meters = 1102
        self.quality = "GOOD"
        self.__dict__.update(kw)

    def isRecording(self):
        return self.recording

    def isFailed(self):
        return self.failed

    def wasSaved(self):
        return self.saved

    def errorText(self):
        return "SAVE ERR"

    def qualityText(self):
        return self.quality

    def elapsed(self):
        return self.seconds

    def distanceMeters(self):
        return self.meters


class FriendView:
    APP_VERSION = "0.9.0"

    def __init__(self, **kw):
        self.mArt = FriendArt()
        self.mPet = PetStub()
        self.mWalk = WalkStub()
        self.mScreen = SCREEN_HOME
        self.mFrame = 0
        self.mMood = 78
        self.mBand = 2
        self.mEvoReady = False
        self.mPending = 0
        self.mPendingFlames = 0
        self.mHeartRate = 72
        self.mBaselineAvg = 67
        self.mChapterActive = False
        self.mPickPal = 0
        self.mPickVoice = 0
        self.mPickForm = FORM_ROUND
        self.mPickEmblem = 0
        self.mRepick = False
        self.mHatchFrame = 0
        self.mRewardExit = True
        self.mExported = False
        self.hour = 14
        self.clock = 0
        self.face = FACE_SUNNY
        self.pose = POSE_IDLE
        self.line = "Hey. Welcome."
        self.rewardLine = "Not bad."
        self.rr = "RR 228  96% VARY"
        self.__dict__.update(kw)

    # ---- helpers the watch has as real logic --------------------------------
    def homeFace(self):
        return self.face

    def homePose(self):
        return self.pose

    def homeLine(self):
        return self.line

    def hourNow(self):
        return self.hour

    def now(self):
        return self.clock

    def isNight(self):
        hour = self.hourNow()
        return hour >= 20 or hour < 6

    def heartDelta(self):
        return self.mHeartRate - self.mBaselineAvg

    def petStage(self):
        if self.mBand >= 3:
            return STAGE_ADULT
        if self.mBand >= 1:
            return STAGE_CHILD
        return STAGE_BABY

    def emblemLevel(self, warm):
        if warm >= 90:
            return 2
        if warm >= 70:
            return 1
        return 0

    def dressPet(self):
        self.mArt.setLook(self.petStage(), self.mBand, self.mPet.form(), self.mPet.evos(),
                          self.mPet.palette())
        self.mArt.setEmblem(self.mPet.emblem(), self.mEmblemLevel())

    def mEmblemLevel(self):
        return self.emblemLevel(self.mPet.warmth(self.now()))

    def walkTooShort(self):
        return self.mWalk.elapsed() < 60 and self.mWalk.distanceMeters() < 50

    def walkElapsedText(self):
        seconds = self.mWalk.elapsed()
        return "%02d:%02d" % (div(seconds, 60), seconds % 60)

    def walkDistanceText(self):
        return "%d m" % self.mWalk.distanceMeters()

    def chordWidth(self, dc, y, lineHeight):
        radius = div(dc.getWidth(), 2)
        top = abs(y - div(lineHeight, 2) - radius)
        bottom = abs(y + div(lineHeight, 2) - radius)
        far = top if top > bottom else bottom
        if far >= radius:
            return 0
        return int(math.sqrt(radius * radius - far * far) * 2) - 24

    def fitFont(self, dc, text, fonts, y):
        for font in fonts:
            if dc.getTextWidthInPixels(text, font) <= self.chordWidth(
                    dc, y, dc.getFontHeight(font)):
                return font
        return fonts[-1]

    def drawCenteredLine(self, dc, x, y, text, color, fonts):
        dc.setColor(color, BLACK)
        dc.drawText(x, y, self.fitFont(dc, text, fonts, y), text, JUST_CENTER)

    def drawStartHint(self, dc):
        center = div(dc.getWidth(), 2)
        dc.setColor(0x6ED6A8, BLACK)
        dc.setPenWidth(8)
        dc.drawArc(center, div(dc.getHeight(), 2), center - 6, ARC_CCW, 22, 42)

    # ---- words (same as the view) -------------------------------------------
    def bandName(self, band):
        names = ["HATCHLING", "SPROUT", "TRAINEE", "ATHLETE", "VETERAN", "ACE",
                 "LEGEND", "HERO", "MYTHIC"]
        if band < len(names):
            return names[band]
        return "MYTHIC " + str(band - 7)

    def unlockWords(self, band):
        if band == 1:
            return "leaf + flex"
        if band == 2:
            return "headband + spin"
        if band == 3:
            return "grown-up form"
        if band == 4:
            return "flames"
        if band == 5:
            return "cape"
        if band == 6:
            return "aura"
        return "bragging rights"

    def nextText(self, band):
        if (band % 3) == 0:
            return "next: evolution"
        return "next: " + self.unlockWords(band)

    def weatherName(self, weather):
        if weather >= 3:
            return "RADIANT"
        if weather == 2:
            return "SUNNY"
        if weather == 1:
            return "FAIR"
        return "MISTY"

    def energyName(self):
        hour = self.hourNow()
        if hour >= 23 or hour < 5:
            return "asleep"
        if hour >= 21:
            return "winding down"
        return "awake"

    def snackName(self, minutes):
        if minutes >= 30:
            return "FULL"
        if minutes > 0:
            return "SNACKED"
        return "PECKISH"

    def warmName(self, warm):
        if warm >= 90:
            return "IN THE ZONE"
        if warm >= 70:
            return "WARMED UP"
        if warm >= 40:
            return "LOOSE"
        return "RUSTY BUT FINE"

    def paletteName(self, pal):
        return PALETTE_NAMES[pal % len(PALETTE_NAMES)]

    def formName(self, form):
        if form == FORM_SLEEK:
            return "SLEEK"
        if form == FORM_WILD:
            return "WILD"
        return "ROUND"

    def goalName(self, goal):
        if goal == 1000:
            return "first km"
        if goal == 5000:
            return "5 km picnic"
        if goal == 10000:
            return "10 km ridge"
        if goal == 21097:
            return "half marathon"
        if goal == 42195:
            return "marathon"
        return str(div(goal, 1000)) + " km club"

    def kmText(self, meters):
        return str(div(meters, 1000)) + "." + str(div(meters % 1000, 100)) + " km"

    def petDebugText(self):
        if not self.mPet.exists():
            return "NO PET YET"
        return "XP " + str(self.mPet.xp()) + "  B" + str(self.mBand) + "  M" + str(self.mMood)

    def rewardDetail(self, hatch):
        if hatch:
            return str(self.mPet.memories()) + " memories"
        if self.mEvoReady:
            return "ready to evolve!"
        minutes = div(self.mPet.owedSeconds() + 30, 60)
        if minutes < 1:
            minutes = 1
        text = str(minutes) + " min"
        if (self.mPet.owedFlags() % 2) == 1:
            text += "  first today"
        return text

    # ---- mirrored drawing ---------------------------------------------------
    def onUpdate(self, dc):
        dc.clear()
        screen = self.mScreen
        if screen == SCREEN_WALK:
            self.drawWalkScreen(dc)
        elif screen == SCREEN_END_WALK:
            self.drawEndWalkScreen(dc)
        elif screen == SCREEN_WALK_RESULT:
            self.drawWalkResultScreen(dc)
        elif screen == SCREEN_EXPORT:
            self.drawExportScreen(dc)
        elif screen == SCREEN_EGG or screen == SCREEN_HATCHING:
            self.drawEggScreen(dc)
        elif screen == SCREEN_VOICE:
            self.drawVoiceScreen(dc)
        elif screen == SCREEN_EMBLEM:
            self.drawEmblemScreen(dc)
        elif screen == SCREEN_REWARD:
            self.drawReward(dc)
        elif screen == SCREEN_GREW:
            self.drawGrew(dc)
        elif screen == SCREEN_EVOLVE or screen == SCREEN_EVOLVE_CONFIRM:
            self.drawEvolveScreen(dc)
        elif screen == SCREEN_TODAY:
            self.drawToday(dc)
        elif screen == SCREEN_GROWTH:
            self.drawGrowth(dc)
        elif screen == SCREEN_TRAIL:
            self.drawTrail(dc)
        else:
            self.drawHome(dc)

    def drawPet(self, dc, x, footY, percent, face, pose):
        height = dc.getHeight()
        if not self.mPet.exists():
            self.mArt.setLook(STAGE_EGG, 0, 0, 0, self.mPickPal)
            self.mArt.setPose(face, pose, self.mFrame)
            eggSize = div(self.mArt.sizeFor(STAGE_EGG, height) * percent, 100)
            self.mArt.drawEgg(dc, x, footY - div(eggSize * 108, 100), eggSize, 0)
            return
        self.dressPet()
        self.mArt.setPose(face, pose, self.mFrame)
        self.mArt.drawStanding(dc, x, footY, percent)

    def drawHome(self, dc):
        height = dc.getHeight()
        width = dc.getWidth()
        centerX = div(width, 2)

        self.drawCenteredLine(dc, centerX, div(height * 9, 100), "FRIEND " + self.APP_VERSION,
                              C_ACCENT, [FONT_XTINY])
        self.mArt.drawSky(dc, width, height, self.mPet.weather(self.mMood), self.isNight(),
                          self.mFrame)
        self.drawPet(dc, centerX, div(height * 54, 100), 100, self.homeFace(), self.homePose())

        self.drawCenteredLine(dc, centerX, div(height * 63, 100), self.homeLine(), WHITE,
                              [FONT_SMALL, FONT_TINY, FONT_XTINY])
        self.drawPulseRow(dc, centerX, div(height * 72, 100))
        self.drawXpBar(dc, centerX - div(width * 24, 100), div(height * 78, 100),
                       div(width * 48, 100), 10, self.mPet.xp(), self.mPending, self.mBand)
        info = self.bandName(self.mBand) + "  " + str(self.mPet.xp() + self.mPending) + "/" + \
            str(self.mPet.bandThreshold(self.mBand + 1))
        self.drawCenteredLine(dc, centerX, div(height * 85, 100), info, LT_GRAY, [FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 92, 100), "START walk", DK_GRAY,
                              [FONT_XTINY])
        self.drawStartHint(dc)

    def drawPulseRow(self, dc, centerX, y):
        text = str(self.mHeartRate) if self.mHeartRate >= 0 else "--"
        lit = self.mPendingFlames if self.mChapterActive else 0
        tail = ""
        if lit > 0:
            tail = "+" + str(self.mPending)
        elif self.mHeartRate >= 0 and self.mBaselineAvg >= 0:
            delta = self.heartDelta()
            tail = ("+" + str(delta)) if delta >= 0 else ("" + str(delta))
        font = FONT_TINY
        size = div(dc.getFontHeight(font) * 30, 100)
        flame = div(dc.getFontHeight(font) * 34, 100)
        textWidth = dc.getTextWidthInPixels(text, font)
        tailWidth = dc.getTextWidthInPixels(tail, font)
        total = size * 3 + textWidth + 14 + lit * (flame + 6) + tailWidth
        x = centerX - div(total, 2)
        self.mArt.drawHeart(dc, x + size, y, size)
        x = x + size * 3
        dc.setColor(LT_GRAY, BLACK)
        dc.drawText(x, y, font, text, JUST_LEFT)
        x = x + textWidth + 14
        i = 0
        while i < lit:
            self.mArt.drawFlame(dc, x + div(flame, 2), y, flame, True)
            x = x + flame + 6
            i += 1
        dc.setColor(C_GOLD if lit > 0 else LT_GRAY, BLACK)
        dc.drawText(x, y, font, tail, JUST_LEFT)

    def drawXpBar(self, dc, x, y, width, height, xp, pending, band):
        low = self.mPet.bandThreshold(band)
        span = self.mPet.bandThreshold(band + 1) - low
        done = xp - low
        if done < 0:
            done = 0
        if done > span:
            done = span
        filled = div(width * done, span)
        extra = div(width * pending, span)
        if filled + extra > width:
            extra = width - filled
        if filled > 0 and filled < height:
            filled = height
        if extra > 0 and filled + extra < height:
            extra = height - filled
        dc.setColor(0x1E2A26, BLACK)
        dc.fillRoundedRectangle(x, y, width, height, div(height, 2))
        if extra > 0:
            dc.setColor(C_GOLD, BLACK)
            dc.fillRoundedRectangle(x, y, filled + extra, height, div(height, 2))
        if filled > 0:
            dc.setColor(self.mArt.bodyColor(), BLACK)
            dc.fillRoundedRectangle(x, y, filled, height, div(height, 2))

    def drawMeter(self, dc, x, y, width, height, value, full, backColor, fillColor):
        dc.setColor(backColor, BLACK)
        dc.fillRoundedRectangle(x, y, width, height, div(height, 2))
        filled = div(width * value, full)
        if filled > width:
            filled = width
        if filled > 0 and filled < height:
            filled = height
        if filled > 0:
            dc.setColor(fillColor, BLACK)
            dc.fillRoundedRectangle(x, y, filled, height, div(height, 2))

    def drawToday(self, dc):
        height = dc.getHeight()
        width = dc.getWidth()
        centerX = div(width, 2)
        now = self.now()
        weather = self.mPet.weather(self.mMood)
        self.drawCenteredLine(dc, centerX, div(height * 10, 100), "TODAY", C_ACCENT,
                              [FONT_XTINY])
        self.mArt.drawSky(dc, width, height, 1 if weather < 1 else weather, self.isNight(), 0)
        self.drawCenteredLine(dc, centerX, div(height * 23, 100), self.weatherName(weather),
                              WHITE, [FONT_MEDIUM, FONT_SMALL])
        self.drawCenteredLine(dc, centerX, div(height * 33, 100),
                              "mood " + str(self.mMood) + "   " + self.energyName(),
                              LT_GRAY, [FONT_XTINY])

        minutes = self.mPet.dayMinutes(now)
        self.drawCenteredLine(dc, centerX, div(height * 45, 100), self.snackName(minutes),
                              C_ORANGE, [FONT_SMALL, FONT_TINY])
        barWidth = div(width * 44, 100)
        self.drawMeter(dc, centerX - div(barWidth, 2), div(height * 51, 100), barWidth, 8,
                       minutes, 30, 0x2A2018, C_ORANGE)
        self.drawCenteredLine(dc, centerX, div(height * 58, 100),
                              "" + str(minutes) + " of 30 effort min", LT_GRAY, [FONT_XTINY])

        self.drawCenteredLine(dc, centerX, div(height * 70, 100),
                              self.warmName(self.mPet.warmth(now)), C_GOLD,
                              [FONT_SMALL, FONT_TINY])
        held = self.mPet.shields(now)
        self.mArt.drawShield(dc, centerX - 16, div(height * 79, 100), 9, held >= 1)
        self.mArt.drawShield(dc, centerX + 16, div(height * 79, 100), 9, held >= 2)
        self.drawCenteredLine(dc, centerX, div(height * 88, 100), "rest-day shields", DK_GRAY,
                              [FONT_XTINY])

    def drawGrowth(self, dc):
        height = dc.getHeight()
        width = dc.getWidth()
        centerX = div(width, 2)
        toGo = self.mPet.bandThreshold(self.mBand + 1) - self.mPet.xp()
        self.drawCenteredLine(dc, centerX, div(height * 10, 100), "GROWING", C_ACCENT,
                              [FONT_XTINY])
        self.drawPet(dc, centerX, div(height * 37, 100), 62, FACE_SUNNY, POSE_IDLE)
        self.drawCenteredLine(dc, centerX, div(height * 46, 100), self.bandName(self.mBand),
                              WHITE, [FONT_MEDIUM, FONT_SMALL])
        self.drawXpBar(dc, centerX - div(width * 30, 100), div(height * 54, 100),
                       div(width * 60, 100), 12, self.mPet.xp(), 0, self.mBand)
        self.drawCenteredLine(dc, centerX, div(height * 63, 100),
                              ("" + str(toGo) + " XP to " + self.bandName(self.mBand + 1))
                              if toGo > 0 else "enough to evolve",
                              LT_GRAY, [FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 73, 100), self.nextText(self.mBand + 1),
                              C_GOLD, [FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 82, 100),
                              "" + str(self.mPet.memories()) + " memories", LT_GRAY,
                              [FONT_XTINY])
        if self.mEvoReady:
            self.drawCenteredLine(dc, centerX, div(height * 90, 100), "START evolve", C_MINT,
                                  [FONT_XTINY])
            self.drawStartHint(dc)
        else:
            self.drawCenteredLine(dc, centerX, div(height * 90, 100),
                                  "day " + str(self.mPet.ageDays(self.now())), DK_GRAY, [FONT_XTINY])

    def drawTrail(self, dc):
        height = dc.getHeight()
        width = dc.getWidth()
        centerX = div(width, 2)
        meters = self.mPet.trailMeters()
        walks = self.mPet.trailWalks()
        goal = self.mPet.trailGoal()
        self.dressPet()
        self.drawCenteredLine(dc, centerX, div(height * 11, 100), "OUR TRAIL", C_ACCENT,
                              [FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 26, 100), self.kmText(meters), WHITE,
                              [FONT_LARGE, FONT_MEDIUM])
        self.drawCenteredLine(dc, centerX, div(height * 38, 100),
                              "1 walk together" if walks == 1
                              else ("" + str(walks) + " walks together"),
                              LT_GRAY, [FONT_XTINY])

        left = centerX - div(width * 30, 100)
        span = div(width * 60, 100)
        y = div(height * 56, 100)
        reached = div(12 * meters, goal)
        i = 0
        while i <= 12:
            x = left + div(span * i, 12)
            dotY = y + (-3 if (i % 4) < 2 else 3)
            if i <= reached:
                dc.setColor(self.mArt.bodyColor(), BLACK)
                dc.fillCircle(x, dotY, 5)
            else:
                dc.setColor(0x33403A, BLACK)
                dc.fillCircle(x, dotY, 3)
            i += 1
        flagX = left + span
        dc.setColor(LT_GRAY, BLACK)
        dc.setPenWidth(3)
        dc.drawLine(flagX, y - 30, flagX, y)
        dc.setColor(C_GOLD, BLACK)
        dc.fillPolygon([[flagX, y - 30], [flagX + 20, y - 23], [flagX, y - 16]])

        self.drawCenteredLine(dc, centerX, div(height * 70, 100),
                              "next: " + self.goalName(goal), C_GOLD, [FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 80, 100),
                              self.kmText(goal - meters) + " to go", LT_GRAY, [FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 90, 100), "START walk", DK_GRAY,
                              [FONT_XTINY])
        self.drawStartHint(dc)

    def drawReward(self, dc):
        height = dc.getHeight()
        width = dc.getWidth()
        centerX = div(width, 2)
        points = self.mPet.owedPoints()
        lit = self.mPet.owedFlames()
        hatch = (lit == 0)
        title = "LAST TIME"
        if hatch:
            title = "HATCHED!"
        elif self.mRewardExit:
            title = "EFFORT SNACK"
        self.drawCenteredLine(dc, centerX, div(height * 9, 100), title, C_ACCENT, [FONT_XTINY])
        self.drawPet(dc, centerX, div(height * 43, 100), 66, FACE_JOY, POSE_HOP)
        self.drawCenteredLine(dc, centerX, div(height * 55, 100), "+" + str(points) + " XP",
                              C_GOLD, [FONT_LARGE, FONT_MEDIUM])
        rowY = div(height * 66, 100)
        if hatch:
            self.mArt.drawSparkle(dc, centerX - 44, rowY, 8, 0xFFF3B8)
            self.mArt.drawSparkle(dc, centerX, rowY, 11, 0xFFF3B8)
            self.mArt.drawSparkle(dc, centerX + 44, rowY, 8, 0xFFF3B8)
        else:
            flame = 26
            x = centerX - div(3 * flame + 2 * 10, 2) + div(flame, 2)
            i = 0
            while i < 3:
                self.mArt.drawFlame(dc, x, rowY, flame, i < lit)
                x = x + flame + 10
                i += 1
        self.drawCenteredLine(dc, centerX, div(height * 75, 100),
                              "I heard it all." if hatch else self.rewardLine,
                              WHITE, [FONT_TINY, FONT_XTINY])
        self.drawXpBar(dc, centerX - div(width * 22, 100), div(height * 81, 100),
                       div(width * 44, 100), 10, self.mPet.xp() - points, points, self.mBand)
        self.drawCenteredLine(dc, centerX, div(height * 89, 100), self.rewardDetail(hatch),
                              LT_GRAY, [FONT_XTINY])
        self.drawStartHint(dc)

    def drawGrew(self, dc):
        height = dc.getHeight()
        width = dc.getWidth()
        centerX = div(width, 2)
        self.drawCenteredLine(dc, centerX, div(height * 10, 100), "GREW UP!", C_GOLD,
                              [FONT_TINY])
        self.mArt.drawSparkle(dc, div(width * 20, 100), div(height * 26, 100), 9, 0xFFF3B8)
        self.mArt.drawSparkle(dc, div(width * 82, 100), div(height * 32, 100), 7, 0xFFF3B8)
        self.mArt.drawSparkle(dc, div(width * 76, 100), div(height * 17, 100), 5, 0xFFF3B8)
        self.drawPet(dc, centerX, div(height * 53, 100), 82, FACE_RADIANT,
                     POSE_FLEX if self.mBand >= 1 else POSE_HOP)
        self.drawCenteredLine(dc, centerX, div(height * 64, 100), self.bandName(self.mBand),
                              WHITE, [FONT_LARGE, FONT_MEDIUM, FONT_SMALL])
        self.drawCenteredLine(dc, centerX, div(height * 75, 100),
                              "new: " + self.unlockWords(self.mBand), C_GOLD,
                              [FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 86, 100), "START ok", DK_GRAY,
                              [FONT_XTINY])
        self.drawStartHint(dc)

    def drawEggScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        hatching = (self.mScreen == SCREEN_HATCHING)
        title = "AN EGG!"
        if hatching:
            title = "IT'S HATCHING!"
        elif self.mRepick:
            title = "NEW LOOK"
        crack = 0
        if hatching:
            crack = div(self.mFrame - self.mHatchFrame, 4) + 1
            if crack > 3:
                crack = 3
        self.mArt.setLook(STAGE_EGG, 0, 0, 0, self.mPickPal)
        self.mArt.setPose(FACE_FAIR, POSE_IDLE, self.mFrame)
        size = self.mArt.sizeFor(STAGE_EGG, height)
        self.drawCenteredLine(dc, centerX, div(height * 11, 100), title, C_GOLD, [FONT_TINY])
        self.mArt.drawEgg(dc, centerX, div(height * 56, 100) - div(size * 108, 100), size, crack)
        self.drawCenteredLine(dc, centerX, div(height * 67, 100),
                              self.paletteName(self.mPickPal), self.mArt.bodyColor(),
                              [FONT_SMALL, FONT_TINY])
        if not hatching:
            self.drawCenteredLine(dc, centerX, div(height * 77, 100), "UP/DOWN color", LT_GRAY,
                                  [FONT_XTINY])
            self.drawCenteredLine(dc, centerX, div(height * 86, 100),
                                  "START next" if self.mRepick else "START hatch", C_MINT,
                                  [FONT_TINY, FONT_XTINY])
            self.drawStartHint(dc)

    def drawVoiceScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        stage = STAGE_BABY
        if self.mRepick:
            stage = self.petStage()
            self.mArt.setLook(stage, self.mBand, self.mPet.form(), self.mPet.evos(),
                              self.mPickPal)
            self.mArt.setEmblem(self.mPet.emblem(), self.mEmblemLevel())
        else:
            self.mArt.setLook(stage, 0, 0, 0, self.mPickPal)
        self.mArt.setPose(FACE_SUNNY, POSE_IDLE, self.mFrame)
        self.drawCenteredLine(dc, centerX, div(height * 10, 100), "HOW DO I TALK?", C_GOLD,
                              [FONT_XTINY])
        self.mArt.drawStanding(dc, centerX, div(height * 40, 100), 62 if self.mRepick else 80)
        self.drawCenteredLine(dc, centerX, div(height * 51, 100), VOICE_NAMES[self.mPickVoice],
                              WHITE, [FONT_MEDIUM, FONT_SMALL])
        self.drawCenteredLine(dc, centerX, div(height * 62, 100),
                              VOICE_SAMPLES[self.mPickVoice], C_MINT, [FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 75, 100), "UP/DOWN voice", LT_GRAY,
                              [FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 85, 100),
                              "START next" if (self.mRepick and self.mBand >= 1)
                              else "START keep", C_MINT, [FONT_TINY, FONT_XTINY])
        self.drawStartHint(dc)

    def drawEmblemScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        self.mArt.setLook(self.petStage(), self.mBand, self.mPet.form(), self.mPet.evos(),
                          self.mPickPal)
        self.mArt.setEmblem(self.mPickEmblem, 1)
        self.mArt.setPose(FACE_SUNNY, POSE_IDLE, self.mFrame)
        self.drawCenteredLine(dc, centerX, div(height * 10, 100), "BELLY MARK", C_GOLD,
                              [FONT_XTINY])
        self.mArt.drawStanding(dc, centerX, div(height * 52, 100), 100)
        self.drawCenteredLine(dc, centerX, div(height * 62, 100),
                              self.emblemName(self.mPickEmblem), WHITE,
                              [FONT_MEDIUM, FONT_SMALL])
        self.drawCenteredLine(dc, centerX, div(height * 74, 100), "UP/DOWN mark", LT_GRAY,
                              [FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 84, 100), "START keep", C_MINT,
                              [FONT_TINY, FONT_XTINY])
        self.drawStartHint(dc)

    def emblemName(self, emblem):
        if emblem < 1 or emblem > FRIEND_EMBLEMS:
            return "BARE"
        return friendEmblemNames()[emblem - 1]

    def drawEvolveScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        confirm = (self.mScreen == SCREEN_EVOLVE_CONFIRM)
        self.mArt.setLook(STAGE_ADULT, self.mBand + 1, self.mPickForm, self.mPet.evos() + 1,
                          self.mPet.palette())
        self.mArt.setEmblem(self.mPet.emblem(), self.mEmblemLevel())
        self.mArt.setPose(FACE_SUNNY, POSE_IDLE, self.mFrame)
        self.drawCenteredLine(dc, centerX, div(height * 10, 100),
                              "KEEP FOREVER?" if confirm else "WHO WILL I BE?", C_GOLD,
                              [FONT_XTINY])
        self.mArt.drawStanding(dc, centerX, div(height * 53, 100), 82)
        self.drawCenteredLine(dc, centerX, div(height * 61, 100), self.formName(self.mPickForm),
                              WHITE, [FONT_MEDIUM, FONT_SMALL])
        if confirm:
            self.drawCenteredLine(dc, centerX, div(height * 73, 100), "START yes", C_MINT,
                                  [FONT_TINY])
            self.drawCenteredLine(dc, centerX, div(height * 83, 100), "BACK look again", LT_GRAY,
                                  [FONT_XTINY])
        else:
            self.drawCenteredLine(dc, centerX, div(height * 73, 100), "UP/DOWN look", LT_GRAY,
                                  [FONT_XTINY])
            self.drawCenteredLine(dc, centerX, div(height * 83, 100), "START choose", C_MINT,
                                  [FONT_TINY, FONT_XTINY])
        self.drawStartHint(dc)

    def drawWalkScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        recording = self.mWalk.isRecording()

        self.drawCenteredLine(dc, centerX, div(height * 10, 100), "FRIEND WALK", C_ACCENT,
                              [FONT_XTINY])
        self.drawPet(dc, centerX, div(height * 35, 100), 45,
                     FACE_EFFORT if recording else FACE_SUNNY,
                     POSE_RUN if recording else POSE_IDLE)
        self.drawCenteredLine(dc, centerX, div(height * 43, 100),
                              self.line if recording else "READY TO WALK",
                              0xFFB15C if recording else 0x6ED6A8,
                              [FONT_MEDIUM, FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 55, 100),
                              "GPS " + self.mWalk.qualityText(), LT_GRAY,
                              [FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 67, 100), self.walkElapsedText(), WHITE,
                              [FONT_NUMBER_MILD, FONT_MEDIUM])

        hr = str(self.mHeartRate) if self.mHeartRate > 0 else "--"
        self.drawCenteredLine(dc, centerX, div(height * 79, 100),
                              self.walkDistanceText() + "   HR " + hr, LT_GRAY,
                              [FONT_SMALL, FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 89, 100),
                              "START finish" if recording else "START walk   BACK cancel",
                              LT_GRAY, [FONT_XTINY])
        self.drawStartHint(dc)

    def drawEndWalkScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        tooShort = self.walkTooShort()
        self.drawCenteredLine(dc, centerX, div(height * 12, 100), "FRIEND WALK", C_ACCENT,
                              [FONT_XTINY])
        self.drawPet(dc, centerX, div(height * 43, 100), 62, FACE_EFFORT, POSE_IDLE)
        self.drawCenteredLine(dc, centerX, div(height * 53, 100), "END WALK?", WHITE,
                              [FONT_MEDIUM, FONT_SMALL])
        self.drawCenteredLine(dc, centerX, div(height * 66, 100),
                              "too short to keep" if tooShort else "recording continues",
                              C_GOLD, [FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 80, 100),
                              "START drop it" if tooShort else "START save", C_MINT,
                              [FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 90, 100),
                              "BACK keep walking" if tooShort else "BACK resume",
                              LT_GRAY, [FONT_XTINY])
        self.drawStartHint(dc)

    def drawWalkResultScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        failed = self.mWalk.isFailed()
        kept = self.mWalk.wasSaved()
        headline = "WE WALKED"
        detail = "ACTIVITY SAVED"
        if failed:
            headline = "WALK FAILED"
            detail = self.mWalk.errorText()
        elif not kept:
            headline = "NO WALK KEPT"
            detail = "too short"
        elif self.mPet.exists():
            detail = "SAVED   TRAIL " + self.kmText(self.mPet.trailMeters())
        self.drawCenteredLine(dc, centerX, div(height * 12, 100), "FRIEND WALK", C_ACCENT,
                              [FONT_XTINY])
        self.drawPet(dc, centerX, div(height * 43, 100), 62,
                     FACE_FAIR if (failed or not kept) else FACE_JOY,
                     POSE_IDLE if (failed or not kept) else POSE_HOP)
        self.drawCenteredLine(dc, centerX, div(height * 53, 100), headline,
                              0xFF6060 if failed else C_GOLD,
                              [FONT_MEDIUM, FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 66, 100),
                              self.walkElapsedText() + "   " + self.walkDistanceText(), WHITE,
                              [FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 78, 100), detail, LT_GRAY,
                              [FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 90, 100), "START home", LT_GRAY,
                              [FONT_XTINY])
        self.drawStartHint(dc)

    def drawExportScreen(self, dc):
        height = dc.getHeight()
        centerX = div(dc.getWidth(), 2)
        exported = self.mExported
        self.drawCenteredLine(dc, centerX, div(height * 11, 100), "FRIEND " + self.APP_VERSION,
                              C_ACCENT, [FONT_XTINY])
        self.drawPet(dc, centerX, div(height * 37, 100), 55, FACE_FAIR, POSE_IDLE)
        self.drawCenteredLine(dc, centerX, div(height * 46, 100), "DEBUG DATA", WHITE,
                              [FONT_MEDIUM, FONT_SMALL])
        self.drawCenteredLine(dc, centerX, div(height * 56, 100), self.rr, LT_GRAY,
                              [FONT_SMALL, FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 65, 100), self.petDebugText(), LT_GRAY,
                              [FONT_TINY, FONT_XTINY])
        self.drawCenteredLine(dc, centerX, div(height * 76, 100),
                              "EXPORTED" if exported else "START export",
                              C_MINT if exported else LT_GRAY, [FONT_SMALL, FONT_TINY])
        self.drawCenteredLine(dc, centerX, div(height * 87, 100),
                              "MENU new look" if self.mPet.exists() else "BACK egg", DK_GRAY,
                              [FONT_XTINY])
        self.drawStartHint(dc)


# ---------------------------------------------------------------- sheets

def render(**state):
    view = FriendView(**state)
    dc = Dc()
    view.onUpdate(dc)
    return dc.finish()


def sheet(cells, columns, path):
    cell = 416
    label = 30
    rows = (len(cells) + columns - 1) // columns
    out = Image.new("RGB", (columns * cell, rows * (cell + label)), (24, 24, 28))
    d = ImageDraw.Draw(out)
    font = load_font(20)
    for i, (title, img) in enumerate(cells):
        x = (i % columns) * cell
        y = (i // columns) * (cell + label)
        out.paste(img, (x, y))
        d.text((x + cell // 2, y + cell + label // 2), title, font=font,
               fill=(200, 200, 200), anchor="mm")
    out.save(path)
    print("[wrote]", path)


def band_xp(band, extra=40):
    return PetStub().bandThreshold(band) + extra


def write_sheets(out):
    os.makedirs(out, exist_ok=True)

    # 1. The friend itself: every stage and evolved form.
    cells = []
    for title, band, form, evos, face in [
            ("hatchling (band 0)", 0, FORM_ROUND, 0, FACE_FAIR),
            ("sprout (band 1): leaf", 1, FORM_ROUND, 0, FACE_SUNNY),
            ("trainee (band 2)", 2, FORM_ROUND, 0, FACE_SUNNY),
            ("athlete (band 3), sleek", 3, FORM_SLEEK, 1, FACE_SUNNY),
            ("athlete (band 3), round", 3, FORM_ROUND, 1, FACE_SUNNY),
            ("athlete (band 3), wild", 3, FORM_WILD, 1, FACE_SUNNY),
            ("ace (band 5)", 5, FORM_ROUND, 1, FACE_RADIANT),
            ("legend (band 6): aura", 6, FORM_SLEEK, 2, FACE_RADIANT)]:
        cells.append((title, render(
            mBand=band, face=face, line="I'm here.",
            mMood=90 if face == FACE_RADIANT else 78,
            mPet=PetStub(xp_=band_xp(band), form_=form, evos_=evos))))
    sheet(cells, 4, os.path.join(out, "1-stages.png"))

    # 2. Home: the pet this watch's own chapters hatch (band 2, 372 XP).
    cells = [
        ("mood: misty", render(mMood=42, face=FACE_MISTY, line="Still here.")),
        ("mood: fair", render(mMood=60, face=FACE_FAIR, line="Oh. It's you.")),
        ("mood: sunny", render(mMood=78, face=FACE_SUNNY, line="Hey. Welcome.")),
        ("mood: radiant", render(mMood=92, face=FACE_RADIANT, line="Hi hi hi!")),
        ("in a chapter, steady", render(
            face=FACE_EFFORT, pose=POSE_RUN, line="Now we're working.", mHeartRate=108,
            mChapterActive=True, mPendingFlames=2, mPending=23, mFrame=1)),
        ("in a chapter, hard", render(
            mMood=92, face=FACE_EFFORT, pose=POSE_RUN, line="Heart says work.",
            mHeartRate=142, mChapterActive=True, mPendingFlames=3, mPending=41, mFrame=2)),
        ("asleep at night", render(
            mMood=60, face=FACE_SLEEP, pose=POSE_SLEEP, line="zzz", hour=23, mFrame=5)),
        ("chapter just closed", render(
            face=FACE_JOY, pose=POSE_HOP, line="+37 XP", mFrame=3,
            mPet=PetStub(xp_=409))),
    ]
    sheet(cells, 4, os.path.join(out, "2-home.png"))

    # 3. Emotes (a tap pets the friend) and the run cycle.
    cells = []
    for title, pose, face, band, frames in [
            ("hop", POSE_HOP, FACE_JOY, 2, [1, 3]),
            ("flex (band 1)", POSE_FLEX, FACE_JOY, 2, [1, 3]),
            ("spin (band 2)", POSE_SPIN, FACE_JOY, 2, [1, 2]),
            ("flames (band 4)", POSE_FLAMES, FACE_JOY, 4, [0, 1]),
            ("run", POSE_RUN, FACE_EFFORT, 2, [0, 2])]:
        for f in frames:
            cells.append((title + ", frame " + str(f), render(
                mBand=band, face=face, pose=pose, mFrame=f, line="Hehe!! Again!",
                mPet=PetStub(xp_=band_xp(band), evos_=1 if band >= 3 else 0, voice=1))))
    sheet(cells, 5, os.path.join(out, "3-emotes.png"))

    # 4. The card stack (Up/Down from home).
    cells = [
        ("card: today", render(mScreen=SCREEN_TODAY, mPet=PetStub(shields_=1))),
        ("card: today, a quiet day", render(
            mScreen=SCREEN_TODAY, mMood=48, hour=22,
            mPet=PetStub(day_minutes=0, warm=52, shields_=2))),
        ("card: growing", render(mScreen=SCREEN_GROWTH)),
        ("card: growing, ready", render(
            mScreen=SCREEN_GROWTH, mEvoReady=True, mPet=PetStub(xp_=702))),
        ("card: our trail", render(
            mScreen=SCREEN_TRAIL, mPet=PetStub(trail_m=1102, trail_walks=1))),
        ("card: debug data", render(mScreen=SCREEN_EXPORT)),
    ]
    sheet(cells, 3, os.path.join(out, "4-cards.png"))

    # 5. Rewards.
    cells = [
        ("Back after a session", render(
            mScreen=SCREEN_REWARD, mFrame=3, rewardLine="Not bad.",
            mPet=PetStub(xp_=409, owed_points=37, owed_flames=2))),
        ("a hard one", render(
            mScreen=SCREEN_REWARD, mFrame=2, rewardLine="Fine. That was good.",
            mPet=PetStub(xp_=426, owed_points=54, owed_flames=3, owed_seconds=2340))),
        ("second session of a day", render(
            mScreen=SCREEN_REWARD, mFrame=1, rewardLine="Counts. Barely.",
            mPet=PetStub(xp_=377, owed_points=5, owed_flames=1, owed_seconds=1240,
                         owed_flags=0))),
        ("seen at the next open", render(
            mScreen=SCREEN_REWARD, mRewardExit=False, mFrame=4, rewardLine="Not bad.",
            mPet=PetStub(xp_=409, owed_points=37, owed_flames=2))),
        ("grew up", render(mScreen=SCREEN_GREW, mMood=92, mFrame=3)),
        ("hatch: it remembers", render(
            mScreen=SCREEN_REWARD, mFrame=3,
            mPet=PetStub(owed_points=372, owed_flames=0))),
    ]
    sheet(cells, 3, os.path.join(out, "5-rewards.png"))

    # 6. First run, and the evolution choice.
    egg = PetStub(alive=False)
    cells = [
        ("first open: an egg", render(mScreen=SCREEN_EGG, mPet=egg)),
        ("Up/Down: color", render(mScreen=SCREEN_EGG, mPet=egg, mPickPal=3, mFrame=3)),
        ("START: hatching", render(
            mScreen=SCREEN_HATCHING, mPet=egg, mPickPal=1, mFrame=9)),
        ("voice pick", render(mScreen=SCREEN_VOICE, mPet=egg, mPickPal=1, mPickVoice=2)),
        ("evolve: sleek", render(mScreen=SCREEN_EVOLVE, mPickForm=FORM_SLEEK)),
        ("evolve: round", render(mScreen=SCREEN_EVOLVE, mPickForm=FORM_ROUND)),
        ("evolve: wild", render(mScreen=SCREEN_EVOLVE, mPickForm=FORM_WILD)),
        ("evolve: confirm", render(mScreen=SCREEN_EVOLVE_CONFIRM, mPickForm=FORM_WILD)),
    ]
    sheet(cells, 4, os.path.join(out, "6-first-run.png"))

    # 7. Colorways, and Friend Walk with the friend in it.
    cells = []
    for pal in range(len(PALETTES)):
        cells.append((PALETTE_NAMES[pal].lower(), render(mPet=PetStub(pal=pal), line="Hi!")))
    sheet(cells, 6, os.path.join(out, "7-colors.png"))
    cells = [
        ("walk: ready", render(mScreen=SCREEN_WALK, mWalk=WalkStub(recording=False, seconds=0,
                                                                  meters=0))),
        ("walk: recording", render(mScreen=SCREEN_WALK, line="Let's wander.", mHeartRate=96,
                                   mFrame=1)),
        ("end walk?", render(mScreen=SCREEN_END_WALK)),
        ("end walk? (stray press)", render(
            mScreen=SCREEN_END_WALK, mWalk=WalkStub(seconds=5, meters=4))),
        ("walk saved", render(mScreen=SCREEN_WALK_RESULT, mFrame=3,
                              mPet=PetStub(trail_m=2204, trail_walks=2))),
        ("stray press dropped", render(
            mScreen=SCREEN_WALK_RESULT, mWalk=WalkStub(recording=False, saved=False, seconds=5,
                                                       meters=4))),
    ]
    sheet(cells, 6, os.path.join(out, "8-walk.png"))

    # 9. The belly emblem: how bright it is follows warmth, and the pick screen.
    grown = dict(mBand=3, line="Hi!")
    cells = [
        ("bare belly", render(mBand=1, line="Hi!", mPet=PetStub(xp_=band_xp(1), pal=2,
                                                                emblem_=0))),
        ("warmth 50: dull", render(mBand=1, line="Hi!", mPet=PetStub(
            xp_=band_xp(1), pal=2, emblem_=2, warm=50))),
        ("warmth 80: steady", render(mBand=1, line="Hi!", mPet=PetStub(
            xp_=band_xp(1), pal=2, emblem_=2, warm=80))),
        ("warmth 100: glowing", render(mBand=1, line="Hi!", mPet=PetStub(
            xp_=band_xp(1), pal=2, emblem_=2, warm=100))),
        ("steady, rose", render(mPet=PetStub(xp_=band_xp(3), evos_=1, form_=FORM_SLEEK, pal=5,
                                             emblem_=7, warm=80), **grown)),
        ("steady, sun", render(mPet=PetStub(xp_=band_xp(3), evos_=1, form_=FORM_ROUND, pal=4,
                                            emblem_=9, warm=80), **grown)),
        ("dull, lilac", render(mPet=PetStub(xp_=band_xp(3), evos_=1, form_=FORM_WILD, pal=3,
                                            emblem_=14, warm=50), **grown)),
        ("glowing, peach", render(mPet=PetStub(xp_=band_xp(3), evos_=1, form_=FORM_WILD, pal=1,
                                               emblem_=5, warm=100), **grown)),
    ]
    for title, pal, form, emblem in [("pick: star", 2, FORM_ROUND, 2), ("pick: paw", 5, FORM_WILD, 5),
                                     ("pick: crown", 4, FORM_SLEEK, 9), ("pick: bare", 0, FORM_ROUND, 0)]:
        cells.append((title, render(
            mScreen=SCREEN_EMBLEM, mRepick=True, mBand=3, mPickPal=pal, mPickEmblem=emblem,
            mPet=PetStub(xp_=band_xp(3), evos_=1, form_=form, pal=pal))))
    sheet(cells, 4, os.path.join(out, "9-emblems.png"))


# ----------------------------------------------------------------- checks

def strip_python(text):
    """Python source with comments and strings blanked, positions kept."""
    import io
    import tokenize
    lines = text.split("\n")
    for tok in tokenize.generate_tokens(io.StringIO(text).readline):
        if tok.type not in (tokenize.COMMENT, tokenize.STRING):
            continue
        (r1, c1), (r2, c2) = tok.start, tok.end
        for r in range(r1, r2 + 1):
            line = lines[r - 1]
            lo = c1 if r == r1 else 0
            hi = c2 if r == r2 else len(line)
            lines[r - 1] = line[:lo] + " " * (hi - lo) + line[hi:]
    return "\n".join(lines)


def strip_monkeyc(text):
    """Monkey C source with // comments and string literals blanked."""
    out = []
    for line in text.split("\n"):
        kept = []
        in_string = False
        i = 0
        while i < len(line):
            ch = line[i]
            if in_string:
                if ch == "\\":
                    i += 1
                elif ch == '"':
                    in_string = False
            elif ch == '"':
                in_string = True
            elif ch == "/" and line[i:i + 2] == "//":
                break
            else:
                kept.append(ch)
            i += 1
        out.append("".join(kept))
    return "\n".join(out)


def function_numbers(text, pattern):
    """{function name: sorted integer literals in its body}."""
    import re
    found = {}
    matches = list(re.finditer(pattern, text, re.M))
    for i, m in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[m.end():end]
        outdent = re.search(r"\n\S", body)      # a line at column 0: the class ended
        if outdent:
            body = body[:outdent.start()]
        numbers = re.findall(r"\b0x[0-9A-Fa-f]+\b|\b\d+\b", body)
        found[m.group(1)] = sorted(int(n, 16) if n.lower().startswith("0x") else int(n)
                                   for n in numbers)
    return found


def check(repo):
    """Hold the mock to the Monkey C: the same numbers in every mirrored function,
    and every voice line narrow enough for its row."""
    import re
    source = os.path.join(repo, "garmin-pet", "probes", "wrist-diary", "source")
    here = strip_python(open(os.path.abspath(__file__), encoding="utf-8").read())
    art_py, view_py = here.split("class FriendView:")[0], here.split("class FriendView:")[1]
    art_py = art_py.split("class FriendArt:")[1].split("class PetStub:")[0]
    py_art = function_numbers(art_py, r"^    def (\w+)\(")
    py_view = function_numbers(view_py.split("def render(")[0], r"^    def (\w+)\(")
    mc_art = function_numbers(
        strip_monkeyc(open(os.path.join(source, "FriendArt.mc"), encoding="utf-8").read()
                      .split("class FriendArt")[1]),
        r"^    function (\w+)\(")
    mc_view = function_numbers(
        strip_monkeyc(open(os.path.join(source, "WristDiaryView.mc"), encoding="utf-8").read()),
        r"^    function (\w+)\(")

    failures = []
    py_sprites = function_numbers(
        here.split("class FriendSprites:")[1].split("class FriendArt:")[0], r"^    def (\w+)\(")
    mc_sprites = function_numbers(
        strip_monkeyc(open(os.path.join(source, "FriendSprites.mc"), encoding="utf-8").read()
                      .split("class FriendSprites")[1]),
        r"^    function (\w+)\(")
    for name in sorted(set(py_sprites) | set(mc_sprites)):
        if name in ("__init__", "initialize"):
            continue
        if py_sprites.get(name) != mc_sprites.get(name):
            failures.append("FriendSprites.%s: mock %s, watch %s" % (
                name, py_sprites.get(name), mc_sprites.get(name)))
    skip_art = {"__init__", "initialize", "setLook", "setPose", "bodyColor", "shadeColor",
                "bellyColor"}
    for name in sorted(set(py_art) | set(mc_art)):
        if name in skip_art:
            continue
        if py_art.get(name) != mc_art.get(name):
            failures.append("FriendArt.%s: mock %s, watch %s" % (
                name, py_art.get(name), mc_art.get(name)))
    mirrored = [n for n in py_view if n.startswith("draw")] + [
        "bandName", "unlockWords", "nextText", "weatherName", "energyName", "snackName",
        "warmName", "formName", "goalName", "kmText", "rewardDetail", "walkTooShort",
        "isNight", "petStage", "emblemLevel", "emblemName"]
    for name in mirrored:
        if py_view.get(name) != mc_view.get(name):
            failures.append("view %s: mock %s, watch %s" % (
                name, py_view.get(name), mc_view.get(name)))

    # The tables at the top of FriendArt.
    art_text = open(os.path.join(source, "FriendArt.mc"), encoding="utf-8").read()
    for label, values in (("mBob", BOB), ("mRunJump", RUN_JUMP), ("mHopJump", HOP_JUMP),
                          ("mSpinWidth", SPIN_WIDTH)):
        m = re.search(label + r" = \[([^\]]*)\]", art_text)
        if not m or [int(v) for v in m.group(1).split(",")] != values:
            failures.append("FriendArt table %s differs" % label)
    watch_palettes = [int(v, 16) for v in re.findall(
        r"0x[0-9A-F]{6}", art_text.split("mPalettes = [")[1].split("as Lang.Array")[0])]
    if watch_palettes != [c for row in PALETTES for c in row]:
        failures.append("FriendArt palettes differ")

    # Every voice line must fit the speech row at the smallest font it may use.
    voice = open(os.path.join(source, "FriendVoice.mc"), encoding="utf-8").read()
    lines = re.findall(r'"([^"]+)"', voice.split("mLines = [")[1].split("as Lang.Array")[0])
    dc = Dc()
    view = FriendView()
    row = div(dc.getHeight() * 75, 100)        # the reward card's row is the narrowest
    limit = view.chordWidth(dc, row, dc.getFontHeight(FONT_XTINY))
    widest = ""
    for text in lines:
        if dc.getTextWidthInPixels(text, FONT_XTINY) > limit:
            failures.append("voice line too wide: %r" % text)
        if len(text) > len(widest):
            widest = text
    if failures:
        for failure in failures:
            print("[fail]", failure)
        return 1
    print("[pass] Friend mock: %d art, %d sprite and %d view functions match the watch code; "
          "tables and palettes match; %d voice lines fit (longest %r)" % (
              len([n for n in py_art if n not in skip_art]), len(py_sprites) - 1, len(mirrored),
              len(lines), widest))
    return 0


def main():
    repo = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", default=os.path.join(repo, "bin", "friend", "preview"))
    parser.add_argument("--check", action="store_true",
                        help="compare the mock with the Monkey C source instead of drawing")
    args = parser.parse_args()
    if args.check:
        raise SystemExit(check(repo))
    write_sheets(args.out)


if __name__ == "__main__":
    main()
