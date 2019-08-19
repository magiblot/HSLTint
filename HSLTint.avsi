#HSLTint rev. 20190815 by magiblot1
#Requires AviSynth+r2768 or newer

#Changelog:
#20190815: (1) drop support for AVS+ < r2728, (2) remove workaround for fixed AVS+ bug (https://github.com/pinterf/AviSynthPlus/issues/19)
#20181027: added parameter oldAvsPlus for easier compatibility between old and new versions of AviSynth+
#20181024: initial release

/*
--- HSLTint ---

Create monochromatic tints given hue, saturation and lightness values.
This filter takes only the Luma the component of a YUV clip since it is thought for B&W films.
It does not overlay on already present color. Hue and Saturation are the same for
all the pixels in the resulting clip.

Arguments:

*** (Input clip)

Source clip must be YUV (or Y). All bitdepths are supported.
The resulting clip will be the same colorspace and bitdepth than the source.

*** hue, sat

Hue and Saturation values for the monochromatic tint.

*** minLight, maxLight

By default, pure black in the source clip (luma == 16d or 0d) will keep looking pure black
after applying the filter, and pure white (luma == 235d or 255d) will keep looking pure white.

These parameters adjust this setting. Take any color picker tool of your choice that
supports HSL and choose the color you think pure black in the source should turn into
in the resulting clip, then use its Lightness value for the minLight parameter. Likewise,
choose the color you consider pure white in the source should become in the resulting clip
and put its Lightness value in the maxLight parameter.

If you specify values such that maxLight < minLight, the resulting clip will look inverted
in brightness but not in color.

If you don't modify these parameters, luma values in the resulting clip will be exactly
the same as in the source clip.

*** hueRange, satRange, lightRange

These parameters allow you to specify the range of values for the hue, sat,
minLight and maxLight parameters explained above. The purpose of this is to
allow compatibility with your favourite color picker tool.

Default values are 360.0, 1.0 and 1.0, respectively.
Values smaller than 1.0 cannot be used.

*** matrix

Color matrix for RGB <-> YUV conversion.
The default value is decided by the following statement:
c.Width() > 1100 || c.Height() > 600 ? "Rec709" : "Rec601"

*** tv_range

This is true by default because YUV clips are expected to use the TV range.
This parameter determines wheter luma values in the source clip
are to be considered in the range 16d to 235d (TV range)
or in the range 0d to 255d (Full Range).

*/

function HSLTint(clip c, float "hue", float "sat", float "minLight", float "maxLight", float "hueRange", float "satRange", float "lightRange", string "matrix", bool "tv_range") {
    
    Assert(c.IsYUV() || c.IsYUVA(), """FilmTint: Source must be YUV. All bit depths are accepted.
Color information (UV) will be ignored, so you can just convert from RGB with ConvertToY.""")
    
    hueRange = Default(hueRange, 360.0)
    satRange = Default(satRange, 1.0)
    lightRange = Default(lightRange, 1.0)

    Assert(1.0 <= hueRange && 1.0 <= satRange && 1.0 <= lightRange, """FilmTint: "hueRange", "satRange" and "lightRange" cannot be smaller than 1.0.""")

    hue = Default(hue, 0.0)
    sat = Default(sat, 0.625*satRange)
    minLight = Default(minLight, 0.0)
    maxLight = Default(maxLight, lightRange)
    
    Assert(0.0 <= hue <= hueRange, """FilmTint: "hue" must be in the range [0.0 , """+ String(hueRange)+"""],
where the upper bound is determined by "hueRange".""")
    Assert(0.0 <= sat <= satRange, """FilmTint: "sat" must be in the range [0.0 , """+ String(satRange)+"""],
where the upper bound is determined by "satRange".""")
    Assert(0.0 <= minLight <= lightRange && 0.0 <= maxLight <= lightRange, """FilmTint: "minLight" and "maxLight" must be in the range [0.0 , """+ String(lightRange)+"""],
where the upper bound is determined by "lightRange".""")
    
    hue = 360.0/hueRange*hue
    sat = sat/satRange
    minLight = minLight/lightRange
    maxLight = maxLight/lightRange
    
    matrix = Default(matrix, c.Width() > 1100 || c.Height() > 600 ? "Rec709" : "Rec601")
    tv_range = Default(tv_range, true)
    
    if (matrix == "Rec601") {
        mR = 0.299
        mG = 0.587
        mB = 0.114
    } else if (matrix == "Rec709") {
        mR = 0.2126
        mG = 0.7152
        mB = 0.0722
    } else {
        Assert(false, """FilmTint: Valid "matrix" values are "Rec601" and "Rec709".""")
    }

    #Generate an RGB color with Hue=hue, Sat=1.0 and Lightness=0.5.

    if (0.0 <= hue <= 60.0) {
        hR = 1.0
        hG = hue/60.0
        hB = 0.0
    } else if (60.0 <= hue <= 120.0) {
        hR = (60.0 - (hue - 60.0))/60.0
        hG = 1.0
        hB = 0.0
    } else if (120.0 <= hue <= 180.0) {
        hR = 0.0
        hG = 1.0
        hB = (hue - 120.0)/60.0
    } else if (180.0 <= hue <= 240.0) {
        hR = 0.0
        hG = (60.0 - (hue - 180.0))/60.0
        hB = 1.0
    } else if (240.0 <= hue <= 300.0) {
        hR = (hue - 240.0)/60.0
        hG = 0.0
        hB = 1.0
    } else { # 300.0 <= hue <= 360.0
        hR = 1.0
        hG = 0.0
        hB = (60.0 - (hue - 300.0))/60.0
    }
    
    #Generate an RGB color with Hue=hue, Sat=sat and Lightness=0.5.
    #A saturation of 1 leaves the result the same.
    #A saturation of 0 makes all channels become 0.5 (out of 1.0).
    
    hsR = hR + (0.5 - hR)*(1 - sat)
    hsG = hG + (0.5 - hG)*(1 - sat)
    hsB = hB + (0.5 - hB)*(1 - sat)
    
    function _HSLtoRGB(float "hs", float "l") {
        #Applies lightness ('x') to the color component 'hs', which has been defined with Hue=hue, Sat=sat and Lightness=0.5.
        #A lightness of 0.5 leaves the result the same.
        #A lightness of 0 makes the component become 0.
        #A lightness of 1 makes the component become 1.
        return l <= 0.5 ? 2*hs*l : hs + 2*(1 - hs)*(l - 0.5)
    }
    
    #Translates the darkest and brightest colors from HSL to RGB, and then to Luma (Y).
    #The following is always true: a lightness of 0 always results in a luma of 0, and a lightness of 1 always results in a luma of 1
    
    minLight_Y = mR*_HSLtoRGB(hsR, minLight) + mG*_HSLtoRGB(hsG, minLight) + mB*_HSLtoRGB(hsB, minLight)
    maxLight_Y = mR*_HSLtoRGB(hsR, maxLight) + mG*_HSLtoRGB(hsG, maxLight) + mB*_HSLtoRGB(hsB, maxLight)
    
    bitDepth = c.BitsPerComponent()
    
    #http://avisynth.nl/index.php/Levels
    
    scale_to_32bit = tv_range ? 219.0/256.0*pow(2,bitDepth%32) : 255.0/256.0*pow(2,bitDepth%32)
    tv_range_start = tv_range ? 16.0/256.0*pow(2,bitDepth%32) : 0.0
    
    #Get luma of video and convert to [0 .. 1] range in float.
    
    Y = c.IsInterleaved() ? c.ConvertToY() : c
    Y = Expr(Y, "x "+String(tv_range_start)+" - "+String(scale_to_32bit)+" /", format="Y32")
    Y = (minLight != 0.0 || maxLight != 1.0) ? Expr(Y, "x "+String(maxLight_Y - minLight_Y)+" * "+String(minLight_Y)+" +", format="Y32") : Y
    
    #Calculate the lightness values that, when converted from HSL to RGB and then back to Luma (Y), will result in the same Luma values than the original, source clip.
    #Otherwise, using Luma values directly in the HSL->RGB conversion formulas (like Colorize filter in VirtualDub) will result in distortion.
    #This is undocumented math, the following operations are not meant to be comprehensive.
    
    Llow = Expr(Y, "x "+String(0.5/(hsB*mB+hsG*mG+hsR*mR))+" *",format="Y32")
    Lhigh = Expr(Y, String(2*((hsB-0.5)*mB+(hsG-0.5)*mG+(hsR-0.5)*mR))+" x - "+String(0.5/((hsB-1)*mB+(hsG-1)*mG+mR*(hsR-1)))+" *",format="Y32")
    L = Expr(Y,Llow,Lhigh, "x 0.5 <= y 0.5 <= y z ? z 0.5 > z y ? ?",format="Y32")
    
    function _HSLtoRGB_expr(float "hs") {
        #Generates a string for Expr that will apply lightness ('x') to the color component 'hs', which has been defined with Hue=hue, Sat=sat and lightness=0.5.
        return  "x 0.5 < "+String(2*hs)+" x * "+String(2*hs-1)+" "+String(2*(1-hs))+" x * + ?"
    }
    
    hslRGB = Expr(L, _HSLtoRGB_expr(hsR), _HSLtoRGB_expr(hsG), _HSLtoRGB_expr(hsB), format="RGBPS")
    
    hslYUV =
    \ c.Is420() ? hslRGB.ConvertToYUV420(matrix=matrix)
    \ : c.Is422() ? hslRGB.ConvertToYUV422(matrix=matrix)
    \ : hslRGB.ConvertToYUV444(matrix=matrix)
    
    return hslYUV.ConvertBits(bitDepth)

}