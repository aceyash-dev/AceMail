package app.tab.mail

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Ace Mail's activity, plus the one thing about it that Android will not let
 * Dart do: point the launcher entry at a different icon.
 *
 * The accent is a setting, and a launcher icon is fixed at install time. The
 * way round that is activity aliases: fifteen of them, one per accent, each with
 * its own icon, and exactly one enabled. MainActivity itself has no launcher
 * filter, so the enabled alias *is* the launcher entry.
 *
 * The switching order matters. The new alias is enabled before the old ones are
 * disabled, so the worst a failed switch can do is leave two icons on the
 * launcher for a moment. Disabling first could leave none, and an app with no
 * launcher entry is an app that has disappeared. The default alias is enabled
 * in the manifest, so a fresh install always has exactly one.
 *
 * It also runs the microphone. `RecognizerIntent` hands the listening to the
 * device's own speech app — on a phone with Google services that is Google's
 * recogniser, which is what the search bar's microphone is meant to be — and
 * comes back with text. Nothing is recorded here: the app never sees the audio,
 * and it never asks for the microphone permission, because it never listens.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "setLauncherAccent") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(setLauncherAccent(call.argument<String>("accent") ?: ""))
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "listen") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                listen(result)
            }
    }

    /** The reply waiting on the recogniser, or null when none is listening. */
    private var listening: MethodChannel.Result? = null

    /**
     * Asks the device's speech app to listen, and answers with what it heard.
     *
     * Answers null when the person cancelled, and an error when there is nothing
     * on the device that can listen at all — which is a real possibility on a
     * phone without Google's app, and not something to report as a failure of
     * the microphone.
     */
    private fun listen(result: MethodChannel.Result) {
        if (listening != null) {
            // Already listening. One microphone, one listener.
            result.success(null)
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // The device's own language, not the app's — somebody searching in
            // Hindi on an English phone still says Hindi words.
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
        }
        try {
            listening = result
            startActivityForResult(intent, VOICE_REQUEST)
        } catch (error: ActivityNotFoundException) {
            listening = null
            result.error("no_recogniser", "This device has no speech recogniser.", null)
        }
    }

    /**
     * Answers a caller that is still waiting when this activity goes away.
     *
     * A `MethodChannel.Result` that is never resolved is an `await` on the Dart
     * side that never completes — the microphone would pulse for ever. A
     * configuration change or a low-memory kill while the recogniser is open is
     * enough to do it.
     */
    override fun onDestroy() {
        listening?.success(null)
        listening = null
        super.onDestroy()
    }

    @Deprecated("The result API is newer, but this is what FlutterActivity forwards.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != VOICE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val heard = if (resultCode == Activity.RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        } else {
            null
        }
        listening?.success(heard)
        listening = null
    }

    /**
     * Points the launcher at the alias wearing [accent]. Returns false when the
     * accent is not one this build knows, or when the launcher refused — which
     * the caller is free to ignore: an icon is the least important thing in the
     * app, and it must never be the reason the app misbehaves.
     */
    private fun setLauncherAccent(accent: String): Boolean {
        val wanted = aliasFor(accent) ?: return false
        return try {
            val pm = packageManager
            // Enabled first, disabled second. See the note on this class.
            pm.setComponentEnabledSetting(
                ComponentName(this, wanted),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            for (alias in ALL_ALIASES) {
                if (alias == wanted) continue
                pm.setComponentEnabledSetting(
                    ComponentName(this, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun aliasFor(accent: String): String? = when (accent) {
            "orange" -> LauncherOrange
            "red" -> LauncherRed
            "pink" -> LauncherPink
            "purple" -> LauncherPurple
            "indigo" -> LauncherIndigo
            "blue" -> LauncherBlue
            "teal" -> LauncherTeal
            "green" -> LauncherGreen
            "amber" -> LauncherAmber
            "brown" -> LauncherBrown
            "cyan" -> LauncherCyan
            "lime" -> LauncherLime
            "slate" -> LauncherSlate
            "deepPurple" -> LauncherDeepPurple
            "deepOrange" -> LauncherDeepOrange
            else -> null
        }

    companion object {
        private const val CHANNEL = "app.tab.mail/launcher"
        private const val VOICE_CHANNEL = "app.tab.mail/voice"
        private const val VOICE_REQUEST = 7301
        private const val PACKAGE = "app.tab.mail"

        private const val LauncherOrange = "$PACKAGE.LauncherOrange"
        private const val LauncherRed = "$PACKAGE.LauncherRed"
        private const val LauncherPink = "$PACKAGE.LauncherPink"
        private const val LauncherPurple = "$PACKAGE.LauncherPurple"
        private const val LauncherIndigo = "$PACKAGE.LauncherIndigo"
        private const val LauncherBlue = "$PACKAGE.LauncherBlue"
        private const val LauncherTeal = "$PACKAGE.LauncherTeal"
        private const val LauncherGreen = "$PACKAGE.LauncherGreen"
        private const val LauncherAmber = "$PACKAGE.LauncherAmber"
        private const val LauncherBrown = "$PACKAGE.LauncherBrown"
        private const val LauncherCyan = "$PACKAGE.LauncherCyan"
        private const val LauncherLime = "$PACKAGE.LauncherLime"
        private const val LauncherSlate = "$PACKAGE.LauncherSlate"
        private const val LauncherDeepPurple = "$PACKAGE.LauncherDeepPurple"
        private const val LauncherDeepOrange = "$PACKAGE.LauncherDeepOrange"

        private val ALL_ALIASES = listOf(
            LauncherOrange,
            LauncherRed,
            LauncherPink,
            LauncherPurple,
            LauncherIndigo,
            LauncherBlue,
            LauncherTeal,
            LauncherGreen,
            LauncherAmber,
            LauncherBrown,
            LauncherCyan,
            LauncherLime,
            LauncherSlate,
            LauncherDeepPurple,
            LauncherDeepOrange,
        )
    }
}
