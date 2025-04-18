Shader "Raymarch/MandelbulbStatic"
{
    Properties {
        _CamPos ("Camera Position", Vector) = (0,0,0,0)
        _Power ("Mandelbulb Power", Range(2, 12)) = 8
        _Iterations ("Raymarch Iterations", Int) = 8
        _BaseColor ("Base Color", Color) = (0.4, 0.6, 1.0, 1)
        _Zoom ("Fractal Zoom", Float) = 1.0
        _MaxSteps ("Max Raymarch Steps", Int) = 512
        _FogDensity ("Fog Density", Range(0, 1)) = 0.1
        _RimPower ("Rim Lighting Power", Range(0, 5)) = 2.0
        _LightDir ("Light Direction", Vector) = (0.8, 1.2, -0.6, 0)
        _FogColor ("Fog Color", Color) = (0, 0, 0, 1)
        _RimIntensity ("Rim Intensity", Range(0, 2)) = 0.5
        _RimColor ("Rim Color", Color) = (0.4, 0.2, 0.8)
        _ShapeShiftSpeed ("Shape Shift Speed", Float) = 1.5
        _ShapeShiftStrength ("Shape Shift Strength", Float) = 0.5
        _ScaleOscillation ("Scale Oscillation Amount", Float) = 0.3
        _ShiftMode ("Phi Distort Mode", Range(0,1)) = 1

    }

    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float3 _CamPos;
            float3 _CamRight;
            float3 _CamUp;
            float3 _CamForward;
            float4x4 _Rotation;
            float3 _Offset;
            float _Power;
            int _Iterations;
            float4 _BaseColor;
            float _Zoom;
            int _MaxSteps;
            float _FogDensity;
            float _RimPower;
            float4 _LightDir;
            float4 _FogColor;
            float _RimIntensity;
            float4 _RimColor;
            float _ShapeShiftSpeed;
            float _ShapeShiftStrength;
            float _ScaleOscillation;
            float _ShiftMode;


            struct appdata {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f {
                float2 uv     : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float3 rotateQuat(float3 v, float angle, float3 axis)
            {
                float s = sin(angle * 0.5);
                float c = cos(angle * 0.5);
                float3 qv = axis * s;
                float qw = c;

                // Quaternion rotation: v' = q * v * q⁻¹
                return v + 2.0 * cross(qv, cross(qv, v) + qw * v);
            }

            float3 palette(float t)
            {
                // Based on IQ's palette function
                float3 a = float3(0.5, 0.5, 0.5);
                float3 b = float3(0.5, 0.5, 0.5);
                float3 c = float3(1.0, 1.0, 1.0);
                float3 d = float3(0.00, 0.33, 0.67); // phase offset

                return a + b * cos(6.28318 * (c * t + d));
            }

            float mandelbulbDE(float3 pos)
            {
                float3 z = pos;
                float dr = 1.0;
                float r = 0.0;

                for (int i = 0; i < _Iterations; ++i)
                {
                    r = length(z);
                    if (r > 4.0) break;

                    float safeZ = clamp(z.z / r, -1.0, 1.0);
                    float theta = acos(safeZ);
                    float phi = atan2(z.y, z.x);

                    float shift = sin(_Time.y * _ShapeShiftSpeed + z.x * 2.0 + z.y * 1.5 + z.z * 1.2) * _ShapeShiftStrength;
                    float dynamicPower = _Power + shift;

                    float scale = 1.0 + _ScaleOscillation * sin(_Time.y + r * 2.0);
                    z *= scale;

                    float zr = pow(r, dynamicPower);
                    dr = pow(r, dynamicPower - 1.0) * dynamicPower * dr + 1.0;

                    theta *= dynamicPower;
                    float phiWarp = cos(_Time.y * 0.8 + z.y * 1.5) * 0.3;
                    phi = lerp(phi * dynamicPower, phi + phiWarp, _ShiftMode);

                    z = zr * float3(
                        sin(theta) * cos(phi),
                        sin(theta) * sin(phi),
                        cos(theta)
                    ) + pos;
            }

            return 0.5 * log(r) * r / dr;
        }


            float map(float3 p) {
                float3 localP = (p - _Offset) * _Zoom;
                localP = mul(_Rotation, localP);
                return mandelbulbDE(localP);
            }

            float3 getNormal(float3 p) {
                float eps = 0.001;
                float3 n = float3(
                    map(p + float3(eps, 0, 0)) - map(p - float3(eps, 0, 0)),
                    map(p + float3(0, eps, 0)) - map(p - float3(0, eps, 0)),
                    map(p + float3(0, 0, eps)) - map(p - float3(0, 0, eps))
                );
                return normalize(n);
            }

            float calcAO(float3 p, float3 normal)
            {
                float ao = 0.0;
                float sca = 1.0;
                for (int i = 0; i < 5; i++)
                {
                    float h = 0.01 + 0.02 * i;
                    float d = map(p + normal * h);
                    ao += (h - d) * sca;
                    sca *= 0.75;
                }
                return saturate(1.0 - 2.0 * ao);
            }

            float softShadow(float3 ro, float3 rd)
            {
                float shadow = 1.0;
                float t = 0.02;
                for (int i = 0; i < 32; i++)
                {
                    float3 p = ro + rd * t;
                    float h = map(p);
                    if (h < 0.001) return 0.0;
                    shadow = min(shadow, 8.0 * h / t);
                    t += h;
                    if (t > 10.0) break;
                }
                return saturate(shadow);
            }

            float3 getRayDir(float2 uv) {
                uv = uv * 2.0 - 1.0;
                uv.x *= _ScreenParams.x / _ScreenParams.y;
                return normalize(uv.x * _CamRight + uv.y * _CamUp + _CamForward);
            }

            fixed4 frag(v2f i) : SV_Target {
                
                float3 ro = _CamPos;
                float3 rd = getRayDir(i.uv);

                float t = 0.1;
                float d = 0.0;
                int stepCount = 0;

                for (int steps = 0; steps < _MaxSteps; ++steps) {
                    float3 p = ro + rd * t;
                    d = map(p);
                    if (d < 0.00001 || t > 200.0) break;
                    t += d;
                    stepCount = steps;
                }

                if (t > 200.0) return float4(0, 0, 0, 1);

                float fade = stepCount / (float)_MaxSteps;
                fade = pow(fade, 0.5); // Smoother fade curve

                float3 hitPos = ro + rd * t;
                float3 normal = getNormal(hitPos);

                // Lighting
                float3 worldLightDir = normalize(_LightDir.xyz);
                float3 lightDir = mul((float3x3)_Rotation, worldLightDir);
                float diff = max(dot(normal, lightDir), 0.0);

                float shadow = softShadow(hitPos + normal * 0.01, lightDir);
                float ao = calcAO(hitPos, normal);

                // Animated color palette
                float tColor = frac(_Time.y * 0.1 + stepCount * 0.01); // time + steps
                float3 paletteCol = palette(tColor);
                float3 baseColor = lerp(_BaseColor.rgb, paletteCol, 0.7);
                float3 ambient = 0.1 * baseColor;
                float3 color = baseColor * diff * shadow + ambient;

                // Rim lighting
                float rimDot = dot(rd, normal);
                float rim = pow(1.0 - saturate(rimDot), _RimPower);
                color += rim * _RimIntensity * _RimColor;

                // Fog
                float fog = saturate(t * _FogDensity);
                color = lerp(color, _FogColor.rgb, fog);

                // Ripple
                //float ripple = sin(length(hitPos.xy) * 10.0 - _Time.y * 5.0) * 0.5 + 0.5;
                //color += ripple * 0.1 * float3(0.2, 0.5, 1.0); // bluish ripple highlight

                color *= ao;
                color *= fade;


                return float4(color, 1.0);
            }
            ENDCG
        }
    }
}
