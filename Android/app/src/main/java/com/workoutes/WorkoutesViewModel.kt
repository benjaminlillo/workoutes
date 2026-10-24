package com.workoutes

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.workoutes.data.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class WorkoutesViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = (application as WorkoutesApplication).repository
    val state = repository.state
    private val mutableLoaded = MutableStateFlow(false)
    val loaded = mutableLoaded.asStateFlow()
    private val mutableMessage = MutableStateFlow<String?>(null)
    val message = mutableMessage.asStateFlow()
    init { viewModelScope.launch {
        try { repository.load(); mutableLoaded.value = true }
        catch (error: Exception) { mutableMessage.value = "Couldn't load saved data: ${error.message}" }
    } }
    fun dismissMessage() { mutableMessage.value = null }
    fun update(transform: (AppState) -> AppState) { viewModelScope.launch {
        try { repository.update(transform) }
        catch (error: Exception) { mutableMessage.value = "Couldn't save changes: ${error.message}" }
    } }
    fun importFile(uri: Uri, success: () -> Unit) { viewModelScope.launch {
        try { repository.importFile(uri); success(); mutableMessage.value = "Your data has been successfully imported." }
        catch (error: Exception) { mutableMessage.value = "Import failed: ${error.message}" }
    } }
    fun exportFile(includeHistory: Boolean, share: (Uri) -> Unit) { viewModelScope.launch {
        try { share(repository.exportFile(includeHistory)) }
        catch (error: Exception) { mutableMessage.value = "Export failed: ${error.message}" }
    } }
    fun saveWallpaper(key: String, uri: Uri) { viewModelScope.launch {
        try { repository.saveWallpaper(key, uri) }
        catch (error: Exception) { mutableMessage.value = "Background: ${error.message}" }
    } }
    fun report(message: String) { mutableMessage.value = message }
}
