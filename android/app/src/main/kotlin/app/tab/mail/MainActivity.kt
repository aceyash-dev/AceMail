package app.tab.mail

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
