package com.xiamijun.image_picker_controller;


import android.content.Context;
import android.graphics.Point;

import com.zhihu.matisse.MimeType;
import com.zhihu.matisse.filter.Filter;
import com.zhihu.matisse.internal.entity.IncapableCause;
import com.zhihu.matisse.internal.entity.Item;
import com.zhihu.matisse.internal.utils.PhotoMetadataUtils;

import java.util.HashSet;
import java.util.Set;

class VideoDurationFilter extends Filter {
    private long maxDuration;

    public VideoDurationFilter(long maxDuration) {
        this.maxDuration = maxDuration;
    }


    @Override
    public Set<MimeType> constraintTypes() {
        return new HashSet<MimeType>() {{
//            add(MimeType.GIF);
            for (MimeType mimeType : MimeType.ofVideo()){
                add(mimeType);
            }
        }};
    }

    @Override
    public IncapableCause filter(Context context, Item item) {
        if (!needFiltering(context, item))
            return null;

        if (maxDuration == 0) {
            return null;
        }
        final long duration = item.duration;
        if (duration > maxDuration * 1000) {
            return new IncapableCause(IncapableCause.TOAST, "视频时长超出限制");
        }
        return null;
    }
}