package com.github.rmtmckenzie.qrmobilevision;


import java.util.List;
import java.util.Map;

public interface QrReaderCallbacks {
    void qrRead(List<Map<String, Object>> data);
}
