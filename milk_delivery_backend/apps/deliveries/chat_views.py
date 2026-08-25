from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.core.cache import cache
from .models import DeliveryChatMessage, DeliveryTask, LiveOrder


def _get_delivery_chat_cache_key(channel_key):
    return f"deliv_chat_{channel_key}"


class DeliveryChatSendView(APIView):
    """
    Send an in-app message between Driver and Customer for a delivery.
    POST /api/deliveries/chat/send/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        channel_key = request.data.get("channel_key") or request.data.get("channel") or ""
        task_id = request.data.get("task_id")
        order_id = request.data.get("order_id")
        sender_role = request.data.get("sender_role", "DRIVER").upper()  # 'DRIVER' or 'CUSTOMER'
        sender_name = request.data.get("sender_name", "Delivery Partner")
        sender_phone = request.data.get("sender_phone", "")
        text = request.data.get("text", "").strip()

        if not channel_key and task_id:
            channel_key = f"delivery_task_{task_id}"
        elif not channel_key and order_id:
            channel_key = f"delivery_order_{order_id}"

        if not channel_key or not text:
            return Response(
                {"error": "channel_key and text are required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        task_obj = None
        if task_id:
            try:
                task_obj = DeliveryTask.objects.filter(pk=int(task_id)).first()
            except (ValueError, TypeError):
                pass

        order_obj = None
        if order_id:
            try:
                order_obj = LiveOrder.objects.filter(pk=str(order_id)).first()
            except Exception:
                pass

        # 1. Save to PostgreSQL
        msg = DeliveryChatMessage.objects.create(
            channel_key=channel_key,
            task=task_obj,
            order=order_obj,
            sender_role=sender_role,
            sender_name=sender_name,
            sender_phone=sender_phone,
            text=text,
        )

        msg_payload = {
            "id": msg.id,
            "channel_key": msg.channel_key,
            "task_id": task_id,
            "order_id": order_id,
            "sender_role": msg.sender_role,
            "sender_name": msg.sender_name,
            "sender_phone": msg.sender_phone,
            "text": msg.text,
            "is_driver": msg.sender_role == "DRIVER",
            "timestamp": msg.created_at.isoformat(),
        }

        # 2. Update Redis Cache Stream
        cache_key = _get_delivery_chat_cache_key(channel_key)
        history = cache.get(cache_key) or []
        history.append(msg_payload)
        if len(history) > 100:
            history = history[-100:]
        cache.set(cache_key, history, timeout=7 * 86400)

        return Response({"status": "success", "message": msg_payload}, status=status.HTTP_201_CREATED)


class DeliveryChatHistoryView(APIView):
    """
    Retrieve real-time conversation history for a delivery channel.
    GET /api/deliveries/chat/history/?channel=...&task_id=...
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        channel_key = request.query_params.get("channel") or request.query_params.get("channel_key") or ""
        task_id = request.query_params.get("task_id")
        order_id = request.query_params.get("order_id")

        if not channel_key and task_id:
            channel_key = f"delivery_task_{task_id}"
        elif not channel_key and order_id:
            channel_key = f"delivery_order_{order_id}"

        if not channel_key:
            return Response(
                {"error": "channel or task_id required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cache_key = _get_delivery_chat_cache_key(channel_key)
        cached_messages = cache.get(cache_key)

        if cached_messages is not None and len(cached_messages) > 0:
            return Response({"status": "success", "channel_key": channel_key, "messages": cached_messages})

        # Query PostgreSQL
        db_messages = DeliveryChatMessage.objects.filter(channel_key=channel_key).order_by("created_at")
        results = []
        for m in db_messages:
            results.append({
                "id": m.id,
                "channel_key": m.channel_key,
                "task_id": m.task_id,
                "order_id": m.order_id,
                "sender_role": m.sender_role,
                "sender_name": m.sender_name,
                "sender_phone": m.sender_phone,
                "text": m.text,
                "is_driver": m.sender_role == "DRIVER",
                "timestamp": m.created_at.isoformat(),
            })

        cache.set(cache_key, results, timeout=7 * 86400)
        return Response({"status": "success", "channel_key": channel_key, "messages": results})
