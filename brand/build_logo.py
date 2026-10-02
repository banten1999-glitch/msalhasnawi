#!/usr/bin/env python3
"""يبني ملفات شعار «حاسبة الرمان» من مصدر واحد.

المخرجات:
  brand/logo.svg                 الشعار الثابت
  brand/logo-animated.svg        الشعار المتحرك (يعمل مرة واحدة، 3 ثوانٍ)
  brand/layers/*.svg             طبقات منفصلة لتحريكها داخل Flutter
  app/assets/brand/*.svg         نسخة الطبقات والشعار داخل تطبيق Flutter

التشغيل:  python3 brand/build_logo.py
"""
import math
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "brand")
APP_ASSETS = os.path.join(ROOT, "app", "assets", "brand")

RED = "#A00B1E"
GREEN = "#1F6B2C"
GAP = "#FFFFFF"  # لون الفواصل بين الرمانة والبراد (لون الخلفية)

VIEWBOX = "155 124 960 960"

BODY = '<circle cx="515" cy="690" r="345" fill="{red}"/>'
HIGHLIGHT = ('<path d="M470 412C340 420 228 548 232 750C252 610 320 474 470 412Z" '
             'fill="{gap}"/>')
CROWN = ('<path d="M435 400L440 352C442 305 425 262 385 232C430 226 470 232 497 250'
         'C503 222 518 198 537 180C556 198 571 222 577 250C604 232 644 226 690 232'
         'C650 262 633 305 637 360L642 400Z" fill="{red}"/>'
         '<path d="M497 250C506 280 514 305 521 332M577 250C568 280 560 305 553 332" '
         'fill="none" stroke="{gap}" stroke-width="11" stroke-linecap="round"/>')

LEAF_D = "M676 384C690 322 780 262 956 247C936 322 880 392 772 399C736 401 700 396 676 384Z"
LEAF = ('<path d="{leaf}" fill="{gap}" stroke="{gap}" stroke-width="18" stroke-linejoin="round"/>'
        '<path d="{leaf}" fill="{green}"/>'
        '<path d="M712 388C760 346 806 318 853 302" fill="none" stroke="{gap}" '
        'stroke-width="10" stroke-linecap="round"/>')

BOX_D = "M615 566H852V962H470C425 930 410 880 418 830C440 700 520 590 615 566Z"
CAB_D = ("M893 625H952Q970 625 981 640L1077 772Q1090 790 1090 812V925Q1090 962 1053 962"
         "H868V650Q868 625 893 625Z")
INTERIOR_D = ("M600 622H806Q830 622 830 646V869Q830 893 806 893H628C612 866 588 853 556 853"
              "C536 853 516 857 500 862C503 770 525 690 568 637Q580 622 600 622Z")
WINDOW_D = ("M916 662H958Q968 662 975 671L1035 751Q1045 765 1028 765H916Q903 765 903 752"
            "V675Q903 662 916 662Z")
NOTCH_D = "M1100 815H1052Q1037 815 1037 831Q1037 847 1052 847H1100Z"
WHEELS = [(535, 957), (928, 952)]

SNOW_C = (688, 758)
SNOW_R = 98


def snowflake_path():
    cx, cy = SNOW_C
    parts = []
    for k in range(6):
        a = math.radians(90 + 60 * k)
        ux, uy = math.cos(a), -math.sin(a)
        ex, ey = cx + ux * SNOW_R, cy + uy * SNOW_R
        parts.append(f"M{cx:.1f} {cy:.1f}L{ex:.1f} {ey:.1f}")
        # فرعان على شكل V قرب طرف كل ذراع
        bx, by = cx + ux * SNOW_R * 0.58, cy + uy * SNOW_R * 0.58
        for s in (1, -1):
            b = a + s * math.radians(45)
            tx = bx + math.cos(b) * SNOW_R * 0.34
            ty = by - math.sin(b) * SNOW_R * 0.34
            parts.append(f"M{bx:.1f} {by:.1f}L{tx:.1f} {ty:.1f}")
    return "".join(parts)


def truck_markup(gap=GAP):
    wheels = "".join(
        f'<circle cx="{x}" cy="{y}" r="84" fill="{gap}"/>'
        f'<circle cx="{x}" cy="{y}" r="68" fill="{RED}"/>'
        f'<circle cx="{x}" cy="{y}" r="33" fill="{gap}"/>'
        for x, y in WHEELS)
    return (
        f'<path d="{BOX_D}" fill="{gap}" stroke="{gap}" stroke-width="26" stroke-linejoin="round"/>'
        f'<path d="{CAB_D}" fill="{gap}" stroke="{gap}" stroke-width="26" stroke-linejoin="round"/>'
        f'<path d="{BOX_D}" fill="{RED}"/>'
        f'<path d="{CAB_D}" fill="{RED}"/>'
        f'<path d="{INTERIOR_D}" fill="{gap}"/>'
        f'<path d="{WINDOW_D}" fill="{gap}"/>'
        f'<path d="{NOTCH_D}" fill="{gap}"/>'
        + wheels)


def snow_markup():
    return (f'<path d="{snowflake_path()}" fill="none" stroke="{GREEN}" stroke-width="15" '
            'stroke-linecap="round"/>')


def pomegranate_markup(gap=GAP):
    return (BODY.format(red=RED) + HIGHLIGHT.format(gap=gap) + CROWN.format(red=RED, gap=gap))


def leaf_markup(gap=GAP):
    return LEAF.format(leaf=LEAF_D, gap=gap, green=GREEN)


def svg(inner, title="شعار حاسبة الرمان", extra=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX}" role="img" '
            f'aria-label="{title}">{extra}<title>{title}</title>{inner}</svg>\n')


ANIM_CSS = """<style>
.pom{transform-origin:515px 690px;animation:pom .6s cubic-bezier(.2,.8,.2,1) both}
.leaf{transform-origin:676px 384px;animation:leaf .6s .35s cubic-bezier(.2,.8,.2,1) both}
.truck{animation:truck .8s .45s cubic-bezier(.2,1.25,.4,1) both}
.snow{transform-origin:688px 758px;animation:snow .6s 1s cubic-bezier(.2,.8,.2,1) both}
@keyframes pom{from{opacity:0;transform:scale(.85)}to{opacity:1;transform:none}}
@keyframes leaf{from{opacity:0;transform:rotate(-28deg) scale(.6)}to{opacity:1;transform:none}}
@keyframes truck{0%{opacity:0;transform:translateX(-140px)}25%{opacity:1}100%{opacity:1;transform:none}}
@keyframes snow{from{opacity:0;transform:rotate(-90deg) scale(.4)}to{opacity:1;transform:none}}
@media (prefers-reduced-motion:reduce){.pom,.leaf,.truck,.snow{animation:fade .2s both}}
@keyframes fade{from{opacity:0}to{opacity:1}}
</style>"""


def main():
    os.makedirs(os.path.join(BRAND, "layers"), exist_ok=True)
    os.makedirs(APP_ASSETS, exist_ok=True)

    static = pomegranate_markup() + leaf_markup() + truck_markup() + snow_markup()
    with open(os.path.join(BRAND, "logo.svg"), "w", encoding="utf-8") as f:
        f.write(svg(static))

    animated = (f'<g class="pom">{pomegranate_markup()}</g>'
                f'<g class="leaf">{leaf_markup()}</g>'
                f'<g class="truck">{truck_markup()}</g>'
                f'<g class="snow">{snow_markup()}</g>')
    with open(os.path.join(BRAND, "logo-animated.svg"), "w", encoding="utf-8") as f:
        f.write(svg(animated, extra=ANIM_CSS))

    layers = {
        "pomegranate": pomegranate_markup(),
        "leaf": leaf_markup(),
        "truck": truck_markup(),
        "snowflake": snow_markup(),
    }
    for name, inner in layers.items():
        path = os.path.join(BRAND, "layers", f"{name}.svg")
        with open(path, "w", encoding="utf-8") as f:
            f.write(svg(inner, title=name))
        shutil.copy(path, os.path.join(APP_ASSETS, f"{name}.svg"))
    shutil.copy(os.path.join(BRAND, "logo.svg"), os.path.join(APP_ASSETS, "logo.svg"))
    print("logo files written")


if __name__ == "__main__":
    main()
