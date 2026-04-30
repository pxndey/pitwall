package com.pitcrew.app.data.remote

import com.google.gson.Gson
import com.pitcrew.app.BuildConfig
import com.pitcrew.app.data.remote.model.ChatHistoryItem
import com.pitcrew.app.data.remote.model.WebSocketInbound
import com.pitcrew.app.data.remote.model.WebSocketOutbound
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.WebSocket
import okhttp3.WebSocketListener
sealed class StreamEvent {
    data class Token(val content: String) : StreamEvent()
    data class Done(val fullContent: String) : StreamEvent()
    data class Error(val message: String) : StreamEvent()
}

class WebSocketManager(
    private val okHttpClient: OkHttpClient,
    private val gson: Gson,
) {
    companion object {
        private val WS_URL: String get() = "${BuildConfig.WS_BASE_URL}api/chat/ws"
    }

    fun stream(
        token: String,
        message: String,
        history: List<ChatHistoryItem> = emptyList(),
        circuitContext: String = "",
        conversationId: String = "",
    ): Flow<StreamEvent> = callbackFlow {
        val request = Request.Builder().url(WS_URL).build()

        val ws = okHttpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: okhttp3.Response) {
                val payload = WebSocketOutbound(
                    token = token,
                    message = message,
                    history = history,
                    circuitContext = circuitContext,
                    conversationId = conversationId,
                )
                webSocket.send(gson.toJson(payload))
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                val msg = gson.fromJson(text, WebSocketInbound::class.java)
                when {
                    msg.error != null -> {
                        trySend(StreamEvent.Error(msg.error))
                        webSocket.close(1000, "Error received")
                    }
                    msg.type == "token" -> {
                        trySend(StreamEvent.Token(msg.content ?: ""))
                    }
                    msg.type == "done" -> {
                        trySend(StreamEvent.Done(msg.content ?: ""))
                        webSocket.close(1000, "Done")
                    }
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: okhttp3.Response?) {
                trySend(StreamEvent.Error(t.message ?: "WebSocket connection failed"))
                close(t)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                close()
            }
        })

        awaitClose { ws.cancel() }
    }
}
