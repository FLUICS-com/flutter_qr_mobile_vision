package com.github.rmtmckenzie.qrmobilevision;

interface QrCamera {
    void start() throws QrReader.Exception;
    void stop();
    void switchCamera();
    int getOrientation();
    int getWidth();
    int getHeight();
}
