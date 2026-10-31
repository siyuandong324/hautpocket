package com.hautpocket.worker

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.delay
import kotlin.random.Random

class ElectricitySampleWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        // 防 DDoS 随机抖动延迟 (5秒 ~ 120秒)，避免整点并发请求学校服务器
        delay(Random.nextLong(5_000L, 120_000L))
        return Result.success()
    }
}
