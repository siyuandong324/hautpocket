package com.hautpocket.domain

import kotlin.math.max
import kotlin.math.roundToInt

fun parseZfWeeksToBitmask(zcd: String): Int {
    var mask = 0
    zcd.split(",").forEach { segment ->
        val isOdd = segment.contains("单")
        val isEven = segment.contains("双")
        val clean = segment.replace(Regex("[^0-9-]"), "")
        val parts = clean.split("-").filter { it.isNotEmpty() }.map { it.toInt() }
        val start = parts.firstOrNull() ?: return@forEach
        val end = if (parts.size > 1) parts[1] else start
        for (w in start..end) {
            if ((isOdd && w % 2 == 0) || (isEven && w % 2 != 0)) continue
            mask = mask or (1 shl w)
        }
    }
    return mask
}
