package cn.edu.haut.hautpocket

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.AlarmClock
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.math.BigInteger
import java.net.CookieHandler
import java.net.CookieManager
import java.net.CookiePolicy
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.spec.RSAPublicKeySpec
import java.util.regex.Pattern
import javax.crypto.Cipher

class MainActivity : Activity() {

    private lateinit var webView: WebView
    private val cookieManager = CookieManager(null, CookiePolicy.ACCEPT_ALL)

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CookieHandler.setDefault(cookieManager)

        if (Build.VERSION.SDK_INT >= 33) {
            requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 101)
        }

        webView = WebView(this)
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.allowFileAccess = true
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

        webView.webViewClient = WebViewClient()
        webView.webChromeClient = WebChromeClient()
        webView.addJavascriptInterface(HautNativeBridge(), "HautNative")

        setContentView(webView)
        webView.loadUrl("file:///android_asset/index.html")
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (this::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    inner class HautNativeBridge {

        @JavascriptInterface
        fun sendNotification(title: String, message: String) {
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channelId = "hautpocket_class_reminder"
                val builder: Notification.Builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channel = NotificationChannel(
                        channelId,
                        "Hautpocket 上课提醒",
                        NotificationManager.IMPORTANCE_HIGH
                    )
                    nm.createNotificationChannel(channel)
                    Notification.Builder(this@MainActivity, channelId)
                } else {
                    @Suppress("DEPRECATION")
                    Notification.Builder(this@MainActivity)
                }
                builder.setContentTitle(title)
                    .setContentText(message)
                    .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                    .setAutoCancel(true)
                nm.notify((System.currentTimeMillis() % 10000).toInt(), builder.build())
            } catch (_: Exception) {
            }
        }

        @JavascriptInterface
        fun setAlarm(hour: Int, minute: Int, title: String) {
            try {
                val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                    putExtra(AlarmClock.EXTRA_HOUR, hour)
                    putExtra(AlarmClock.EXTRA_MINUTES, minute)
                    putExtra(AlarmClock.EXTRA_MESSAGE, title)
                    putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (_: Exception) {
            }
        }

        @JavascriptInterface
        fun syncJwglxt(studentId: String, password: String, year: String, term: String) {
            Thread {
                val responseObj = try {
                    performSync(studentId, password, year, term)
                } catch (e: Exception) {
                    if (password.contains("！")) {
                        try {
                            performSync(studentId, password.replace("！", "!"), year, term)
                        } catch (e2: Exception) {
                            JSONObject().put("ok", false).put("error", e2.message ?: "登录失败")
                        }
                    } else {
                        JSONObject().put("ok", false).put("error", e.message ?: "网络请求异常")
                    }
                }
                val jsonStr = responseObj.toString()
                val quoted = JSONObject.quote(jsonStr)
                webView.post {
                    webView.evaluateJavascript("window.onNativeJwglxtSynced($quoted)", null)
                }
            }.start()
        }

        private fun performSync(studentId: String, password: String, year: String, term: String): JSONObject {
            val baseUrl = "https://jwglxt.haut.edu.cn/jwglxt"
            cookieManager.cookieStore.removeAll()
            val now = System.currentTimeMillis()

            // 1. 获取登录页 csrftoken
            val loginPageHtml = httpGet("$baseUrl/xtgl/login_slogin.html?language=zh_CN&_t=$now")
            val regexStr = "id=['\"]csrftoken['\"][^>]*value=['\"]([^'\"]+)['\"]"
            val m = Pattern.compile(regexStr).matcher(loginPageHtml)
            val csrfToken = if (m.find()) m.group(1) ?: "" else ""
            if (csrfToken.isEmpty()) {
                throw RuntimeException("未能从教务系统登录页解析到 csrftoken")
            }

            // 2. 获取 RSA 公钥
            val pubKeyJsonStr = httpGet("$baseUrl/xtgl/login_getPublicKey.html?time=$now")
            val pubKeyJson = JSONObject(pubKeyJsonStr)
            val modulusB64 = pubKeyJson.optString("modulus")
            val exponentB64 = pubKeyJson.optString("exponent")
            val encryptedPwd = encryptRsa(password, modulusB64, exponentB64)

            // 3. 提交登录表单
            val loginBody = "csrftoken=" + URLEncoder.encode(csrfToken, "UTF-8") +
                    "&language=zh_CN" +
                    "&yhm=" + URLEncoder.encode(studentId, "UTF-8") +
                    "&mm=" + URLEncoder.encode(encryptedPwd, "UTF-8") +
                    "&mm=" + URLEncoder.encode(encryptedPwd, "UTF-8")

            val loginResp = httpPost("$baseUrl/xtgl/login_slogin.html?time=$now", loginBody)
            if (loginResp.contains("id=\"tips\"") || loginResp.contains("id='tips'")) {
                throw RuntimeException("教务系统提示用户名或密码错误（或需通过校园网环境访问）")
            }

            val xqm = when (term.trim()) {
                "1", "3" -> "3"
                "2", "12" -> "12"
                else -> "3"
            }

            // 4. 拉取个人课表查询 (N2151)
            val kbRespStr = httpPost(
                "$baseUrl/kbcx/xskbcx_cxXsgrkb.html?gnmkdm=N2151",
                "xnm=$year&xqm=$xqm&kzlx=ck&xsdm="
            )
            val kbJson = JSONObject(kbRespStr)

            // 5. 拉取选课信息 (N100801)
            val xkList = try {
                val xkStr = httpPost(
                    "$baseUrl/xsxxxggl/xsxxwh_cxXsxkxx.html?gnmkdm=N100801",
                    "xnm=$year&xqm=$xqm&_search=false&queryModel.showCount=5000&queryModel.currentPage=1&time=1"
                )
                JSONObject(xkStr).optJSONArray("items") ?: JSONArray()
            } catch (_: Exception) {
                JSONArray()
            }

            // 6. 拉取全部历史成绩信息 (N305005)
            val cjList = try {
                val cjStr = httpPost(
                    "$baseUrl/cjcx/cjcx_cxDgXscj.html?doType=query&gnmkdm=N305005",
                    "xnm=&xqm=&_search=false&queryModel.showCount=5000&queryModel.currentPage=1&time=1"
                )
                JSONObject(cjStr).optJSONArray("items") ?: JSONArray()
            } catch (_: Exception) {
                JSONArray()
            }

            return JSONObject().apply {
                put("ok", true)
                put("xsxx", kbJson.optJSONObject("xsxx") ?: JSONObject())
                put("kbList", kbJson.optJSONArray("kbList") ?: JSONArray())
                put("xkList", xkList)
                put("cjList", cjList)
            }
        }

        private fun encryptRsa(plain: String, modulusB64: String, exponentB64: String): String {
            val modBytes = Base64.decode(modulusB64, Base64.DEFAULT)
            val expBytes = Base64.decode(exponentB64, Base64.DEFAULT)
            val n = BigInteger(1, modBytes)
            val e = BigInteger(1, expBytes)
            val spec = RSAPublicKeySpec(n, e)
            val pubKey = KeyFactory.getInstance("RSA").generatePublic(spec)
            val cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
            cipher.init(Cipher.ENCRYPT_MODE, pubKey)
            val encrypted = cipher.doFinal(plain.toByteArray(StandardCharsets.UTF_8))
            return Base64.encodeToString(encrypted, Base64.NO_WRAP)
        }

        private fun httpGet(urlStr: String): String {
            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 12000
                readTimeout = 12000
                setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14) Hautpocket/1.0")
                setRequestProperty("X-Requested-With", "XMLHttpRequest")
            }
            return BufferedReader(InputStreamReader(conn.inputStream, StandardCharsets.UTF_8)).use { it.readText() }
        }

        private fun httpPost(urlStr: String, formBody: String): String {
            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                instanceFollowRedirects = true
                connectTimeout = 12000
                readTimeout = 12000
                setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14) Hautpocket/1.0")
                setRequestProperty("Content-Type", "application/x-www-form-urlencoded;charset=UTF-8")
                setRequestProperty("X-Requested-With", "XMLHttpRequest")
            }
            OutputStreamWriter(conn.outputStream, StandardCharsets.UTF_8).use {
                it.write(formBody)
                it.flush()
            }
            return BufferedReader(InputStreamReader(conn.inputStream, StandardCharsets.UTF_8)).use { it.readText() }
        }
    }
}
