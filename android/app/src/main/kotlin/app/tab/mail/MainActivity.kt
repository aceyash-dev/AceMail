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
                result.success(
                    setLauncherAccent(
                        call.argument<String>("accent") ?: "",
                        call.argument<String>("mark") ?: "",
                    )
                )
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
    private fun setLauncherAccent(accent: String, mark: String): Boolean {
        val wanted = aliasFor(accent, mark) ?: return false
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

    /**
     * The alias wearing [accent] and [monogram]'s mark.
     *
     * Built rather than listed. Thirty aliases is thirty constants that have to
     * agree with thirty manifest entries, and the rule that connects them is one
     * line — so writing it out fifteen more times would be fifteen more chances
     * to be wrong about it.
     */
    private fun aliasFor(accent: String, mark: String): String? {
        val name = ACCENT_NAMES[accent] ?: return null
        // The suffix is the mark's, and the empty one is the envelope. Nothing
        // here knows how many marks there are: adding one is a name and a
        // resource, not a branch.
        if (mark !in MARK_SUFFIXES) return null
        return "$PACKAGE.Launcher$name$mark"
    }

    companion object {
        private const val CHANNEL = "app.tab.mail/launcher"
        private const val VOICE_CHANNEL = "app.tab.mail/voice"
        private const val VOICE_REQUEST = 7301
        private const val PACKAGE = "app.tab.mail"


        /** Accent key, as the app names it, to the capitalised part of its alias. */
        private val ACCENT_NAMES = mapOf(
            "orange" to "Orange",
            "red" to "Red",
            "pink" to "Pink",
            "purple" to "Purple",
            "indigo" to "Indigo",
            "blue" to "Blue",
            "teal" to "Teal",
            "green" to "Green",
            "amber" to "Amber",
            "brown" to "Brown",
            "cyan" to "Cyan",
            "lime" to "Lime",
            "slate" to "Slate",
            "deepPurple" to "DeepPurple",
            "deepOrange" to "DeepOrange",
        )

        /**
         * Every alias this build ships: each accent with each mark.
         *
         * Derived from [ACCENT_NAMES] rather than written out, so adding an
         * accent or a mark is one line here and the disabling loop cannot fall
         * out of step with it.
         */
        /** The marks, as the suffix each one adds to an alias name. */
        private val MARK_SUFFIXES = listOf("", "A", "Open")

        private val ALL_ALIASES = ACCENT_NAMES.values.flatMap { name ->
            MARK_SUFFIXES.map { suffix -> "$PACKAGE.Launcher$name$suffix" }
        }
    }
}
