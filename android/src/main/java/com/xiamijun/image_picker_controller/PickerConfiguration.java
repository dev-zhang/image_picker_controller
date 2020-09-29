package com.xiamijun.image_picker_controller;

import java.util.Map;

public class PickerConfiguration {
    public int maxImageCount;
    public boolean allowCrop;
    public int videoMaxDuration;
    public boolean allowTakePicture;
    public boolean allowTakeVideo;
    public boolean allowPickingOriginalPhoto;
    public boolean allowPickingVideo;
    public boolean allowPickingImage;

    public static PickerConfiguration fromMap(Map map) {

        PickerConfiguration config = new PickerConfiguration();
        if (map == null) {
            return config;
        }
        if (map.get("allowCrop") != null) {
            config.allowCrop = (boolean) map.get("allowCrop");
        }
        if (map.get("maxImageCount") != null) {
            config.maxImageCount = (int) map.get("maxImageCount");
        }

        if (map.get("videoMaxDuration") != null) {
            config.videoMaxDuration = (int) map.get("videoMaxDuration");
        }
        if (map.get("allowTakePicture") != null) {
            config.allowTakePicture = (boolean) map.get("allowTakePicture");
        }
        if (map.get("allowTakeVideo") != null) {
            config.allowTakeVideo = (boolean) map.get("allowTakeVideo");
        }
        if (map.get("allowPickingOriginalPhoto") != null) {
            config.allowPickingOriginalPhoto = (boolean) map.get("allowPickingOriginalPhoto");
        }
        if (map.get("allowPickingVideo") != null) {
            config.allowPickingVideo = (boolean) map.get("allowPickingVideo");
        }
        if (map.get("allowPickingImage") != null) {
            config.allowPickingImage = (boolean) map.get("allowPickingImage");
        }
        return config;
    }

    @Override
    public String toString() {
        return "PickerConfiguration{" +
                "maxImageCount=" + maxImageCount +
                ", allowCrop=" + allowCrop +
                ", videoMaxDuration=" + videoMaxDuration +
                ", allowTakePicture=" + allowTakePicture +
                ", allowTakeVideo=" + allowTakeVideo +
                ", allowPickingOriginalPhoto=" + allowPickingOriginalPhoto +
                ", allowPickingVideo=" + allowPickingVideo +
                ", allowPickingImage=" + allowPickingImage +
                '}';
    }
}
