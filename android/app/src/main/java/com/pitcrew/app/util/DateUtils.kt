package com.pitcrew.app.util

import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale
import java.util.TimeZone

fun parseDateFlexible(dateStr: String?): LocalDate? {
    if (dateStr == null) return null
    return try {
        LocalDate.parse(dateStr, DateTimeFormatter.ISO_DATE)
    } catch (_: DateTimeParseException) {
        try {
            ZonedDateTime.parse(dateStr, DateTimeFormatter.ISO_DATE_TIME).toLocalDate()
        } catch (_: DateTimeParseException) {
            null
        }
    }
}

fun parseDateTime(dateStr: String?, timeStr: String?): LocalDateTime? {
    if (dateStr == null) return null
    val date = parseDateFlexible(dateStr) ?: return null
    if (timeStr == null) return date.atTime(14, 0)
    return try {
        val time = java.time.LocalTime.parse(timeStr.removeSuffix("Z"))
        date.atTime(time)
    } catch (_: DateTimeParseException) {
        date.atTime(14, 0)
    }
}

fun weekendRange(dateStr: String?): String {
    val date = parseDateFlexible(dateStr) ?: return ""
    val friday = date.minusDays(2)
    val formatter = DateTimeFormatter.ofPattern("MMM d", Locale.US)
    return "${friday.format(formatter)}–${date.format(formatter)}"
}

fun formatMemberSince(dateStr: String?): String {
    if (dateStr == null) return ""
    return try {
        val zdt = ZonedDateTime.parse(dateStr)
        zdt.format(DateTimeFormatter.ofPattern("MMM d, yyyy"))
    } catch (_: Exception) {
        dateStr.take(10)
    }
}

fun isPast(dateStr: String?): Boolean {
    val date = parseDateFlexible(dateStr) ?: return false
    return date.isBefore(LocalDate.now())
}

fun isNextRace(dateStr: String?): Boolean {
    val date = parseDateFlexible(dateStr) ?: return false
    return !date.isBefore(LocalDate.now())
}

fun flag(country: String?): String {
    return when (country?.lowercase()) {
        "bahrain" -> "\uD83C\uDDE7\uD83C\uDDED"
        "saudi arabia" -> "\uD83C\uDDF8\uD83C\uDDE6"
        "australia" -> "\uD83C\uDDE6\uD83C\uDDFA"
        "japan" -> "\uD83C\uDDEF\uD83C\uDDF5"
        "china" -> "\uD83C\uDDE8\uD83C\uDDF3"
        "usa", "united states" -> "\uD83C\uDDFA\uD83C\uDDF8"
        "italy" -> "\uD83C\uDDEE\uD83C\uDDF9"
        "monaco" -> "\uD83C\uDDF2\uD83C\uDDE8"
        "canada" -> "\uD83C\uDDE8\uD83C\uDDE6"
        "spain" -> "\uD83C\uDDEA\uD83C\uDDF8"
        "austria" -> "\uD83C\uDDE6\uD83C\uDDF9"
        "uk", "united kingdom", "great britain" -> "\uD83C\uDDEC\uD83C\uDDE7"
        "hungary" -> "\uD83C\uDDED\uD83C\uDDFA"
        "belgium" -> "\uD83C\uDDE7\uD83C\uDDEA"
        "netherlands", "the netherlands" -> "\uD83C\uDDF3\uD83C\uDDF1"
        "singapore" -> "\uD83C\uDDF8\uD83C\uDDEC"
        "azerbaijan" -> "\uD83C\uDDE6\uD83C\uDDFF"
        "mexico" -> "\uD83C\uDDF2\uD83C\uDDFD"
        "brazil", "brasil" -> "\uD83C\uDDE7\uD83C\uDDF7"
        "qatar" -> "\uD83C\uDDF6\uD83C\uDDE6"
        "uae", "abu dhabi" -> "\uD83C\uDDE6\uD83C\uDDEA"
        "portugal" -> "\uD83C\uDDF5\uD83C\uDDF9"
        "france" -> "\uD83C\uDDEB\uD83C\uDDF7"
        "germany" -> "\uD83C\uDDE9\uD83C\uDDEA"
        "russia" -> "\uD83C\uDDF7\uD83C\uDDFA"
        "turkey", "türkiye" -> "\uD83C\uDDF9\uD83C\uDDF7"
        "switzerland" -> "\uD83C\uDDE8\uD83C\uDDED"
        else -> "\uD83C\uDFF3\uFE0F"
    }
}
