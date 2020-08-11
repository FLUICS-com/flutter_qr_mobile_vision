package com.github.rmtmckenzie.qrmobilevision;

interface QrCamera {
    void start() throws QrReader.Exception;
    void stop();
    int getOrientation();
    int getWidth();
    int getHeight();
    void toggleTorch();
    float getZoomFactor();
    int getCameraLensFacing();
    void setZoomFactor(Float zoomFactor);
    void setCameraLensFacing(Integer cameraLensFacing);
}
