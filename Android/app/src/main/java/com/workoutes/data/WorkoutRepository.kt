package com.workoutes.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.util.AtomicFile
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import java.io.File

class WorkoutRepository(private val context: Context) {
    private val file = AtomicFile(File(context.filesDir, "workoutes.json"))
    private val mutex = Mutex()
    private val mutableState = MutableStateFlow(AppState())
    val state = mutableState.asStateFlow()
    private var writable = false

    suspend fun load() = withContext(Dispatchers.IO) {
        mutex.withLock {
            if (writable) return@withLock
            val saved = if (file.baseFile.exists() || File(file.baseFile.path + ".bak").exists()) {
                workoutesJson.decodeFromString<AppState>(file.openRead().bufferedReader().use { it.readText() })
            } else AppState()
            saved.data.validate()
            val restored = saved.restoreSession().let { it.copy(preferences = it.preferences.copy(accent = AppTheme.resolve(it.preferences.accent).name)) }
            if (restored != saved) write(restored)
            mutableState.value = restored
            writable = true
        }
    }

    suspend fun update(transform: (AppState) -> AppState) = withContext(Dispatchers.IO) {
        mutex.withLock {
            check(writable) { "Stored data could not be loaded. Your original file has been preserved." }
            val previous = mutableState.value
            val next = transform(previous)
            next.data.validate()
            write(next)
            mutableState.value = next
            val referencedImages = next.backgrounds.values.mapNotNull { it.imageFile }.toSet()
            previous.backgrounds.values.mapNotNull { it.imageFile }.filterNot { it in referencedImages }
                .forEach { File(context.filesDir, it).delete() }
        }
    }

    private fun write(state: AppState) {
        val stream = file.startWrite()
        try { stream.write(workoutesJson.encodeToString(state).toByteArray()); file.finishWrite(stream) }
        catch (error: Exception) { file.failWrite(stream); throw error }
    }

    suspend fun importFile(uri: Uri) = withContext(Dispatchers.IO) {
        val bytes = context.contentResolver.openInputStream(uri)?.use { input ->
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                require(output.size() + count <= 10 * 1024 * 1024) { "Choose a JSON file smaller than 10 MB." }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
            ?: error("Couldn't open this file.")
        require(bytes.size <= 10 * 1024 * 1024) { "Choose a JSON file smaller than 10 MB." }
        val imported = decodeImport(bytes.toString(Charsets.UTF_8), state.value.data)
        update { it.importData(imported) }
    }

    suspend fun exportFile(includeHistory: Boolean): Uri = withContext(Dispatchers.IO) {
        check(writable) { "Data is not loaded." }
        val directory = File(context.cacheDir, "shared").apply { mkdirs() }
        val export = File(directory, "workoutes_export_${System.currentTimeMillis()}.json")
        export.writeText(workoutesJson.encodeToString(state.value.data.let { if (includeHistory) it else it.copy(history = null) }))
        androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.files", export)
    }

    suspend fun saveWallpaper(key: String, uri: Uri) = withContext(Dispatchers.IO) {
        val resolver = context.contentResolver
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
        require(options.outWidth > 0 && options.outHeight > 0) { "This image couldn't be loaded. Choose another photo." }
        options.inSampleSize = 1
        while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > 2048) options.inSampleSize *= 2
        options.inJustDecodeBounds = false
        val bitmap = resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: error("This image couldn't be loaded.")
        val orientation = resolver.openInputStream(uri)?.use {
            ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }
        val matrix = Matrix().apply {
            when (orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f, 1f)
                ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> setScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> { setRotate(90f); postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
                ExifInterface.ORIENTATION_TRANSVERSE -> { setRotate(-90f); postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(-90f)
            }
        }
        val oriented = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        val relative = "backgrounds/${newId()}.jpg"
        val image = File(context.filesDir, relative)
        image.parentFile?.mkdirs()
        try {
            image.outputStream().use { require(oriented.compress(Bitmap.CompressFormat.JPEG, 85, it)) }
            update { it.copy(backgrounds = it.backgrounds + (key to Background(BackgroundMode.Wallpaper, imageFile = relative))) }
        } catch (error: Exception) { image.delete(); throw error }
        finally { oriented.recycle(); if (oriented !== bitmap) bitmap.recycle() }
    }
}
