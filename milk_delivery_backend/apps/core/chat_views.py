import json
import time
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.core.cache import cache


def _get_redis_chat_key(phone):
    clean = phone.replace("+91", "").replace(" ", "").replace("-", "").strip()
    return f"chat_history_{clean}"


def _get_active_threads_key():
    return "active_support_chat_threads"


class SupportChatSendView(APIView):
    """
    Send a message into the Redis chat stream (from Customer or Support Agent).
    POST /api/support/chat/send/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        sender_type = request.data.get("sender_type", "user")  # 'user' or 'agent'
        sender_name = request.data.get("sender_name", "Customer")
        text = request.data.get("text", "").strip()
        order_id = request.data.get("order_id")

        if not phone or not text:
            return Response({"error": "phone and text are required"}, status=status.HTTP_400_BAD_REQUEST)

        clean_phone = phone.replace("+91", "").replace(" ", "").replace("-", "").strip()
        chat_key = _get_redis_chat_key(phone)

        msg_obj = {
            "id": f"msg_{int(time.time() * 1000)}",
            "sender_type": sender_type,
            "sender_name": sender_name,
            "text": text,
            "order_id": order_id,
            "timestamp": timezone.now().isoformat(),
        }

        # Retrieve existing history from Redis
        history = cache.get(chat_key) or []
        history.append(msg_obj)
        # Keep last 100 messages
        if len(history) > 100:
            history = history[-100:]
        cache.set(chat_key, history, timeout=7 * 86400)  # 7-day TTL

        # Update active threads in Redis
        threads = cache.get(_get_active_threads_key()) or {}
        threads[clean_phone] = {
            "phone": phone,
            "clean_phone": clean_phone,
            "customer_name": sender_name if sender_type == "user" else threads.get(clean_phone, {}).get("customer_name", "Customer"),
            "last_message": text,
            "last_timestamp": timezone.now().isoformat(),
            "unread_count": (threads.get(clean_phone, {}).get("unread_count", 0) + 1) if sender_type == "user" else 0,
        }
        cache.set(_get_active_threads_key(), threads, timeout=7 * 86400)

        # Automated Agent AI reply if customer query and no agent present
        auto_reply = None
        if sender_type == "user":
            lower = text.lower()
            if any(w in lower for w in ["track", "where", "late", "order", "delivery"]):
                reply_text = "🥛 Your morning milk delivery is guaranteed by 06:00 AM! Our driver will place the insulated chilled bag at your doorstep with a photo confirmation."
            elif any(w in lower for w in ["pause", "vacation", "stop", "hold"]):
                reply_text = "🏖️ You can pause deliveries anytime with 1 tap from the Subscriptions Tab. No wallet deductions will occur for paused days."
            elif any(w in lower for w in ["wallet", "refund", "balance", "money"]):
                reply_text = "💳 All unused subscription days and skips are automatically credited back to your prepaid wallet in real-time."
            elif any(w in lower for w in ["call", "human", "agent", "executive", "help"]):
                reply_text = "👨‍💼 Connected to MilkDrop Live Support Desk! A support executive is assigned to your ticket."
            else:
                reply_text = "👋 Thank you for contacting MilkDrop 24x7 Support! How may we assist with your fresh farm deliveries or subscriptions today?"

            auto_reply = {
                "id": f"rep_{int(time.time() * 1000) + 1}",
                "sender_type": "agent",
                "sender_name": "Priya (MilkDrop Support)",
                "text": reply_text,
                "order_id": order_id,
                "timestamp": timezone.now().isoformat(),
            }
            history.append(auto_reply)
            cache.set(chat_key, history, timeout=7 * 86400)

        return Response({
            "status": "SENT",
            "message": msg_obj,
            "auto_reply": auto_reply,
            "total_messages": len(history),
        }, status=status.HTTP_200_OK)


class SupportChatHistoryView(APIView):
    """
    Retrieve Redis chat history for a customer phone number.
    GET /api/support/chat/history/?phone=...
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        phone = request.query_params.get("phone", "").strip()
        if not phone:
            return Response({"error": "phone query parameter is required"}, status=status.HTTP_400_BAD_REQUEST)

        chat_key = _get_redis_chat_key(phone)
        history = cache.get(chat_key) or []
        return Response({
            "phone": phone,
            "count": len(history),
            "messages": history,
        }, status=status.HTTP_200_OK)


class AdminSupportChatThreadsView(APIView):
    """
    Admin endpoint to view all active customer support chat threads from Redis.
    GET /api/admin/support/threads/
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        threads_dict = cache.get(_get_active_threads_key()) or {}
        threads_list = sorted(
            threads_dict.values(),
            key=lambda x: x.get("last_timestamp", ""),
            reverse=True,
        )
        return Response({
            "count": len(threads_list),
            "threads": threads_list,
        }, status=status.HTTP_200_OK)
