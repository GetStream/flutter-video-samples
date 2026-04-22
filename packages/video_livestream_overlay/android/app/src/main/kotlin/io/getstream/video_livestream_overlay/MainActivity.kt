package io.getstream.video_livestream_overlay

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import io.getstream.video.flutter.stream_video_filters.common.BitmapVideoFilter
import io.getstream.video.flutter.stream_video_filters.common.VideoFrameProcessorWithBitmapFilter
import io.getstream.webrtc.flutter.videoEffects.ProcessorProvider
import io.getstream.webrtc.flutter.videoEffects.VideoFrameProcessor
import io.getstream.webrtc.flutter.videoEffects.VideoFrameProcessorFactoryInterface

class MainActivity : FlutterActivity() {
    private val CHANNEL = "io.getstream.video_livestream_overlay.channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "registerScoreboardEffect" -> {
                        ProcessorProvider.addProcessor(
                            "scoreboard",
                            ScoreboardVideoFilterFactory()
                        )
                        result.success(null)
                    }
                    "updateScoreboardState" -> {
                        ScoreboardState.update(
                            homeLabel = call.argument("homeLabel"),
                            awayLabel = call.argument("awayLabel"),
                            homeScore = call.argument("homeScore"),
                            awayScore = call.argument("awayScore"),
                            clockLabel = call.argument("clockLabel"),
                            mirror = call.argument("mirror"),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

/**
 * Mutable snapshot of the scoreboard configuration, driven from Flutter via
 * `updateScoreboardState`. The filter reads a consistent copy once per frame
 * via [snapshot], so mid-update tearing is avoided.
 */
object ScoreboardState {
    data class Snapshot(
        val homeLabel: String,
        val awayLabel: String,
        val homeScore: String,
        val awayScore: String,
        val clockLabel: String,
        val mirror: Boolean,
    )

    private val lock = Any()
    private var current = Snapshot(
        homeLabel = "HOME",
        awayLabel = "AWAY",
        homeScore = "0",
        awayScore = "0",
        clockLabel = "00:00",
        mirror = false,
    )

    fun snapshot(): Snapshot = synchronized(lock) { current }

    fun update(
        homeLabel: String?,
        awayLabel: String?,
        homeScore: String?,
        awayScore: String?,
        clockLabel: String?,
        mirror: Boolean?,
    ) {
        synchronized(lock) {
            current = current.copy(
                homeLabel = homeLabel ?: current.homeLabel,
                awayLabel = awayLabel ?: current.awayLabel,
                homeScore = homeScore ?: current.homeScore,
                awayScore = awayScore ?: current.awayScore,
                clockLabel = clockLabel ?: current.clockLabel,
                mirror = mirror ?: current.mirror,
            )
        }
    }
}

/**
 * Scoreboard overlay filter. Runs on the local publisher track, so the overlay
 * is encoded into the outgoing WebRTC video and flows through to all
 * participants and HLS/RTMP egress. Reads state from [ScoreboardState] every
 * frame, so updates pushed from Flutter appear on the next captured frame.
 */
class ScoreboardVideoFilterFactory : VideoFrameProcessorFactoryInterface {
    override fun build(): VideoFrameProcessor {
        return VideoFrameProcessorWithBitmapFilter { ScoreboardVideoFilter() }
    }
}

private class ScoreboardVideoFilter : BitmapVideoFilter() {

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(0xE6, 0x1A, 0x1A, 0x1A)
    }
    private val homeStripePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#E53935")
    }
    private val awayStripePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1E88E5")
    }
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    private val scorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    private val clockPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    private val dividerPaint = Paint().apply {
        color = Color.parseColor("#555555")
        strokeWidth = 1f
    }

    override fun applyFilter(videoFrameBitmap: Bitmap) {
        val state = ScoreboardState.snapshot()

        val w = videoFrameBitmap.width.toFloat()
        val h = videoFrameBitmap.height.toFloat()
        val shorter = minOf(w, h)

        val boardWidth = shorter * 0.72f
        val boardHeight = shorter * 0.12f
        val cornerRadius = boardHeight * 0.18f

        val left = (w - boardWidth) / 2f
        val top = shorter * 0.12f
        val right = left + boardWidth
        val bottom = top + boardHeight
        val boardRect = RectF(left, top, right, bottom)

        val canvas = Canvas(videoFrameBitmap)

        val mirrored = state.mirror
        if (mirrored) {
            canvas.save()
            canvas.scale(-1f, 1f, w / 2f, h / 2f)
        }

        canvas.drawRoundRect(boardRect, cornerRadius, cornerRadius, bgPaint)

        val stripeWidth = boardWidth * 0.022f
        canvas.save()
        canvas.clipRect(left, top, left + stripeWidth, bottom)
        canvas.drawRoundRect(boardRect, cornerRadius, cornerRadius, homeStripePaint)
        canvas.restore()

        canvas.save()
        canvas.clipRect(right - stripeWidth, top, right, bottom)
        canvas.drawRoundRect(boardRect, cornerRadius, cornerRadius, awayStripePaint)
        canvas.restore()

        labelPaint.textSize = boardHeight * 0.26f
        scorePaint.textSize = boardHeight * 0.60f
        clockPaint.textSize = boardHeight * 0.28f

        val midY = (top + bottom) / 2f
        val labelBaselineOffset = labelPaint.textSize * 0.35f
        val scoreBaselineOffset = scorePaint.textSize * 0.35f
        val clockBaselineOffset = clockPaint.textSize * 0.35f

        labelPaint.textAlign = Paint.Align.LEFT
        canvas.drawText(state.homeLabel, left + boardWidth * 0.08f, midY + labelBaselineOffset, labelPaint)
        labelPaint.textAlign = Paint.Align.RIGHT
        canvas.drawText(state.awayLabel, right - boardWidth * 0.08f, midY + labelBaselineOffset, labelPaint)

        canvas.drawText(state.homeScore, left + boardWidth * 0.38f, midY + scoreBaselineOffset, scorePaint)
        canvas.drawText(state.awayScore, right - boardWidth * 0.38f, midY + scoreBaselineOffset, scorePaint)

        val centerX = (left + right) / 2f
        canvas.drawText(state.clockLabel, centerX, midY + clockBaselineOffset, clockPaint)

        val divX1 = centerX - boardWidth * 0.065f
        val divX2 = centerX + boardWidth * 0.065f
        val divTop = top + boardHeight * 0.22f
        val divBot = bottom - boardHeight * 0.22f
        canvas.drawLine(divX1, divTop, divX1, divBot, dividerPaint)
        canvas.drawLine(divX2, divTop, divX2, divBot, dividerPaint)

        if (mirrored) {
            canvas.restore()
        }
    }
}
