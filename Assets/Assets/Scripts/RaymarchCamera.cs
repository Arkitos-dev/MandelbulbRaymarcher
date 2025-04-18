using UnityEngine;

[RequireComponent(typeof(Camera))]
public class RaymarchCamera : MonoBehaviour
{
    public Material mandelbulbMaterial;
    public Material juliaMaterial;
    private Material raymarchMat;
    private bool usingJulia = false;
    [Range(2f, 12f)] public float power = 8f;
    [Range(1, 20)] public int iterations = 8;
    [Range(0.1f, 2f)] public float zoom = 1.0f;
    [Range(32, 1024)] public int maxRaySteps = 512;
    [Range(0, 1)] public float fogDensity = 0.1f;
    [Range(0, 5)] public float rimPower = 2f;
    [Range(0f, 10f)] public float shapeShiftSpeed = 1.5f;
    [Range(0f, 2f)] public float shapeShiftStrength = 0.5f;
    [Range(0f, 2f)] public float scaleOscillation = 0.3f;
    [Range(0f, 1f)] public float shapeMode = 0.0f;
    public float rimIntensity = 0.5f;
    public Vector3 lightDirection = new Vector3(0.8f, 1.2f, -0.6f);
    public Color baseColor = new Color(0.4f, 0.6f, 1f);
    public Color fogColor = Color.black;
    public Color rimColor = Color.black;
    public float mouseSensitivity = 2.0f;
    private Quaternion fractalRotation = Quaternion.identity;
    public float fractalRotationSpeed = 0.5f;
    public float orbitDistance = 3f;
    private float orbitYaw = 0f;
    private float orbitPitch = 0f;


    void Start()
    {
        transform.position = new Vector3(0, 0, -3);
        transform.rotation = Quaternion.identity;

        raymarchMat = mandelbulbMaterial;

        Application.targetFrameRate = 60;
    }

    void Update()
    {   
        if (Input.GetMouseButton(0))
        {
            Cursor.lockState = CursorLockMode.Locked;
            float mouseX = Input.GetAxis("Mouse X");
            float mouseY = Input.GetAxis("Mouse Y");

            orbitYaw += mouseX * mouseSensitivity;
            orbitPitch -= mouseY * mouseSensitivity;
            orbitPitch = Mathf.Clamp(orbitPitch, -89f, 89f);
        }
        else
        {
            Cursor.lockState = CursorLockMode.None;
        }
        if (Input.GetKeyDown(KeyCode.J))
        {
            usingJulia = !usingJulia;
            raymarchMat = usingJulia ? juliaMaterial : mandelbulbMaterial;
        }


        // Zoom with scroll wheel
        float scroll = Input.GetAxis("Mouse ScrollWheel");
        if (scroll != 0f)
        {
            orbitDistance *= 1f - scroll;
            orbitDistance = Mathf.Clamp(orbitDistance, 0.5f, 100f);
        }

        // Convert spherical to cartesian
        Quaternion rotation = Quaternion.Euler(orbitPitch, orbitYaw, 0f);
        Vector3 direction = rotation * Vector3.forward;

        transform.position = -direction * orbitDistance;
        transform.rotation = Quaternion.LookRotation(direction, Vector3.up);
    }



    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (raymarchMat)
        {
            raymarchMat.SetVector("_CamPos", transform.position);
            raymarchMat.SetVector("_CamRight", transform.right);
            raymarchMat.SetVector("_CamUp", transform.up);
            raymarchMat.SetVector("_CamForward", transform.forward);

            Matrix4x4 m = Matrix4x4.Rotate(fractalRotation);
            raymarchMat.SetMatrix("_Rotation", m);
            raymarchMat.SetVector("_Offset", Vector3.zero);

            raymarchMat.SetFloat("_Power", power);
            raymarchMat.SetInt("_Iterations", iterations);
            raymarchMat.SetColor("_BaseColor", baseColor);

            raymarchMat.SetFloat("_Zoom", zoom);
            raymarchMat.SetInt("_MaxSteps", maxRaySteps);

            raymarchMat.SetFloat("_FogDensity", fogDensity);
            raymarchMat.SetFloat("_RimPower", rimPower);
            raymarchMat.SetVector("_LightDir", new Vector4(lightDirection.x, lightDirection.y, lightDirection.z, 0));

            raymarchMat.SetColor("_FogColor", fogColor);
            raymarchMat.SetFloat("_RimIntensity", rimIntensity);
            raymarchMat.SetColor("_RimColor", rimColor);

            raymarchMat.SetFloat("_ShapeShiftSpeed", shapeShiftSpeed);
            raymarchMat.SetFloat("_ShapeShiftStrength", shapeShiftStrength);
            raymarchMat.SetFloat("_ScaleOscillation", scaleOscillation);
            raymarchMat.SetFloat("_ShiftMode", shapeMode);

            Graphics.Blit(src, dest, raymarchMat);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
