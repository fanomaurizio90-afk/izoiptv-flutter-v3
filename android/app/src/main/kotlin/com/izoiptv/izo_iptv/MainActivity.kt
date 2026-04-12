package com.izoiptv.izo_iptv

import android.util.LongSparseArray
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer

@OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.izoiptv/exo_tracks"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val textureId = (call.argument<Number>("textureId"))?.toLong() ?: -1L

                try {
                    val exoPlayer = getExoPlayer(flutterEngine, textureId)
                    if (exoPlayer == null) {
                        result.error("NO_PLAYER", "No ExoPlayer for textureId $textureId", null)
                        return@setMethodCallHandler
                    }

                    when (call.method) {
                        "getAudioTracks" -> {
                            val tracks = mutableListOf<Map<String, Any?>>()
                            val groups = exoPlayer.currentTracks.groups
                            for (gi in groups.indices) {
                                val group = groups[gi]
                                if (group.type != C.TRACK_TYPE_AUDIO) continue
                                for (ti in 0 until group.length) {
                                    val fmt = group.getTrackFormat(ti)
                                    tracks.add(
                                        mapOf(
                                            "groupIndex" to gi,
                                            "trackIndex" to ti,
                                            "language" to fmt.language,
                                            "label" to fmt.label,
                                            "channels" to fmt.channelCount,
                                            "selected" to group.isTrackSelected(ti)
                                        )
                                    )
                                }
                            }
                            result.success(tracks)
                        }

                        "getSubtitleTracks" -> {
                            val tracks = mutableListOf<Map<String, Any?>>()
                            val groups = exoPlayer.currentTracks.groups
                            for (gi in groups.indices) {
                                val group = groups[gi]
                                if (group.type != C.TRACK_TYPE_TEXT) continue
                                for (ti in 0 until group.length) {
                                    val fmt = group.getTrackFormat(ti)
                                    tracks.add(
                                        mapOf(
                                            "groupIndex" to gi,
                                            "trackIndex" to ti,
                                            "language" to fmt.language,
                                            "label" to fmt.label,
                                            "selected" to group.isTrackSelected(ti)
                                        )
                                    )
                                }
                            }
                            result.success(tracks)
                        }

                        "selectAudioTrack" -> {
                            val gi = call.argument<Int>("groupIndex") ?: 0
                            val ti = call.argument<Int>("trackIndex") ?: 0
                            val groups = exoPlayer.currentTracks.groups
                            if (gi < groups.size) {
                                val override = TrackSelectionOverride(
                                    groups[gi].mediaTrackGroup, listOf(ti)
                                )
                                exoPlayer.trackSelectionParameters =
                                    exoPlayer.trackSelectionParameters
                                        .buildUpon()
                                        .setOverrideForType(override)
                                        .build()
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }

                        "selectSubtitleTrack" -> {
                            val gi = call.argument<Int>("groupIndex") ?: 0
                            val ti = call.argument<Int>("trackIndex") ?: 0
                            val groups = exoPlayer.currentTracks.groups
                            if (gi < groups.size) {
                                // Re-enable text tracks if previously disabled
                                val params = exoPlayer.trackSelectionParameters
                                    .buildUpon()
                                    .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                                    .setOverrideForType(
                                        TrackSelectionOverride(
                                            groups[gi].mediaTrackGroup, listOf(ti)
                                        )
                                    )
                                    .build()
                                exoPlayer.trackSelectionParameters = params
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }

                        "disableSubtitles" -> {
                            exoPlayer.trackSelectionParameters =
                                exoPlayer.trackSelectionParameters
                                    .buildUpon()
                                    .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                                    .build()
                            result.success(true)
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, e.stackTraceToString())
                }
            }
    }

    @Suppress("UNCHECKED_CAST")
    private fun getExoPlayer(flutterEngine: FlutterEngine, textureId: Long): ExoPlayer? {
        return try {
            val plugin = flutterEngine.plugins.get(
                io.flutter.plugins.videoplayer.VideoPlayerPlugin::class.java
            ) ?: return null

            val field = plugin.javaClass.getDeclaredField("videoPlayers")
            field.isAccessible = true
            val videoPlayers = field.get(plugin) as? LongSparseArray<*> ?: return null
            val videoPlayer = videoPlayers.get(textureId) ?: return null

            val method = videoPlayer.javaClass.getMethod("getExoPlayer")
            method.invoke(videoPlayer) as? ExoPlayer
        } catch (e: Exception) {
            android.util.Log.e("ExoTrack", "Failed to get ExoPlayer: ${e.message}")
            null
        }
    }
}
