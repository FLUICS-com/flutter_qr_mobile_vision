package com.github.rmtmckenzie.qrmobilevision;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.ImageFormat;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.util.Log;
import android.util.Size;
import android.util.SparseIntArray;
import android.view.Surface;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import com.google.android.gms.vision.Frame;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;

import static android.hardware.camera2.CameraMetadata.CONTROL_AF_MODE_AUTO;
import static android.hardware.camera2.CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE;
import static android.hardware.camera2.CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO;
import static android.hardware.camera2.CameraMetadata.LENS_FACING_BACK;
import static android.hardware.camera2.CameraMetadata.LENS_FACING_FRONT;
import static com.github.rmtmckenzie.qrmobilevision.CameraZoom.ZOOM_1X;
import static com.github.rmtmckenzie.qrmobilevision.CameraZoom.ZOOM_2X;
import static com.github.rmtmckenzie.qrmobilevision.CameraZoom.ZOOM_4X;

/**
 * Implements QrCamera using Camera2 API
 */
@TargetApi(21)
@RequiresApi(21)
class QrCameraC2 implements QrCamera {

    private static final String TAG = "cgr.qrmv.QrCameraC2";
    private static final SparseIntArray ORIENTATIONS = new SparseIntArray();

    static {
        ORIENTATIONS.append(Surface.ROTATION_0, 90);
        ORIENTATIONS.append(Surface.ROTATION_90, 0);
        ORIENTATIONS.append(Surface.ROTATION_180, 270);
        ORIENTATIONS.append(Surface.ROTATION_270, 180);
    }

    private final int targetWidth;
    private final int targetHeight;
    private final Context context;
    private final SurfaceTexture texture;
    private Size size;
    private ImageReader reader;
    private CaptureRequest.Builder previewBuilder;
    private CameraCaptureSession previewSession;
    private Size[] jpegSizes = null;
    private QrDetector2 detector;
    private int sensorOrientation;
    private CameraDevice cameraDevice;
    private CameraCharacteristics cameraCharacteristics;
    private Integer cameraLensFacing;
    private boolean isFlashSupported;
    private boolean isTorchOn;
    private CameraZoom cameraZoom;
    private float zoomFactor;

    QrCameraC2(int width, int height, float zoomFactor, int cameraLensFacing, SurfaceTexture texture, Context context, QrDetector2 detector) {
        this.targetWidth = width;
        this.targetHeight = height;
        this.context = context;
        this.texture = texture;
        this.detector = detector;
        this.zoomFactor = zoomFactor;
        this.cameraLensFacing = cameraLensFacing;
    }

    @Override
    public int getWidth() {
        return size.getWidth();
    }

    @Override
    public int getHeight() {
        return size.getHeight();
    }

    @Override
    public int getOrientation() {
        // ignore sensor orientation of devices with 'reverse landscape' orientation of sensor
        // as camera2 api seems to already rotate the output.
        return sensorOrientation == 270 ? 90 : sensorOrientation;
    }

    @Override
    public void toggleTorch() {
        try {
            if (isFlashSupported) {
                if (isTorchOn) {
                    previewBuilder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_OFF);
                    isTorchOn = false;
                } else {
                    previewBuilder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_TORCH);
                    isTorchOn = true;
                }
            }
            previewSession.setRepeatingRequest(previewBuilder.build(), null, null);
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }

    }

    @Override
    public float getZoomFactor() {
        return zoomFactor;
    }

    @Override
    public int getCameraLensFacing() {
        return cameraLensFacing;
    }

    @Override
    public void setZoomFactor(Float zoomFactor) {
        if (zoomFactor != null) {
            if (zoomFactor == ZOOM_1X) {
                this.zoomFactor = ZOOM_1X;
            } else if (zoomFactor == ZOOM_2X) {
                this.zoomFactor = ZOOM_2X;
            } else if (zoomFactor == ZOOM_4X) {
                this.zoomFactor = ZOOM_4X;
            } else {
                return;
            }
            try {
                cameraZoom.setZoom(previewBuilder, zoomFactor);
                previewSession.setRepeatingRequest(previewBuilder.build(), null, null);
            } catch (CameraAccessException e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public void setCameraLensFacing(Integer cameraLensFacing) {
        if (cameraLensFacing != null) {
            switch (cameraLensFacing) {
                case LENS_FACING_BACK:
                    this.cameraLensFacing = LENS_FACING_BACK;
                    break;
                case LENS_FACING_FRONT:
                    this.cameraLensFacing = LENS_FACING_FRONT;
                    break;
                default:
                    return;
            }
            cameraDevice.close();
            try {
                start();
            } catch (QrReader.Exception e) {
                e.printStackTrace();
            }
        }
    }


    private int getFrameOrientation() {
        WindowManager windowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        int deviceRotation = windowManager.getDefaultDisplay().getRotation();
        int rotationCompensation = (ORIENTATIONS.get(deviceRotation) + sensorOrientation + 270) % 360;

        int result;
        switch (rotationCompensation) {
            case 0:
                result = Frame.ROTATION_0;
                break;
            case 90:
                result = Frame.ROTATION_90;
                break;
            case 180:
                result = Frame.ROTATION_180;
                break;
            case 270:
                result = Frame.ROTATION_270;
                break;
            default:
                result = Frame.ROTATION_0;
                Log.e(TAG, "Bad rotation value: " + rotationCompensation);
        }
        return result;
    }


    @Override
    public void start() throws QrReader.Exception {
        CameraManager manager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);

        if (manager == null) {
            throw new RuntimeException("Unable to get camera manager.");
        }

        String cameraId = null;
        try {
            String[] cameraIdList = manager.getCameraIdList();
            for (String id : cameraIdList) {
                CameraCharacteristics cameraCharacteristics = manager.getCameraCharacteristics(id);
                Integer integer = cameraCharacteristics.get(CameraCharacteristics.LENS_FACING);
                if (integer != null && integer.equals(cameraLensFacing)) {
                    cameraId = id;
                    break;
                }
            }
        } catch (CameraAccessException e) {
            Log.w(TAG, "Error getting back camera.", e);
            throw new RuntimeException(e);
        }

        if (cameraId == null) {
            throw new QrReader.Exception(QrReader.Exception.Reason.noBackCamera);
        }

        try {
            cameraCharacteristics = manager.getCameraCharacteristics(cameraId);
            StreamConfigurationMap map = cameraCharacteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            Integer sensorOrientationInteger = cameraCharacteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
            sensorOrientation = sensorOrientationInteger == null ? 0 : sensorOrientationInteger;
            Boolean available = cameraCharacteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
            isFlashSupported = available == null ? false : available;
            cameraZoom = new CameraZoom(cameraCharacteristics);

            size = getAppropriateSize(map.getOutputSizes(SurfaceTexture.class));
            jpegSizes = map.getOutputSizes(ImageFormat.JPEG);
            manager.openCamera(cameraId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(@NonNull CameraDevice device) {
                    cameraDevice = device;
                    startCamera();
                }

                @Override
                public void onDisconnected(@NonNull CameraDevice device) {
                }

                @Override
                public void onError(@NonNull CameraDevice device, int error) {
                    Log.w(TAG, "Error opening camera: " + error);
                }
            }, null);
        } catch (CameraAccessException e) {
            Log.w(TAG, "Error getting camera configuration.", e);
        }
    }

    private Integer afMode(CameraCharacteristics cameraCharacteristics) {

        int[] afModes = cameraCharacteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);

        if (afModes == null) {
            return null;
        }

        HashSet<Integer> modes = new HashSet<>(afModes.length * 2);
        for (int afMode : afModes) {
            modes.add(afMode);
        }

        if (modes.contains(CONTROL_AF_MODE_CONTINUOUS_VIDEO)) {
            return CONTROL_AF_MODE_CONTINUOUS_VIDEO;
        } else if (modes.contains(CONTROL_AF_MODE_CONTINUOUS_PICTURE)) {
            return CONTROL_AF_MODE_CONTINUOUS_PICTURE;
        } else if (modes.contains(CONTROL_AF_MODE_AUTO)) {
            return CONTROL_AF_MODE_AUTO;
        } else {
            return null;
        }
    }

    private void initAutoFocus() {
        Integer afMode = afMode(cameraCharacteristics);

        if (afMode != null) {
            previewBuilder.set(CaptureRequest.CONTROL_AF_MODE, afMode);
            Log.i(TAG, "Setting af mode to: " + afMode);
            if (afMode == CONTROL_AF_MODE_AUTO) {
                previewBuilder.set(
                    CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START);
            } else {
                previewBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_CANCEL);
            }
        }
    }


    private void startCamera() {
        List<Surface> list = new ArrayList<>();

        Size jpegSize = getAppropriateSize(jpegSizes);

        final int width = jpegSize.getWidth(), height = jpegSize.getHeight();
        reader = ImageReader.newInstance(width, height, ImageFormat.YUV_420_888, 5);

        list.add(reader.getSurface());

        ImageReader.OnImageAvailableListener imageAvailableListener = new ImageReader.OnImageAvailableListener() {
            @Override
            public void onImageAvailable(ImageReader reader) {
                try (Image image = reader.acquireLatestImage()) {
                    if (image == null) return;
                    detector.detect(image, getFrameOrientation());
                } catch (Throwable t) {
                    t.printStackTrace();
                }
            }
        };

        reader.setOnImageAvailableListener(imageAvailableListener, null);

        texture.setDefaultBufferSize(size.getWidth(), size.getHeight());
        list.add(new Surface(texture));
        try {
            previewBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            previewBuilder.addTarget(list.get(0));
            previewBuilder.addTarget(list.get(1));

            Integer afMode = afMode(cameraCharacteristics);

            previewBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO);
            cameraZoom.setZoom(previewBuilder, zoomFactor);

        } catch (java.lang.Exception e) {
            e.printStackTrace();
            return;
        }

        try {
            cameraDevice.createCaptureSession(list, new CameraCaptureSession.StateCallback() {
                @Override
                public void onConfigured(@NonNull CameraCaptureSession session) {
                    previewSession = session;
                    startPreview();
                }

                @Override
                public void onConfigureFailed(@NonNull CameraCaptureSession session) {
                    System.out.println("### Configuration Fail ###");
                }
            }, null);
        } catch (Throwable t) {
            t.printStackTrace();

        }
    }

    private void startPreview() {
        CameraCaptureSession.CaptureCallback listener = new CameraCaptureSession.CaptureCallback() {
            @Override
            public void onCaptureCompleted(@NonNull CameraCaptureSession session, @NonNull CaptureRequest request, @NonNull TotalCaptureResult result) {
                super.onCaptureCompleted(session, request, result);
            }
        };

        if (cameraDevice == null) return;

        try {
            previewSession.setRepeatingRequest(previewBuilder.build(), listener, null);

            initAutoFocus();

        } catch (java.lang.Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void stop() {
        if (cameraDevice != null) {
            cameraDevice.close();
        }
        if (reader != null) {
            reader.close();
        }
    }

    private Size getAppropriateSize(Size[] sizes) {
        // assume sizes is never 0
        if (sizes.length == 1) {
            return sizes[0];
        }

        Size s = sizes[0];
        Size s1 = sizes[1];

        if (s1.getWidth() > s.getWidth() || s1.getHeight() > s.getHeight()) {
            // ascending
            if (sensorOrientation % 180 == 0) {
                for (Size size : sizes) {
                    s = size;
                    if (size.getHeight() > targetHeight && size.getWidth() > targetWidth) {
                        break;
                    }
                }
            } else {
                for (Size size : sizes) {
                    s = size;
                    if (size.getHeight() > targetWidth && size.getWidth() > targetHeight) {
                        break;
                    }
                }
            }
        } else {
            // descending
            if (sensorOrientation % 180 == 0) {
                for (Size size : sizes) {
                    if (size.getHeight() < targetHeight || size.getWidth() < targetWidth) {
                        break;
                    }
                    s = size;
                }
            } else {
                for (Size size : sizes) {
                    if (size.getHeight() < targetWidth || size.getWidth() < targetHeight) {
                        break;
                    }
                    s = size;
                }
            }
        }
        return s;
    }
}
