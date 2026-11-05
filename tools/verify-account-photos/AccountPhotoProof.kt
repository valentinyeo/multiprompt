package dev.multiprompt.companion.ui

import android.Manifest
import android.graphics.Bitmap
import android.graphics.Color
import android.os.SystemClock
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.toArgb
import dev.multiprompt.companion.BuildConfig
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
    private val colorsRequired = BuildConfig.ACCOUNT_ORIGIN.matches(Regex("https://[a-z0-9-]+\\.trycloudflare\\.com"))
    private var workspaceColors: JSONObject? = null

    private fun dismissDeviceApproval() {
        if (compose.onAllNodesWithText("Approve this device?").fetchSemanticsNodes().isNotEmpty()) {
            try {
                compose.onNodeWithText("No").performClick()
            } catch (failure: AssertionError) {
                if (!failure.message.orEmpty().contains("Expected exactly '1' node but could not find any node") ||
                    compose.onAllNodesWithText("Approve this device?").fetchSemanticsNodes().isNotEmpty() ||
                    compose.onAllNodesWithText("No").fetchSemanticsNodes().isNotEmpty()) {
                    throw failure
                }
            }
        }
    }

    private fun openWorkspaceColors() {
        dismissDeviceApproval()
        compose.onNodeWithContentDescription("Session list actions").performClick()
        compose.onNodeWithText("Settings").performClick()
        compose.onAllNodesWithText("Auto").onFirst().performScrollTo()
        dismissDeviceApproval()
    }

    private fun colorCenter(index: Int): Offset {
        val density = InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
        val label = compose.onNodeWithText("Work").fetchSemanticsNode().boundsInWindow
        return Offset(label.left + (index * 36 + 14) * density, label.bottom + 20 * density)
    }

    private fun colorSelected(index: Int): Boolean {
        dismissDeviceApproval()
        val center = colorCenter(index)
        val density = InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
        val image = checkNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
        try {
            val ring = image.getPixel(center.x.toInt(), (center.y - 12 * density).toInt())
            val expected = Kit.Text.toArgb()
            return kotlin.math.abs(Color.red(ring) - Color.red(expected)) < 20 &&
                kotlin.math.abs(Color.green(ring) - Color.green(expected)) < 20 &&
                kotlin.math.abs(Color.blue(ring) - Color.blue(expected)) < 20
        } finally { image.recycle() }
    }

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
            .put("workspace_colors_required", colorsRequired)
            .put("workspace_colors", workspaceColors ?: JSONObject.NULL)
            .put("cached_pictures", File(instrumentation.targetContext.filesDir, "bot-photos").listFiles()?.count { it.extension == "png" } ?: 0)
            .toString())
    }

    @Test
    fun desktopPhotoAppearsOnRealAvatar() {
        try {
            compose.waitUntil(180_000) {
                compose.onAllNodesWithText("All").fetchSemanticsNodes().size == 1
            }
            compose.onNodeWithText("All").performClick()
            val avatar = compose.onNodeWithContentDescription("Robot runner-1", useUnmergedTree = true)
            compose.waitUntil(180_000) {
                compose.onAllNodesWithContentDescription("Robot runner-1", useUnmergedTree = true)
                    .fetchSemanticsNodes().size == 1
            }
            avatar.assertIsDisplayed()
            val context = InstrumentationRegistry.getInstrumentation().targetContext
            if (colorsRequired) {
                openWorkspaceColors()
                val center = colorCenter(4)
                val root = compose.onRoot().fetchSemanticsNode().boundsInWindow
                compose.onRoot().performTouchInput { click(center - root.topLeft) }
                compose.waitUntil(60_000) { colorSelected(4) }
                compose.onNodeWithContentDescription("Back").performClick()
            }
            runBlocking {
                withContext(Dispatchers.IO) {
                    val auth = SyncAuthManager(context)
                    var updated = false
                    repeat(60) {
                        if (!updated) {
                            val reply = auth.request("GET", "/v1/layout")
                            check(reply.status == 200)
                            val layout = reply.json.getJSONObject("layout")
                            if (colorsRequired) {
                                val workspaces = layout.getJSONArray("workspaces")
                                val work = (0 until workspaces.length()).map { workspaces.getJSONObject(it) }
                                    .single { it.getString("name") == "Work" }
                                if (work.optInt("color", -1) != 4) {
                                    Thread.sleep(1000)
                                    return@repeat
                                }
                            }
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
                dismissDeviceApproval()
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
            if (colorsRequired) {
                openWorkspaceColors()
                compose.waitUntil(60_000) { colorSelected(6) }
                workspaceColors = JSONObject().put("workspace", "Work").put("sent_color", 4).put("received_color", 6)
            }
            renderedAt = rendered
        } catch (failure: Throwable) {
            error = failure.javaClass.simpleName + ": " + failure.message.orEmpty()
                .replace(Regex("[A-Za-z0-9_-]{40,}"), "[redacted]").take(240)
            throw failure
        }
    }
}
