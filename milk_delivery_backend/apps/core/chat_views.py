import json
import time
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.core.cache import cache
from apps.accounts.models import SupportMessage, User
from apps.core.permissions import IsAdminOrStaff


def _clean_phone_digits(phone):
    digits = "".join(filter(str.isdigit, str(phone or "")))
    return digits[-10:] if len(digits) >= 10 else digits


def _get_redis_chat_key(phone):
    clean = _clean_phone_digits(phone)
    return f"chat_history_{clean}"


def _get_active_threads_key():
    return "active_support_chat_threads"


class SupportChatSendView(APIView):
    """
    Send a message into the persistent PostgreSQL database and Redis chat stream.
    POST /api/support/chat/send/
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        sender_type = request.data.get("sender_type", "user")  # 'user' or 'agent'
        sender_name = request.data.get("sender_name", "Customer")
        text = request.data.get("text", "").strip()
        order_id = request.data.get("order_id")

        if not phone or not text:
            return Response({"error": "phone and text are required"}, status=status.HTTP_400_BAD_REQUEST)

        clean_phone = _clean_phone_digits(phone)
        matched_user = User.objects.filter(phone__endswith=clean_phone).first()

        # 1. Save message to PostgreSQL
        supp_msg = SupportMessage.objects.create(
            phone=phone,
            user=matched_user,
            sender_type=sender_type,
            sender_name=sender_name if sender_name else ("Support Executive" if sender_type == "agent" else "Customer"),
            text=text,
            order_id=order_id,
            is_read=False,
        )

        msg_obj = {
            "id": f"msg_{supp_msg.id}",
            "sender_type": supp_msg.sender_type,
            "sender_name": supp_msg.sender_name,
            "text": supp_msg.text,
            "order_id": supp_msg.order_id,
            "timestamp": supp_msg.created_at.isoformat(),
        }

        # 2. Update Redis Cache Stream
        chat_key = _get_redis_chat_key(phone)
        history = cache.get(chat_key) or []
        history.append(msg_obj)
        if len(history) > 150:
            history = history[-150:]
        cache.set(chat_key, history, timeout=14 * 86400)

        # 3. Update active threads in Redis
        threads = cache.get(_get_active_threads_key()) or {}
        cust_name = matched_user.get_full_name() if matched_user and matched_user.get_full_name() else (sender_name if sender_type == "user" else threads.get(clean_phone, {}).get("customer_name", "Customer"))
        threads[clean_phone] = {
            "phone": phone,
            "clean_phone": clean_phone,
            "customer_name": cust_name,
            "last_message": text,
            "last_timestamp": timezone.now().isoformat(),
            "unread_count": (threads.get(clean_phone, {}).get("unread_count", 0) + 1) if sender_type == "user" else 0,
        }
        cache.set(_get_active_threads_key(), threads, timeout=14 * 86400)

        # 4. First-Time Welcome Greeting only if 0 previous messages exist
        auto_reply = None
        user_msg_count = SupportMessage.objects.filter(phone__endswith=clean_phone).count()
        if sender_type == "user" and user_msg_count <= 1:
            reply_text = f"👋 Hello {cust_name}! Connected to MilkDrop Live Support Desk. How can our team assist you today?"
            bot_msg = SupportMessage.objects.create(
                phone=phone,
                user=matched_user,
                sender_type="agent",
                sender_name="Priya (MilkDrop Support)",
                text=reply_text,
                order_id=order_id,
            )
            auto_reply = {
                "id": f"msg_{bot_msg.id}",
                "sender_type": "agent",
                "sender_name": bot_msg.sender_name,
                "text": bot_msg.text,
                "order_id": order_id,
                "timestamp": bot_msg.created_at.isoformat(),
            }
            history.append(auto_reply)
            cache.set(chat_key, history, timeout=14 * 86400)

        # 5. Broadcast real-time Redis WebSocket event
        try:
            from apps.core.consumers import broadcast_hub_event
            broadcast_hub_event("SUPPORT_DESK", "support_message", {
                "phone": phone,
                "clean_phone": clean_phone,
                "customer_name": cust_name,
                "sender_type": sender_type,
                "text": text,
                "timestamp": msg_obj["timestamp"],
            })
        except Exception:
            pass

        return Response({
            "status": "SENT",
            "message": msg_obj,
            "auto_reply": auto_reply,
            "total_messages": SupportMessage.objects.filter(phone__endswith=clean_phone).count(),
        }, status=status.HTTP_200_OK)


class SupportChatHistoryView(APIView):
    """
    Retrieve PostgreSQL + Redis chat history for a customer phone number.
    GET /api/support/chat/history/?phone=...
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        phone = request.query_params.get("phone", "").strip()
        if not phone:
            return Response({"error": "phone query parameter is required"}, status=status.HTTP_400_BAD_REQUEST)

        clean_phone = _clean_phone_digits(phone)

        # Fetch from PostgreSQL DB
        db_messages = SupportMessage.objects.filter(phone__endswith=clean_phone).order_by("created_at")
        if db_messages.exists():
            messages_list = [
                {
                    "id": f"msg_{m.id}",
                    "sender_type": m.sender_type,
                    "sender_name": m.sender_name,
                    "text": m.text,
                    "order_id": m.order_id,
                    "timestamp": m.created_at.isoformat(),
                }
                for m in db_messages
            ]
        else:
            chat_key = _get_redis_chat_key(phone)
            messages_list = cache.get(chat_key) or []

        return Response({
            "phone": phone,
            "clean_phone": clean_phone,
            "count": len(messages_list),
            "messages": messages_list,
        }, status=status.HTTP_200_OK)


class AdminSupportChatThreadsView(APIView):
    """
    Admin endpoint to view all customer support chat threads from PostgreSQL & Redis.
    GET /api/admin/support/threads/
    """
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        from django.db.models import Max

        # 1. Query distinct customer phones with messages in PostgreSQL
        phones_with_msgs = (
            SupportMessage.objects.values("phone")
            .annotate(last_created=Max("created_at"))
            .order_by("-last_created")
        )

        threads_dict = {}
        for item in phones_with_msgs:
            raw_phone = item["phone"]
            clean_digits = _clean_phone_digits(raw_phone)
            last_msg = SupportMessage.objects.filter(phone__endswith=clean_digits).order_by("-created_at").first()
            matched_user = User.objects.filter(phone__endswith=clean_digits).first()

            cust_name = matched_user.get_full_name() if matched_user and matched_user.get_full_name() else (matched_user.username if matched_user else f"Customer {clean_digits[-4:]}")
            unread_count = SupportMessage.objects.filter(phone__endswith=clean_digits, sender_type="user", is_read=False).count()

            threads_dict[clean_digits] = {
                "phone": raw_phone,
                "clean_phone": clean_digits,
                "customer_name": cust_name,
                "customer_address": matched_user.address if matched_user else "Kodad",
                "last_message": last_msg.text if last_msg else "Active thread",
                "last_timestamp": last_msg.created_at.isoformat() if last_msg else timezone.now().isoformat(),
                "unread_count": unread_count,
            }

        # 2. Overlay any active Redis memory threads
        redis_threads = cache.get(_get_active_threads_key()) or {}
        for clean_digits, r_thread in redis_threads.items():
            if clean_digits not in threads_dict:
                threads_dict[clean_digits] = r_thread

        threads_list = sorted(
            threads_dict.values(),
            key=lambda x: x.get("last_timestamp", ""),
            reverse=True,
        )

        return Response({
            "count": len(threads_list),
            "threads": threads_list,
        }, status=status.HTTP_200_OK)
