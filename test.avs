function CheckSameLuma(clip c) {
# Generate all possible tints with hue [0..100] and saturation [0..100],
# and compare the luma planes, which should remain unchanged.
    return ScriptClip(c, """
hue = current_frame%101
sat = (current_frame/101)%101
HSLTint(hue,sat,hueRange=100,satRange=100)
""").Compare(c, "Y")
}

# Rec601
ColorBars(pixel_type="YV12").trim(0, 10200)
test1 := CheckSameLuma()

# Rec709
ColorBarsHD(pixel_type="YV24").trim(0, 10200)
test2 := CheckSameLuma()