package com.github.rmtmckenzie.qrmobilevision;
import android.graphics.Rect;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CaptureRequest;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.math.MathUtils;

public final class CameraZoom {
    private static final float DEFAULT_ZOOM_FACTOR = 1.0f;

    public static final float ZOOM_1X = 1.0f;
    public static final float ZOOM_2X = 2.0f;
    public static final float ZOOM_4X = 4.0f;

    @NonNull
    private final Rect mCropRegion = new Rect();

    public final float maxZoom;

    @Nullable
    private final Rect mSensorSize;

    public final boolean hasSupport;

    public CameraZoom(@NonNull final CameraCharacteristics characteristics) {
        this.mSensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE);

        if (this.mSensorSize == null) {
            this.maxZoom = CameraZoom.DEFAULT_ZOOM_FACTOR;
            this.hasSupport = false;
            return;
        }

        final Float value = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);

        this.maxZoom = ((value == null) || (value < CameraZoom.DEFAULT_ZOOM_FACTOR))
            ? CameraZoom.DEFAULT_ZOOM_FACTOR
            : value;

        this.hasSupport = (Float.compare(this.maxZoom, CameraZoom.DEFAULT_ZOOM_FACTOR) > 0);
    }

    public void setZoom(@NonNull final CaptureRequest.Builder builder, final float zoom) {
        if (!this.hasSupport) {
            return;
        }

        final float newZoom = MathUtils.clamp(zoom, CameraZoom.DEFAULT_ZOOM_FACTOR, this.maxZoom);

        final int centerX = this.mSensorSize.width() / 2;
        final int centerY = this.mSensorSize.height() / 2;
        final int deltaX = (int) ((0.5f * this.mSensorSize.width()) / newZoom);
        final int deltaY = (int) ((0.5f * this.mSensorSize.height()) / newZoom);

        this.mCropRegion.set(centerX - deltaX,
            centerY - deltaY,
            centerX + deltaX,
            centerY + deltaY);

        builder.set(CaptureRequest.SCALER_CROP_REGION, this.mCropRegion);
    }
}
