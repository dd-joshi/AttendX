package io.github.ddjoshi.attendx

import android.accounts.Account
import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.identity.RevokeAccessRequest
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val driveScope = "https://www.googleapis.com/auth/drive.appdata"
    private val authorizationRequestCode = 6137
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "attendx/drive")
            .setMethodCallHandler { call, result ->
                if (pendingResult != null) {
                    result.error("busy", "A Google account request is already open.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "authorize" -> {
                        pendingResult = result
                        val builder = AuthorizationRequest.builder()
                            .setRequestedScopes(listOf(Scope(driveScope)))
                        val email = call.argument<String>("email")
                        if (email != null) {
                            builder.setAccount(Account(email, "com.google"))
                        } else {
                            builder.setPrompt(AuthorizationRequest.Prompt.SELECT_ACCOUNT)
                        }
                        Identity.getAuthorizationClient(this).authorize(builder.build())
                            .addOnSuccessListener { authorization ->
                                if (authorization.hasResolution()) {
                                    try {
                                        startIntentSenderForResult(
                                            authorization.pendingIntent!!.intentSender,
                                            authorizationRequestCode, null, 0, 0, 0
                                        )
                                    } catch (error: Exception) {
                                        failAuthorization(error)
                                    }
                                } else {
                                    completeAuthorization(authorization)
                                }
                            }
                            .addOnFailureListener(::failAuthorization)
                    }
                    "disconnect" -> {
                        val email = call.argument<String>("email")
                        if (email == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        val request = RevokeAccessRequest.builder()
                            .setAccount(Account(email, "com.google"))
                            .setScopes(listOf(Scope(driveScope)))
                            .build()
                        Identity.getAuthorizationClient(this).revokeAccess(request)
                            .addOnSuccessListener {
                                pendingResult?.success(null)
                                pendingResult = null
                            }
                            .addOnFailureListener(::failAuthorization)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Used by the FlutterActivity authorization bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != authorizationRequestCode) return
        if (resultCode != Activity.RESULT_OK) {
            pendingResult?.error("cancelled", "Google Drive connection cancelled.", null)
            pendingResult = null
            return
        }
        try {
            completeAuthorization(
                Identity.getAuthorizationClient(this).getAuthorizationResultFromIntent(data)
            )
        } catch (error: Exception) {
            failAuthorization(error)
        }
    }

    private fun completeAuthorization(authorization: AuthorizationResult) {
        val token = authorization.accessToken
        if (token.isNullOrBlank() || !authorization.grantedScopes.contains(driveScope)) {
            pendingResult?.error("permission", "Allow AttendX backup access to continue.", null)
        } else {
            // Short-lived token is passed to Dart in memory only, never logged or persisted.
            pendingResult?.success(token)
        }
        pendingResult = null
    }

    private fun failAuthorization(error: Exception) {
        val status = (error as? ApiException)?.statusCode
        val code = when (status) {
            16 -> "cancelled"
            10 -> "configuration"
            7 -> "network"
            else -> "authorization"
        }
        pendingResult?.error(code, "Could not connect Google Drive.", status)
        pendingResult = null
    }

    override fun onDestroy() {
        pendingResult?.error("interrupted", "Google Drive connection interrupted. Try again.", null)
        pendingResult = null
        super.onDestroy()
    }
}
