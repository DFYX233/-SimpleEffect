using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShieldInteractive : MonoBehaviour
{
    public Material _material;
    public float scanSpeed;
    public float stopDis = 20f;
    public float hitRange = 2f;
    public float _HitOffsetIntensity = 1.5f;
    public Vector3 HitLimitHeight = new Vector3(2f, 2f, 2f) ;
    public static int MaxHit = 4;
    public GameObject target;
    

    private Vector4[] hitPos = new Vector4[MaxHit];
    private float[] hitDis = new float[MaxHit];
    private int currentIndex = 0;

    private void Update()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            Physics.Raycast(ray, out hit);

            if (hit.collider.gameObject.name == target.name)
            {
                hitPos[currentIndex%MaxHit] = hit.point;
                hitDis[currentIndex%MaxHit] = 0.01f;
                currentIndex++;
            }
            
        }
        _material.SetFloat("_HitArray",MaxHit);
        _material.SetFloat("_HitRange",hitRange);
        _material.SetFloat("_HitOffsetIntensity",_HitOffsetIntensity);
        
        _material.SetVectorArray("_HitPos",hitPos);
        _material.SetVector("_HitLimitHeight", HitLimitHeight);
        _material.SetFloatArray("_HitDistence",hitDis);
        Debug.Log(hitDis[0]);
        for (int i = 0; i < MaxHit; i++)
        {
            if (hitDis[i] != 0)
            {
                
                hitDis[i] += 0.1f * scanSpeed * Time.deltaTime;
            }

            if (hitDis[i] >= stopDis)
            {
                hitDis[i] = 0;
            }
        }
    }
}