#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;// 0, 1
uniform float uTime;// 2
uniform float uTextY;// 3
uniform float uWaterY;// 4
uniform float uTextOpacity;// 5
uniform float uTextScale;// 6
uniform float uTextWidth;// 7  (Physical Texture Width)
uniform float uTextHeight;// 8  (Physical Texture Height)
uniform float uTextX;// 9  (Logical Center X)
uniform float uPixelRatio;// 10
uniform float uOpacity;// 11
uniform float uLightning;// 12
uniform float uPanic;// 13
uniform vec2 uRippleOrigin;// 14, 15
uniform float uRippleTime;// 16
uniform float uScrollProgress;// 17 (0.0 = start, 1.0 = end of section)

uniform sampler2D uTextTexture;

out vec4 fragColor;

const float pi = 3.14159;
int idObj, idObjGrp;
mat3 bdMat, birdMat[2];
vec3 bdPos, birdPos[2], fltBox, qHit, sunDir, waterDisp, cloudDisp;
float tCur, birdVel, birdLen, legAng;
const float dstFar = 100.0;
const int idWing = 21, idBdy = 22, idEye = 23, idBk = 24, idLeg = 25;
const int idHull = 1, idRud = 2, idStruc = 3, idMast = 4, idSparT = 5, idSparL = 6, idSailT = 7, idSailA = 8, idSailF = 9, idFlag = 10, idRig = 11;

vec3 shipConf, bDeck, shipPanicShake;
float szFac, shipRot, shipRoll, shipPitch, shipHeave;
vec4 vum[4], vur[5];
vec3 vim[4], vir[5];
bool isRefl;

// --- Helper Functions (Hash, Noise, SDFs) ---
const vec4 cHashA4 = vec4 (0., 1., 57., 58.);
const vec3 cHashA3 = vec3 (1., 57., 113.);
const float cHashM = 43758.54;

vec4 Hashv4f (float p) { return fract (sin (p + cHashA4) * cHashM); }
float Noisefv2 (vec2 p) {
    vec2 i = floor (p); vec2 f = fract (p);
    f = f * f * (3. - 2. * f);
    vec4 t = Hashv4f (dot (i, cHashA3.xy));
    return mix (mix (t.x, t.y, f.x), mix (t.z, t.w, f.x), f.y);
}
float Noisefv3 (vec3 p) {
    vec3 i = floor (p); vec3 f = fract (p);
    f = f * f * (3. - 2. * f);
    float q = dot (i, cHashA3);
    vec4 t1 = Hashv4f (q); vec4 t2 = Hashv4f (q + cHashA3.z);
    return mix (mix (mix (t1.x, t1.y, f.x), mix (t1.z, t1.w, f.x), f.y),
    mix (mix (t2.x, t2.y, f.x), mix (t2.z, t2.w, f.x), f.y), f.z);
}
float SmoothBump (float lo, float hi, float w, float x) {
    return (1. - smoothstep (hi - w, hi + w, x)) * smoothstep (lo - w, lo + w, x);
}
vec2 Rot2D (vec2 q, float a) { return q * cos (a) * vec2 (1., 1.) + q.yx * sin (a) * vec2 (-1., 1.); }
float PrSphDf (vec3 p, float s) { return length (p) - s; }
float PrCapsDf (vec3 p, float r, float h) { return length (p - vec3 (0., 0., h * clamp (p.z / h, -1., 1.))) - r; }
float PrCylDf (vec3 p, float r, float h) { return max (length (p.xy) - r, abs (p.z) - h); }
float PrFlatCylDf (vec3 p, float rhi, float rlo, float h) {
    return max (length (p.xy - vec2 (rhi * clamp (p.x / rhi, -1., 1.), 0.)) - rlo, abs (p.z) - h);
}
float PrTorusDf (vec3 p, float ri, float rc) { return length (vec2 (length (p.xy) - rc, p.z)) - ri; }
float PrBoxDf (vec3 p, vec3 b) {
    vec3 d = abs (p) - b;
    return min (max (d.x, max (d.y, d.z)), 0.) + length (max (d, 0.));
}
float PrBox2Df (vec2 p, vec2 b) {
    vec2 d = abs (p) - b;
    return min (max (d.x, d.y), 0.) + length (max (d, 0.));
}
float PrEVCapsDf (vec3 p, vec4 u, float r) {
    return length (p - clamp (dot (p, u.xyz), 0., u.w) * u.xyz) - r;
}
float PrEECapsDf (vec3 p, vec3 v1, vec3 v2, float r) {
    return PrEVCapsDf (p - v1, vec4 (normalize (v2 - v1), length (v2 - v1)), r);
}

// --- Water & Sky logic ---
float WaterHt (vec3 p) {
    float pMult = 1.0 + uPanic * 1.5;
    p *= 0.03; p += waterDisp * (1.0 + uPanic * 0.5);
    // Reduced from 7 → 5 octaves. WaterHt runs ~3× per ray step × 100 ray
    // steps = 300 calls/pixel; the last 2 octaves produce sub-pixel noise
    // that's invisible after bloom. ~28% less math per call = 10–15% total
    // GPU time saved on this shader.
    float ht = 0.; const float wb = 1.414; float w = wb * pMult;
    for (int j = 0; j < 5; j ++) {
        w *= 0.5;
        p = wb * vec3 (p.y + p.z, p.z - p.y, 2. * p.x) + 20. * waterDisp;
        ht += w * abs (Noisefv3 (p) - 0.5);
    }
    return ht;
}
vec3 WaterNf (vec3 p, float d) {
    vec2 e = vec2 (max (0.01, 0.001 * d * d), 0.);
    float ht = WaterHt (p);
    return normalize (vec3 (ht - WaterHt (p + e.xyy), e.x, ht - WaterHt (p + e.yyx)));
}
float FbmS (vec2 p) {
    float a = 1.; float v = 0.;
    for (int i = 0; i < 5; i ++) {
        v += a * (sin (6. * Noisefv2 (p)) + 1.);
        a *= 0.5; p *= 2.;
        p *= mat2 (0.8, -0.6, 0.6, 0.8);
    }
    return v;
}
// --- Ship logic ---
void UpdateHit(float d, inout float dMin, int id, vec3 q) {
    if (d < dMin) {
        dMin = d;
        idObj = id;
        qHit = q;
    }
}

float ShipHullDf (vec3 p, float dMin) {
    vec3 q; float d, fy, fz, gz;
    q = p; d = abs (p.z) - 4.5;
    q.z = mod (q.z + 1.4, 2.8) - 1.4;
    q.yz -= vec2 (-3.4, -0.4);
    d = max (d, PrBoxDf (q, vec3 (0.3, 0.1, 0.5)));
    UpdateHit(d, dMin, idStruc, q);
    q = p; q.x = abs (q.x); q.yz -= vec2 (-3.8, 0.5);
    fz = q.z / 5. + 0.3; fz *= fz;
    fy = 1. - smoothstep (-1.3, -0.1, q.y);
    gz = smoothstep (2., 5., q.z);
    bDeck = vec3 ((1. - 0.45 * fz * fz) * (1.1 - 0.5 * fy * fy) *
    (1. - 0.5 * smoothstep (-5., -2., q.y) * smoothstep (2., 5., q.z)),
    0.78 - 0.8 * gz * gz - 0.2 * (1. - smoothstep (-5.2, -4., q.z)), 5. * (1. + 0. * 0.02 * q.y));
    d = min (PrBoxDf (vec3 (q.x, q.y + bDeck.y - 0.6, q.z), bDeck),
    max (PrBoxDf (q - vec3 (0., 0.72, -4.6), vec3 (bDeck.x, 0.12, 0.4)),
    - PrBox2Df (vec2 (abs (q.x) - 0.4, q.y - 0.65), vec2 (0.2, 0.08))));
    d = max (d, - PrBoxDf (vec3 (q.x, q.y - 0.58 - 0.1 * fz, q.z), vec3 (bDeck.x - 0.07, 0.3, bDeck.z - 0.1)));
    q = p; d = max (d, - max (PrBox2Df (vec2 (q.y + 3.35, mod (q.z + 0.25, 0.5) - 0.25), vec2 (0.08, 0.1)),
    abs (q.z + 0.5) - 3.75));
    UpdateHit(d, dMin, idHull, q);
    q = p; d = PrBoxDf (q + vec3 (0., 4.4, 4.05), vec3 (0.03, 0.35, 0.5));
    UpdateHit(d, dMin, idRud, q);
    return dMin;
}

float ShipMastDf (vec3 p, float dMin) {
    vec3 q, qq; float d, fy, fz, rSpar, yLim, zLim;
    rSpar = 0.05; fy = 1. - 0.07 * p.y;
    fz = 1. - 0.14 * step (1., abs (p.z));
    zLim = abs (p.z) - 4.5;
    q = p; d = zLim;
    q.z = mod (q.z + 1.4, 2.8) - 1.2;
    d = max (d, PrCapsDf ((q - vec3 (0., 3.7 * (fz - 1.), 0.)).xzy, 0.1 * fy, 3.7 * fz));
    UpdateHit(d, dMin, idMast, q);
    q = p; yLim = abs (q.y - 0.2 * fz) - 3. * fz;
    qq = q; qq.y = mod (qq.y - 3.3 * (fz - 1.), 2. * fz) - fz;
    qq.z = mod (qq.z + 1.4, 2.8) - 1.4 + 0.1 * fz;
    d = max (max (min (d, PrCylDf (vec3 (qq - vec3 (0., 0.05 * fy * fz, 0.1 * fz - 0.23)).xzy,
    0.15 * fy, 0.11 * fy * fz)), yLim), zLim);
    UpdateHit(d, dMin, idMast, q);
    d = max (max (PrCapsDf (qq.yzx, 0.05, 1.23 * fy * fz), yLim), zLim);
    UpdateHit(d, dMin, idSparT, q);
    q = p; d = min (d, min (PrEVCapsDf (q - vim[0], vum[0], rSpar), PrEVCapsDf (q - vim[1], vum[1], rSpar)));
    d = min (d, min (PrEVCapsDf (q - vim[2], vum[2], rSpar), PrEVCapsDf (q - vim[3], vum[3], rSpar)));
    UpdateHit(d, dMin, idSparL, q);
    return dMin;
}

float ShipSailDf (vec3 p, float dMin) {
    vec3 q, qq, w; float d, fy, fz;
    fy = 1. - 0.07 * p.y; fz = 1. - 0.14 * step (1., abs (p.z));
    q = p; qq = q;
    qq.y = mod (qq.y - 3.1 * (fz - 1.), 2. * fz) - fz;
    qq.z = mod (qq.z + 1.4, 2.8) - 1.4 + 0.2 * (fz - abs (qq.y)) * (fz - abs (qq.y)) - 0.1 * fz;
    d = max (max (max (PrBoxDf (qq, vec3 ((1.2 - 0.07 * q.y) * fz, fz, 0.01)),
    min (qq.y, 1.5 * fy * fz - length (vec2 (qq.x, qq.y + 0.9 * fy * fz)))),
    abs (q.y - 3. * (fz - 1.)) - 2.95 * fz), - PrBox2Df (qq.yz, vec2 (0.01 * fz)));
    d = max (d, abs (p.z) - 4.5);
    UpdateHit(d, dMin, idSailT, q);
    q = p; q.z -= -3.8; q.y -= -1.75 - 0.2 * q.z;
    d = PrBoxDf (q, vec3 (0.01, 0.9 - 0.2 * q.z, 0.6));
    UpdateHit(d, dMin, idSailA, q);
    q = p; q.yz -= vec2 (-1., 4.5);
    w = vec3 (1., q.yz);
    d = max (max (max (abs (q.x) - 0.01, - dot (w, vec3 (2.3, 1., -0.35))),
    - dot (w, vec3 (0.68, -0.74, -1.))), - dot (w, vec3 (0.41, 0.4, 1.)));
    UpdateHit(d, dMin, idSailF, q);
    q = p; q.yz -= vec2 (3.4, 0.18);
    d = PrBoxDf (q, vec3 (0.01, 0.2, 0.3));
    UpdateHit(d, dMin, idFlag, q);
    return dMin;
}

float ShipRigDf (vec3 p, float dMin) {
    vec3 q; float rRig, d, fz, gz, s;
    rRig = 0.02; fz = 1. - 0.14 * step (1., abs (p.z));
    q = p; d = abs (p.z) - 4.5;
    gz = (q.z - 0.5) / 5. + 0.3; gz *= gz;
    gz = 1.05 * (1. - 0.45 * gz * gz);
    q.x = abs (q.x); q.z = mod (q.z + 1.4, 2.8) - 1.4;
    d = max (d, min (PrEECapsDf (q, vec3 (1.05 * gz, -3.25, -0.5), vec3 (1.4 * fz, -2.95, -0.05), 0.7 * rRig),
    PrEECapsDf (vec3 (q.xy, abs (q.z + 0.2) - 0.01 * (0.3 - 2. * q.y)), vec3 (gz, -3.2, 0.),
    vec3 (0.05, -0.9 + 2. * (fz - 1.), 0.), rRig)));
    q = p; d = min (d, PrEVCapsDf (q - vir[0], vur[0], 0.8 * rRig));
    d = min (min (d, min (PrEVCapsDf (q - vir[1], vur[1], rRig),
    PrEVCapsDf (q - vir[2], vur[2], rRig))), PrEVCapsDf (q - vir[3], vur[3], rRig));
    q.x = abs (q.x); d = min (d, PrEVCapsDf (q - vir[4], vur[4], rRig));
    s = step (1.8, q.y) - step (q.y, -0.2);
    d = min (min (d, min (PrEECapsDf (q, vec3 (0.95, 0.4, 2.7) + vec3 (-0.1, 1.7, 0.) * s,
    vec3 (0.05, 1.1, -0.15) + vec3 (0., 2., 0.) * s, rRig),
    PrEECapsDf (q, vec3 (1.05, 1., -0.1) + vec3 (-0.1, 2., 0.) * s,
    vec3 (0.05, 0.5, -2.95) + vec3 (0., 1.7, 0.) * s, rRig))),
    PrEECapsDf (q, vec3 (0.95, 0.4, -2.9) + vec3 (-0.1, 1.7, 0.) * s,
    vec3 (0.05, 0.9, -0.25) + vec3 (0., 2., 0.) * s, rRig));
    UpdateHit(d, dMin, idRig, q);
    return dMin;
}

void EvalShipConf () {
    vec3 vd;
    shipConf = vec3 (-4. * szFac, 0., 0.);
    shipRot = 0.25 * pi * cos (0.02 * pi * tCur);
    vim[0] = vec3 (0., -3.5, 4.3);   vd = vec3 (0., -2.6, 6.7) - vim[0];   vum[0] = vec4 (normalize (vd), length (vd));
    vim[1] = vec3 (0., -4., 4.1);    vd = vec3 (0., -2.9, 6.) - vim[1];    vum[1] = vec4 (normalize (vd), length (vd));
    vim[2] = vec3 (0., -1.2, -3.);   vd = vec3 (0., -0.5, -4.5) - vim[2];  vum[2] = vec4 (normalize (vd), length (vd));
    vim[3] = vec3 (0., -2.7, -3.);   vd = vec3 (0., -2.7, -4.5) - vim[3];  vum[3] = vec4 (normalize (vd), length (vd));
    vir[0] = vec3 (0., -3., -4.45);  vd = vec3 (0., -2.7, -4.5) - vir[0];  vur[0] = vec4 (normalize (vd), length (vd));
    vir[1] = vec3 (0., 2.45, 2.65);  vd = vec3 (0., -2.7, 6.5) - vir[1];   vur[1] = vec4 (normalize (vd), length (vd));
    vir[2] = vec3 (0., 2.5, 2.65);   vd = vec3 (0., -3.2, 4.9) - vir[2];   vur[2] = vec4 (normalize (vd), length (vd));
    vir[3] = vec3 (0., 2.6, -3.);    vd = vec3 (0., -0.5, -4.5) - vir[3];  vur[3] = vec4 (normalize (vd), length (vd));
    vur[4] = vec4 (normalize (vd), length (vd));
    
    // Physical ship motion synchronized with Waves (WaterHt)
    vec3 pShip = vec3(0.0); // Focus on world center where ship is
    float hC = WaterHt(pShip);
    float hF = WaterHt(pShip + vec3(0.0, 0.0, 5.0));
    float hB = WaterHt(pShip + vec3(0.0, 0.0, -5.0));
    float hL = WaterHt(pShip + vec3(-2.0, 0.0, 0.0));
    float hR = WaterHt(pShip + vec3(2.0, 0.0, 0.0));

    shipHeave = hC * 0.6 - 0.5; // Offset to keep it grounded
    shipPitch = atan(hF - hB, 10.0);
    shipRoll = atan(hL - hR, 4.0);
    
    // Add subtle structural creaking/vibration only at high panic
    float vibrate = uPanic * (Noisefv2(vec2(tCur * 50.0, 0.0)) - 0.5) * 0.05;
    shipHeave += vibrate;
    shipRoll += vibrate * 0.2;

    // Subtle side-to-side drift
    shipPanicShake.x = 0.1 * uPanic * sin (tCur * 0.1);
}
vec3 SkyCol (vec3 ro, vec3 rd) {
    vec3 skyCol, sunCol, p;
    float ds, fd, att, attSum, d, dDotS, skyHt = 200.;
    p = ro + rd * (skyHt - ro.y) / rd.y;
    ds = 0.1 * sqrt (distance (ro, p));
    fd = 0.001 / (smoothstep (0., 10., ds) + 0.1);
    p.xz *= fd; p.xz += cloudDisp.xz;
    att = FbmS (p.xz); attSum = att; d = fd; ds *= fd;
    for (int i = 0; i < 4; i ++) { attSum += FbmS (p.xz + d * sunDir.xz); d += ds; }
    attSum *= 0.27; att *= 0.27;
    dDotS = clamp (dot (sunDir, rd), 0., 1.);
    skyCol = mix (vec3 (0.7, 1., 1.), vec3 (1., 0.4, 0.1), 0.25 + 0.75 * dDotS);
    sunCol = vec3 (1., 0.8, 0.7) * pow (dDotS, 1024.) + vec3 (1., 0.4, 0.2) * pow (dDotS, 256.);
    vec3 col = mix (vec3 (0.5, 0.75, 1.), skyCol, exp (-2. * (3. - dDotS) * max (rd.y - 0.1, 0.))) + 0.3 * sunCol;
    attSum = 1. - smoothstep (1., 9., attSum);
    col = mix (vec3 (0.4, 0., 0.2), mix (col, vec3 (0.2), att), attSum) +
    vec3 (1., 0.4, 0.) * pow (attSum * att, 3.) * (pow (dDotS, 10.) + 0.5);
    return col;
}

// --- Bird Animation ---
float AngQnt (float a, float s1, float s2, float nr) { return (s1 + floor (s2 + a * (nr / (2. * pi)))) * (2. * pi / nr); }
float BdWingDf (vec3 p, float dHit) {
    vec3 q, qh = vec3(0.); float d, dd, a, wr, wSegLen = 0.18, wChord = 0.36, wSpar = 0.036, fTap = 8., tFac = 0.875;

    // Flapping speed increases with panic
    float wngFreq = 6.0 + (uPanic * 12.0);

    q = p - vec3 (0., 0., 0.36); q.x = abs (q.x) - 0.12;
    float wf = 1.0;

    // Add a slight 'tremor' to the wing amplitude during panic
    float tremor = Noisefv2(vec2(uTime * 30.0, 0.0)) * uPanic * 0.1;
    a = -0.1 + (0.2 + tremor) * sin (wngFreq * tCur);

    d = dHit; qh = q;
    for (int k = 0; k < 5; k ++) {
        q.xy = Rot2D (q.xy, a); q.x -= wSegLen; wr = wf * (1. - 0.5 * q.x / (fTap * wSegLen));
        dd = PrFlatCylDf (q.zyx, wr * wChord, wr * wSpar, wSegLen);
        if (k < 4) { q.x -= wSegLen; dd = min (dd, PrCapsDf (q, wr * wSpar, wr * wChord)); }
        else { q.x += wSegLen; dd = max (dd, PrCylDf (q.xzy, wr * wChord, wSpar)); dd = min (dd, max (PrTorusDf (q.xzy, 0.98 * wr * wSpar, wr * wChord), - q.x)); }
        if (dd < d) { d = dd;  qh = q; }
        a *= 1.03; wf *= tFac;
    }
    if (d < dHit) { dHit = min (dHit, d);  idObj = idObjGrp + idWing;  qHit = qh; }
    return dHit;
}
float BdBodyDf (vec3 p, float dHit) {
    vec3 q = p; float d, wr = q.z / birdLen, tr, u, bkLen = 0.15 * birdLen;
    if (wr > 0.5) { u = (wr - 0.5) / 0.5; tr = 0.17 - 0.11 * u * u; }
    else { u = clamp ((wr - 0.5) / 1.5, -1., 1.); u *= u; tr = 0.17 - u * (0.34 - 0.18 * u); }
    d = PrCapsDf (q, tr * birdLen, birdLen);
    if (d < dHit) { dHit = d;  idObj = idObjGrp + idBdy;  qHit = q; }
    q = p; q.x = abs (q.x); wr = (wr + 1.) * (wr + 1.); q -= birdLen * vec3 (0.3 * wr, 0.1 * wr, -1.2);
    d = PrCylDf (q, 0.009 * birdLen, 0.2 * birdLen);
    if (d < dHit) { dHit = min (dHit, d);  idObj = idObjGrp + idBdy;  qHit = q; }
    q = p; q.x = abs (q.x); q -= birdLen * vec3 (0.08, 0.05, 0.9);
    d = PrSphDf (q, 0.04 * birdLen);
    if (d < dHit) { dHit = d;  idObj = idObjGrp + idEye;  qHit = q; }
    q = p; q -= birdLen * vec3 (0., -0.015, 1.15); wr = clamp (0.5 - 0.3 * q.z / bkLen, 0., 1.);
    d = PrFlatCylDf (q, 0.25 * wr * bkLen, 0.25 * wr * bkLen, bkLen);
    if (d < dHit) { dHit = d;  idObj = idObjGrp + idBk;  qHit = q; }
    return dHit;
}
float BdFootDf (vec3 p, float dHit) {
    vec3 q = p; float d, lgLen = 0.1 * birdLen, ftLen = 0.5 * lgLen;
    q.x = abs (q.x); q -= birdLen * vec3 (0.1, -0.12, 0.6);
    q.yz = Rot2D (q.yz, legAng); q.xz = Rot2D (q.xz, -0.05 * pi); q.z += lgLen;
    d = PrCylDf (q, 0.15 * lgLen, lgLen);
    if (d < dHit) { dHit = d;  idObj = idLeg;  qHit = q; }
    q.z += lgLen; q.xy = Rot2D (q.xy, 0.5 * pi); q.xy = Rot2D (q.xy, AngQnt (atan (q.y, - q.x), 0., 0.5, 3.));
    q.xz = Rot2D (q.xz, - pi + 0.4 * legAng); q.z -= ftLen;
    d = PrCapsDf (q, 0.2 * ftLen, ftLen);
    if (d < dHit) { dHit = d;  idObj = idObjGrp + idLeg;  qHit = q; }
    return dHit;
}
float BirdDf (vec3 p, float dHit) {
    dHit = BdWingDf (p, dHit);
    dHit = BdBodyDf (p, dHit);
    dHit = BdFootDf (p, dHit);
    return dHit;
}
vec4 BirdCol (vec3 n) {
    vec3 col = vec3(0.); int ig = idObj / 256; int id = idObj - 256 * ig; float spec = 1.;
    if (id == idWing) {
        float gw = 0.15 * birdLen; float w = mod (qHit.x, gw);
        w = SmoothBump (0.15 * gw, 0.65 * gw, 0.1 * gw, w);
        col = mix (vec3 (0.05), vec3 (1.), w);
    } else if (id == idEye) { col = vec3 (0., 0.6, 0.); spec = 5.; }
    else if (id == idBdy) {
        vec3 nn = (ig == 1) ? birdMat[0] * n : birdMat[1] * n;
        col = mix (mix (vec3 (1.), vec3 (0.1), smoothstep (0.5, 1., nn.y)), vec3 (1.), 1. - smoothstep (-1., -0.7, nn.y));
    } else if (id == idBk) { col = vec3 (1., 1., 0.); }
    else if (id == idLeg) { col = (0.5 + 0.4 * sin (100. * qHit.z)) * vec3 (0.6, 0.4, 0.); }
    col.gb *= 0.7;

    // Add an electric rim light during panic/lightning
    float rim = 1.0 - max(dot(n, -sunDir), 0.0);
    rim = pow(rim, 3.0) * uLightning;

    vec3 electricGlow = vec3(0.7, 0.9, 1.0) * rim * 2.0;
    col += electricGlow;

    return vec4 (col, spec);
}

vec4 ShipCol (vec3 n) {
    vec4 col4; vec2 cg;
    if (idObj == idHull) {
        if (abs (qHit.x) < bDeck.x - 0.08 && qHit.y > -3.6 && qHit.z > - bDeck.z + 0.62) {
            col4 = vec4 (0.5, 0.3, 0., 0.1) * (0.5 + 0.5 * SmoothBump (0.05, 0.95, 0.02, mod (8. * qHit.x, 1.)));
        } else if (qHit.y > -4.) {
            col4 = vec4 (0.7, 0.5, 0.1, 0.1);
            if (abs (qHit.z - 4.) < 0.25 && abs (qHit.y + 3.55) < 0.05) col4 *= 1.2;
            else if (qHit.z < -4. && abs (qHit.x) < 0.84 && abs (qHit.y + 3.62) < 0.125) {
                cg = step (0.1, abs (fract (vec2 (6. * qHit.x, 8. * (qHit.y + 3.62)) + 0.5) - 0.5));
                if (cg.x * cg.y == 1.) col4 = vec4 (0.8, 0.8, 0.2, -1.);
                else col4 *= 0.8;
            } else {
                col4 *= 0.7 + 0.3 * SmoothBump (0.05, 0.95, 0.02, mod (8. * qHit.y, 1.));
            }
        } else if (qHit.y > -4.05) { col4 = vec4 (0.8, 0.8, 0.8, 0.1); }
        else { col4 = vec4 (0.3, 0.2, 0.1, 0.); }
    } else if (idObj == idRud) { col4 = vec4 (0.5, 0.3, 0., 0.); }
    else if (idObj == idStruc) {
        col4 = vec4 (0.4, 0.3, 0.1, 0.1);
        if (max (abs (qHit.x), abs (qHit.z + 0.22)) < 0.2) {
            cg = step (0.1, abs (fract (vec2 (10. * vec2 (qHit.x, qHit.z + 0.22)) + 0.5) - 0.5));
            if (cg.x * cg.y == 1.) col4 = vec4 (0.8, 0.8, 0.2, -1.);
        }
    } else if (idObj == idSailT) {
        qHit.x *= (1. + 0.07 * qHit.y) * (1. + 0.14 * step (1., abs (qHit.z)));
        col4 = vec4 (1., 1., 1., 0.) * (0.7 + 0.3 * SmoothBump (0.05, 0.95, 0.02, mod (4. * qHit.x, 1.)));
        if (abs (qHit.z) < 0.2 && abs (abs (length (qHit.xy - vec2 (0., 0.3)) - 0.35) - 0.15) < 0.07) col4 *= vec4 (1., 0.2, 0.2, 1.);
    } else if (idObj == idSailA) { col4 = vec4 (1., 1., 1., 0.) * (0.7 + 0.3 * SmoothBump (0.05, 0.95, 0.02, mod (5. * qHit.z, 1.))); }
    else if (idObj == idSailF) { col4 = vec4 (1., 1., 1., 0.) * (0.7 + 0.3 * SmoothBump (0.05, 0.95, 0.02, mod (2.95 * qHit.y + 4. * qHit.z - 0.5, 1.))); }
    else if (idObj == idFlag) {
        col4 = vec4 (1., 1., 0.5, 0.1);
        if (abs (abs (length (qHit.yz) - 0.1) - 0.04) < 0.02) col4 *= vec4 (1., 0.2, 0.2, 1.);
    } else if (idObj == idMast) {
        col4 = vec4 (0.7, 0.4, 0., 0.1);
        if (length (qHit.xz) < 0.16 * (1. - 0.07 * qHit.y))
        col4 *= 0.6 + 0.4 * SmoothBump (0.03, 0.97, 0.01, mod (2. * qHit.y / (1. + 0.14 * step (1., abs (qHit.z))), 1.));
        if (qHit.y > 3.65) col4 = vec4 (1., 0., 0., -1.);
    } else if (idObj == idSparT) {
        qHit.x *= (1. + 0.07 * qHit.y) * (1. + 0.14 * step (1., abs (qHit.z)));
        col4 = vec4 (0.7, 0.4, 0., 0.1) *  (0.6 + 0.4 * SmoothBump (0.08, 0.92, 0.01, mod (4. * qHit.x, 1.)));
    } else if (idObj == idSparL) {
        col4 = vec4 (0.7, 0.4, 0., 0.1);
        if (qHit.z > 6.65) col4 = vec4 (1., 1., 0.3, -1.);
    } else if (idObj == idRig) { col4 = vec4 (0.2, 0.15, 0.1, 0.); }

    // Lightning reaction (electric rim light + global boost)
    float rim = 1.0 - abs (dot (n, sunDir));
    vec3 electricGlow = vec3 (0.7, 0.9, 1.0) * uLightning;
    col4.rgb = mix(col4.rgb, electricGlow, uLightning * 0.4); // Subtle global tint
    col4.rgb += electricGlow * (pow(rim, 2.0) * 3.0 + 0.5); // Stronger glow

    return col4;
}
float ObjDf (vec3 p) {
    float dHit = dstFar;
    vec3 q = p;
    q.x -= shipPanicShake.x;
    q.y -= shipHeave;
    q.xz = Rot2D (q.xz, shipRot);
    q.yz = Rot2D (q.yz, shipPitch);
    q.xy = Rot2D (q.xy, shipRoll);
    q.y -= shipConf.x + 6.6 * szFac;
    q /= szFac;
    float dShip = dstFar / szFac;
    dShip = ShipHullDf (q, dShip);
    dShip = ShipMastDf (q, dShip);
    dShip = ShipSailDf (q, dShip);
    if (! isRefl) dShip = ShipRigDf (q, dShip);
    dShip *= 0.7 * szFac;
    dHit = min(dHit, dShip);

    idObjGrp = 256; dHit = BirdDf (birdMat[0] * (p - birdPos[0]), dHit);
    idObjGrp = 512; dHit = BirdDf (birdMat[1] * (p - birdPos[1]), dHit);
    return 0.9 * dHit;
}
float ObjRay (vec3 ro, vec3 rd) {
    float d, dHit = 0.;
    for (int j = 0; j < 100; j ++) {
        d = ObjDf (ro + dHit * rd); dHit += d;
        if (d < 0.001 || dHit > dstFar) break;
    }
    return dHit;
}
vec3 ObjNf (vec3 p) {
    vec3 e = vec3 (0.001, -0.001, 0.);
    vec4 v = vec4 (ObjDf (p + e.xxx), ObjDf (p + e.xyy), ObjDf (p + e.yxy), ObjDf (p + e.yyx));
    return normalize (vec3 (v.x - v.y - v.z - v.w) + 2. * vec3 (v.y, v.z, v.w));
}
vec3 ShowScene (vec3 ro, vec3 rd) {
    vec3 vn; vec4 objCol; float dstHit, htWat = -1.5, reflFac = 1.;
    vec3 col = vec3 (0.); idObj = -1; isRefl = false;
    dstHit = ObjRay (ro, rd);
    if (rd.y < 0. && dstHit >= dstFar) {
        isRefl = true;
        float dw = - (ro.y - htWat) / rd.y;
        ro += dw * rd; rd = reflect (rd, WaterNf (ro, dw)); ro += 0.01 * rd;
        idObj = -1; dstHit = ObjRay (ro, rd); reflFac *= 0.7;
    }
    if (idObj < 0 || dstFar <= dstHit) col = reflFac * SkyCol (ro, rd);
    else {
        ro += rd * dstHit; vn = ObjNf (ro);
        objCol = (idObj <= idRig) ? ShipCol(vn) : BirdCol (vn);
        float dif = max (dot (vn, sunDir), 0.);
        col = reflFac * objCol.xyz * (0.2 + max (0., dif) * (dif + objCol.a * pow (max (0., dot (sunDir, reflect (rd, vn))), 128.)));
    }
    return col;
}
vec3 BirdTrack (float t) {
    // Chaotic offset only active during lightning panic; ~95% of frames skip
    // the 3× Noisefv3 calls whose result was multiplied by ~0 anyway.
    vec3 chaoticOffset = vec3(0.0);
    if (uPanic > 0.05) {
        chaoticOffset = vec3(
            Noisefv3(vec3(t, 0.0, 0.0)),
            Noisefv3(vec3(0.0, t, 0.0)),
            Noisefv3(vec3(0.0, 0.0, t))
        ) * uPanic * 2.0;// Birds veer off path by up to 2 units
    }

    t = -t; vec3 bp; float rdTurn = 0.45 * min (fltBox.x, fltBox.z), tC = 0.5 * pi * rdTurn / birdVel;
    vec3 tt = vec3 (fltBox.x - rdTurn, length (fltBox.xy), fltBox.z - rdTurn) * 2. / birdVel;
    float tCyc = 2. * (2. * tt.z + tt.x  + 4. * tC + tt.y), tSeq = mod (t, tCyc), ti[9];
    ti[0] = 0.; ti[1] = tt.z; ti[2] = ti[1] + tC; ti[3] = ti[2] + tt.x; ti[4] = ti[3] + tC;
    ti[5] = ti[4] + tt.z; ti[6] = ti[5] + tC; ti[7] = ti[6] + tt.y; ti[8] = ti[7] + tC;
    float a, h = -fltBox.y, hd = 1., tf, rSeg = -1.;
    if (tSeq > 0.5 * tCyc) { tSeq -= 0.5 * tCyc; h = - h; hd = - hd; }
    vec3 fbR = 1.0 - vec3(rdTurn) / fltBox;
    bp.xz = fltBox.xz; bp.y = h;
    if (tSeq < ti[4]) {
        if (tSeq < ti[1]) { tf = tSeq / ti[1]; bp.xz *= vec2 (1., fbR.z * (2. * tf - 1.)); }
        else if (tSeq < ti[2]) { tf = (tSeq - ti[1]) / tC; rSeg = 0.; bp.xz *= fbR.xz; }
        else if (tSeq < ti[3]) { tf = (tSeq - ti[2]) / tt.x; bp.xz *= vec2 (fbR.x * (1. - 2. * tf), 1.); }
        else { tf = (tSeq - ti[3]) / tC; rSeg = 1.; bp.xz *= fbR.xz * vec2 (-1., 1.); }
    } else {
        if (tSeq < ti[5]) { tf = (tSeq - ti[4]) / tt.z; bp.xz *= vec2 (- 1., fbR.z * (1. - 2. * tf)); }
        else if (tSeq < ti[6]) { tf = (tSeq - ti[5]) / tC; rSeg = 2.; bp.xz *= - fbR.xz; }
        else if (tSeq < ti[7]) { tf = (tSeq - ti[6]) / tt.y; bp.xz *= vec2 (fbR.x * (2. * tf - 1.), - 1.); bp.y = h + 2. * fltBox.y * hd * tf; }
        else { tf = (tSeq - ti[7]) / tC; rSeg = 3.; bp.xz *= fbR.xz * vec2 (1., -1.); bp.y = - h; }
    }
    if (rSeg >= 0.) { a = 0.5 * pi * (rSeg + tf); bp += rdTurn * vec3 (cos (a), 0., sin (a)); }
    bp.y -= -1.1 * fltBox.y;

    return bp + chaoticOffset;
}
void BirdPM (float t) {
    float dt = 1.; bdPos = BirdTrack (t); vec3 bpF = BirdTrack (t + dt), bpB = BirdTrack (t - dt);
    vec3 vel = (bpF - bpB) / (2. * dt); float vy = vel.y; vel.y = 0.;
    vec3 acc = (bpF - 2. * bdPos + bpB) / (dt * dt); acc.y = 0.;
    vec3 va = cross (acc, vel) / length (vel); vel.y = vy;
    float el = -0.7 * asin (vel.y / length (vel));
    vec3 ort = vec3 (el, atan (vel.z, vel.x) - 0.5 * pi, 0.2 * length (va) * sign (va.y)), cr = cos (ort), sr = sin (ort);
    bdMat = mat3 (cr.z, - sr.z, 0., sr.z, cr.z, 0., 0., 0., 1.) *
    mat3 (1., 0., 0., 0., cr.x, - sr.x, 0., sr.x, cr.x) *
    mat3 (cr.y, 0., - sr.y, 0., 1., 0., sr.y, 0., cr.y);
    legAng = pi * clamp (0.4 + 1.5 * el, 0.12, 0.8);
}

// --- REFLECTION LOGIC ---
vec3 RenderPerspectiveReflection(vec2 logicalCoord) {
    float distToHorizon = logicalCoord.y - uWaterY;
    if (distToHorizon < 0.0) return vec3(0.0);

    // 1. VARIABLE JITTER    // Normalized depth: 0 at horizon, 1 at top
    float depthFactor = clamp(distToHorizon / uWaterY, 0.0, 1.0);

    // Ambient wave (always present, independent of lightning)
    float ambientWave = sin(uTime * 0.5 + logicalCoord.x * 0.01) * 0.002;

    // Lightning jitter — gated on uLightning > 0.01. Lightning fires every
    // 6–15 seconds, so 99% of frames previously wasted a Noisefv2() call whose
    // result was multiplied by ~0 anyway. Skipping it saves 2–3% GPU time.
    float lightningJitter = 0.0;
    if (uLightning > 0.01) {
        float timeSpeed = 30.0 * (1.0 + uLightning * 5.0);
        float jitterStrength = mix(0.01, 0.04, depthFactor);
        lightningJitter = Noisefv2(vec2(logicalCoord.y * 2.0, uTime * timeSpeed)) * jitterStrength * uLightning;
    }

    // Combined displacement
    float jitter = ambientWave + lightningJitter;

    // 2. WIDE-TO-NARROW PERSPECTIVE WARP
    // Reduced stretch from 0.45 to 0.30 for tighter reflection spacing
    float stretch = 0.30;
    float vCoord = 1.0 - (distToHorizon / (uSize.y * stretch));

    // --- NARROWING LOGIC ---
    // Calculate how much to narrow the reflection.
    // 0.0 = no narrowing (at horizon), 1.0 = maximum narrowing (far away).
    float narrowingProgress = 1.0 - vCoord;

    // 'strength' controls how drastic the narrowing is.
    // 0.0 = straight reflection, 0.8 = very pointy triangle shape.
    float narrowingStrength = 0.6;
    float currentNarrowing = narrowingProgress * narrowingStrength;

    // Calculate the horizontal UV, centered around 0.0
    float centeredU = (logicalCoord.x / uSize.x) - 0.5;

    // Apply the narrowing effect. As we get further from the horizon,
    // we squeeze the U coordinate towards the center.
    float narrowedU = centeredU * (1.0 - currentNarrowing);

    // Shift back to the 0.0-1.0 range
    float perspectiveWarp = narrowedU + 0.5;
    // --- END NARROWING LOGIC ---

    // --- RIPPLE EFFECT ---
    // Radial wave that emanates from card lock position
    float rippleDisplacement = 0.0;
    if (uRippleTime >= 0.0 && uRippleTime < 2.0) {
        float distToRipple = length(logicalCoord - uRippleOrigin);
        // Wave propagation: rings move outward
        float wave = sin(distToRipple * 10.0 - uRippleTime * 5.0) * 0.01;
        // Fade in at start, fade out with distance and time
        float fadeIn = smoothstep(0.0, 0.1, uRippleTime);
        float fadeOut = 1.0 - smoothstep(0.0, 300.0, distToRipple);
        float timeFade = 1.0 - smoothstep(1.5, 2.0, uRippleTime);
        rippleDisplacement = wave * fadeIn * fadeOut * timeFade;
    }
    // --- END RIPPLE ---

    vec2 distortedUV = vec2(perspectiveWarp + jitter + rippleDisplacement, vCoord);

    // Ensure we don't sample outside bounds
    if (distortedUV.y < 0.0 || distortedUV.y > 1.0 || distortedUV.x < 0.0 || distortedUV.x > 1.0) {
        return vec3(0.0);
    }

    vec4 tex = texture(uTextTexture, distortedUV);

    // 3. FRESNEL-BASED OPACITY
    // Reflections are stronger at grazing angles (further away -> near horizon)
    // depthFactor is 0 at horizon.
    float fresnel = pow(1.0 - depthFactor, 2.0);

    // 4. OVER-EXPOSURE (Neon look)
    // Multiply by a high factor
    // Dynamic Boost from Lightning
    float bloom = 5.0 + (uLightning * 20.0);

    // 5. COLOR GRADING - Water temperature tint
    // Cool cyan tint for water reflection
    vec3 waterTint = vec3(0.6, 0.8, 1.0);
    vec3 gradedColor = mix(tex.rgb, tex.rgb * waterTint, 0.3);

    return gradedColor * tex.a * uTextOpacity * fresnel * bloom;
}

void main() {
    vec2 physCoord = FlutterFragCoord().xy;
    vec2 logicalCoord = physCoord / uPixelRatio;

    // --- Scene Rendering ---
    vec2 sceneCoord = vec2(logicalCoord.x, uSize.y - logicalCoord.y);
    vec2 uv = 2.0 * sceneCoord / uSize.xy - 1.0;
    uv.x *= uSize.x / uSize.y;

    tCur = uTime;
    sunDir = normalize(vec3(-1.0, 0.05, 0.0));
    waterDisp = -0.002 * tCur * vec3(-1.0, 0.0, 1.0);
    cloudDisp = -0.05 * tCur * vec3(1.0, 0.0, 1.0);
    birdLen = 1.2; birdVel = 7.0;
    fltBox = vec3(12.0, 4.0, 12.0);
    szFac = 0.8;
    EvalShipConf();

    BirdPM(tCur); birdMat[0] = bdMat; birdPos[0] = bdPos;
    BirdPM(tCur + 10.0); birdMat[1] = bdMat; birdPos[1] = bdPos;

    mat3 vuMat = mat3(0., 0., 1., 0., 1., 0., -1., 0., 0.);
    vec3 rd = vuMat * normalize(vec3(uv, 2.4));
    vec3 ro = vuMat * vec3(0.0, 4.0, -30.0);

    vec3 col = ShowScene(ro, rd);

    // --- Add Reflection ---
    vec3 reflection = RenderPerspectiveReflection(logicalCoord);

    // Ambient light: The reflection is always slightly visible,
    // but lightning makes it 5x stronger.
    float dynamicBoost = 1.0 + (uLightning * 5.0);

    // Apply lightning to the whole scene color (Blue-ish sky flash)
    col += vec3(0.8, 0.9, 1.0) * uLightning * 0.5;

    // Apply lightning to the reflection
    col += reflection * dynamicBoost;

    fragColor = vec4(col, uOpacity);
}