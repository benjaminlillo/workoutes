package com.workoutes

import android.os.Bundle
import android.content.Intent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import com.workoutes.ui.WorkoutesApp

class MainActivity : ComponentActivity() {
    private var reveal by mutableStateOf<Pair<String, Int>?>(null)
    private var revealCounter = 0
    private fun readReveal(intent: Intent?) { intent?.getStringExtra("revealExerciseId")?.let { reveal = it to ++revealCounter } }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); readReveal(intent) }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readReveal(intent)
        enableEdgeToEdge()
        setContent { WorkoutesApp(viewModel<WorkoutesViewModel>(), reveal) }
    }
}
