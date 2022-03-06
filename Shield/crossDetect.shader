Shader "深度图应用/crossDetect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("Src Mode",Float)=0
        [Enum(UnityEngine.Rendering.BlendMode)]_DesBlend("Des Mode",Float)=0
        [HDR]_IntersectionColor("Intersection Color", Color) = (1,1,0,0)
        _IntersectionWidth("Intersection Width", Range(0, 1)) = 0.1
        _Alpha("Alpha",Float)=1
        _Fresnal("Fresnal",Float)=1
        [HDR]_FresnalColor("FresnalColor",Color)=(1,1,1,1)
        _Noise("Noise Map",2D)="gray"{}
        _NoiseSpeed("Noise Speed",Float)=0.1
        _NoiseScale("Noise Scale",Float)=0.1
        _VertexOffsetTex("VertexOffsetTex",2D)="gray"{}
        _VertexOffsetIntensity("VertexOffsetIntensity",Float)=0.1
        _VertexOffsetSpeed("VertexOffsetSpeed",Float)=0.1
        _FixedFactor("TesselltionFactor",Float)=5
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" "ForceNoShadowCasting"="True"
            "IgnoreProjector"="True"
        }
        LOD 100
        GrabPass
        {
            "_RefractionTex"
        }

        Pass
        {
            Tags
            {
                "LightMode"="ForwardBase"
            }
            ZWrite Off Cull Back

            Blend [_SrcBlend] [_DesBlend]
            CGPROGRAM
            #pragma vertex tessvert
            #pragma fragment frag
            #pragma hull HullProgarm
            #pragma domain ds

            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD1;
                float eyeZ : TEXCOORD2;
                float3 worldNor :TEXCOORD3;
                float3 worldPos:TEXCOORD4;
                float2 noiseUV : TEXCOORD5;
                float4 screenGrabPos : TEXCOORD6;
                float4 temp : TEXCOORD7;
            };

            struct TessellationFactor
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            struct ControPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _CameraDepthTexture;
            float _IntersectionWidth;
            fixed4 _IntersectionColor;
            float _Alpha;
            float _Fresnal;
            fixed4 _FresnalColor;
            sampler2D _Noise;
            float4 _Noise_ST;
            float _NoiseSpeed;
            float _NoiseScale;
            sampler2D _RefractionTex;
            float4 _RefractionTex_TexelSize;
            fixed4 _RefractionTex_ST;
            float _VertexOffsetIntensity;
            float _FixedFactor;
            sampler2D _VertexOffsetTex;
            float4 _VertexOffsetTex_ST;
            float _VertexOffsetSpeed;

            //交互参数
            float _HitArray;
            float3 _HitPos[10];
            float _HitRange;
            float _HitDistence[10];
            float _HitOffsetIntensity;
            float3 _HitLimitHeight;

            v2f vert(appdata v)
            {
                v2f o;
                float2 vertexOffsetUV = v.uv * _VertexOffsetTex_ST.xy + _VertexOffsetTex_ST.zw;
                float VertexOffset = tex2Dlod(_VertexOffsetTex,
                                              float4(vertexOffsetUV + frac(_Time.x * _VertexOffsetSpeed), 0, 0));
                v.vertex.xyz += v.normal * _VertexOffsetIntensity * VertexOffset;
                float temp[4] = {1, 1, 1, 1};

                float dis = 0;
                for (int i = 0; i < _HitArray; i++)
                {
                    if (_HitDistence[i] == 0)
                        continue;
                    float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                    dis = length(worldPos - _HitPos[i]);

                    float halfWidth = _HitRange / 2;
                    temp[i] = saturate(abs(dis - _HitDistence[i]) / halfWidth);
                    float3 offset = v.vertex.xyz + v.normal * _HitOffsetIntensity;
                    v.vertex.xyz = lerp(offset, v.vertex, temp[i]);
                }


                o.temp = float4(temp[0], temp[1], temp[2], temp[3]);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.noiseUV = v.uv * _Noise_ST.xy + frac(_Noise_ST.zw + _Time.x * _NoiseSpeed);
                o.screenPos = ComputeScreenPos(o.pos);
                o.screenGrabPos = ComputeGrabScreenPos(o.pos);
                o.worldNor = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                COMPUTE_EYEDEPTH(o.screenPos.z);
                return o;
            }

            ControPoint tessvert(appdata v)
            {
                ControPoint o;
                o.vertex = v.vertex;
                o.uv = v.uv;
                o.normal = v.normal;
                return o;
            }

            TessellationFactor hs(InputPatch<ControPoint, 3> v)
            {
                TessellationFactor o;
                o.edge[0] = _FixedFactor;
                o.edge[1] = _FixedFactor;
                o.edge[2] = _FixedFactor;
                o.inside = _FixedFactor;
                return o;
            }

            [UNITY_domain("tri")]
            [UNITY_partitioning("fractional_odd")]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_patchconstantfunc("hs")]
            [UNITY_outputcontrolpoints(3)]
            ControPoint HullProgarm(InputPatch<ControPoint, 3> v, uint id :SV_OutputControlPointID)
            {
                return v[id];
            }

            [UNITY_domain("tri")]
            v2f ds(TessellationFactor tessFactor, const OutputPatch<ControPoint, 3> vi, float3 bary :SV_DomainLocation)
            {
                appdata v;

                v.vertex = vi[0].vertex * bary.x + vi[1].vertex * bary.y + vi[2].vertex * bary.z;
                v.normal = vi[0].normal * bary.x + vi[1].normal * bary.y + vi[2].normal * bary.z;
                v.uv = vi[0].uv * bary.x + vi[1].uv * bary.y + vi[2].uv * bary.z;
                v2f o = vert(v);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float fresnal = pow(1 - saturate(dot(viewDir, i.worldNor)), _Fresnal);
                float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos));




                float4 offset = tex2D(_Noise, i.noiseUV);
                float4 bumpColor1 = tex2D(_Noise, i.noiseUV + offset  + float2(_NoiseSpeed * _Time.x * _Time.x, 0));
                float4 bumpColor2 = tex2D(
                    _Noise, offset + float2(1 - i.noiseUV.y, i.noiseUV.x) + float2(
                        _NoiseSpeed * _Time.x * _Time.x, 0));
                float3 normal = UnpackNormal((bumpColor1 + bumpColor2) / 2).xyz;

                float subTemp = (1 - i.temp[0]) + (1 - i.temp[1]) + (1 - i.temp[2]) + (1 - i.temp[3]);
                subTemp = clamp(0, 1, subTemp);

                i.screenGrabPos.x = i.screenGrabPos.x + normal.r * _NoiseScale + subTemp;
                i.screenGrabPos.y = i.screenGrabPos.y + normal.g * _NoiseScale + subTemp;
                col = tex2Dproj(_RefractionTex, i.screenGrabPos);


                depth = LinearEyeDepth(depth);
                float halfWidth = _IntersectionWidth / 2;
                float diff = saturate(abs(i.screenPos.z - depth) / halfWidth);
                col = col + fresnal * _FresnalColor;
                fixed3 finalColor = lerp(_IntersectionColor.rgb, col.rgb, diff);

                return fixed4(finalColor, _Alpha);
            }
            ENDCG
        }
        Pass
        {
            ZWrite Off Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex tessvert
            #pragma fragment frag
            #pragma hull HullProgarm
            #pragma domain ds

            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD1;
                float eyeZ : TEXCOORD2;
                float3 worldNor :TEXCOORD3;
                float3 worldPos:TEXCOORD4;
                float2 noiseUV : TEXCOORD5;
                float4 screenGrabPos : TEXCOORD6;
                float4 temp : TEXCOORD7;
            };

            struct TessellationFactor
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            struct ControPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _CameraDepthTexture;
            float _IntersectionWidth;
            fixed4 _IntersectionColor;
            float _Alpha;
            float _Fresnal;
            fixed4 _FresnalColor;
            sampler2D _Noise;
            float4 _Noise_ST;
            float _NoiseSpeed;
            float _isOpenNoise;
            float _NoiseScale;
            sampler2D _RefractionTex;
            float4 _RefractionTex_TexelSize;
            fixed4 _RefractionTex_ST;
            float _VertexOffsetIntensity;
            float _FixedFactor;
            sampler2D _VertexOffsetTex;
            float4 _VertexOffsetTex_ST;
            float _VertexOffsetSpeed;

            float _HitArray;
            float3 _HitPos[10];
            float _HitRange;
            float _HitDistence[10];
            float _HitOffsetIntensity;
            float3 _HitLimitHeight;

            v2f vert(appdata v)
            {
                v2f o;
                float2 vertexOffsetUV = v.uv * _VertexOffsetTex_ST.xy + _VertexOffsetTex_ST.zw;
                float VertexOffset = tex2Dlod(_VertexOffsetTex,
                                              float4(vertexOffsetUV + frac(_Time.x * _VertexOffsetSpeed), 0, 0)).g;
                v.vertex.xyz += v.normal * _VertexOffsetIntensity * VertexOffset;
                float temp[4] = {1, 1, 1, 1};
                float dis = 0;
                for (int i = 0; i < _HitArray; i++)
                {
                    if (_HitDistence[i] == 0)
                        continue;
                    float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                    dis = length(worldPos - _HitPos[i]);

                    float halfWidth = _HitRange / 2;
                    temp[i] = saturate(abs(dis - _HitDistence[i]) / halfWidth);
                    float3 offset = v.vertex.xyz + v.normal * _HitOffsetIntensity;

                    v.vertex.xyz = lerp(offset, v.vertex, temp[i]);
                }


                o.temp = float4(temp[0], temp[1], temp[2], temp[3]);


                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.noiseUV = v.uv * _Noise_ST.xy + frac(_Noise_ST.zw + _Time.x * _NoiseSpeed);
                o.screenPos = ComputeScreenPos(o.pos);
                o.screenGrabPos = ComputeGrabScreenPos(o.pos);
                o.worldNor = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                COMPUTE_EYEDEPTH(o.screenPos.z);
                return o;
            }

            ControPoint tessvert(appdata v)
            {
                ControPoint o;
                o.vertex = v.vertex;
                o.uv = v.uv;
                o.normal = v.normal;
                return o;
            }

            TessellationFactor hs(InputPatch<ControPoint, 3> v)
            {
                TessellationFactor o;
                o.edge[0] = _FixedFactor;
                o.edge[1] = _FixedFactor;
                o.edge[2] = _FixedFactor;
                o.inside = _FixedFactor;
                return o;
            }

            [UNITY_domain("tri")]
            [UNITY_partitioning("fractional_odd")]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_patchconstantfunc("hs")]
            [UNITY_outputcontrolpoints(3)]
            ControPoint HullProgarm(InputPatch<ControPoint, 3> v, uint id :SV_OutputControlPointID)
            {
                return v[id];
            }

            [UNITY_domain("tri")]
            v2f ds(TessellationFactor tessFactor, const OutputPatch<ControPoint, 3> vi, float3 bary :SV_DomainLocation)
            {
                appdata v;

                v.vertex = vi[0].vertex * bary.x + vi[1].vertex * bary.y + vi[2].vertex * bary.z;
                v.normal = vi[0].normal * bary.x + vi[1].normal * bary.y + vi[2].normal * bary.z;
                v.uv = vi[0].uv * bary.x + vi[1].uv * bary.y + vi[2].uv * bary.z;
                v2f o = vert(v);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float fresnal = pow(1 - saturate(dot(viewDir, i.worldNor)), _Fresnal);
                float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos));


                depth = LinearEyeDepth(depth);
                float halfWidth = _IntersectionWidth / 2;
                float diff = saturate(abs(i.screenPos.z - depth) / halfWidth);
                col = col + fresnal * _FresnalColor;
                fixed3 finalColor = lerp(_IntersectionColor.rgb, col.rgb, diff);

                return fixed4(finalColor, _Alpha);
            }
            ENDCG
        }
    }
}