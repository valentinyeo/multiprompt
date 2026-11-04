package dev.multiprompt.companion.ui

import android.Manifest
import android.graphics.Bitmap
import android.graphics.Color
import android.os.SystemClock
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import dev.multiprompt.companion.MainActivity
import dev.multiprompt.companion.auth.SyncAuthManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.junit.After
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.time.Instant

class AccountPhotoProof {
    @get:Rule(order = 0)
    val permission = GrantPermissionRule.grant(Manifest.permission.POST_NOTIFICATIONS)

    @get:Rule(order = 1)
    val compose = createAndroidComposeRule<MainActivity>()

    private var renderedAt: String? = null
    private var error: String? = null

    @After
    fun saveEvidence() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val evidence = File(checkNotNull(instrumentation.targetContext.getExternalFilesDir(null)), "photo-proof")
        check(evidence.mkdirs() || evidence.isDirectory)
        val screen = instrumentation.uiAutomation.takeScreenshot()
        if (screen != null) {
            File(evidence, "root.png").outputStream().use { check(screen.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            screen.recycle()
        }
        File(evidence, "phone.json").writeText(JSONObject()
            .put("status", if (renderedAt != null) "passed" else "failed")
            .put("rendered_at", renderedAt ?: JSONObject.NULL)
            .put("error", error ?: JSONObject.NULL)
            .put("cached_pictures", File(instrumentation.targetContext.filesDir, "bot-photos").listFiles()?.count { it.extension == "png" } ?: 0)
            .toString())
    }

    @Test
    fun desktopPhotoAppearsOnRealAvatar() {
        try {
            val avatar = compose.onNodeWithContentDescription("Robot runner-1", useUnmergedTree = true)
            compose.waitUntil(180_000) {
                compose.onAllNodesWithContentDescription("Robot runner-1", useUnmergedTree = true)
                    .fetchSemanticsNodes().size == 1
            }
            avatar.assertIsDisplayed()
            val context = InstrumentationRegistry.getInstrumentation().targetContext
            runBlocking {
                withContext(Dispatchers.IO) {
                    val auth = SyncAuthManager(context)
                    var updated = false
                    repeat(10) {
                        if (!updated) {
                            val reply = auth.request("GET", "/v1/layout")
                            check(reply.status == 200)
                            val layout = reply.json.getJSONObject("layout")
                            val tabs = layout.getJSONArray("tabs")
                            val matches = (0 until tabs.length()).map { tabs.getJSONObject(it) }
                                .filter { it.optString("tmux_session") == "runner-1" && it.optInt("tmux_host", -1) == 0 }
                            check(matches.size == 1)
                            matches.single().put("name", "Phone ready").put("manual", true)
                            val result = auth.request("PUT", "/v1/layout", JSONObject()
                                .put("base_revision", reply.json.getLong("revision"))
                                .put("layout", layout))
                            updated = result.status == 200
                        }
                    }
                    check(updated) { "Could not signal phone readiness" }
                    val deadline = SystemClock.elapsedRealtime() + 1_500_000
                    var uploaded = false
                    while (!uploaded && SystemClock.elapsedRealtime() < deadline) {
                        val reply = auth.request("GET", "/v1/layout")
                        check(reply.status == 200)
                        val tabs = reply.json.getJSONObject("layout").getJSONArray("tabs")
                        uploaded = (0 until tabs.length()).map { tabs.getJSONObject(it) }
                            .any { it.optString("tmux_session") == "runner-1" && it.optLong("photo") > 0 }
                        if (!uploaded) Thread.sleep(1000)
                    }
                    check(uploaded) { "Desktop did not upload a picture" }
                }
            }
            val deadline = SystemClock.elapsedRealtime() + 60_000
            var image: Bitmap? = null
            while (SystemClock.elapsedRealtime() < deadline) {
                if (compose.onAllNodesWithText("Approve this device?").fetchSemanticsNodes().isNotEmpty()) {
                    compose.onNodeWithText("No").performClick()
                }
                val bounds = avatar.fetchSemanticsNode().boundsInWindow
                val screen = checkNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
                val candidate = Bitmap.createBitmap(screen, bounds.left.toInt(), bounds.top.toInt(), bounds.width.toInt(), bounds.height.toInt())
                screen.recycle()
                val green = candidate.getPixel((candidate.width * 0.3).toInt(), (candidate.height * 0.3).toInt())
                val blue = candidate.getPixel((candidate.width * 0.6).toInt(), (candidate.height * 0.6).toInt())
                if (Color.green(green) > 180 && Color.red(green) < 100 && Color.blue(green) < 100 &&
                    Color.blue(blue) > 180 && Color.red(blue) < 100 && Color.green(blue) < 100) {
                    image = candidate
                    break
                }
                candidate.recycle()
                Thread.sleep(250)
            }
            val result = checkNotNull(image) { "Desktop photo did not appear on the phone" }
            val rendered = Instant.now().toString()
            val evidence = File(checkNotNull(context.getExternalFilesDir(null)), "photo-proof")
            check(evidence.mkdirs() || evidence.isDirectory)
            File(evidence, "avatar.png").outputStream().use { check(result.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            result.recycle()
            renderedAt = rendered
        } catch (failure: Throwable) {
            error = failure.javaClass.simpleName + ": " + failure.message.orEmpty()
                .replace(Regex("[A-Za-z0-9_-]{40,}"), "[redacted]").take(240)
            throw failure
        }
    }
}
