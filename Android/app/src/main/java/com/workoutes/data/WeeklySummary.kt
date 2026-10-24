package com.workoutes.data

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class WeeklyDay(val date: LocalDate, val completions: List<ExerciseCompletion>)
data class WeeklySummary(val start: LocalDate, val endExclusive: LocalDate, val days: List<WeeklyDay>) {
    val total get() = days.sumOf { it.completions.size }
    val activeDays get() = days.count { it.completions.isNotEmpty() }
    companion object {
        fun containing(history: List<ExerciseCompletion>, now: Instant, zone: ZoneId = ZoneId.systemDefault()): WeeklySummary {
            val today = now.atZone(zone).toLocalDate()
            val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
            val end = monday.plusDays(7)
            val startInstant = monday.atStartOfDay(zone).toInstant()
            val endInstant = end.atStartOfDay(zone).toInstant()
            val records = history.filter { Instant.parse(it.completedAt).let { date -> date >= startInstant && date < endInstant } }
            return WeeklySummary(monday, end, (0L..6L).map { offset ->
                val date = monday.plusDays(offset)
                WeeklyDay(date, records.filter { Instant.parse(it.completedAt).atZone(zone).toLocalDate() == date }
                    .sortedWith(compareBy<ExerciseCompletion> { Instant.parse(it.completedAt) }.thenBy { it.id }))
            })
        }
    }
}
